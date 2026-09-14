import 'package:flutter/material.dart';
import '../../core/theme/species_theme.dart';
import '../../data/services/app_settings_service.dart';

/// 첫 실행 환영 가이드 — 핵심 육성 루프를 3줄로 안내한다.
///
/// [hasSeenWelcome]가 false일 때 한 번만 뜨고, 확인 시 플래그를 저장한다.
Future<void> showWelcomeGuideIfNeeded(BuildContext context) async {
  final settings = AppSettingsService();
  if (await settings.hasSeenWelcome()) return;
  if (!context.mounted) return;

  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const _WelcomeDialog(),
  );
  await settings.markWelcomeSeen();
}

class _WelcomeDialog extends StatelessWidget {
  const _WelcomeDialog();

  Widget _step(IconData icon, String title, String body) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 22, color: MockUI.green),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        color: DesignTokens.ink,
                        fontSize: 14)),
                Text(body,
                    style: const TextStyle(
                        color: DesignTokens.ink3, fontSize: 12.5)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: DesignTokens.surface,
      title: const Text('갓생몬에 오신 걸 환영해요!',
          style: TextStyle(
              fontWeight: FontWeight.w900, color: DesignTokens.ink)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _step(Icons.directions_walk, '움직이면 자라요',
              '걸음·수면·물마시기 같은 건강 습관이 펫의 성장 재료예요.'),
          _step(Icons.auto_awesome, '목표를 채워 진화',
              '하루 목표를 달성하면 경험치와 코인을 얻고, 신화 펫으로 진화해요.'),
          _step(Icons.sports_kabaddi, '배틀·상점으로 즐기기',
              '모은 코인으로 상점에서 아이템을 사고, 배틀·놀아주기로 교감해요.'),
        ],
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('시작하기'),
        ),
      ],
    );
  }
}
