import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../core/theme/species_theme.dart';
import '../../data/services/battery_optimization_service.dart';

/// 동기화 권한 배너 — 걸음/수면 자동 측정에 필요한 권한이 빠졌을 때만 노출.
///
/// 평소(권한 모두 허용)에는 [SizedBox.shrink]로 아무것도 그리지 않는다.
/// 배터리 최적화 제외 + 활동 인식 권한 중 하나라도 빠지면 홈 상단에
/// 경고 배너를 띄우고, 탭하면 한 번에 권한을 요청한다.
class SyncPermissionBanner extends StatefulWidget {
  final SpeciesTheme theme;

  const SyncPermissionBanner({super.key, required this.theme});

  @override
  State<SyncPermissionBanner> createState() => _SyncPermissionBannerState();
}

class _SyncPermissionBannerState extends State<SyncPermissionBanner> {
  final _batteryService = BatteryOptimizationService();
  PermissionStatus? _batteryStatus;
  PermissionStatus? _activityStatus;
  bool _loaded = false;
  bool _requesting = false;

  @override
  void initState() {
    super.initState();
    _loadStatus();
  }

  Future<void> _loadStatus() async {
    try {
      final battery = await _batteryService.getStatus();
      final activity = await Permission.activityRecognition.status;
      if (!mounted) return;
      setState(() {
        _batteryStatus = battery;
        _activityStatus = activity;
        _loaded = true;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loaded = true);
    }
  }

  Future<void> _fixPermissions() async {
    if (_requesting) return;
    setState(() => _requesting = true);

    final batteryOk = _batteryStatus?.isGranted ?? false;
    final activityOk = _activityStatus?.isGranted ?? false;
    final anyPermanentlyDenied =
        (_batteryStatus?.isPermanentlyDenied ?? false) ||
            (_activityStatus?.isPermanentlyDenied ?? false);

    // 영구 거부가 섞여 있으면 시스템 설정으로 안내
    if (anyPermanentlyDenied) {
      await openAppSettings();
    } else {
      if (!activityOk) await Permission.activityRecognition.request();
      if (!batteryOk) await _batteryService.request();
    }

    if (!mounted) return;
    setState(() => _requesting = false);
    await _loadStatus();
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) return const SizedBox.shrink();

    final batteryOk = _batteryStatus?.isGranted ?? false;
    final activityOk = _activityStatus?.isGranted ?? false;
    if (batteryOk && activityOk) return const SizedBox.shrink();

    final theme = widget.theme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 0, 18, 8),
      child: GestureDetector(
        onTap: _requesting ? null : _fixPermissions,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: DesignTokens.warn.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: DesignTokens.warn.withValues(alpha: 0.4),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              const Icon(Icons.warning_amber_rounded,
                  size: 18, color: DesignTokens.warn),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  '걸음·수면 자동 측정이 꺼져 있어요. 탭해서 권한을 켜주세요.',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: DesignTokens.ink2,
                    height: 1.3,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: theme.primaryDeep,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: _requesting
                    ? const SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Text(
                        '설정',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
