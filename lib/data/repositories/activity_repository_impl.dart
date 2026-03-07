import '../../domain/entities/activity_data.dart';
import '../../domain/repositories/activity_repository.dart';
import '../datasources/health_datasource.dart';

/// ActivityRepository 인터페이스 구현
/// Domain의 추상화된 인터페이스를 실제 구현
/// 
/// HealthDataSource를 사용하여 헬스케어 API에서 데이터 조회
class ActivityRepositoryImpl implements ActivityRepository {
  final HealthDataSource healthDataSource;
  
  ActivityRepositoryImpl(this.healthDataSource);
  
  @override
  Future<ActivityData> getActivityData({
    required int startTime,
    required int endTime,
  }) async {
    final startDateTime = DateTime.fromMillisecondsSinceEpoch(startTime);
    final endDateTime = DateTime.fromMillisecondsSinceEpoch(endTime);
    
    return await healthDataSource.getActivityData(
      startTime: startDateTime,
      endTime: endDateTime,
    );
  }
  
  @override
  Future<ActivityData> getTodayActivityData() async {
    return await healthDataSource.getTodayActivityData();
  }
  
  @override
  Future<ActivityData> getLast24HoursActivityData() async {
    return await healthDataSource.getLast24HoursActivityData();
  }
}
