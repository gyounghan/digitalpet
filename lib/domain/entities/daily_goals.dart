/// 일일 목표 엔티티
/// 포만감, 수면, 운동 각각의 일일 목표 달성 상태를 추적
class DailyGoals {
  /// 오늘 날짜 (YYYY-MM-DD 형식)
  final String date;
  
  /// 포만감 목표 달성 여부
  /// 하루 3회 식사 (아침/점심/저녁) 완료 시 true
  final bool feedGoalAchieved;
  
  /// 수면 목표 달성 여부
  /// 하루 6시간 이상 수면 시 true
  final bool sleepGoalAchieved;
  
  /// 운동 목표 달성 여부
  /// 하루 10,000보 또는 30분 운동 시 true
  final bool exerciseGoalAchieved;
  
  /// 포만감 목표 진행도 (0~3, 식사 횟수)
  final int feedProgress;
  
  /// 수면 목표 진행도 (시간)
  final int sleepHours;
  
  /// 운동 목표 진행도 (걸음 수 또는 운동 시간)
  final int exerciseSteps;
  final int exerciseMinutes;
  
  DailyGoals({
    required this.date,
    this.feedGoalAchieved = false,
    this.sleepGoalAchieved = false,
    this.exerciseGoalAchieved = false,
    this.feedProgress = 0,
    this.sleepHours = 0,
    this.exerciseSteps = 0,
    this.exerciseMinutes = 0,
  });
  
  /// 일일 목표 달성 점수 계산
  /// 
  /// 각 목표 달성 시 점수:
  /// - 포만감: 1점
  /// - 수면: 1점
  /// - 운동: 1점
  /// 
  /// 반환: 총 점수 (0~3)
  int get totalScore {
    int score = 0;
    if (feedGoalAchieved) score += 1;
    if (sleepGoalAchieved) score += 1;
    if (exerciseGoalAchieved) score += 1;
    return score;
  }
  
  /// 모든 목표 달성 여부
  bool get allGoalsAchieved {
    return feedGoalAchieved && sleepGoalAchieved && exerciseGoalAchieved;
  }
  
  DailyGoals copyWith({
    String? date,
    bool? feedGoalAchieved,
    bool? sleepGoalAchieved,
    bool? exerciseGoalAchieved,
    int? feedProgress,
    int? sleepHours,
    int? exerciseSteps,
    int? exerciseMinutes,
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
    );
  }
}
