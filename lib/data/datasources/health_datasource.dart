import 'package:health/health.dart';
import '../../domain/entities/activity_data.dart';

/// 헬스케어 데이터소스
/// Health 패키지를 사용하여 플랫폼의 헬스케어 API에 접근
/// 
/// Android: Google Fit
/// iOS: HealthKit
class HealthDataSource {
  /// Health 인스턴스
  late final Health health;
  
  /// 접근 가능한 데이터 타입 목록
  static final List<HealthDataType> _healthDataTypes = [
    HealthDataType.STEPS,
    HealthDataType.WORKOUT,
  ];
  
  /// Health 초기화
  /// 
  /// 앱 시작 시 한 번 호출하여 Health 인스턴스를 준비
  Future<void> init() async {
    health = Health();
    
    // 권한 요청 및 초기화
    final requested = await health.requestAuthorization(_healthDataTypes);
    if (!requested) {
      throw Exception('Health data permission denied');
    }
  }
  
  /// 활동 데이터 조회
  /// 
  /// [startTime] 조회 시작 시간
  /// [endTime] 조회 종료 시간
  /// 
  /// 반환: ActivityData 엔티티
  /// 
  /// 주의: 권한이 없거나 데이터가 없으면 빈 ActivityData 반환
  Future<ActivityData> getActivityData({
    required DateTime startTime,
    required DateTime endTime,
  }) async {
    try {
      // 걸음 수 조회
      final steps = await health.getHealthDataFromTypes(
        startTime: startTime,
        endTime: endTime,
        types: [HealthDataType.STEPS],
      );
      
      int totalSteps = 0;
      if (steps.isNotEmpty) {
        for (final step in steps) {
          if (step.value is NumericHealthValue) {
            totalSteps += (step.value as NumericHealthValue).numericValue.toInt();
          }
        }
      }
      
      // 운동 데이터 조회
      final workouts = await health.getHealthDataFromTypes(
        startTime: startTime,
        endTime: endTime,
        types: [HealthDataType.WORKOUT],
      );
      
      int totalExerciseMinutes = 0;
      if (workouts.isNotEmpty) {
        for (final workout in workouts) {
          // HealthDataPoint의 dateFrom과 dateTo를 사용하여 운동 시간 계산
          final duration = workout.dateTo.difference(workout.dateFrom);
          totalExerciseMinutes += duration.inMinutes.toInt();
        }
      }
      
      return ActivityData(
        steps: totalSteps,
        exerciseMinutes: totalExerciseMinutes,
        startTime: startTime.millisecondsSinceEpoch,
        endTime: endTime.millisecondsSinceEpoch,
      );
    } catch (e) {
      // 에러 발생 시 빈 데이터 반환
      return ActivityData.empty();
    }
  }
  
  /// 오늘의 활동 데이터 조회
  /// 
  /// 반환: 오늘 0시부터 현재까지의 ActivityData 엔티티
  Future<ActivityData> getTodayActivityData() async {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    
    return await getActivityData(
      startTime: startOfDay,
      endTime: now,
    );
  }
  
  /// 최근 24시간 활동 데이터 조회
  /// 
  /// 반환: 현재 시간 기준 24시간 전부터 현재까지의 ActivityData 엔티티
  Future<ActivityData> getLast24HoursActivityData() async {
    final now = DateTime.now();
    final yesterday = now.subtract(const Duration(hours: 24));
    
    return await getActivityData(
      startTime: yesterday,
      endTime: now,
    );
  }
}
