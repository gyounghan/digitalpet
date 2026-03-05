import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/pet_provider.dart';
import '../widgets/pet_button.dart';
import '../widgets/glass_card.dart';
import '../../core/theme/app_colors.dart';
import 'home_screen.dart';

/// 진화 화면
/// design 폴더의 Evolution.tsx를 기반으로 구현
class EvolutionScreen extends ConsumerStatefulWidget {
  const EvolutionScreen({super.key});
  
  @override
  ConsumerState<EvolutionScreen> createState() => _EvolutionScreenState();
}

class _EvolutionScreenState extends ConsumerState<EvolutionScreen>
    with TickerProviderStateMixin {
  bool isEvolving = false;
  bool hasEvolved = false;
  late AnimationController _evolutionController;
  late AnimationController _particleController;
  
  @override
  void initState() {
    super.initState();
    _evolutionController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );
    _particleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat();
  }
  
  @override
  void dispose() {
    _evolutionController.dispose();
    _particleController.dispose();
    super.dispose();
  }
  
  void _handleEvolve() {
    setState(() {
      isEvolving = true;
    });
    
    _evolutionController.forward().then((_) {
      setState(() {
        hasEvolved = true;
        isEvolving = false;
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
        child: SafeArea(
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
            data: (pet) => _buildEvolutionContent(context, pet),
          ),
        ),
      ),
    );
  }
  
  Widget _buildEvolutionContent(BuildContext context, pet) {
    final requiredLevel = 15;
    final currentLevel = pet.level;
    final progress = (currentLevel / requiredLevel).clamp(0.0, 1.0);
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 32),
          // 헤더
          const Column(
            children: [
              Text(
                'Evolution',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Ready to evolve your pet?',
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.textTertiary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 48),
          // 진화 디스플레이
          Stack(
            alignment: Alignment.center,
            children: [
              // 글로우 효과 (진화 중일 때)
              if (isEvolving)
                AnimatedBuilder(
                  animation: _evolutionController,
                  builder: (context, child) {
                    return Container(
                      width: 300,
                      height: 300,
                      decoration: BoxDecoration(
                        gradient: RadialGradient(
                          colors: [
                            AppColors.primaryGlow.withValues(
                              alpha: 0.2 * _evolutionController.value,
                            ),
                            AppColors.accentPink.withValues(
                              alpha: 0.2 * _evolutionController.value,
                            ),
                          ],
                        ),
                        shape: BoxShape.circle,
                      ),
                    );
                  },
                ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Before
                  AnimatedBuilder(
                    animation: _evolutionController,
                    builder: (context, child) {
                      return Transform.scale(
                        scale: isEvolving
                            ? 1.0 - (0.1 * _evolutionController.value)
                            : 1.0,
                        child: Opacity(
                          opacity: isEvolving
                              ? 1.0 - (0.5 * _evolutionController.value)
                              : 1.0,
                          child: Column(
                            children: [
                              Container(
                                width: 128,
                                height: 128,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      AppColors.glassBackground,
                                      AppColors.glassBackgroundLight,
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(24),
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
                                child: const Center(
                                  child: Text(
                                    '🌟',
                                    style: TextStyle(fontSize: 64),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                              const Text(
                                'Current',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: AppColors.textTertiary,
                                ),
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                'Luna',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Lv. $currentLevel',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textTertiary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(width: 32),
                  // Arrow / Animation
                  SizedBox(
                    width: 64,
                    height: 64,
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      child: isEvolving
                          ? Container(
                              key: const ValueKey('evolving'),
                              decoration: BoxDecoration(
                                gradient: AppColors.primaryGradient,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.auto_awesome,
                                color: AppColors.textPrimary,
                                size: 32,
                              ),
                            )
                          : const Icon(
                              Icons.arrow_forward,
                              key: ValueKey('arrow'),
                              color: AppColors.textTertiary,
                              size: 32,
                            ),
                    ),
                  ),
                  const SizedBox(width: 32),
                  // After
                  AnimatedBuilder(
                    animation: _evolutionController,
                    builder: (context, child) {
                      return Transform.scale(
                        scale: isEvolving
                            ? 1.0 + (0.1 * _evolutionController.value)
                            : hasEvolved
                                ? 1.0
                                : 1.0,
                        child: Column(
                          children: [
                            Container(
                              width: 128,
                              height: 128,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    AppColors.glassBackground,
                                    AppColors.glassBackgroundLight,
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(24),
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
                              child: Stack(
                                children: [
                                  if (hasEvolved)
                                    Container(
                                      decoration: BoxDecoration(
                                        gradient: AppColors.glassGradient,
                                        borderRadius: BorderRadius.circular(24),
                                      ),
                                    ),
                                  Center(
                                    child: Text(
                                      hasEvolved ? '✨' : '?',
                                      style: const TextStyle(fontSize: 64),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'Next Stage',
                              style: TextStyle(
                                fontSize: 14,
                                color: AppColors.textTertiary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              hasEvolved ? 'Celestia' : '???',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Lv. $requiredLevel',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textTertiary,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 48),
          // 정보 카드
          GlassCard(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(
                        Icons.star,
                        color: AppColors.primary,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Evolution Requirements',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Level 15 or higher',
                            style: TextStyle(
                              fontSize: 14,
                              color: AppColors.textTertiary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Current Level',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.textTertiary,
                      ),
                    ),
                    Text(
                      '$currentLevel / $requiredLevel',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Container(
                  height: 8,
                  decoration: BoxDecoration(
                    color: AppColors.glassBackground,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: FractionallySizedBox(
                    widthFactor: progress,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: AppColors.primaryGradient,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          // 액션 버튼
          PetButton(
            variant: PetButtonVariant.primary,
            icon: Icons.auto_awesome,
            onPressed: isEvolving ? null : _handleEvolve,
            disabled: isEvolving || currentLevel < requiredLevel,
            child: Text(isEvolving
                ? 'Evolving...'
                : hasEvolved
                    ? 'Evolved!'
                    : 'Evolve Now'),
          ),
        ],
      ),
    );
  }
}
