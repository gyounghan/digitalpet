/// 활동 데이터 엔티티
/// Domain 레이어의 순수 Dart 클래스로, 사용자의 활동 데이터를 나타내는 모델
class ActivityData {
  /// 걸음 수
  final int steps;
  
  /// 운동 시간 (분)
  final int exerciseMinutes;
  
  /// 데이터 수집 시작 시간 (타임스탬프)
  /// 밀리초 단위 Unix timestamp
  final int startTime;
  
  /// 데이터 수집 종료 시간 (타임스탬프)
  /// 밀리초 단위 Unix timestamp
  final int endTime;
  
  ActivityData({
    required this.steps,
    required this.exerciseMinutes,
    required this.startTime,
    required this.endTime,
  });
  
  /// ActivityData 객체 복사본 생성
  ActivityData copyWith({
    int? steps,
    int? exerciseMinutes,
    int? startTime,
    int? endTime,
  }) {
    return ActivityData(
      steps: steps ?? this.steps,
      exerciseMinutes: exerciseMinutes ?? this.exerciseMinutes,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
    );
  }
  
  /// 빈 ActivityData 생성
  /// 
  /// 활동 데이터가 없을 때 사용
  factory ActivityData.empty() {
    final now = DateTime.now().millisecondsSinceEpoch;
    return ActivityData(
      steps: 0,
      exerciseMinutes: 0,
      startTime: now,
      endTime: now,
    );
  }
}
