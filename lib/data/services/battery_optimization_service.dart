import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

/// 배터리 최적화 화이트리스트 서비스
///
/// Android의 Doze 모드/Battery optimization은 WorkManager 백그라운드 작업을
/// 매우 자주 지연/중단시킨다. 사용자가 명시적으로 화이트리스트를 등록하면
/// 백그라운드 동기화 신뢰도가 크게 향상된다.
///
/// iOS는 시스템 정책으로 사용자 화이트리스트가 없으므로 항상 granted 처리한다.
class BatteryOptimizationService {
  /// 현재 화이트리스트 상태 조회
  ///
  /// 반환:
  /// - `granted`: 화이트리스트 등록됨 (배터리 최적화 무시)
  /// - `denied`/그 외: 화이트리스트 미등록
  ///
  /// Android만 의미가 있다. iOS/기타 플랫폼은 항상 granted를 반환.
  Future<PermissionStatus> getStatus() async {
    if (!Platform.isAndroid) return PermissionStatus.granted;
    try {
      return await Permission.ignoreBatteryOptimizations.status;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('BatteryOptimizationService.getStatus 실패: $e');
      }
      return PermissionStatus.denied;
    }
  }

  /// 화이트리스트 등록 요청
  ///
  /// 시스템 다이얼로그를 띄워 사용자가 직접 허용해야 한다.
  ///
  /// 반환: 요청 후의 PermissionStatus (granted이면 성공)
  Future<PermissionStatus> request() async {
    if (!Platform.isAndroid) return PermissionStatus.granted;
    try {
      return await Permission.ignoreBatteryOptimizations.request();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('BatteryOptimizationService.request 실패: $e');
      }
      return PermissionStatus.denied;
    }
  }

  /// 화이트리스트 등록 여부 (status == granted)
  Future<bool> get isWhitelisted async {
    final status = await getStatus();
    return status.isGranted;
  }
}
