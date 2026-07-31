import '../entities/pet.dart';
import '../repositories/pet_repository.dart';
import 'calculate_daily_goals_score_usecase.dart';

/// 카테고리별 목표 점수 적용 유스케이스
///
/// 달성이 감지된 카테고리별로:
///  - 해당 진행도에서 목표치만큼 차감 (다음 목표로 이어짐)
///  - 카테고리 달성 카운트를 증가시키고 경험치를 부여
///    (카테고리당 expPerCategory — 한 카테고리만 해도 성장 가능)
///  - 3종 모두 달성한 "세트"에는 반감 보너스 EXP 추가 지급
///  - 티어 업/세트 마일스톤 시 추가 보너스 EXP 부여
///
/// 하루 리셋/페널티 로직은 없다.
class ApplyDailyGoalsScoreUseCase {
  final PetRepository petRepository;
  final CalculateDailyGoalsScoreUseCase calculateScoreUseCase;

  ApplyDailyGoalsScoreUseCase({
    required this.petRepository,
    required this.calculateScoreUseCase,
  });

  Future<Pet> call(String petId) async {
    var pet = await petRepository.getPet(petId);
    if (pet.isDead) return pet;

    if (pet.needsGoalReset) {
      pet = pet.resetDailyGoals();
      await petRepository.updatePet(pet);
    }

    final scoreResult = await calculateScoreUseCase(petId);
    final todayDate = pet.todayDateString;

    // 포만감: feedGoalCount만큼 달성 횟수만큼 차감
    if (scoreResult.feedAchievements > 0) {
      final consumed = scoreResult.feedGoalCount * scoreResult.feedAchievements;
      pet = pet.copyWith(
        todayFeedCount: (pet.todayFeedCount - consumed).clamp(0, 1 << 30),
        feedAchievedCount:
            pet.feedAchievedCount + scoreResult.feedAchievements,
        todayFeedAchievedCount:
            pet.todayFeedAchievedCount + scoreResult.feedAchievements,
        lastFeedAchievedDate: todayDate,
      );
    }

    // 수면: sleepGoalHours * 60 만큼 차감, todaySleepHours 재계산
    if (scoreResult.sleepAchievements > 0) {
      final consumedMinutes =
          scoreResult.sleepGoalHours * 60 * scoreResult.sleepAchievements;
      final remainingMinutes =
          (pet.todaySleepMinutes - consumedMinutes).clamp(0, 1 << 30);
      pet = pet.copyWith(
        todaySleepMinutes: remainingMinutes,
        todaySleepHours: remainingMinutes ~/ 60,
        sleepAchievedCount:
            pet.sleepAchievedCount + scoreResult.sleepAchievements,
        todaySleepAchievedCount:
            pet.todaySleepAchievedCount + scoreResult.sleepAchievements,
        lastSleepAchievedDate: todayDate,
      );
    }

    // 운동: 걸음(steps) 단일 축만 차감 (걸음만 판정하므로 이중 카운트 없음)
    if (scoreResult.exerciseAchievements > 0) {
      final consumedSteps =
          scoreResult.exerciseGoalSteps * scoreResult.exerciseAchievements;
      pet = pet.copyWith(
        lastExerciseGoalSteps: pet.lastExerciseGoalSteps + consumedSteps,
        exerciseAchievedCount:
            pet.exerciseAchievedCount + scoreResult.exerciseAchievements,
        todayExerciseAchievedCount:
            pet.todayExerciseAchievedCount + scoreResult.exerciseAchievements,
        lastExerciseAchievedDate: todayDate,
      );
    }

    // 카테고리 독립 EXP: 달성한 카테고리마다 expPerCategory(+티어업 보너스)
    // 부여 — 한 카테고리만 꾸준히 해도 성장 가능 (좌식/부분참여 사용자 경로).
    // scoreResult.expGain = (달성 횟수 합) × expPerCategory + 티어업 × 보너스
    final categoryExpGain = scoreResult.expGain;

    // 세트 클리어 EXP 적용 (포만감+수면+운동 모두 달성 = 1세트)
    // - 완성 세트 총량 = min(달성 카운트 3종) — 셋을 다 채워야 한 세트
    // - 신규 세트 = 완성 세트 총량 - 누적 보상 세트(totalSetsRewarded)
    // - 오늘 N번째 세트는 setExpBase >> N 으로 반감 (60, 30, 15, 7, 3, 1, 0...)
    //   todaySetExpClaimed는 자정 resetDailyGoals에서 0으로 리셋 → 매일 풀 사이클
    final completedSets = [
      pet.feedAchievedCount,
      pet.sleepAchievedCount,
      pet.exerciseAchievedCount,
    ].reduce((a, b) => a < b ? a : b);
    final newSets = (completedSets - pet.totalSetsRewarded).clamp(0, 1 << 30);

    final setExpGain = _setExpForRange(pet.todaySetExpClaimed, newSets);

    // 세트 마일스톤 보너스: 누적 세트가 10의 배수를 넘을 때마다 +tierUpBonusExp
    final setMilestones =
        _countMilestones(pet.totalSetsRewarded, newSets);
    final milestoneBonusExp =
        setMilestones * CalculateDailyGoalsScoreUseCase.tierUpBonusExp;

    final totalExpGain = categoryExpGain + setExpGain + milestoneBonusExp;

    // 아무 변화가 없으면 저장하지 않는다 — 매 호출마다 lastUpdated를 밀면
    // 서버 sync의 "서버가 최신" 회수 경로가 영영 실행되지 못한다.
    // (feed/login 등이 쌓아둔 미소화 EXP는 레벨업 처리를 위해 계속 진행)
    final hasAchievements = scoreResult.feedAchievements > 0 ||
        scoreResult.sleepAchievements > 0 ||
        scoreResult.exerciseAchievements > 0;
    final hasPendingLevelUp =
        pet.exp + totalExpGain >= Pet.getRequiredExpForLevel(pet.level);
    if (!hasAchievements &&
        newSets == 0 &&
        totalExpGain == 0 &&
        !hasPendingLevelUp) {
      return pet;
    }

    // 세트 보상 카운터 갱신 (오늘 받은 세트 + 누적 워터마크)
    pet = pet.copyWith(
      todaySetExpClaimed: pet.todaySetExpClaimed + newSets,
      totalSetsRewarded: pet.totalSetsRewarded + newSets,
    );

    var currentExp = pet.exp + totalExpGain;
    var currentLevel = pet.level;
    int levelUps = 0;

    while (true) {
      final requiredExp = Pet.getRequiredExpForLevel(currentLevel);
      if (currentExp >= requiredExp) {
        currentExp -= requiredExp;
        currentLevel++;
        levelUps++;
      } else {
        break;
      }
    }

    final levelUpStatBonus = levelUps * 10;
    final currentTime = DateTime.now().millisecondsSinceEpoch;

    final updatedPet = pet.copyWith(
      exp: currentExp,
      level: currentLevel,
      hunger: (pet.hunger + levelUpStatBonus).clamp(0, 100),
      happiness: (pet.happiness + levelUpStatBonus).clamp(0, 100),
      stamina: (pet.stamina + levelUpStatBonus).clamp(0, 100),
      lastUpdated: currentTime,
    );

    await petRepository.updatePet(updatedPet);
    return updatedPet;
  }

  /// 세트 반감 EXP 계산
  ///
  /// 오늘 이미 [alreadyClaimed]세트의 EXP를 받은 상태에서 [newSets]세트를
  /// 추가로 완성했을 때 부여할 총 EXP. 오늘 N번째(0-based) 세트는
  /// `setExpBase >> N` EXP를 준다 — 60, 30, 15, 7, 3, 1, 0, ...
  ///
  /// 예) alreadyClaimed=0, newSets=3 → 60 + 30 + 15 = 105
  ///     alreadyClaimed=2, newSets=2 → 15 +  7      =  22
  int _setExpForRange(int alreadyClaimed, int newSets) {
    if (newSets <= 0) return 0;
    int sum = 0;
    for (int i = 0; i < newSets; i++) {
      final shift = alreadyClaimed + i;
      // shift가 너무 크면 0 — bit shift overflow 방지
      if (shift >= 32) break;
      sum += CalculateDailyGoalsScoreUseCase.setExpBase >> shift;
    }
    return sum;
  }

  /// 누적 세트가 [base]에서 [gain]만큼 증가했을 때 10의 배수를 넘긴 횟수
  int _countMilestones(int base, int gain) {
    if (gain <= 0) return 0;
    final prevTier = base ~/ 10;
    final newTier = (base + gain) ~/ 10;
    return newTier - prevTier;
  }
}
