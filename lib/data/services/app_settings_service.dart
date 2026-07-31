import 'package:hive/hive.dart';
import '../../core/constants/hive_constants.dart';

/// 앱 전역 설정/플래그 저장 서비스 (Hive 기반)
///
/// shared_preferences를 추가로 도입하지 않고 기존 Hive 인프라로 처리.
class AppSettingsService {
  static const _kHasSeenDiagnosticsOnboarding = 'has_seen_diagnostics_onboarding';

  Box? _box;

  Future<void> _ensureBox() async {
    _box ??= await Hive.openBox(HiveConstants.appSettingsBoxName);
    if (!_box!.isOpen) {
      _box = await Hive.openBox(HiveConstants.appSettingsBoxName);
    }
  }

  /// 진단 onboarding을 본 적이 있는지
  Future<bool> hasSeenDiagnosticsOnboarding() async {
    await _ensureBox();
    return _box!.get(_kHasSeenDiagnosticsOnboarding, defaultValue: false)
        as bool;
  }

  /// 진단 onboarding 본 적 있음으로 표시
  Future<void> markDiagnosticsOnboardingSeen() async {
    await _ensureBox();
    await _box!.put(_kHasSeenDiagnosticsOnboarding, true);
  }
}
