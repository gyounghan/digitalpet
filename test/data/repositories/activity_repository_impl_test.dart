import 'package:flutter_test/flutter_test.dart';
import 'package:pocketfriend/domain/entities/activity_data.dart';
import 'package:pocketfriend/data/repositories/activity_repository_impl.dart';
import 'package:pocketfriend/data/datasources/health_datasource.dart';
import 'package:pocketfriend/data/datasources/step_sensor_datasource.dart';

/// Health Connect에서 데이터를 반환하는 Fake
class FakeHealthDataSource extends HealthDataSource {
  final int steps;
  final int exerciseMinutes;

  FakeHealthDataSource({
    required this.steps,
    required this.exerciseMinutes,
  });

  @override
  Future<ActivityData> getActivityData({
    required DateTime startTime,
    required DateTime endTime,
    bool skipRequest = false,
  }) async {
    return ActivityData(
      steps: steps,
      exerciseMinutes: exerciseMinutes,
      startTime: startTime.millisecondsSinceEpoch,
      endTime: endTime.millisecondsSinceEpoch,
    );
  }

  @override
  Future<ActivityData> getTodayActivityData() async {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    return getActivityData(startTime: startOfDay, endTime: now);
  }
}

/// Health 조회 실패 Fake
class FakeFailingHealthDataSource extends HealthDataSource {
  @override
  Future<ActivityData> getActivityData({
    required DateTime startTime,
    required DateTime endTime,
    bool skipRequest = false,
  }) async {
    throw Exception('Health 연결 실패');
  }

  @override
  Future<ActivityData> getTodayActivityData() async {
    throw Exception('Health 연결 실패');
  }
}

/// 내장 센서 Fake: 걸음수 반환
class FakeStepSensorDatasource extends StepSensorDatasource {
  final int todaySteps;

  FakeStepSensorDatasource({required this.todaySteps});

  @override
  Future<int> getTodaySteps() async => todaySteps;
}

/// 내장 센서 Fake: 센서 없음 (-1)
class FakeUnavailableStepSensor extends StepSensorDatasource {
  @override
  Future<int> getTodaySteps() async => -1;
}

void main() {
  group('ActivityRepositoryImpl - 내장 센서 우선 + Health Connect 폴백', () {
    test('내장 센서 성공 시 센서 걸음수 사용, 운동 데이터는 Health Connect', () async {
      final repo = ActivityRepositoryImpl(
        healthDataSource:
            FakeHealthDataSource(steps: 3000, exerciseMinutes: 25),
        stepSensorDatasource: FakeStepSensorDatasource(todaySteps: 5000),
      );

      final data = await repo.getTodayActivityData();

      expect(data.steps, 5000); // 센서 값 우선
      expect(data.exerciseMinutes, 25); // Health Connect에서
    });

    test('내장 센서 실패(-1) 시 Health Connect 폴백', () async {
      final repo = ActivityRepositoryImpl(
        healthDataSource:
            FakeHealthDataSource(steps: 3000, exerciseMinutes: 25),
        stepSensorDatasource: FakeUnavailableStepSensor(),
      );

      final data = await repo.getTodayActivityData();

      expect(data.steps, 3000); // Health Connect 폴백
      expect(data.exerciseMinutes, 25);
    });

    test('내장 센서 0, Health Connect도 실패 시 모두 0', () async {
      final repo = ActivityRepositoryImpl(
        healthDataSource: FakeFailingHealthDataSource(),
        stepSensorDatasource: FakeStepSensorDatasource(todaySteps: 0),
      );

      final data = await repo.getTodayActivityData();

      expect(data.steps, 0);
      expect(data.exerciseMinutes, 0);
    });

    test('Health 실패 시에도 startTime/endTime은 보존', () async {
      final repo = ActivityRepositoryImpl(
        healthDataSource: FakeFailingHealthDataSource(),
        stepSensorDatasource: FakeUnavailableStepSensor(),
      );

      final start = DateTime(2026, 1, 1).millisecondsSinceEpoch;
      final end = DateTime(2026, 1, 2).millisecondsSinceEpoch;
      final data = await repo.getActivityData(
        startTime: start,
        endTime: end,
      );

      expect(data.startTime, start);
      expect(data.endTime, end);
    });
  });
}
