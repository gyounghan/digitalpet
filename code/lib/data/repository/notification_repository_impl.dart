import '../../domain/repositories/notification_repository.dart';
import '../datasource/notification_local_datasource.dart';

/// NotificationRepository 인터페이스 구현
/// Domain의 추상화된 인터페이스를 실제 구현
/// 
/// NotificationLocalDataSource를 사용하여 알림 기록 저장/조회
class NotificationRepositoryImpl implements NotificationRepository {
  final NotificationLocalDataSource localDataSource;
  
  NotificationRepositoryImpl(this.localDataSource);
  
  @override
  Future<int> getTodayNotificationCount() async {
    return await localDataSource.getTodayNotificationCount();
  }
  
  @override
  Future<void> recordNotification() async {
    await localDataSource.recordNotification();
  }
  
  @override
  Future<int?> getLastAccessTime() async {
    return await localDataSource.getLastAccessTime();
  }
  
  @override
  Future<void> updateLastAccessTime(int timestamp) async {
    await localDataSource.updateLastAccessTime(timestamp);
  }
  
  @override
  Future<void> resetDailyNotificationCount() async {
    await localDataSource.resetDailyNotificationCount();
  }
}
