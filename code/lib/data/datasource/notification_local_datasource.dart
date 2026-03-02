import 'package:hive/hive.dart';
import '../../core/constants/hive_constants.dart';

/// 알림 로컬 데이터소스
/// Hive를 사용한 알림 기록 및 설정 저장
/// 
/// 알림 발송 기록과 마지막 접속 시간을 관리
class NotificationLocalDataSource {
  Box? _box;
  static const String _boxName = 'notifications';
  static const String _todayCountKey = 'today_count';
  static const String _lastNotificationDateKey = 'last_notification_date';
  static const String _lastAccessTimeKey = 'last_access_time';
  
  /// Hive Box 초기화
  /// 
  /// 앱 시작 시 한 번 호출하여 Hive Box를 준비
  Future<void> init() async {
    if (_box == null || !_box!.isOpen) {
      _box = await Hive.openBox(_boxName);
      _checkAndResetDailyCount();
    }
  }
  
  /// Hive Box 초기화 확인 및 실행
  /// 
  /// Box가 초기화되지 않았으면 자동으로 초기화
  Future<void> _ensureInitialized() async {
    if (_box == null || !_box!.isOpen) {
      await init();
    }
  }
  
  /// 날짜 변경 확인 및 알림 기록 초기화
  /// 
  /// 자정이 지나면 알림 발송 횟수를 초기화
  Future<void> _checkAndResetDailyCount() async {
    await _ensureInitialized();
    
    final lastDate = _box!.get(_lastNotificationDateKey) as String?;
    final today = _getTodayDateString();
    
    if (lastDate != today) {
      // 날짜가 바뀌었으면 알림 횟수 초기화
      await _box!.put(_todayCountKey, 0);
      await _box!.put(_lastNotificationDateKey, today);
    }
  }
  
  /// 오늘 날짜 문자열 반환 (YYYY-MM-DD 형식)
  String _getTodayDateString() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }
  
  /// 오늘 발송한 알림 횟수 조회
  /// 
  /// 반환: 오늘 발송한 알림 횟수
  Future<int> getTodayNotificationCount() async {
    await _ensureInitialized();
    await _checkAndResetDailyCount();
    return _box!.get(_todayCountKey, defaultValue: 0) as int;
  }
  
  /// 알림 발송 기록 추가
  /// 
  /// 알림을 발송했을 때 기록을 저장
  Future<void> recordNotification() async {
    await _ensureInitialized();
    await _checkAndResetDailyCount();
    
    final currentCount = await getTodayNotificationCount();
    await _box!.put(_todayCountKey, currentCount + 1);
    await _box!.put(_lastNotificationDateKey, _getTodayDateString());
  }
  
  /// 마지막 접속 시간 조회
  /// 
  /// 반환: 마지막 접속 시간 (밀리초 단위 Unix timestamp)
  Future<int?> getLastAccessTime() async {
    await _ensureInitialized();
    return _box!.get(_lastAccessTimeKey) as int?;
  }
  
  /// 마지막 접속 시간 업데이트
  /// 
  /// [timestamp] 업데이트할 시간 (밀리초 단위 Unix timestamp)
  Future<void> updateLastAccessTime(int timestamp) async {
    await _ensureInitialized();
    await _box!.put(_lastAccessTimeKey, timestamp);
  }
  
  /// 오늘 날짜의 알림 기록 초기화
  /// 
  /// 날짜가 바뀌면 알림 기록을 초기화
  Future<void> resetDailyNotificationCount() async {
    await _ensureInitialized();
    await _box!.put(_todayCountKey, 0);
    await _box!.put(_lastNotificationDateKey, _getTodayDateString());
  }
  
  /// Hive Box 닫기
  /// 
  /// 앱 종료 시 호출하여 리소스 정리
  Future<void> close() async {
    if (_box != null && _box!.isOpen) {
      await _box!.close();
    }
  }
}
