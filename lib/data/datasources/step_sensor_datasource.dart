import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Android 내장 걸음수 센서(TYPE_STEP_COUNTER) 직접 읽기
///
/// Health Connect 설치 없이 모든 Android 폰에서 걸음수를 측정.
/// TYPE_STEP_COUNTER는 마지막 재부팅 이후의 누적 걸음수를 반환하므로,
/// 오늘 0시 시점의 기준값(baseline)과의 차이로 오늘 걸음수를 계산한다.
///
/// 기준값은 Hive에 저장하여 앱 재시작 후에도 유지된다.
/// 재부팅 감지: 현재 누적값이 기준값보다 작으면 재부팅으로 판단, 기준값 초기화.
///
/// 백그라운드 폴백: MethodChannel은 MainActivity에서만 등록되므로
/// WorkManager 백그라운드 isolate에서는 사용할 수 없다. 대신 네이티브
/// (센서 이벤트 + 15분 주기 StepCacheWorker)가 SharedPreferences에 캐시해 둔
/// 누적값([_prefsKeyCumulative])을 읽는다. 누적값은 단조 증가하므로
/// 캐시가 다소 오래됐어도 과대 계산 없이 안전하다 (다음 동기화에서 따라잡음).
class StepSensorDatasource {
  static const _channel = MethodChannel('com.han.godsaengmon/step_counter');
  static const _boxName = 'step_sensor';
  static const _keyBaseline = 'baseline_steps';
  static const _keyBaselineDate = 'baseline_date';

  /// 네이티브 StepCacheStore가 기록하는 누적 걸음수 캐시 키
  /// (Kotlin 쪽 'flutter.step_sensor_cumulative'와 접두어 제외 동일해야 함)
  static const _prefsKeyCumulative = 'step_sensor_cumulative';

  Box? _box;

  /// Hive Box 초기화
  Future<void> init() async {
    _box ??= await Hive.openBox(_boxName);
  }

  /// 센서 사용 가능 여부 확인
  Future<bool> isAvailable() async {
    try {
      final result = await _channel.invokeMethod<bool>('isStepSensorAvailable');
      return result ?? false;
    } catch (e) {
      return false;
    }
  }

  /// 오늘의 걸음수 조회
  ///
  /// 반환: 오늘 0시 이후 걸음수 (센서 없으면 -1)
  Future<int> getTodaySteps() async {
    try {
      await init();

      final cumulativeSteps = await _getCumulativeSteps();
      if (cumulativeSteps < 0) return -1; // 센서 없음

      final today = _todayKey();
      final savedDate = _box!.get(_keyBaselineDate) as String?;
      var baseline = _box!.get(_keyBaseline) as int?;

      // 날짜가 바뀌었거나 기준값이 없으면 현재 값을 기준으로 저장
      if (savedDate != today || baseline == null) {
        baseline = cumulativeSteps;
        await _box!.put(_keyBaseline, baseline);
        await _box!.put(_keyBaselineDate, today);
        if (kDebugMode) {
          debugPrint(
            'StepSensorDatasource: 새 기준값 설정 '
            'date=$today, baseline=$baseline',
          );
        }
        return 0; // 방금 기준값을 설정했으므로 0
      }

      // 재부팅 감지: 누적값이 기준값보다 작으면 리셋
      if (cumulativeSteps < baseline) {
        baseline = cumulativeSteps;
        await _box!.put(_keyBaseline, baseline);
        if (kDebugMode) {
          debugPrint(
            'StepSensorDatasource: 재부팅 감지, 기준값 리셋 baseline=$baseline',
          );
        }
        return 0;
      }

      final todaySteps = cumulativeSteps - baseline;
      if (kDebugMode) {
        debugPrint(
          'StepSensorDatasource: 오늘 걸음수=$todaySteps '
          '(cumulative=$cumulativeSteps, baseline=$baseline)',
        );
      }
      return todaySteps;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('StepSensorDatasource.getTodaySteps failed: $e');
      }
      return -1;
    }
  }

  /// 현재 누적 걸음수 읽기 — 채널 우선, 실패 시 네이티브 캐시 폴백
  ///
  /// 1) MethodChannel (포그라운드, MainActivity 살아있을 때)
  /// 2) SharedPreferences 캐시 (백그라운드 isolate — MissingPluginException,
  ///    또는 채널이 -1을 반환한 경우)
  Future<int> _getCumulativeSteps() async {
    try {
      final result = await _channel.invokeMethod<num>('getStepCount');
      final steps = result?.toInt() ?? -1;
      if (steps >= 0) return steps;
    } catch (e) {
      if (kDebugMode) {
        debugPrint(
          'StepSensorDatasource: 채널 실패, 캐시 폴백 시도: $e',
        );
      }
    }
    return _getCachedCumulativeSteps();
  }

  /// 네이티브가 SharedPreferences에 캐시해 둔 누적 걸음수 읽기
  Future<int> _getCachedCumulativeSteps() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cached = prefs.getInt(_prefsKeyCumulative) ?? -1;
      if (kDebugMode) {
        debugPrint('StepSensorDatasource: 캐시된 누적 걸음수=$cached');
      }
      return cached;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('StepSensorDatasource._getCachedCumulativeSteps 실패: $e');
      }
      return -1;
    }
  }

  String _todayKey() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }
}
