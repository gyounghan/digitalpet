/// 일일 목표 엔티티
/// 포만감, 수면, 운동 각각의 일일 목표 달성 상태를 추적
///
/// 각 카테고리는 독립적으로 티어(누적 달성 10회마다 1단계)가 존재하며,
/// 하나만 꾸준히 달성해도 경험치가 쌓여 레벨업이 가능하다.
class DailyGoals {
  /// 오늘 날짜 (YYYY-MM-DD 형식)
  final String date;

  /// 포만감 목표 달성 여부
  final bool feedGoalAchieved;

  /// 수면 목표 달성 여부
  final bool sleepGoalAchieved;

  /// 운동 목표 달성 여부
  final bool exerciseGoalAchieved;

  /// 포만감 목표 진행도 (식사 횟수)
  final int feedProgress;

  /// 수면 목표 진행도 (시간)
  final int sleepHours;

  /// 운동 목표 진행도 (걸음 수)
  final int exerciseSteps;

  /// 운동 목표 진행도 (분)
  final int exerciseMinutes;

  /// 포만감 카테고리 누적 달성 횟수
  final int feedAchievedCount;

  /// 수면 카테고리 누적 달성 횟수
  final int sleepAchievedCount;

  /// 운동 카테고리 누적 달성 횟수
  final int exerciseAchievedCount;

  DailyGoals({
    required this.date,
    this.feedGoalAchieved = false,
    this.sleepGoalAchieved = false,
    this.exerciseGoalAchieved = false,
    this.feedProgress = 0,
    this.sleepHours = 0,
    this.exerciseSteps = 0,
    this.exerciseMinutes = 0,
    this.feedAchievedCount = 0,
    this.sleepAchievedCount = 0,
    this.exerciseAchievedCount = 0,
  });

  /// 일일 목표 달성 점수 계산 (각 목표 1점, 최대 3점)
  /// 표시용 점수이며 경험치 계산에는 사용되지 않는다.
  int get totalScore {
    int score = 0;
    if (feedGoalAchieved) score += 1;
    if (sleepGoalAchieved) score += 1;
    if (exerciseGoalAchieved) score += 1;
    return score;
  }

  /// 모든 목표 달성 여부 (UI 표시용)
  bool get allGoalsAchieved {
    return feedGoalAchieved && sleepGoalAchieved && exerciseGoalAchieved;
  }

  /// 티어 (달성 10회마다 1단계)
  int get feedTier => feedAchievedCount ~/ 10;
  int get sleepTier => sleepAchievedCount ~/ 10;
  int get exerciseTier => exerciseAchievedCount ~/ 10;

  /// 다음 티어까지 남은 달성 횟수
  int get feedRemainingToNextTier => 10 - (feedAchievedCount % 10);
  int get sleepRemainingToNextTier => 10 - (sleepAchievedCount % 10);
  int get exerciseRemainingToNextTier => 10 - (exerciseAchievedCount % 10);

  DailyGoals copyWith({
    String? date,
    bool? feedGoalAchieved,
    bool? sleepGoalAchieved,
    bool? exerciseGoalAchieved,
    int? feedProgress,
    int? sleepHours,
    int? exerciseSteps,
    int? exerciseMinutes,
    int? feedAchievedCount,
    int? sleepAchievedCount,
    int? exerciseAchievedCount,
  }) {
    return DailyGoals(
      date: date ?? this.date,
      feedGoalAchieved: feedGoalAchieved ?? this.feedGoalAchieved,
      sleepGoalAchieved: sleepGoalAchieved ?? this.sleepGoalAchieved,
      exerciseGoalAchieved: exerciseGoalAchieved ?? this.exerciseGoalAchieved,
      feedProgress: feedProgress ?? this.feedProgress,
      sleepHours: sleepHours ?? this.sleepHours,
      exerciseSteps: exerciseSteps ?? this.exerciseSteps,
      exerciseMinutes: exerciseMinutes ?? this.exerciseMinutes,
      feedAchievedCount: feedAchievedCount ?? this.feedAchievedCount,
      sleepAchievedCount: sleepAchievedCount ?? this.sleepAchievedCount,
      exerciseAchievedCount:
          exerciseAchievedCount ?? this.exerciseAchievedCount,
    );
  }
}
