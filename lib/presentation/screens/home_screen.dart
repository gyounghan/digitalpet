import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/pet_provider.dart';
import '../widgets/status_bar.dart';
import '../widgets/pet_button.dart';
import '../widgets/glass_card.dart';
import '../widgets/sleeping_pet_animation.dart';
import '../../core/theme/app_colors.dart';

/// 홈 화면
/// Pet의 상태를 표시하고 Feed/Play/Sleep 액션을 수행할 수 있는 메인 화면
/// design 폴더의 Home.tsx를 기반으로 재디자인
class HomeScreen extends ConsumerStatefulWidget {
  /// 기본 Pet ID
  /// 실제 앱에서는 사용자가 선택한 Pet ID를 사용
  static const String defaultPetId = 'default-pet';
  
  const HomeScreen({super.key});
  
  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _petAnimationController;
  
  @override
  void initState() {
    super.initState();
    _petAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }
  
  @override
  void dispose() {
    _petAnimationController.dispose();
    super.dispose();
  }
  
  String _getMoodEmoji(int happiness) {
    if (happiness >= 70) {
      return '🌟';
    } else if (happiness >= 40) {
      return '💤';
    } else {
      return '💧';
    }
  }
  
  @override
  Widget build(BuildContext context) {
    // Pet 상태를 관리하는 Notifier 가져오기
    final petAsync = ref.watch(petNotifierProvider(HomeScreen.defaultPetId));
    
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppColors.backgroundGradient,
        ),
        child: Stack(
          children: [
            // 배경 글로우 효과
            Positioned(
              top: 80,
              left: MediaQuery.of(context).size.width / 2 - 192,
              child: Container(
                width: 384,
                height: 384,
                decoration: BoxDecoration(
                  color: AppColors.primaryGlow,
                  shape: BoxShape.circle,
                ),
              ),
            ),
            Positioned(
              bottom: 80,
              right: 40,
              child: Container(
                width: 256,
                height: 256,
                decoration: BoxDecoration(
                  color: AppColors.accentPink.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
              ),
            ),
            // 메인 콘텐츠
            SafeArea(
              child: petAsync.when(
                // 로딩 중
                loading: () => const Center(
                  child: CircularProgressIndicator(
                    color: AppColors.primary,
                  ),
                ),
                // 에러 발생
                error: (error, stackTrace) => Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.error_outline,
                        size: 64,
                        color: AppColors.danger,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Error: $error',
                        style: const TextStyle(color: AppColors.danger),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      PetButton(
                        variant: PetButtonVariant.primary,
                        onPressed: () {
                          ref
                              .read(petNotifierProvider(HomeScreen.defaultPetId)
                                  .notifier)
                              .refresh();
                        },
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
                // 데이터 로드 완료
                data: (pet) => _buildPetContent(context, ref, pet),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  /// Pet 콘텐츠 빌드
  /// 
  /// Pet 정보와 상태바, 액션 버튼을 표시
  /// design 폴더의 Home.tsx 레이아웃을 정확히 매칭
  Widget _buildPetContent(BuildContext context, WidgetRef ref, pet) {
    final petName = 'Luna'; // TODO: Pet 엔티티에 name 필드 추가 필요
    final moodEmoji = _getMoodEmoji(pet.happiness);
    
    // 기본 펫은 항상 잠자는 모습으로 표시
    final isSleeping = true;
    
    return LayoutBuilder(
      builder: (context, constraints) {
        return Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: 390,
            ),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
            // 헤더
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // 메뉴 버튼
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.glassBackground,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: AppColors.glassBorder,
                      width: 1,
                    ),
                  ),
                  child: IconButton(
                    icon: const Icon(
                      Icons.menu,
                      color: AppColors.textSecondary,
                      size: 20,
                    ),
                    onPressed: () {
                      // TODO: 네비게이션 메뉴
                    },
                  ),
                ),
                // Pet 이름과 레벨
                Column(
                  children: [
                    Text(
                      petName,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      'Level ${pet.level}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ],
                ),
                // 설정 버튼
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.glassBackground,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: AppColors.glassBorder,
                      width: 1,
                    ),
                  ),
                  child: IconButton(
                    icon: const Icon(
                      Icons.settings,
                      color: AppColors.textSecondary,
                      size: 20,
                    ),
                    onPressed: () {
                      // TODO: 설정 화면
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),
            // Pet Display (flex-1 역할 - 남은 공간 차지)
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Center(
                    child: AnimatedBuilder(
                      animation: _petAnimationController,
                      builder: (context, child) {
                        // 잠자는 상태일 때는 위아래 움직임 없음
                        final yOffset = isSleeping ? 0.0 : -10 * _petAnimationController.value;
                        return Transform.translate(
                          offset: Offset(0, yOffset),
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              // 글로우 효과 (blur-3xl scale-150)
                              Transform.scale(
                                scale: 1.5,
                                child: Container(
                                  width: 192,
                                  height: 192,
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [
                                        AppColors.primary.withValues(alpha: 0.3),
                                        AppColors.accentPink.withValues(alpha: 0.3),
                                      ],
                                    ),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ),
                              // Pet 컨테이너 (w-48 h-48 = 192px)
                              Container(
                                width: 192,
                                height: 192,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      AppColors.glassBackground,
                                      AppColors.glassBackgroundLight,
                                    ],
                                  ),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: AppColors.glassBorder,
                                    width: 1,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.3),
                                      blurRadius: 20,
                                      spreadRadius: 0,
                                    ),
                                  ],
                                ),
                                child: ClipOval(
                                  child: isSleeping
                                      ? SleepingPetAnimation(
                                          size: 192,
                                          duration: const Duration(milliseconds: 800),
                                        )
                                      : Center(
                                          child: Text(
                                            moodEmoji,
                                            style: const TextStyle(fontSize: 96),
                                          ),
                                        ),
                                ),
                              ),
                              // 플로팅 파티클 (w-2 h-2 = 8px)
                              // 잠자는 상태일 때는 파티클 숨김
                              if (!isSleeping)
                                ...List.generate(3, (index) {
                                  return Positioned(
                                    left: (20 + index * 30) * 1.92,
                                    top: (10 + index * 20) * 1.92,
                                    child: AnimatedBuilder(
                                      animation: _petAnimationController,
                                      builder: (context, child) {
                                        final delay = index * 0.3;
                                        final cycle = (_petAnimationController.value + delay) % 1.0;
                                        final yOffset = -20 + (-20 * (cycle < 0.5 ? cycle * 2 : 2 - cycle * 2));
                                        final opacity = 0.3 + (0.5 * (cycle < 0.5 ? cycle * 2 : 2 - cycle * 2));
                                        
                                        return Transform.translate(
                                          offset: Offset(0, yOffset),
                                          child: Opacity(
                                            opacity: opacity,
                                            child: Container(
                                              width: 8,
                                              height: 8,
                                              decoration: BoxDecoration(
                                                color: AppColors.accentCyan.withValues(alpha: 0.5),
                                                shape: BoxShape.circle,
                                              ),
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  );
                                }),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            // 상태 섹션
            GlassCard(
              gradient: true,
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  StatusBar(
                    label: 'Hunger',
                    value: pet.hunger,
                    color: StatusBarColor.hunger,
                    icon: Icons.restaurant,
                  ),
                  const SizedBox(height: 16),
                  StatusBar(
                    label: 'Happiness',
                    value: pet.happiness,
                    color: StatusBarColor.happiness,
                    icon: Icons.favorite,
                  ),
                  const SizedBox(height: 16),
                  StatusBar(
                    label: 'Stamina',
                    value: pet.stamina,
                    color: StatusBarColor.stamina,
                    icon: Icons.battery_charging_full,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            // 액션 버튼들 (grid grid-cols-3 gap-3)
            Row(
              children: [
                Expanded(
                  child: PetButton(
                    variant: PetButtonVariant.secondary,
                    onPressed: () {
                      ref
                          .read(petNotifierProvider(HomeScreen.defaultPetId)
                              .notifier)
                          .feed();
                    },
                    child: const Text('Feed'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: PetButton(
                    variant: PetButtonVariant.primary,
                    onPressed: () {
                      ref
                          .read(petNotifierProvider(HomeScreen.defaultPetId)
                              .notifier)
                          .play();
                    },
                    child: const Text('Play'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: PetButton(
                    variant: PetButtonVariant.secondary,
                    onPressed: () {
                      ref
                          .read(petNotifierProvider(HomeScreen.defaultPetId)
                              .notifier)
                          .sleep();
                    },
                    child: const Text('Sleep'),
                  ),
                ),
              ],
            ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
