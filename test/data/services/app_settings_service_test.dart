import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:pocketfriend/core/constants/hive_constants.dart';
import 'package:pocketfriend/data/services/app_settings_service.dart';

/// AppSettingsService의 onboarding 플래그 영속성 검증
void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('hive_app_settings_test');
    Hive.init(tempDir.path);
  });

  tearDown(() async {
    await Hive.deleteBoxFromDisk(HiveConstants.appSettingsBoxName);
    await Hive.close();
    try {
      await tempDir.delete(recursive: true);
    } catch (_) {}
  });

  group('AppSettingsService', () {
    test('초기값은 false (한 번도 안 본 상태)', () async {
      final service = AppSettingsService();
      expect(await service.hasSeenDiagnosticsOnboarding(), false);
    });

    test('markDiagnosticsOnboardingSeen 호출 후 true 반환', () async {
      final service = AppSettingsService();
      await service.markDiagnosticsOnboardingSeen();
      expect(await service.hasSeenDiagnosticsOnboarding(), true);
    });

    test('서비스 인스턴스가 새로 생성돼도 플래그 유지 (영속성)', () async {
      final service1 = AppSettingsService();
      await service1.markDiagnosticsOnboardingSeen();

      final service2 = AppSettingsService();
      expect(await service2.hasSeenDiagnosticsOnboarding(), true);
    });
  });
}
