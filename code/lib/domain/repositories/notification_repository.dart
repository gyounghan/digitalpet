/// 알림 저장소 인터페이스
/// Domain 레이어에서 정의하며, Data 레이어에서 구현
/// 
/// 알림 발송 기록 및 설정을 관리
abstract class NotificationRepository {
  /// 오늘 발송한 알림 횟수 조회
  /// 
  /// 반환: 오늘 발송한 알림 횟수
  Future<int> getTodayNotificationCount();
  
  /// 알림 발송 기록 추가
  /// 
  /// 알림을 발송했을 때 기록을 저장
  Future<void> recordNotification();
  
  /// 마지막 접속 시간 조회
  /// 
  /// 반환: 마지막 접속 시간 (밀리초 단위 Unix timestamp)
  Future<int?> getLastAccessTime();
  
  /// 마지막 접속 시간 업데이트
  /// 
  /// [timestamp] 업데이트할 시간 (밀리초 단위 Unix timestamp)
  Future<void> updateLastAccessTime(int timestamp);
  
  /// 오늘 날짜의 알림 기록 초기화 (자정 경과 시)
  /// 
  /// 날짜가 바뀌면 알림 기록을 초기화
  Future<void> resetDailyNotificationCount();
}
