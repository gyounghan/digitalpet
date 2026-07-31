import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../core/constants/app_strings.dart';
import '../../core/theme/species_theme.dart';
import '../../data/services/battery_optimization_service.dart';
import '../../data/services/notification_service.dart';
import '../../data/services/widget_service.dart';
import '../../domain/usecases/calculate_daily_goals_score_usecase.dart';
import '../../domain/usecases/species_reveal_narrator.dart';
import '../providers/pet_provider.dart';
import '../widgets/pixel_motion_animation.dart';
import 'home_screen.dart';

/// 첫 실행 온보딩 — 이름 짓기 → 걸음 권한 → 첫 목표 → 위젯 유도 (4장)
///
/// 톤 규칙: 펫 1인칭 + 가벼운 제안, 압박 없음. 권한/위젯은 건너뛸 수 있고
/// 놓친 권한은 홈의 [SyncPermissionBanner]가 이후에 다시 안내한다.
/// 완료 플래그는 호출부(MainNavigationScreen)가 pop 후에 기록한다.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  static const int _pageCount = 4;

  final PageController _pageController = PageController();
  final TextEditingController _nameController = TextEditingController();
  int _page = 0;
  bool _requesting = false;

  @override
  void dispose() {
    _pageController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  void _goTo(int page) {
    setState(() => _page = page);
    _pageController.animateToPage(
      page,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
    );
  }

  void _next() {
    if (_page >= _pageCount - 1) {
      _finish();
    } else {
      _goTo(_page + 1);
    }
  }

  /// 걸음(활동 인식) + 배터리 최적화 제외 + 알림 권한 요청
  ///
  /// 각 요청은 독립적으로 실패를 무시한다 — 거부해도 온보딩은 계속되고,
  /// 홈의 SyncPermissionBanner가 필요 시 재안내한다.
  Future<void> _requestPermissions() async {
    if (_requesting) return;
    setState(() => _requesting = true);
    try {
      await Permission.activityRecognition.request();
    } catch (_) {}
    try {
      await BatteryOptimizationService().request();
    } catch (_) {}
    try {
      await NotificationService().requestPermission();
    } catch (_) {}
    if (!mounted) return;
    setState(() => _requesting = false);
    _next();
  }

  /// 위젯 추가 요청 — 런처 미지원이면 수동 추가 안내 후 계속 진행
  Future<void> _requestPinWidget() async {
    if (_requesting) return;
    setState(() => _requesting = true);
    final requested = await WidgetService().requestPinWidget();
    if (!mounted) return;
    setState(() => _requesting = false);
    if (!requested) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(AppStrings.onboardWidgetUnsupported)),
      );
    }
    _finish();
  }

  /// 온보딩 종료 — 지어준 이름을 펫에 반영하고 닫는다
  ///
  /// 펫 생성(PetNotifier._loadPet)이 아직 안 끝났을 수 있어 최대 3초 대기.
  Future<void> _finish() async {
    final name = _nameController.text.trim();
    if (name.isNotEmpty) {
      for (var i = 0; i < 10; i++) {
        if (ref.read(petNotifierProvider(HomeScreen.defaultPetId)).hasValue) {
          break;
        }
        await Future.delayed(const Duration(milliseconds: 300));
      }
      await ref
          .read(petNotifierProvider(HomeScreen.defaultPetId).notifier)
          .updateName(name);
    }
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    const theme = SpeciesTheme.defaultTheme;

    return PopScope(
      // 시스템 뒤로가기: 첫 장에서는 온보딩을 닫고(건너뛰기 취급),
      // 이후 장에서는 이전 장으로 되돌린다.
      canPop: _page == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _goTo(_page - 1);
      },
      child: Scaffold(
        backgroundColor: DesignTokens.bg,
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Column(
                children: [
                  Expanded(
                    child: PageView(
                      controller: _pageController,
                      physics: const NeverScrollableScrollPhysics(),
                      children: [
                        _welcomePage(theme),
                        _permissionPage(theme),
                        _firstGoalPage(theme),
                        _widgetPage(theme),
                      ],
                    ),
                  ),
                  _pageDots(theme),
                  const SizedBox(height: 14),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── 1장: 환영 + 이름 짓기 ──────────────────────────────────────────

  Widget _welcomePage(SpeciesTheme theme) {
    final (dotColor, accentColor) = dotColorsForKey('fluff', null, theme);
    return _pageFrame(
      hero: PixelMotionAnimation(
        spriteKey: 'fluff',
        motion: PixelMotion.joy,
        width: 170,
        height: 170,
        dotColor: dotColor,
        accentColor: accentColor,
      ),
      title: AppStrings.onboardWelcomeTitle,
      body: AppStrings.onboardWelcomeBody,
      extra: TextField(
        controller: _nameController,
        maxLength: 20,
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: DesignTokens.ink,
        ),
        decoration: InputDecoration(
          hintText: AppStrings.onboardNameHint,
          counterText: '',
          filled: true,
          fillColor: DesignTokens.surface,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: DesignTokens.line2),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: DesignTokens.line2),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: theme.primary, width: 1.5),
          ),
        ),
      ),
      primaryLabel: AppStrings.onboardNameButton,
      onPrimary: _next,
      theme: theme,
    );
  }

  // ── 2장: 걸음 권한 ─────────────────────────────────────────────────

  Widget _permissionPage(SpeciesTheme theme) {
    return _pageFrame(
      hero: _heroIcon(Icons.directions_walk_rounded, theme),
      title: AppStrings.onboardPermissionTitle,
      body: AppStrings.onboardPermissionBody,
      primaryLabel: AppStrings.onboardPermissionButton,
      onPrimary: _requestPermissions,
      secondaryLabel: AppStrings.onboardPermissionSkip,
      onSecondary: _next,
      theme: theme,
    );
  }

  // ── 3장: 첫 목표 ──────────────────────────────────────────────────

  Widget _firstGoalPage(SpeciesTheme theme) {
    final feedGoal = CalculateDailyGoalsScoreUseCase.getFeedGoalCount(1);
    final stepsGoal = CalculateDailyGoalsScoreUseCase.getExerciseGoalSteps(1);
    final sleepGoal = CalculateDailyGoalsScoreUseCase.getSleepGoalHours(1);
    const setExp = CalculateDailyGoalsScoreUseCase.setExpBase;

    return _pageFrame(
      hero: _heroIcon(Icons.flag_rounded, theme),
      title: AppStrings.onboardGoalTitle,
      body: AppStrings.onboardGoalBody,
      extra: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        decoration: BoxDecoration(
          color: DesignTokens.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: DesignTokens.line),
        ),
        child: Column(
          children: [
            _goalRow(Icons.restaurant, '식사', '$feedGoal회', theme),
            const SizedBox(height: 10),
            _goalRow(Icons.directions_run, '걸음',
                '${SpeciesRevealNarrator.formatNumber(stepsGoal)}보', theme),
            const SizedBox(height: 10),
            _goalRow(Icons.bedtime, '수면', '$sleepGoal시간', theme),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.task_alt, size: 14, color: theme.primaryDeep),
                const SizedBox(width: 5),
                Text(
                  '셋 다 채우면 +$setExp EXP',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: theme.primaryDeep,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      primaryLabel: AppStrings.onboardGoalButton,
      onPrimary: _next,
      theme: theme,
    );
  }

  Widget _goalRow(
      IconData icon, String label, String value, SpeciesTheme theme) {
    return Row(
      children: [
        Icon(icon, size: 16, color: theme.primaryDeep),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w700,
            color: DesignTokens.ink2,
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: const TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w800,
            color: DesignTokens.ink,
          ),
        ),
      ],
    );
  }

  // ── 4장: 위젯 유도 ────────────────────────────────────────────────

  Widget _widgetPage(SpeciesTheme theme) {
    final (dotColor, accentColor) = dotColorsForKey('fluff', null, theme);
    // 홈 위젯 미리보기 느낌의 미니 카드
    final preview = Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [theme.gradStart, theme.gradEnd],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: DesignTokens.line),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          PixelMotionAnimation(
            spriteKey: 'fluff',
            motion: PixelMotion.walk,
            width: 64,
            height: 64,
            dotColor: dotColor,
            accentColor: accentColor,
          ),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _nameController.text.trim().isEmpty
                    ? '내 펫'
                    : _nameController.text.trim(),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: DesignTokens.ink,
                ),
              ),
              const SizedBox(height: 2),
              const Text(
                'Lv.1 · 행복',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: DesignTokens.ink3,
                ),
              ),
            ],
          ),
        ],
      ),
    );

    return _pageFrame(
      hero: preview,
      title: AppStrings.onboardWidgetTitle,
      body: AppStrings.onboardWidgetBody,
      primaryLabel: AppStrings.onboardWidgetButton,
      onPrimary: _requestPinWidget,
      secondaryLabel: AppStrings.onboardWidgetSkip,
      onSecondary: _finish,
      theme: theme,
    );
  }

  // ── 공통 레이아웃 ─────────────────────────────────────────────────

  Widget _heroIcon(IconData icon, SpeciesTheme theme) {
    return Container(
      width: 150,
      height: 150,
      decoration: BoxDecoration(
        color: theme.primarySoft,
        shape: BoxShape.circle,
      ),
      child: Icon(icon, size: 64, color: theme.primaryDeep),
    );
  }

  Widget _pageFrame({
    required Widget hero,
    required String title,
    required String body,
    Widget? extra,
    required String primaryLabel,
    required VoidCallback onPrimary,
    String? secondaryLabel,
    VoidCallback? onSecondary,
    required SpeciesTheme theme,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
      child: Column(
        children: [
          const Spacer(flex: 2),
          hero,
          const SizedBox(height: 24),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 21,
              fontWeight: FontWeight.w800,
              color: DesignTokens.ink,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            body,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
              color: DesignTokens.ink3,
              height: 1.5,
            ),
          ),
          if (extra != null) ...[
            const SizedBox(height: 18),
            extra,
          ],
          const Spacer(flex: 3),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _requesting ? null : onPrimary,
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 0,
              ),
              child: _requesting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : Text(
                      primaryLabel,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
            ),
          ),
          if (secondaryLabel != null)
            TextButton(
              onPressed: _requesting ? null : onSecondary,
              child: Text(
                secondaryLabel,
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: DesignTokens.ink3,
                ),
              ),
            )
          else
            const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _pageDots(SpeciesTheme theme) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(_pageCount, (i) {
        final active = i == _page;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          margin: const EdgeInsets.symmetric(horizontal: 3),
          width: active ? 18 : 6,
          height: 6,
          decoration: BoxDecoration(
            color: active ? theme.primary : DesignTokens.line2,
            borderRadius: BorderRadius.circular(999),
          ),
        );
      }),
    );
  }
}
