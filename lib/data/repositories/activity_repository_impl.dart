import 'package:flutter/foundation.dart';
import '../../domain/entities/activity_data.dart';
import '../../domain/repositories/activity_repository.dart';
import '../datasources/health_datasource.dart';
import '../datasources/step_sensor_datasource.dart';

/// ActivityRepository 인터페이스 구현
///
/// 걸음수 조회 전략:
/// - 오늘 범위(센서 신뢰 가능): Health Connect와 내장 센서를 **모두 시도**해
///   더 큰 값을 채택. 두 소스가 다르면 더 정확한 쪽이 채택됨.
/// - retroactive 범위(과거): 센서는 baseline 기반이라 신뢰 불가 → Health
///   Connect만 사용.
///
/// 운동 데이터: Health Connect에서만 조회 (센서로는 측정 불가).
class ActivityRepositoryImpl implements ActivityRepository {
  final HealthDataSource healthDataSource;
  final StepSensorDatasource stepSensorDatasource;

  ActivityRepositoryImpl({
    required this.healthDataSource,
    required this.stepSensorDatasource,
  });

  @override
  Future<ActivityData> getActivityData({
    required int startTime,
    required int endTime,
  }) async {
    final startDateTime = DateTime.fromMillisecondsSinceEpoch(startTime);
    final endDateTime = DateTime.fromMillisecondsSinceEpoch(endTime);

    return _fetch(startTime: startDateTime, endTime: endDateTime);
  }

  @override
  Future<ActivityData> getTodayActivityData() async {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    return _fetch(startTime: startOfDay, endTime: now);
  }

  @override
  Future<ActivityData> getLast24HoursActivityData() async {
    final now = DateTime.now();
    final yesterday = now.subtract(const Duration(hours: 24));
    return _fetch(startTime: yesterday, endTime: now);
  }

  Future<ActivityData> _fetch({
    required DateTime startTime,
    required DateTime endTime,
  }) async {
    // retroactive 여부 판정 (오늘 0시 이전 시작 또는 1분 이상 과거에서 끝)
    final now = DateTime.now();
    final startOfToday = DateTime(now.year, now.month, now.day);
    final isRetroactive = startTime.isBefore(startOfToday) ||
        endTime.isBefore(now.subtract(const Duration(minutes: 1)));

    // 1. Health Connect에서 시도 (백그라운드/포그라운드 모두 안정적)
    int healthSteps = 0;
    int healthExerciseMinutes = 0;
    try {
      final healthData = await healthDataSource.getActivityData(
        startTime: startTime,
        endTime: endTime,
      );
      healthSteps = healthData.steps;
      healthExerciseMinutes = healthData.exerciseMinutes;
      if (kDebugMode) {
        debugPrint(
          'ActivityRepositoryImpl: Health Connect '
          'steps=$healthSteps, exerciseMinutes=$healthExerciseMinutes',
        );
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('ActivityRepositoryImpl: Health Connect 실패: $e');
      }
    }

    // 2. retroactive면 센서는 사용하지 않음 (baseline 기반이라 부정확)
    int sensorSteps = 0;
    if (!isRetroactive) {
      try {
        final s = await stepSensorDatasource.getTodaySteps();
        if (s > 0) sensorSteps = s;
        if (kDebugMode) {
          debugPrint('ActivityRepositoryImpl: 내장 센서 걸음수=$sensorSteps');
        }
      } catch (e) {
        if (kDebugMode) {
          debugPrint('ActivityRepositoryImpl: 내장 센서 실패: $e');
        }
      }
    }

    // 3. 더 큰 값을 채택 — 한쪽이 0이어도 다른 쪽이 살아있으면 그 값 사용
    final steps = healthSteps > sensorSteps ? healthSteps : sensorSteps;

    if (kDebugMode) {
      debugPrint(
        'ActivityRepositoryImpl: 최종 steps=$steps '
        '(health=$healthSteps, sensor=$sensorSteps, retro=$isRetroactive)',
      );
    }

    return ActivityData(
      steps: steps,
      exerciseMinutes: healthExerciseMinutes,
      startTime: startTime.millisecondsSinceEpoch,
      endTime: endTime.millisecondsSinceEpoch,
    );
  }
}
