import '../entities/pet.dart';
import 'calculate_daily_goals_score_usecase.dart';

/// 오늘의 목표 진행도 — 홈 "오늘의 목표" 카드용 순수 파생 모델.
///
/// [Pet]의 진행 필드와 레벨별 목표치([CalculateDailyGoalsScoreUseCase]의
/// static getter)만으로 동기 계산한다. Repository/Future 불필요.
///
/// 달성 시 Apply 유스케이스가 진행도를 차감하므로(다음 목표로 이어짐),
/// "오늘 달성했는가"는 진행도가 아니라 `last*AchievedDate == 오늘`로 판정한다.
class TodayGoalProgress {
  /// 식사: 오늘 급식 횟수 / 목표 횟수
  final int feedProgress;
  final int feedGoal;
  final bool feedDone;

  /// 운동: 현재 목표 진행 걸음 / 목표 걸음 (표시용 — 달성 판정은 분 축도 반영)
  final int steps;
  final int stepsGoal;
  final bool exerciseDone;

  /// 수면: 오늘 수면 분 / 목표 분 (표시는 시간 단위)
  final int sleepMinutes;
  final int sleepGoalMinutes;
  final bool sleepDone;

  const TodayGoalProgress({
    required this.feedProgress,
    required this.feedGoal,
    required this.feedDone,
    required this.steps,
    required this.stepsGoal,
    required this.exerciseDone,
    required this.sleepMinutes,
    required this.sleepGoalMinutes,
    required this.sleepDone,
  });

  factory TodayGoalProgress.fromPet(Pet pet) {
    final today = pet.todayDateString;
    final feedGoal = CalculateDailyGoalsScoreUseCase.getFeedGoalCount(pet.level);
    final stepsGoal =
        CalculateDailyGoalsScoreUseCase.getExerciseGoalSteps(pet.level);
    final minutesGoal =
        CalculateDailyGoalsScoreUseCase.getExerciseGoalMinutes(pet.level);
    final sleepGoalMinutes =
        CalculateDailyGoalsScoreUseCase.getSleepGoalHours(pet.level) * 60;

    // 운동은 걸음/분 두 축 중 하나라도 채우면 달성 (Calculate와 동일 정책)
    final exerciseReached = pet.exerciseProgressSteps >= stepsGoal ||
        (minutesGoal > 0 && pet.exerciseProgressMinutes >= minutesGoal);

    return TodayGoalProgress(
      feedProgress: pet.todayFeedCount,
      feedGoal: feedGoal,
      feedDone:
          pet.lastFeedAchievedDate == today || pet.todayFeedCount >= feedGoal,
      steps: pet.exerciseProgressSteps,
      stepsGoal: stepsGoal,
      exerciseDone: pet.lastExerciseAchievedDate == today || exerciseReached,
      sleepMinutes: pet.todaySleepMinutes,
      sleepGoalMinutes: sleepGoalMinutes,
      sleepDone: pet.lastSleepAchievedDate == today ||
          pet.todaySleepMinutes >= sleepGoalMinutes,
    );
  }

  /// 진행바 비율 0.0~1.0 (달성이면 가득 채움)
  double get feedRatio => _ratio(feedDone, feedProgress, feedGoal);
  double get exerciseRatio => _ratio(exerciseDone, steps, stepsGoal);
  double get sleepRatio => _ratio(sleepDone, sleepMinutes, sleepGoalMinutes);

  /// 오늘 셋 다 달성 (= 세트 완성 상태)
  bool get allDone => feedDone && exerciseDone && sleepDone;

  static double _ratio(bool done, int value, int goal) {
    if (done) return 1.0;
    if (goal <= 0) return 1.0;
    return (value / goal).clamp(0.0, 1.0);
  }
}
