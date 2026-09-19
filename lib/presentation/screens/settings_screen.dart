import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/pet_provider.dart';
import '../providers/active_pet_provider.dart';
import '../../core/theme/species_theme.dart';
import '../../data/services/app_settings_service.dart';
import '../../data/services/feedback_service.dart';
import '../../domain/entities/pet_background.dart';

/// 설정 화면 — 앱 전역 옵션 + 꾸미기(홈 배경).
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _settings = AppSettingsService();
  bool _haptics = true;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final haptics = await _settings.getHapticsEnabled();
    if (!mounted) return;
    setState(() {
      _haptics = haptics;
      _loaded = true;
    });
  }

  Future<void> _setHaptics(bool value) async {
    setState(() => _haptics = value);
    FeedbackService.enabled = value;
    await _settings.setHapticsEnabled(value);
    if (value) FeedbackService.select();
  }

  @override
  Widget build(BuildContext context) {
    final petId = ref.watch(activePetIdProvider);
    final equipped =
        ref.watch(petNotifierProvider(petId)).valueOrNull?.equippedBackground ??
            kDefaultBackgroundId;

    return Scaffold(
      backgroundColor: MockUI.screenTop,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: DesignTokens.ink,
        title:
            const Text('설정', style: TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: SafeArea(
        child: !_loaded
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  SwitchListTile(
                    value: _haptics,
                    onChanged: _setHaptics,
                    title: const Text('햅틱(진동) 피드백',
                        style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: DesignTokens.ink)),
                    subtitle: const Text('밥 주기·배틀·구매 시 진동 반응',
                        style: TextStyle(color: DesignTokens.ink3)),
                    activeColor: MockUI.green,
                  ),
                  const Divider(height: 24),
                  const Padding(
                    padding: EdgeInsets.only(bottom: 8),
                    child: Text('홈 배경 꾸미기',
                        style: TextStyle(
                            fontWeight: FontWeight.w800,
                            color: DesignTokens.ink,
                            fontSize: 15)),
                  ),
                  _buildBackgroundPicker(petId, equipped),
                  const Divider(height: 24),
                  const ListTile(
                    title: Text('앱 정보',
                        style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: DesignTokens.ink)),
                    subtitle: Text('갓생몬 (PocketFriend)',
                        style: TextStyle(color: DesignTokens.ink3)),
                    trailing: Text('v1.0',
                        style: TextStyle(color: DesignTokens.ink3)),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildBackgroundPicker(String petId, String equipped) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        for (final bg in backgroundCatalog)
          GestureDetector(
            onTap: () {
              FeedbackService.select();
              ref.read(petNotifierProvider(petId).notifier).equipBackground(bg.id);
            },
            child: Column(
              children: [
                Container(
                  width: 80,
                  height: 100,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: bg.id == equipped
                          ? MockUI.lineStrong
                          : MockUI.line,
                      width: bg.id == equipped ? 3 : 1,
                    ),
                    color: MockUI.meterTrack,
                    image: bg.assetPath.isNotEmpty
                        ? DecorationImage(
                            image: AssetImage(bg.assetPath), fit: BoxFit.cover)
                        : null,
                  ),
                  child: bg.assetPath.isEmpty
                      ? const Center(
                          child: Text('기본',
                              style: TextStyle(
                                  color: DesignTokens.ink3, fontSize: 12)))
                      : null,
                ),
                const SizedBox(height: 4),
                Text(bg.name,
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: bg.id == equipped
                            ? FontWeight.w800
                            : FontWeight.w500,
                        color: DesignTokens.ink2)),
              ],
            ),
          ),
      ],
    );
  }
}
