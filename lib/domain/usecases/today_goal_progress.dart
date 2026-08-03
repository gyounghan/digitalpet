import '../entities/pet.dart';
import 'calculate_daily_goals_score_usecase.dart';

/// 오늘의 목표 진행도 — 홈 "오늘의 목표" 카드용 순수 파생 모델.
///
/// [Pet]의 진행 필드와 레벨별 목표치([CalculateDailyGoalsScoreUseCase]의
/// static getter)만으로 동기 계산한다. Repository/Future 불필요.
///
/// 표시는 **누적식**: 목표를 달성하면 다음 세트 목표치가 이어진다.
///   식사 1회 목표 달성 → "1/2회" (2회째 도전 중)
///   걸음 3,000보 달성 후 500보 더 걸음 → "3.5k/6k"
/// 즉 진행 = 오늘 달성 횟수 × 단위 + 현재 잔여 진행,
///    목표 = (오늘 달성 횟수 + 1) × 단위.
/// (Apply 유스케이스가 달성 시 잔여 진행을 차감하고
///  today*AchievedCount를 증가시키는 구조를 그대로 표시로 환산)
class TodayGoalProgress {
  /// 식사: 오늘 누적 급식 진행 / 현재 도전 중인 누적 목표 횟수
  final int feedProgress;
  final int feedGoal;
  final bool feedDone;

  /// 운동: 오늘 누적 걸음 / 누적 목표 걸음
  final int steps;
  final int stepsGoal;
  final bool exerciseDone;

  /// 수면: 오늘 누적 수면 분 / 누적 목표 분 (표시는 시간 단위)
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
    final feedUnit = CalculateDailyGoalsScoreUseCase.getFeedGoalCount(pet.level);
    final stepsUnit =
        CalculateDailyGoalsScoreUseCase.getExerciseGoalSteps(pet.level);
    final sleepUnitMinutes =
        CalculateDailyGoalsScoreUseCase.getSleepGoalHours(pet.level) * 60;

    // 오늘 달성 횟수 (자정 리셋, Apply에서 증가)
    final feedN = pet.todayFeedAchievedCount;
    final sleepN = pet.todaySleepAchievedCount;
    final exerciseN = pet.todayExerciseAchievedCount;

    // "오늘 1회 이상 달성" 판정 — Apply가 아직 안 돈 순간(잔여 ≥ 단위)도 포함
    final feedDone = feedN > 0 ||
        pet.lastFeedAchievedDate == today ||
        pet.todayFeedCount >= feedUnit;
    final exerciseDone = exerciseN > 0 ||
        pet.lastExerciseAchievedDate == today ||
        pet.exerciseProgressSteps >= stepsUnit;
    final sleepDone = sleepN > 0 ||
        pet.lastSleepAchievedDate == today ||
        pet.todaySleepMinutes >= sleepUnitMinutes;

    return TodayGoalProgress(
      feedProgress: feedN * feedUnit + pet.todayFeedCount,
      feedGoal: (feedN + 1) * feedUnit,
      feedDone: feedDone,
      steps: exerciseN * stepsUnit + pet.exerciseProgressSteps,
      stepsGoal: (exerciseN + 1) * stepsUnit,
      exerciseDone: exerciseDone,
      sleepMinutes: sleepN * sleepUnitMinutes + pet.todaySleepMinutes,
      sleepGoalMinutes: (sleepN + 1) * sleepUnitMinutes,
      sleepDone: sleepDone,
    );
  }

  /// 진행바 비율 0.0~1.0 — 달성 후에도 다음 누적 목표 기준 진행률을 보여준다
  double get feedRatio => _ratio(feedProgress, feedGoal);
  double get exerciseRatio => _ratio(steps, stepsGoal);
  double get sleepRatio => _ratio(sleepMinutes, sleepGoalMinutes);

  /// 오늘 셋 다 달성 (= 세트 완성 상태)
  bool get allDone => feedDone && exerciseDone && sleepDone;

  static double _ratio(int value, int goal) {
    if (goal <= 0) return 1.0;
    return (value / goal).clamp(0.0, 1.0);
  }
}
