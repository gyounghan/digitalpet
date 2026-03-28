import '../entities/daily_goals.dart';
import '../repositories/pet_repository.dart';
import '../repositories/activity_repository.dart';

/// 일일 목표 점수 계산 유스케이스
/// 포만감, 수면, 운동 각각의 목표 달성 여부를 확인하고 점수를 계산
/// 
/// 목표 (레벨에 따라 다름):
/// - 포만감: 레벨 1~5는 1회, 레벨 6~10은 2회, 레벨 11+는 3회
/// - 수면: 레벨 1~5는 4시간, 레벨 6~10은 5시간, 레벨 11+는 6시간
/// - 운동: 레벨 1~5는 5,000보/15분, 레벨 6~10은 7,500보/22분, 레벨 11+는 10,000보/30분
/// 
/// 점수:
/// - 각 목표 달성 시 1점씩 부여 (최대 3점)
/// - 점수에 따라 경험치 획득 (점수당 20 경험치)
class CalculateDailyGoalsScoreUseCase {
  final PetRepository petRepository;
  final ActivityRepository activityRepository;
  
  /// 점수당 경험치
  static const int expPerScore = 20;
  
  /// 레벨에 따른 포만감 목표 횟수 반환
  /// 
  /// [level] 펫의 현재 레벨
  /// 
  /// 반환: 목표 식사 횟수 (1~3)
  static int getFeedGoalCount(int level) {
    if (level <= 3) return 1;
    if (level <= 9) return 2;
    return 3;
  }

  /// 레벨에 따른 수면 목표 시간 반환 (7단계 세분화)
  static int getSleepGoalHours(int level) {
    if (level <= 3) return 3;
    if (level <= 6) return 4;
    if (level <= 9) return 5;
    if (level <= 12) return 5;
    if (level <= 15) return 6;
    if (level <= 20) return 6;
    return 7;
  }

  /// 레벨에 따른 운동 목표 걸음 수 반환 (7단계 세분화)
  static int getExerciseGoalSteps(int level) {
    if (level <= 3) return 3000;
    if (level <= 6) return 5000;
    if (level <= 9) return 6000;
    if (level <= 12) return 7000;
    if (level <= 15) return 8000;
    if (level <= 20) return 9000;
    return 10000;
  }

  /// 레벨에 따른 운동 목표 시간 반환 (7단계 세분화)
  static int getExerciseGoalMinutes(int level) {
    if (level <= 3) return 10;
    if (level <= 6) return 15;
    if (level <= 9) return 20;
    if (level <= 12) return 22;
    if (level <= 15) return 25;
    if (level <= 20) return 28;
    return 30;
  }
  
  CalculateDailyGoalsScoreUseCase({
    required this.petRepository,
    required this.activityRepository,
  });
  
  /// 목표 점수 계산 (기간제: 완료할 때까지 유지, 최대 7일)
  ///
  /// [petId] 확인할 반려동물 ID
  ///
  /// 반환: 목표 달성 점수와 경험치
  Future<DailyGoalsScore> call(String petId) async {
    // 1. 현재 Pet 조회
    var pet = await petRepository.getPet(petId);

    // 2. 목표 기간 시작일 초기화 (첫 실행 시)
    if (pet.goalStartDate.isEmpty) {
      pet = pet.copyWith(
        goalStartDate: pet.todayDateString,
        goalStartTotalSteps: pet.totalSteps,
        goalStartTotalExerciseMinutes: pet.totalExerciseMinutes,
      );
      await petRepository.updatePet(pet);
    }

    // 3. 일일 항목 리셋 확인 (식사 슬롯, 대체 액션 등)
    if (pet.needsGoalReset) {
      pet = pet.resetDailyGoals();
      await petRepository.updatePet(pet);
    }

    // 4. 7일 초과 강제 리셋 체크
    final goalDaysElapsed = pet.goalDaysElapsed;
    final isExpired = pet.needsGoalPeriodReset;

    // 5. 오늘 날짜
    final todayDate = pet.todayDateString;

    // 6. 레벨에 따른 목표 값 계산
    final feedGoalCount = getFeedGoalCount(pet.level);
    final sleepGoalHours = getSleepGoalHours(pet.level);
    final exerciseGoalSteps = getExerciseGoalSteps(pet.level);
    final exerciseGoalMinutes = getExerciseGoalMinutes(pet.level);

    // 7. 포만감 목표 확인 (기간 누적)
    final feedGoalAchieved = pet.todayFeedCount >= feedGoalCount;

    // 8. 수면 목표 확인 (기간 누적)
    final sleepGoalAchieved = pet.todaySleepHours >= sleepGoalHours;

    // 9. 운동 목표 확인 (기간 누적: totalSteps - goalStartTotalSteps + 오늘 활동)
    final todayActivity = await activityRepository.getTodayActivityData();
    final periodSteps = pet.periodExerciseSteps + todayActivity.steps;
    final periodMinutes = pet.periodExerciseMinutes + todayActivity.exerciseMinutes;
    final exerciseGoalAchieved = periodSteps >= exerciseGoalSteps ||
        periodMinutes >= exerciseGoalMinutes;

    // 10. 목표 엔티티 생성
    final dailyGoals = DailyGoals(
      date: todayDate,
      feedGoalAchieved: feedGoalAchieved,
      sleepGoalAchieved: sleepGoalAchieved,
      exerciseGoalAchieved: exerciseGoalAchieved,
      feedProgress: pet.todayFeedCount,
      sleepHours: pet.todaySleepHours,
      exerciseSteps: periodSteps,
      exerciseMinutes: periodMinutes,
    );

    // 11. 점수 계산
    final score = dailyGoals.totalScore;
    final streakBonusExp = (pet.goalStreakCount * 5).clamp(0, 25);
    final expGain = score * expPerScore + (score == 3 ? streakBonusExp : 0);

    return DailyGoalsScore(
      dailyGoals: dailyGoals,
      score: score,
      expGain: expGain,
      feedGoalCount: feedGoalCount,
      sleepGoalHours: sleepGoalHours,
      exerciseGoalSteps: exerciseGoalSteps,
      exerciseGoalMinutes: exerciseGoalMinutes,
      goalDaysElapsed: goalDaysElapsed,
      goalStreakCount: pet.goalStreakCount,
      streakBonusExp: score == 3 ? streakBonusExp : 0,
      isExpired: isExpired,
    );
  }
}

/// 일일 목표 점수 결과
class DailyGoalsScore {
  /// 일일 목표 달성 상태
  final DailyGoals dailyGoals;
  
  /// 총 점수 (0~3)
  final int score;
  
  /// 획득 경험치
  final int expGain;
  
  /// 레벨에 따른 포만감 목표 횟수
  final int feedGoalCount;
  
  /// 레벨에 따른 수면 목표 시간
  final int sleepGoalHours;
  
  /// 레벨에 따른 운동 목표 걸음 수
  final int exerciseGoalSteps;
  
  /// 레벨에 따른 운동 목표 시간 (분)
  final int exerciseGoalMinutes;

  /// 목표 기간 경과 일수
  final int goalDaysElapsed;

  /// 연속 달성 횟수
  final int goalStreakCount;

  /// 연속 달성 보너스 경험치
  final int streakBonusExp;

  /// 목표 기간 만료 여부 (7일 초과)
  final bool isExpired;

  DailyGoalsScore({
    required this.dailyGoals,
    required this.score,
    required this.expGain,
    required this.feedGoalCount,
    required this.sleepGoalHours,
    required this.exerciseGoalSteps,
    required this.exerciseGoalMinutes,
    this.goalDaysElapsed = 0,
    this.goalStreakCount = 0,
    this.streakBonusExp = 0,
    this.isExpired = false,
  });
}
