import 'package:health/health.dart';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io';
import '../../domain/entities/activity_data.dart';

/// 헬스케어 데이터소스
/// Health 패키지를 사용하여 플랫폼의 헬스케어 API에 접근
///
/// Android: Health Connect (health 패키지 13.x)
/// iOS: HealthKit
///
/// [주의] _initialized는 static으로 선언하여 여러 인스턴스 간 공유.
/// Riverpod Provider와 BackgroundService에서 각각 인스턴스를 생성해도
/// 권한 요청이 중복 발생하지 않도록 보장한다.
class HealthDataSource {
  /// Health 인스턴스
  late final Health health;

  /// 초기화 완료 여부 (모든 인스턴스 공유)
  static bool _initialized = false;
  
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

    if (Platform.isAndroid) {
      // Android에서 걸음수 수집을 위해 ACTIVITY_RECOGNITION 런타임 권한이 필요하다.
      final activityPermission = await Permission.activityRecognition.status;
      if (!activityPermission.isGranted) {
        final requestedPermission = await Permission.activityRecognition.request();
        if (kDebugMode) {
          debugPrint(
            'HealthDataSource: activityRecognition permission '
            'requested -> $requestedPermission',
          );
        }
      } else if (kDebugMode) {
        debugPrint('HealthDataSource: activityRecognition permission already granted');
      }
    }
    
    // 권한 요청 및 초기화 (READ 권한만 요청)
    // WRITE 권한까지 함께 요청하면 사용자 권한 거부 가능성이 커져
    // 걸음 수 조회 자체가 실패할 수 있으므로 최소 권한으로 요청한다.
    final requested = await health.requestAuthorization(
      _requiredHealthDataTypes,
      permissions: [HealthDataAccess.READ],
    );
    if (kDebugMode) {
      debugPrint(
        'HealthDataSource: health requestAuthorization(STEPS/READ) -> $requested',
      );
    }
    if (!requested) {
      if (kDebugMode) {
        debugPrint(
          'HealthDataSource: requestAuthorization returned false. '
          'Health Connect 앱이 설치되어 있는지, 권한이 허용되어 있는지 확인하세요.',
        );
      }
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
        if (kDebugMode) {
          debugPrint(
            'HealthDataSource: getTotalStepsInInterval success '
            '[$startTime ~ $endTime] = $totalSteps',
          );
        }
      } else {
        if (kDebugMode) {
          debugPrint(
            'HealthDataSource: getTotalStepsInInterval returned $totalStepsFromInterval, '
            'fallback to raw STEPS records',
          );
        }
        final steps = await health.getHealthDataFromTypes(
          startTime: startTime,
          endTime: endTime,
          types: [HealthDataType.STEPS],
        );
        if (kDebugMode) {
          debugPrint('HealthDataSource: raw STEPS record count = ${steps.length}');
        }
        for (final step in steps) {
          totalSteps += _extractNumericValue(step.value);
        }
        if (kDebugMode) {
          debugPrint(
            'HealthDataSource: raw STEPS aggregated total '
            '[$startTime ~ $endTime] = $totalSteps',
          );
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
        if (kDebugMode) {
          debugPrint('HealthDataSource: WORKOUT record count = ${workouts.length}');
        }
        for (final workout in workouts) {
          // HealthDataPoint의 dateFrom과 dateTo를 사용하여 운동 시간 계산
          final duration = workout.dateTo.difference(workout.dateFrom);
          totalExerciseMinutes += duration.inMinutes.toInt();
        }
      } catch (_) {
        // 운동 데이터 권한 미허용 시 0으로 처리 (걸음 수 동기화는 유지)
        if (kDebugMode) {
          debugPrint('HealthDataSource: failed to read WORKOUT records (ignored)');
        }
      }
      
      return ActivityData(
        steps: totalSteps,
        exerciseMinutes: totalExerciseMinutes,
        startTime: startTime.millisecondsSinceEpoch,
        endTime: endTime.millisecondsSinceEpoch,
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('HealthDataSource: getActivityData failed: $e');
      }
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
