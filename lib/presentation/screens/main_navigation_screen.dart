import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'home_screen.dart';
import 'evolution_screen.dart';
import 'battle_screen.dart';
import 'share_screen.dart';
import '../providers/pet_provider.dart';
import '../../core/constants/app_strings.dart';
import '../../core/theme/app_colors.dart';

/// 메인 네비게이션 화면
/// 여러 화면 간 전환을 관리하는 컨테이너
/// 앱 생명주기를 감지하여 자동 Sleep 기능을 트리거
class MainNavigationScreen extends ConsumerStatefulWidget {
  const MainNavigationScreen({super.key});
  
  @override
  ConsumerState<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends ConsumerState<MainNavigationScreen> with WidgetsBindingObserver {
  int _currentIndex = 0;
  
  final List<Widget> _screens = const [
    HomeScreen(),
    EvolutionScreen(),
    BattleScreen(),
    ShareScreen(),
  ];
  
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }
  
  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
  
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    
    // 앱 생명주기 변화 감지하여 자동 Sleep 트리거
    final petNotifier = ref.read(petNotifierProvider(HomeScreen.defaultPetId).notifier);
    
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      // 앱이 백그라운드로 전환됨
      petNotifier.onAppBackground();
    } else if (state == AppLifecycleState.resumed) {
      // 앱이 포그라운드로 전환됨
      petNotifier.onAppForeground();
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.transparent,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 10,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: SafeArea(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.backgroundDarkSecondary.withValues(alpha: 0.9), // 반투명 밝은 배경
              border: Border(
                top: BorderSide(
                  color: AppColors.primary.withValues(alpha: 0.2), // 보라색 테두리
                  width: 1,
                ),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: List.generate(
                _screens.length,
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
    
    final labels = [
      AppStrings.home,
      AppStrings.evolution,
      AppStrings.battle,
      AppStrings.share,
    ];
    
    final icons = [
      Icons.home,
      Icons.auto_awesome,
      Icons.sports_martial_arts,
      Icons.share,
    ];
    
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _currentIndex = index;
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isActive
                ? AppColors.primary.withValues(alpha: 0.15) // 활성: 연한 보라색 배경
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icons[index],
                color: isActive
                    ? AppColors.primary // 활성: 보라색
                    : AppColors.textSecondary, // 비활성: 중간 회색
                size: 24,
              ),
              const SizedBox(height: 4),
              Text(
                labels[index],
                style: TextStyle(
                  fontSize: 11,
                  color: isActive
                      ? AppColors.primary // 활성: 보라색
                      : AppColors.textSecondary, // 비활성: 중간 회색
                  fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
