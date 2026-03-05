import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/pet_provider.dart';
import '../widgets/pet_card.dart';
import '../widgets/pet_button.dart';
import '../widgets/glass_card.dart';
import '../../core/theme/app_colors.dart';
import 'home_screen.dart';

/// 배틀 화면
/// design 폴더의 Battle.tsx를 기반으로 구현
class BattleScreen extends ConsumerStatefulWidget {
  const BattleScreen({super.key});
  
  @override
  ConsumerState<BattleScreen> createState() => _BattleScreenState();
}

class _BattleScreenState extends ConsumerState<BattleScreen> {
  int myPetHp = 100;
  int opponentHp = 100;
  String? battleStatus; // "victory" 또는 "defeat"
  
  void _handleAttack() {
    if (battleStatus != null) return;
    
    setState(() {
      final damage = 10 + (DateTime.now().millisecondsSinceEpoch % 20);
      opponentHp = (opponentHp - damage).clamp(0, 100);
      
      if (opponentHp == 0) {
        battleStatus = 'victory';
      } else {
        // 상대방 공격
        Future.delayed(const Duration(milliseconds: 1500), () {
          if (mounted) {
            setState(() {
              final opponentDamage = 8 + (DateTime.now().millisecondsSinceEpoch % 15);
              myPetHp = (myPetHp - opponentDamage).clamp(0, 100);
              
              if (myPetHp == 0) {
                battleStatus = 'defeat';
              }
            });
          }
        });
      }
    });
  }
  
  void _handleDefend() {
    if (battleStatus != null) return;
    
    setState(() {
      // 방어 시 데미지 감소
      Future.delayed(const Duration(milliseconds: 1500), () {
        if (mounted) {
          setState(() {
            final reducedDamage = 3 + (DateTime.now().millisecondsSinceEpoch % 8);
            myPetHp = (myPetHp - reducedDamage).clamp(0, 100);
            
            if (myPetHp == 0) {
              battleStatus = 'defeat';
            }
          });
        }
      });
    });
  }
  
  @override
  Widget build(BuildContext context) {
    final petAsync = ref.watch(petNotifierProvider(HomeScreen.defaultPetId));
    
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppColors.backgroundGradient,
        ),
        child: Stack(
          children: [
            // 배틀 아레나 글로우
            Positioned(
              top: MediaQuery.of(context).size.height / 2 - 192,
              left: MediaQuery.of(context).size.width / 2 - 192,
              child: Container(
                width: 384,
                height: 384,
                decoration: BoxDecoration(
                  color: AppColors.accentPink.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
              ),
            ),
            SafeArea(
              child: petAsync.when(
                loading: () => const Center(
                  child: CircularProgressIndicator(color: AppColors.primary),
                ),
                error: (error, stackTrace) => Center(
                  child: Text(
                    'Error: $error',
                    style: const TextStyle(color: AppColors.danger),
                  ),
                ),
                data: (pet) => _buildBattleContent(context, pet),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildBattleContent(BuildContext context, pet) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 16),
          // 헤더
          const Column(
            children: [
              Text(
                'Battle Arena',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              SizedBox(height: 4),
              Text(
                'Turn: Your',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textTertiary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
          // 배틀 카드
          Stack(
            alignment: Alignment.center,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: PetCard(
                      petName: 'Luna',
                      level: pet.level,
                      hp: myPetHp,
                      maxHp: 100,
                      side: PetCardSide.left,
                      mood: myPetHp > 50
                          ? PetMood.happy
                          : myPetHp > 20
                              ? PetMood.neutral
                              : PetMood.sad,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: PetCard(
                      petName: 'Shadow',
                      level: pet.level - 1,
                      hp: opponentHp,
                      maxHp: 100,
                      side: PetCardSide.right,
                      mood: opponentHp > 50
                          ? PetMood.neutral
                          : opponentHp > 20
                              ? PetMood.neutral
                              : PetMood.sad,
                    ),
                  ),
                ],
              ),
              // VS 배지
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppColors.backgroundDark,
                    width: 4,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.3),
                      blurRadius: 20,
                      spreadRadius: 0,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.flash_on,
                  color: AppColors.textPrimary,
                  size: 32,
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
          // 배틀 로그 (간단한 버전)
          GlassCard(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              height: 128,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (battleStatus == null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.glassBackground,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Text(
                        'Battle started!',
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          // 액션 버튼
          Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: PetButton(
                      variant: PetButtonVariant.primary,
                      icon: Icons.bolt,
                      onPressed: battleStatus == null ? _handleAttack : null,
                      disabled: battleStatus != null || myPetHp == 0 || opponentHp == 0,
                      child: const Text('Attack'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: PetButton(
                      variant: PetButtonVariant.secondary,
                      icon: Icons.shield,
                      onPressed: battleStatus == null ? _handleDefend : null,
                      disabled: battleStatus != null || myPetHp == 0 || opponentHp == 0,
                      child: const Text('Defend'),
                    ),
                  ),
                ],
              ),
              if (battleStatus != null) ...[
                const SizedBox(height: 16),
                GlassCard(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Text(
                        battleStatus == 'victory' ? 'Victory!' : 'Defeat!',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        battleStatus == 'victory'
                            ? 'You won the battle!'
                            : 'Better luck next time!',
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
