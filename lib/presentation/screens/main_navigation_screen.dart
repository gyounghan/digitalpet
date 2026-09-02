import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'home_screen.dart';
import 'care_screen.dart';
import 'me_screen.dart';
import 'battle_screen.dart';
import 'onboarding_screen.dart';
import 'ranking_screen.dart';
import '../providers/pet_provider.dart';
import '../../data/datasources/app_prefs_datasource.dart';
import '../../core/constants/feature_flags.dart';
import '../../core/theme/species_theme.dart';
import '../../main.dart' show runDeferredStartupTasks;

/// 메인 네비게이션 화면 — 홈 / 케어 / 배틀 / (랭킹) / 도감
/// 랭킹 탭은 FeatureFlags.enableRanking일 때만 노출 (MVP 숨김)
class MainNavigationScreen extends ConsumerStatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  ConsumerState<MainNavigationScreen> createState() =>
      _MainNavigationScreenState();
}

class _MainNavigationScreenState extends ConsumerState<MainNavigationScreen>
    with WidgetsBindingObserver {
  int _currentIndex = 0;
  Timer? _periodicUpdateTimer;

  /// 탭 정의 — 랭킹은 feature flag가 켜졌을 때만 포함된다.
  static final List<_NavTab> _tabs = [
    _NavTab(
      label: '홈',
      icon: Icons.home_rounded,
      builder: () => const HomeScreen(),
    ),
    _NavTab(
      label: '케어',
      icon: Icons.favorite_rounded,
      builder: () => const CareScreen(),
    ),
    _NavTab(
      label: '배틀',
      icon: Icons.sports_martial_arts_rounded,
      builder: () => const BattleScreen(),
    ),
    if (FeatureFlags.enableRanking)
      _NavTab(
        label: '랭킹',
        icon: Icons.emoji_events_rounded,
        builder: () => const RankingScreen(),
      ),
    _NavTab(
      label: '도감',
      icon: Icons.menu_book_rounded,
      builder: () => const MeScreen(),
    ),
  ];

  /// 탭 lazy 빌드 — 한 번이라도 방문한 탭만 실제 위젯 인스턴스를 생성·캐싱한다.
  /// 첫 페인트에 전 화면이 동시에 build/Provider watch를 시작하는 비용을 회피.
  /// 한 번 캐시된 위젯은 재사용되어 탭 전환 시 State가 유지된다.
  final List<Widget?> _screenCache = List<Widget?>.filled(_tabs.length, null);

  Widget _screenAt(int index) {
    return _screenCache[index] ??= _tabs[index].builder();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _startPeriodicUpdate();
    WidgetsBinding.instance.addPostFrameCallback((_) => _runStartupFlow());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _periodicUpdateTimer?.cancel();
    super.dispose();
  }

  /// 첫 프레임 이후 시작 흐름
  ///
  /// 1. 첫 실행이면 온보딩(이름→권한→첫 목표→위젯)을 먼저 띄운다 —
  ///    권한 다이얼로그가 온보딩 위에 무작위로 겹치지 않도록,
  ///    무거운 deferred 초기화는 온보딩이 닫힌 뒤에 실행한다.
  /// 2. 이후 무거운 초기화 (WorkManager, 위젯). 동기화 권한 안내는
  ///    홈 상단 배너(SyncPermissionBanner)가 필요 시 자동 노출.
  Future<void> _runStartupFlow() async {
    final prefs = AppPrefsDatasource();
    final onboardingDone = await prefs.isOnboardingDone();
    if (!onboardingDone) {
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          fullscreenDialog: true,
          builder: (_) => const OnboardingScreen(),
        ),
      );
      await prefs.setOnboardingDone();
    }
    await runDeferredStartupTasks();
  }

  /// 포그라운드 주기 갱신
  /// decay 간격(40~60분)을 고려해 5분 폴링이면 사용자 체감에 충분.
  /// 백그라운드는 WorkManager(15분)가 담당.
  static const Duration _foregroundPollInterval = Duration(minutes: 5);

  void _startPeriodicUpdate() {
    _periodicUpdateTimer?.cancel();
    _periodicUpdateTimer = Timer.periodic(_foregroundPollInterval, (_) {
      final petNotifier = ref.read(
        petNotifierProvider(HomeScreen.defaultPetId).notifier,
      );
      petNotifier.onMinuteTick();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    final petNotifier = ref.read(
      petNotifierProvider(HomeScreen.defaultPetId).notifier,
    );
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      petNotifier.onAppBackground();
      _periodicUpdateTimer?.cancel();
    } else if (state == AppLifecycleState.resumed) {
      petNotifier.onAppForeground();
      // 5분 폴링 첫 tick까지 기다리지 않고 복귀 즉시 1회 갱신
      petNotifier.onMinuteTick();
      _startPeriodicUpdate();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DesignTokens.bg,
      // 비활성 탭의 Ticker/애니메이션 자동 정지 (CPU/배터리 절약)
      // + 미방문 탭은 빈 SizedBox로 둬서 첫 빌드 비용 회피 (lazy 빌드)
      body: IndexedStack(
        index: _currentIndex,
        children: List.generate(_screenCache.length, (i) {
          final visited = _screenCache[i] != null || i == _currentIndex;
          if (!visited) return const SizedBox.shrink();
          return TickerMode(enabled: i == _currentIndex, child: _screenAt(i));
        }),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 0, 18, 10),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: DesignTokens.surface.withValues(alpha: 0.96),
              border: Border.all(color: DesignTokens.line, width: 1),
              borderRadius: BorderRadius.circular(22),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF4A3519).withValues(alpha: 0.10),
                  blurRadius: 22,
                  offset: const Offset(0, -6),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(7),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: List.generate(
                  _tabs.length,
                  (index) => _buildNavItem(index),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(int index) {
    final isActive = _currentIndex == index;
    final tab = _tabs[index];
    const accent = SpeciesTheme.defaultTheme;

    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _currentIndex = index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 7),
          decoration: BoxDecoration(
            color: isActive ? accent.primarySoft : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                tab.icon,
                color: isActive ? accent.primaryDeep : DesignTokens.ink3,
                size: 22,
              ),
              const SizedBox(height: 3),
              Text(
                tab.label,
                style: TextStyle(
                  fontSize: 10.5,
                  color: isActive ? accent.primaryDeep : DesignTokens.ink3,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavTab {
  final String label;
  final IconData icon;
  final Widget Function() builder;
  const _NavTab({
    required this.label,
    required this.icon,
    required this.builder,
  });
}
