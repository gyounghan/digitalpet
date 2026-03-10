import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/pet_provider.dart';
import '../widgets/status_bar.dart';
import '../widgets/glass_card.dart';
import '../widgets/pet_image_animation.dart';
import '../widgets/pet_button.dart';
import '../../core/theme/app_colors.dart';
import '../../core/constants/app_strings.dart';
import '../../domain/entities/pet.dart';
import '../../core/utils/pet_image_helper.dart';

/// 홈 화면
/// Pet의 상태를 표시하는 메인 화면
/// Feed/Play/Sleep은 자동화되어 있어 수동 버튼이 없음
/// design 폴더의 Home.tsx를 기반으로 재디자인
class HomeScreen extends ConsumerStatefulWidget {
  /// 기본 Pet ID
  /// 실제 앱에서는 사용자가 선택한 Pet ID를 사용
  static const String defaultPetId = 'default-pet';
  
  const HomeScreen({super.key});
  
  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  
  // Feed 버튼: 조건부 표시 (배고픔 상태 + 식사 시간대)
  // Play: 걷기/운동량 기반 자동
  // Sleep: 폰 미사용 감지 기반 자동
  
  /// 펫 상태를 한국어 텍스트로 변환
  /// 
  /// [mood] 펫의 기분 상태
  /// 
  /// 반환: 한국어 상태 텍스트
  String _getMoodText(PetMood mood) {
    switch (mood) {
      case PetMood.happy:
        return AppStrings.moodHappy;
      case PetMood.sleepy:
        return AppStrings.moodSleepy;
      case PetMood.hungry:
        return AppStrings.moodHungry;
      case PetMood.bored:
        return AppStrings.moodBored;
      case PetMood.normal:
        return AppStrings.moodNormal;
      case PetMood.energetic:
        return AppStrings.moodEnergetic;
      case PetMood.tired:
        return AppStrings.moodTired;
      case PetMood.full:
        return AppStrings.moodFull;
      case PetMood.anxious:
        return AppStrings.moodAnxious;
      case PetMood.satisfied:
        return AppStrings.moodSatisfied;
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
      case PetMood.energetic:
        return Colors.yellow.shade700;
      case PetMood.tired:
        return Colors.deepPurple;
      case PetMood.full:
        return Colors.green;
      case PetMood.anxious:
        return Colors.red.shade300;
      case PetMood.satisfied:
        return Colors.blue;
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
        child: SafeArea(
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
                        '${AppStrings.error}: $error',
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
                        child: Text(AppStrings.retry),
                      ),
                    ],
                  ),
                ),
            // 데이터 로드 완료
            data: (pet) => _buildPetContent(context, ref, pet),
          ),
        ),
      ),
    );
  }
  
  /// Pet 콘텐츠 빌드
  /// 
  /// Pet 정보와 상태바, 액션 버튼을 표시
  /// design 폴더의 Home.tsx 레이아웃을 정확히 매칭
  Widget _buildPetContent(BuildContext context, WidgetRef ref, pet) {
    final petName = pet.name;
    
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
                    color: AppColors.accentCyan, // 밝은 라일락 배경 (#E0D6F5)
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 5,
                        spreadRadius: 0,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: IconButton(
                    icon: Icon(
                      Icons.menu,
                      color: AppColors.primary, // 보라색 아이콘 (#A08CDB)
                      size: 20,
                    ),
                    onPressed: () {
                      // TODO: 네비게이션 메뉴
                    },
                  ),
                ),
                // Pet 이름, 레벨, 상태
                GestureDetector(
                  onTap: () => _showNameEditDialog(context, ref, pet),
                  child: Column(
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            petName,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w500,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            Icons.edit,
                            size: 14,
                            color: AppColors.textSecondary,
                          ),
                        ],
                      ),
                    Text(
                      '${AppStrings.level} ${pet.level}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.primary, // 보라색 (#A08CDB)
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
                ),
                // 설정 버튼
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.accentCyan, // 밝은 라일락 배경 (#E0D6F5)
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 5,
                        spreadRadius: 0,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: IconButton(
                    icon: Icon(
                      Icons.settings,
                      color: AppColors.primary, // 보라색 아이콘 (#A08CDB)
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
                      type: getPetImageTypeFromMood(pet.mood),
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
                    label: AppStrings.hunger,
                    value: pet.hunger,
                    color: StatusBarColor.hunger,
                    icon: Icons.restaurant,
                  ),
                  const SizedBox(height: 16),
                  StatusBar(
                    label: AppStrings.stamina,
                    value: pet.stamina,
                    color: StatusBarColor.stamina,
                    icon: Icons.bedtime,
                  ),
                  const SizedBox(height: 16),
                  StatusBar(
                    label: AppStrings.happiness,
                    value: pet.happiness,
                    color: StatusBarColor.happiness,
                    icon: Icons.directions_run,
                  ),
                ],
              ),
            ),
            // Feed 버튼 (조건부 표시: 배고픔 상태 + 식사 시간대 또는 매우 심한 배고픔)
            Consumer(
              builder: (context, ref, _) {
                final canFeedUseCase = ref.watch(canFeedPetUseCaseProvider);
                final canFeed = canFeedUseCase.canFeed(pet);
                
                if (!canFeed) {
                  return const SizedBox.shrink();
                }
                
                return Padding(
                  padding: const EdgeInsets.only(top: 24),
                  child: PetButton(
                    variant: PetButtonVariant.primary,
                    icon: Icons.restaurant,
                    onPressed: () {
                      ref.read(petNotifierProvider(HomeScreen.defaultPetId).notifier).feed();
                    },
                    child: Text(AppStrings.feed),
                  ),
                );
              },
            ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
  
  /// 펫 이름 편집 다이얼로그 표시
  /// 
  /// [context] BuildContext
  /// [ref] WidgetRef
  /// [pet] 현재 Pet 엔티티
  void _showNameEditDialog(BuildContext context, WidgetRef ref, Pet pet) {
    final TextEditingController nameController = TextEditingController(text: pet.name);
    
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: AppColors.backgroundDark,
          title: const Text(
            '펫 이름 변경',
            style: TextStyle(color: AppColors.textPrimary),
          ),
          content: TextField(
            controller: nameController,
            style: const TextStyle(color: AppColors.textPrimary),
            decoration: InputDecoration(
              hintText: '펫 이름을 입력하세요',
              hintStyle: TextStyle(color: AppColors.textSecondary),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: AppColors.primary),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: AppColors.primary, width: 2),
              ),
            ),
            maxLength: 20,
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                '취소',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ),
            TextButton(
              onPressed: () {
                final newName = nameController.text.trim();
                if (newName.isNotEmpty) {
                  ref.read(petNotifierProvider(HomeScreen.defaultPetId).notifier).updateName(newName);
                }
                Navigator.of(context).pop();
              },
              child: Text(
                '확인',
                style: TextStyle(color: AppColors.primary),
              ),
            ),
          ],
        );
      },
    );
  }
}
