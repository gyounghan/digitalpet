import '../entities/daily_goals.dart';
import '../repositories/pet_repository.dart';
import '../repositories/activity_repository.dart';

/// 카테고리별 목표 점수 계산 유스케이스
///
/// "오늘"의 누적이 아니라 **현재 진행 중인 목표**의 진행도를 계산한다.
/// 포만감/수면/운동 각각 독립된 카운터를 가지며, 목표를 달성하면
/// 즉시 다음 목표로 리셋된다(차감). 진행도는 자정에 리셋되지 않고 이월되며,
/// **달성(EXP 지급) 횟수만 카테고리당 하루 최대 3회로 캡**된다
/// (todayXxxAchievedCount로 추적, 자정 리셋 — 초과 진행분은 다음 날 소화).
///
/// 현실적 목표 (보건 권장량 + 평균 사용자 수치 기반):
/// 레벨이 올라도 목표치는 거의 올리지 않는다 — 습관 앱에서 목표 상향은
/// 이탈 요인이므로 낮은 캡에서 고정하고, 성장 난이도는 레벨별 필요
/// 경험치([Pet.getRequiredExpForLevel])가 담당한다.
/// - 포만감: 1~5=1회, 6+=2회 (캡)
/// - 수면:   1~10=5시간, 11+=6시간 (캡 — 권장 최저 수준 유지)
/// - 운동:   1~5=3,000보(10분), 6+=4,000보(15분) (캡)
class CalculateDailyGoalsScoreUseCase {
  final PetRepository petRepository;
  final ActivityRepository activityRepository;

  /// 카테고리 1회 달성 시 부여 경험치
  /// (ApplyDailyGoalsScoreUseCase가 expGain을 통해 실제 지급)
  static const int expPerCategory = 20;

  /// "세트"(포만감+수면+운동 모두 달성) 1회 완성 시 기본 경험치
  /// 오늘 N번째 세트는 setExpBase >> N 으로 반감 지급 → 60, 30, 15, 7, 3, 1, 0...
  static const int setExpBase = 60;

  /// 세트 마일스톤(10세트 누적 완성) 시 추가 보너스 경험치
  /// 반감과 무관하게 누적 세트 워터마크 기반으로 부여 → RPG 마일스톤 보상
  static const int tierUpBonusExp = 50;

  /// 카테고리당 하루 최대 달성(EXP 지급) 횟수
  /// 오늘 이미 달성한 횟수(todayXxxAchievedCount)를 차감한 잔여만 지급 —
  /// 장기 백그라운드 후 폭발적 지급도 함께 방지된다.
  static const int maxAchievementsPerDay = 3;

  static int getFeedGoalCount(int level) {
    if (level <= 5) return 1;
    return 2;
  }

  static int getSleepGoalHours(int level) {
    if (level <= 10) return 5;
    return 6;
  }

  static int getExerciseGoalSteps(int level) {
    if (level <= 5) return 3000;
    return 4000;
  }

  static int getExerciseGoalMinutes(int level) {
    if (level <= 5) return 10;
    return 15;
  }

  CalculateDailyGoalsScoreUseCase({
    required this.petRepository,
    required this.activityRepository,
  });

  Future<DailyGoalsScore> call(String petId) async {
    var pet = await petRepository.getPet(petId);

    // 자정 넘어간 경우 보조 카운터만 리셋 (목표 진행도는 유지)
    if (pet.needsGoalReset) {
      pet = pet.resetDailyGoals();
      await petRepository.updatePet(pet);
    }

    final feedGoalCount = getFeedGoalCount(pet.level);
    final sleepGoalHours = getSleepGoalHours(pet.level);
    final sleepGoalMinutes = sleepGoalHours * 60;
    final exerciseGoalSteps = getExerciseGoalSteps(pet.level);
    final exerciseGoalMinutes = getExerciseGoalMinutes(pet.level);

    // 오늘 실시간 활동 데이터로 totalSteps/Minutes 반영 여부 판단
    // (이미 updateFromActivityUseCase가 totalSteps를 갱신해두었음)
    final currentExerciseSteps = pet.exerciseProgressSteps;
    final currentExerciseMinutes = pet.exerciseProgressMinutes;

    // 달성 가능 횟수 계산 — 하루 캡(3회)에서 오늘 이미 달성한 횟수를 차감
    final feedRemainingToday =
        (maxAchievementsPerDay - pet.todayFeedAchievedCount).clamp(0, maxAchievementsPerDay);
    final sleepRemainingToday =
        (maxAchievementsPerDay - pet.todaySleepAchievedCount).clamp(0, maxAchievementsPerDay);
    final exerciseRemainingToday =
        (maxAchievementsPerDay - pet.todayExerciseAchievedCount).clamp(0, maxAchievementsPerDay);

    final feedAchievements = feedGoalCount > 0
        ? (pet.todayFeedCount ~/ feedGoalCount)
            .clamp(0, feedRemainingToday)
        : 0;
    final sleepAchievements = sleepGoalMinutes > 0
        ? (pet.todaySleepMinutes ~/ sleepGoalMinutes)
            .clamp(0, sleepRemainingToday)
        : 0;

    // 운동 목표는 걸음(steps)만으로 판정한다. (걸음과 운동분은 별도 원천이라
    // max로 묶으면 안 쓴 축이 남아 이중 카운트되던 문제 → 걸음 단일화)
    final stepsAchievements = exerciseGoalSteps > 0
        ? (currentExerciseSteps ~/ exerciseGoalSteps)
            .clamp(0, exerciseRemainingToday)
        : 0;
    final exerciseAchievements = stepsAchievements;

    // UI용: "현재 진행 중인 목표"에 대한 표시값
    final feedProgressDisplay = pet.todayFeedCount % feedGoalCount;
    final sleepHoursDisplay =
        (pet.todaySleepMinutes % sleepGoalMinutes) ~/ 60;
    final exerciseStepsDisplay = currentExerciseSteps % exerciseGoalSteps;
    final exerciseMinutesDisplay =
        currentExerciseMinutes % exerciseGoalMinutes;

    final dailyGoals = DailyGoals(
      date: pet.todayDateString,
      feedGoalAchieved: feedAchievements > 0,
      sleepGoalAchieved: sleepAchievements > 0,
      exerciseGoalAchieved: exerciseAchievements > 0,
      feedProgress: feedProgressDisplay,
      sleepHours: sleepHoursDisplay,
      exerciseSteps: exerciseStepsDisplay,
      exerciseMinutes: exerciseMinutesDisplay,
      feedAchievedCount: pet.feedAchievedCount,
      sleepAchievedCount: pet.sleepAchievedCount,
      exerciseAchievedCount: pet.exerciseAchievedCount,
    );

    // 티어 업 개수 = 각 카테고리 달성으로 (이전 카운트 + 달성)이 10의 배수를 넘는 횟수
    final feedTierUps = _countTierUps(pet.feedAchievedCount, feedAchievements);
    final sleepTierUps =
        _countTierUps(pet.sleepAchievedCount, sleepAchievements);
    final exerciseTierUps =
        _countTierUps(pet.exerciseAchievedCount, exerciseAchievements);
    final totalTierUps = feedTierUps + sleepTierUps + exerciseTierUps;

    final expGain = (feedAchievements +
                sleepAchievements +
                exerciseAchievements) *
            expPerCategory +
        totalTierUps * tierUpBonusExp;

    return DailyGoalsScore(
      dailyGoals: dailyGoals,
      score: dailyGoals.totalScore,
      expGain: expGain,
      feedGoalCount: feedGoalCount,
      sleepGoalHours: sleepGoalHours,
      exerciseGoalSteps: exerciseGoalSteps,
      exerciseGoalMinutes: exerciseGoalMinutes,
      feedAchievements: feedAchievements,
      sleepAchievements: sleepAchievements,
      exerciseAchievements: exerciseAchievements,
      tierUps: totalTierUps,
      goalStreakCount: pet.goalStreakCount,
      isExpired: false,
    );
  }

  /// 이전 카운트에서 [gain]만큼 증가했을 때 10의 배수를 넘긴 횟수
  int _countTierUps(int prevCount, int gain) {
    if (gain <= 0) return 0;
    final prevTier = prevCount ~/ 10;
    final newTier = (prevCount + gain) ~/ 10;
    return newTier - prevTier;
  }
}

/// 카테고리별 목표 점수 결과
class DailyGoalsScore {
  final DailyGoals dailyGoals;
  final int score;
  final int expGain;
  final int feedGoalCount;
  final int sleepGoalHours;
  final int exerciseGoalSteps;
  final int exerciseGoalMinutes;

  /// 이번 계산 사이클에서 달성된 횟수 (Apply에서 차감 처리)
  final int feedAchievements;
  final int sleepAchievements;
  final int exerciseAchievements;

  /// 이번 달성으로 발생한 총 티어 업 개수
  final int tierUps;

  /// 과거 호환
  final int goalStreakCount;
  final bool isExpired;

  /// 오늘 처음 달성하여 EXP 대상인지 여부 (UI 호환용)
  bool get feedNewlyAchieved => feedAchievements > 0;
  bool get sleepNewlyAchieved => sleepAchievements > 0;
  bool get exerciseNewlyAchieved => exerciseAchievements > 0;

  DailyGoalsScore({
    required this.dailyGoals,
    required this.score,
    required this.expGain,
    required this.feedGoalCount,
    required this.sleepGoalHours,
    required this.exerciseGoalSteps,
    required this.exerciseGoalMinutes,
    this.feedAchievements = 0,
    this.sleepAchievements = 0,
    this.exerciseAchievements = 0,
    this.tierUps = 0,
    this.goalStreakCount = 0,
    this.isExpired = false,
  });
}
