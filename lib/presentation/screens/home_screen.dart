import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/pet_provider.dart';
import '../widgets/status_bar.dart';
import '../widgets/pet_button.dart';
import '../widgets/glass_card.dart';
import '../widgets/pet_image_animation.dart';
import '../../core/theme/app_colors.dart';
import '../../data/services/widget_service.dart';
import '../../domain/entities/pet.dart';

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
  PetImageType _currentPetImageType = PetImageType.sleeping;
  
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
  
  /// Feed 액션 처리
  /// 
  /// Feed 버튼 클릭 시 호출되어 배고픈 이미지로 전환
  Future<void> _handleFeed() async {
    setState(() {
      _currentPetImageType = PetImageType.hungry;
    });
    
    final petNotifier = ref.read(petNotifierProvider(HomeScreen.defaultPetId).notifier);
    await petNotifier.feed();
    
    // 위젯 업데이트 (배고픈 이미지로)
    final petAsync = ref.read(petNotifierProvider(HomeScreen.defaultPetId));
    final pet = petAsync.valueOrNull;
    if (pet != null) {
      final widgetService = WidgetService();
      await widgetService.updatePetWidget(pet, imageType: 'hungry');
    }
    
    // 3초 후 잠자는 상태로 복귀
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _currentPetImageType = PetImageType.sleeping;
        });
        
        // 위젯도 잠자는 이미지로 업데이트
        final pet = ref.read(petNotifierProvider(HomeScreen.defaultPetId)).valueOrNull;
        if (pet != null) {
          final widgetService = WidgetService();
          widgetService.updatePetWidget(pet, imageType: 'sleeping');
        }
      }
    });
  }
  
  /// Sleep 액션 처리
  /// 
  /// Sleep 버튼 클릭 시 호출되어 잠자는 이미지로 전환
  Future<void> _handleSleep() async {
    setState(() {
      _currentPetImageType = PetImageType.sleeping;
    });
    
    final petNotifier = ref.read(petNotifierProvider(HomeScreen.defaultPetId).notifier);
    await petNotifier.sleep();
    
    // 위젯 업데이트 (잠자는 이미지로)
    final petAsync = ref.read(petNotifierProvider(HomeScreen.defaultPetId));
    final pet = petAsync.valueOrNull;
    if (pet != null) {
      final widgetService = WidgetService();
      await widgetService.updatePetWidget(pet, imageType: 'sleeping');
    }
  }
  
  /// 펫 상태를 한국어 텍스트로 변환
  /// 
  /// [mood] 펫의 기분 상태
  /// 
  /// 반환: 한국어 상태 텍스트
  String _getMoodText(PetMood mood) {
    switch (mood) {
      case PetMood.happy:
        return '기쁨';
      case PetMood.sleepy:
        return '졸림';
      case PetMood.hungry:
        return '배고픔';
      case PetMood.bored:
        return '지루함';
      case PetMood.normal:
        return '보통';
    }
  }
  
  /// 펫 상태에 따른 색상 반환
  /// 
  /// [mood] 펫의 기분 상태
  /// 
  /// 반환: 상태에 맞는 색상
  Color _getMoodColor(PetMood mood) {
    switch (mood) {
      case PetMood.happy:
        return AppColors.accentPink;
      case PetMood.sleepy:
        return AppColors.primary;
      case PetMood.hungry:
        return Colors.orange;
      case PetMood.bored:
        return Colors.grey;
      case PetMood.normal:
        return AppColors.textSecondary;
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
                // Pet 이름, 레벨, 상태
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
                    const SizedBox(height: 4),
                    // 펫의 현재 상태 표시
                    Text(
                      _getMoodText(pet.mood),
                      style: TextStyle(
                        fontSize: 11,
                        color: _getMoodColor(pet.mood),
                        fontWeight: FontWeight.w500,
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
                    child: PetImageAnimation(
                      type: _currentPetImageType,
                      duration: const Duration(milliseconds: 800),
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
                    onPressed: _handleFeed,
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
                    onPressed: _handleSleep,
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
