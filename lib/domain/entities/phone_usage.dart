/// 폰 사용 상태 추적 엔티티
/// Domain 레이어의 순수 Dart 클래스로, 폰 사용 패턴을 추적하는 모델
class PhoneUsage {
  /// 마지막으로 앱이 포그라운드에 있었던 시간 (타임스탬프)
  /// 밀리초 단위 Unix timestamp
  final int lastForegroundTime;
  
  /// 마지막으로 앱이 백그라운드로 간 시간 (타임스탬프)
  /// 밀리초 단위 Unix timestamp (null일 수 있음)
  final int? lastBackgroundTime;
  
  /// 누적 미사용 시간 (시간 단위)
  /// 앱이 백그라운드에 있던 시간의 누적
  final int totalIdleHours;
  
  PhoneUsage({
    required this.lastForegroundTime,
    this.lastBackgroundTime,
    required this.totalIdleHours,
  });
  
  /// PhoneUsage 객체 복사본 생성
  PhoneUsage copyWith({
    int? lastForegroundTime,
    int? lastBackgroundTime,
    int? totalIdleHours,
  }) {
    return PhoneUsage(
      lastForegroundTime: lastForegroundTime ?? this.lastForegroundTime,
      lastBackgroundTime: lastBackgroundTime ?? this.lastBackgroundTime,
      totalIdleHours: totalIdleHours ?? this.totalIdleHours,
    );
  }
  
  /// 현재 시간 기준으로 미사용 시간 계산 (분 단위)
  /// 
  /// 앱이 백그라운드에 있으면 마지막 포그라운드 시간부터의 경과 시간을 반환
  /// 앱이 포그라운드에 있으면 0을 반환
  int getIdleMinutes({required bool isInBackground}) {
    if (!isInBackground) {
      return 0;
    }
    
    final currentTime = DateTime.now().millisecondsSinceEpoch;
    final elapsedMilliseconds = currentTime - lastForegroundTime;
    return elapsedMilliseconds ~/ (1000 * 60); // 분 단위로 변환
  }
  
  /// 미사용 상태인지 확인
  /// 
  /// [idleThresholdMinutes] 미사용으로 간주할 최소 시간 (분)
  /// 
  /// 반환: 미사용 상태이면 true
  bool isIdle({required bool isInBackground, int idleThresholdMinutes = 30}) {
    if (!isInBackground) {
      return false;
    }
    
    return getIdleMinutes(isInBackground: isInBackground) >= idleThresholdMinutes;
  }
}
