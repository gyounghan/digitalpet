import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/pet_provider.dart';
import '../widgets/pet_button.dart';
import '../widgets/glass_card.dart';
import '../../core/theme/app_colors.dart';
import '../../core/constants/app_strings.dart';
import '../../domain/usecases/calculate_daily_goals_score_usecase.dart';
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
  
  /// 일일 목표 점수 조회
  /// 
  /// pet 상태 변경 시 자동으로 갱신되도록 FutureProvider 사용
  Future<DailyGoalsScore> _getDailyGoalsScore(WidgetRef ref, dynamic pet) async {
    final petRepository = ref.read(petRepositoryProvider);
    final activityRepository = ref.read(activityRepositoryProvider);
    final calculateScoreUseCase = CalculateDailyGoalsScoreUseCase(
      petRepository: petRepository,
      activityRepository: activityRepository,
    );
    return await calculateScoreUseCase(pet.id);
  }
  
  /// 일일 목표 항목 빌드
  Widget _buildGoalItem(
    String label,
    int progress,
    int goal,
    bool achieved,
    IconData icon,
  ) {
    final progressValue = goal > 0 ? (progress / goal).clamp(0.0, 1.0) : 0.0;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(
                  icon,
                  size: 16,
                  color: achieved ? AppColors.accentPink : AppColors.textSecondary,
                ),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    color: achieved ? AppColors.accentPink : AppColors.textSecondary,
                    fontWeight: achieved ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ],
            ),
            Text(
              achieved ? '완료' : '$progress/$goal',
              style: TextStyle(
                fontSize: 12,
                color: achieved ? AppColors.accentPink : AppColors.textTertiary,
                fontWeight: achieved ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        LinearProgressIndicator(
          value: progressValue,
          backgroundColor: AppColors.glassBackground,
          valueColor: AlwaysStoppedAnimation<Color>(
            achieved ? AppColors.accentPink : AppColors.primary,
          ),
        ),
      ],
    );
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
          Column(
            children: [
              Text(
                AppStrings.evolution,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                AppStrings.evolutionReady,
                style: const TextStyle(
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
              LayoutBuilder(
                builder: (context, constraints) {
                  final maxWidth = constraints.maxWidth;
                  final isSmallScreen = maxWidth < 400;
                  final imageSize = isSmallScreen ? 100.0 : 128.0;
                  final spacing = isSmallScreen ? 16.0 : 32.0;
                  
                  return Row(
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
                                    width: imageSize,
                                    height: imageSize,
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
                              Text(
                                AppStrings.evolutionCurrent,
                                style: const TextStyle(
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
                  SizedBox(width: spacing),
                  // Arrow / Animation
                  SizedBox(
                    width: isSmallScreen ? 48.0 : 64.0,
                    height: isSmallScreen ? 48.0 : 64.0,
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
                  SizedBox(width: spacing),
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
                              width: imageSize,
                              height: imageSize,
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
                            Text(
                              AppStrings.evolutionNextStage,
                              style: const TextStyle(
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
                  );
                },
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
                            AppStrings.evolutionRequirements,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            AppStrings.evolutionLevelRequired,
                            style: const TextStyle(
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
                    Text(
                      AppStrings.evolutionCurrentLevel,
                      style: const TextStyle(
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
          // 일일 목표 진행 상황
          // pet 상태 변경 시 자동으로 갱신되도록 FutureBuilder의 key를 pet 상태로 설정
          FutureBuilder<DailyGoalsScore>(
            key: ValueKey('daily_goals_${pet.todayFeedCount}_${pet.todaySleepHours}_${pet.lastUpdated}_${pet.level}'),
            future: _getDailyGoalsScore(ref, pet),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24.0),
                    child: CircularProgressIndicator(color: AppColors.primary),
                  ),
                );
              }
              
              if (snapshot.hasError) {
                return Center(
                  child: Text(
                    '목표를 불러오는 중 오류가 발생했습니다.',
                    style: const TextStyle(color: AppColors.danger),
                  ),
                );
              }
              
              if (snapshot.hasData) {
                final scoreResult = snapshot.data!;
                final dailyGoals = scoreResult.dailyGoals;
                
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    GlassCard(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '오늘의 목표',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              Text(
                                '${scoreResult.score}/3',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: scoreResult.score == 3 
                                      ? AppColors.accentPink 
                                      : AppColors.textPrimary,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          // 포만감 목표 (레벨에 따라 1~3회)
                          _buildGoalItem(
                            '포만감',
                            dailyGoals.feedProgress,
                            scoreResult.feedGoalCount,
                            dailyGoals.feedGoalAchieved,
                            Icons.restaurant,
                          ),
                          const SizedBox(height: 12),
                          // 수면 목표 (레벨에 따라 4~6시간)
                          _buildGoalItem(
                            '수면',
                            dailyGoals.sleepHours,
                            scoreResult.sleepGoalHours,
                            dailyGoals.sleepGoalAchieved,
                            Icons.bedtime,
                          ),
                          const SizedBox(height: 12),
                          // 운동 목표 (레벨에 따라 다름)
                          // 걸음 수와 운동 시간 중 더 높은 진행도를 표시
                          Builder(
                            builder: (context) {
                              // 걸음 수 진행도
                              final stepsProgress = dailyGoals.exerciseSteps;
                              final stepsProgressPercent = (stepsProgress / scoreResult.exerciseGoalSteps * 100).clamp(0.0, 100.0);
                              
                              // 운동 시간 진행도 (걸음 수 기준으로 변환)
                              final minutesProgressPercent = (dailyGoals.exerciseMinutes / scoreResult.exerciseGoalMinutes * 100).clamp(0.0, 100.0);
                              
                              // 더 높은 진행도 사용
                              final exerciseProgressPercent = stepsProgressPercent > minutesProgressPercent 
                                  ? stepsProgressPercent 
                                  : minutesProgressPercent;
                              
                              // 목표 달성 여부에 따라 진행도 표시
                              final exerciseProgress = dailyGoals.exerciseGoalAchieved 
                                  ? scoreResult.exerciseGoalSteps 
                                  : (exerciseProgressPercent / 100 * scoreResult.exerciseGoalSteps).round();
                              
                              return _buildGoalItem(
                                '운동',
                                exerciseProgress,
                                scoreResult.exerciseGoalSteps,
                                dailyGoals.exerciseGoalAchieved,
                                Icons.directions_run,
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                );
              } else {
                return const SizedBox.shrink();
              }
            },
          ),
          // 액션 버튼
          PetButton(
            variant: PetButtonVariant.primary,
            icon: Icons.auto_awesome,
            onPressed: isEvolving ? null : _handleEvolve,
            disabled: isEvolving || currentLevel < requiredLevel,
            child: Text(isEvolving
                ? AppStrings.evolutionEvolving
                : hasEvolved
                    ? AppStrings.evolutionEvolved
                    : AppStrings.evolutionEvolveNow),
          ),
        ],
      ),
    );
  }
}
