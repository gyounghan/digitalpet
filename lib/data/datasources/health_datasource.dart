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
  bool _initialized = false;
  
  /// 권한 요청용 데이터 타입 목록
  /// 걸음 수 동기화를 우선 보장하기 위해 STEPS만 필수 요청
  static final List<HealthDataType> _requiredHealthDataTypes = [
    HealthDataType.STEPS,
  ];
  
  /// Health 초기화
  /// 
  /// 앱 시작 시 한 번 호출하여 Health 인스턴스를 준비
  Future<void> init() async {
    if (_initialized) {
      return;
    }

    health = Health();
    
    // 권한 요청 및 초기화 (READ 권한만 요청)
    // WRITE 권한까지 함께 요청하면 사용자 권한 거부 가능성이 커져
    // 걸음 수 조회 자체가 실패할 수 있으므로 최소 권한으로 요청한다.
    final requested = await health.requestAuthorization(
      _requiredHealthDataTypes,
      permissions: [HealthDataAccess.READ],
    );
    if (!requested) {
      throw Exception('Health data permission denied');
    }

    _initialized = true;
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
      if (!_initialized) {
        await init();
      }

      // 걸음 수 조회
      // 1) total API를 우선 사용 (플랫폼 집계값)
      // 2) 실패 시 raw 데이터 합산으로 폴백
      int totalSteps = 0;
      final totalStepsFromInterval = await health.getTotalStepsInInterval(
        startTime,
        endTime,
      );
      if (totalStepsFromInterval != null && totalStepsFromInterval > 0) {
        totalSteps = totalStepsFromInterval;
      } else {
        final steps = await health.getHealthDataFromTypes(
          startTime: startTime,
          endTime: endTime,
          types: [HealthDataType.STEPS],
        );
        for (final step in steps) {
          totalSteps += _extractNumericValue(step.value);
        }
      }
      
      // 운동 데이터 조회
      int totalExerciseMinutes = 0;
      try {
        final workouts = await health.getHealthDataFromTypes(
          startTime: startTime,
          endTime: endTime,
          types: [HealthDataType.WORKOUT],
        );
        for (final workout in workouts) {
          // HealthDataPoint의 dateFrom과 dateTo를 사용하여 운동 시간 계산
          final duration = workout.dateTo.difference(workout.dateFrom);
          totalExerciseMinutes += duration.inMinutes.toInt();
        }
      } catch (_) {
        // 운동 데이터 권한 미허용 시 0으로 처리 (걸음 수 동기화는 유지)
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

  /// Health 값에서 숫자만 안전하게 추출
  int _extractNumericValue(dynamic value) {
    if (value is NumericHealthValue) {
      return value.numericValue.toInt();
    }
    if (value is num) {
      return value.toInt();
    }
    final parsed = int.tryParse(value.toString());
    return parsed ?? 0;
  }
}
