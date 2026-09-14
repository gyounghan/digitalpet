import 'package:flutter/material.dart';
import '../../core/theme/species_theme.dart';
import '../../data/services/app_settings_service.dart';
import '../../data/services/feedback_service.dart';

/// 설정 화면 — 앱 전역 옵션.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
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
                    activeThumbColor: MockUI.green,
                  ),
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
}
