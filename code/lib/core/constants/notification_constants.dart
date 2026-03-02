/// 알림 관련 상수
/// 알림 설정 및 제한 등을 중앙에서 관리
class NotificationConstants {
  NotificationConstants._(); // private constructor
  
  /// 하루 최대 알림 발송 횟수
  static const int maxNotificationsPerDay = 3;
  
  /// 미접속 알림 기준 시간 (시간 단위)
  static const int inactiveHoursThreshold = 6;
  
  /// 배고픔 알림 기준값
  static const int hungerThreshold = 30;
  
  /// 행복도 알림 기준값
  static const int happinessThreshold = 30;
  
  /// 알림 채널 ID
  static const String notificationChannelId = 'pet_notifications';
  
  /// 알림 채널 이름
  static const String notificationChannelName = '펫 알림';
  
  /// 알림 채널 설명
  static const String notificationChannelDescription = '펫의 감정 상태 알림';
}
