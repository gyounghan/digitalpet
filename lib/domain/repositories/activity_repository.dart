import '../entities/activity_data.dart';

/// 활동 데이터 저장소 인터페이스
/// Domain 레이어에서 정의하며, Data 레이어에서 구현
abstract class ActivityRepository {
  /// 최근 활동 데이터 조회
  /// 
  /// [startTime] 조회 시작 시간 (타임스탬프)
  /// [endTime] 조회 종료 시간 (타임스탬프)
  /// 
  /// 반환: ActivityData 엔티티
  /// 
  /// 주의: startTime부터 endTime까지의 기간 동안의 활동 데이터를 조회
  Future<ActivityData> getActivityData({
    required int startTime,
    required int endTime,
  });
  
  /// 오늘의 활동 데이터 조회
  /// 
  /// 반환: 오늘 0시부터 현재까지의 ActivityData 엔티티
  Future<ActivityData> getTodayActivityData();
  
  /// 최근 24시간 활동 데이터 조회
  /// 
  /// 반환: 현재 시간 기준 24시간 전부터 현재까지의 ActivityData 엔티티
  Future<ActivityData> getLast24HoursActivityData();
}
