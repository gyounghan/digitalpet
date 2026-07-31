import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:pocketfriend/data/datasources/step_sensor_datasource.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 백그라운드 isolate 폴백 회귀 테스트.
///
/// 테스트 환경에는 MethodChannel 핸들러가 없으므로(MissingPluginException)
/// 실제 WorkManager 백그라운드 isolate와 동일한 조건이 된다. 이때
/// 네이티브(StepCacheStore)가 SharedPreferences에 기록해 둔 누적값으로
/// 오늘 걸음수가 계산되는지 검증한다.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUpAll(() {
    tempDir = Directory.systemTemp.createTempSync('step_sensor_test');
    Hive.init(tempDir.path);
  });

  tearDown(() async {
    // baseline 박스 초기화 (테스트 간 독립성)
    final box = await Hive.openBox('step_sensor');
    await box.clear();
  });

  tearDownAll(() async {
    await Hive.close();
    tempDir.deleteSync(recursive: true);
  });

  group('StepSensorDatasource — 백그라운드 캐시 폴백', () {
    test('채널·캐시 모두 없으면 -1 (센서 없음)', () async {
      SharedPreferences.setMockInitialValues({});
      final datasource = StepSensorDatasource();

      final steps = await datasource.getTodaySteps();

      expect(steps, -1);
    });

    test('첫 조회: 캐시된 누적값으로 baseline 설정 → 0 반환', () async {
      SharedPreferences.setMockInitialValues({
        'step_sensor_cumulative': 10000,
      });
      final datasource = StepSensorDatasource();

      final steps = await datasource.getTodaySteps();

      expect(steps, 0, reason: '방금 baseline을 잡았으므로 오늘 걸음 0');
    });

    test('누적값 증가분 = 오늘 걸음수', () async {
      SharedPreferences.setMockInitialValues({
        'step_sensor_cumulative': 10000,
      });
      final datasource = StepSensorDatasource();
      await datasource.getTodaySteps(); // baseline 10000 설정

      // 네이티브 워커가 캐시를 갱신했다고 가정
      SharedPreferences.setMockInitialValues({
        'step_sensor_cumulative': 12500,
      });

      final steps = await datasource.getTodaySteps();

      expect(steps, 2500);
    });

    test('재부팅 감지: 누적값이 baseline보다 작으면 리셋 후 0', () async {
      SharedPreferences.setMockInitialValues({
        'step_sensor_cumulative': 10000,
      });
      final datasource = StepSensorDatasource();
      await datasource.getTodaySteps(); // baseline 10000

      // 재부팅으로 누적값이 500으로 초기화됨
      SharedPreferences.setMockInitialValues({
        'step_sensor_cumulative': 500,
      });
      final afterReboot = await datasource.getTodaySteps();
      expect(afterReboot, 0, reason: '재부팅 직후엔 baseline 리셋');

      // 재부팅 후 300보 더 걸음
      SharedPreferences.setMockInitialValues({
        'step_sensor_cumulative': 800,
      });
      final steps = await datasource.getTodaySteps();
      expect(steps, 300);
    });
  });
}
