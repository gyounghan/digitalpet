import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'home_screen.dart';
import 'care_screen.dart';
import 'me_screen.dart';
import 'battle_screen.dart';
import 'ranking_screen.dart';
import '../providers/pet_provider.dart';
import '../../core/theme/species_theme.dart';
import '../../main.dart' show runDeferredStartupTasks;

/// 메인 네비게이션 화면 — 5탭 구조 (프로토타입 정렬)
/// 홈 / 케어 / 배틀 / 랭킹 / 진화
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

  /// 5탭 lazy 빌드 — 한 번이라도 방문한 탭만 실제 위젯 인스턴스를 생성·캐싱한다.
  /// 첫 페인트에 5개 화면이 동시에 build/Provider watch를 시작하는 비용을 회피.
  /// 한 번 캐시된 위젯은 재사용되어 탭 전환 시 State가 유지된다.
  final List<Widget?> _screenCache = List<Widget?>.filled(5, null);

  Widget _screenAt(int index) {
    if (_screenCache[index] != null) return _screenCache[index]!;
    final widget = switch (index) {
      0 => const HomeScreen(),
      1 => const CareScreen(),
      2 => const BattleScreen(),
      3 => const RankingScreen(),
      4 => const MeScreen(),
      _ => const SizedBox.shrink(),
    };
    _screenCache[index] = widget;
    return widget;
  }

  static const List<_NavTab> _tabs = [
    _NavTab(label: '홈', icon: Icons.home_rounded),
    _NavTab(label: '케어', icon: Icons.favorite_rounded),
    _NavTab(label: '배틀', icon: Icons.sports_martial_arts_rounded),
    _NavTab(label: '랭킹', icon: Icons.emoji_events_rounded),
    _NavTab(label: '도감', icon: Icons.menu_book_rounded),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _startPeriodicUpdate();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // 첫 프레임 이후 무거운 초기화 (WorkManager, 위젯)
      // 동기화 권한 안내는 홈 상단 배너(SyncPermissionBanner)가 필요 시 자동 노출.
      await runDeferredStartupTasks();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _periodicUpdateTimer?.cancel();
    super.dispose();
  }

  /// 포그라운드 주기 갱신
  /// decay 간격(40~60분)을 고려해 5분 폴링이면 사용자 체감에 충분.
  /// 백그라운드는 WorkManager(15분)가 담당.
  static const Duration _foregroundPollInterval = Duration(minutes: 5);

  void _startPeriodicUpdate() {
    _periodicUpdateTimer?.cancel();
    _periodicUpdateTimer = Timer.periodic(
      _foregroundPollInterval,
      (_) {
        final petNotifier =
            ref.read(petNotifierProvider(HomeScreen.defaultPetId).notifier);
        petNotifier.onMinuteTick();
      },
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    final petNotifier =
        ref.read(petNotifierProvider(HomeScreen.defaultPetId).notifier);
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
      // 비활성 탭의 Ticker/애니메이션 자동 정지 (CPU/배터리 절약)
      // + 미방문 탭은 빈 SizedBox로 둬서 첫 빌드 비용 회피 (lazy 빌드)
      body: IndexedStack(
        index: _currentIndex,
        children: List.generate(_screenCache.length, (i) {
          final visited = _screenCache[i] != null || i == _currentIndex;
          if (!visited) return const SizedBox.shrink();
          return TickerMode(
            enabled: i == _currentIndex,
            child: _screenAt(i),
          );
        }),
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: DesignTokens.surface,
          border: Border(
            top: BorderSide(color: DesignTokens.line, width: 1),
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
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
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            color: isActive ? accent.primarySoft : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
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
  const _NavTab({required this.label, required this.icon});
}
