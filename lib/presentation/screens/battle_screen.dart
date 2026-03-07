import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/pet_provider.dart';
import '../widgets/pet_button.dart';
import '../widgets/glass_card.dart';
import '../../core/theme/app_colors.dart';
import '../../core/constants/app_strings.dart';
import '../../domain/usecases/battle_with_activity_usecase.dart';
import 'home_screen.dart';

/// 배틀 화면
/// 활동 기반 대결 시스템
/// 일일 목표 달성 여부로 승부를 결정
class BattleScreen extends ConsumerStatefulWidget {
  const BattleScreen({super.key});
  
  @override
  ConsumerState<BattleScreen> createState() => _BattleScreenState();
}

class _BattleScreenState extends ConsumerState<BattleScreen> {
  bool? battleResult; // true: 승리, false: 패배, null: 아직 대결 안 함
  bool isLoading = false;
  int todaySteps = 0;
  int todayExerciseMinutes = 0;
  int expGained = 0;
  
  @override
  void initState() {
    super.initState();
    _loadTodayActivity();
  }
  
  /// 오늘의 활동 데이터 로드
  Future<void> _loadTodayActivity() async {
    try {
      final activityRepository = ref.read(activityRepositoryProvider);
      final todayActivity = await activityRepository.getTodayActivityData();
      setState(() {
        todaySteps = todayActivity.steps;
        todayExerciseMinutes = todayActivity.exerciseMinutes;
      });
    } catch (e) {
      // 에러 무시
    }
  }
  
  /// 활동 기반 대결 실행
  Future<void> _startBattle() async {
    if (isLoading || battleResult != null) return;
    
    setState(() {
      isLoading = true;
    });
    
    try {
      final petRepository = ref.read(petRepositoryProvider);
      final activityRepository = ref.read(activityRepositoryProvider);
      final battleUseCase = BattleWithActivityUseCase(
        petRepository: petRepository,
        activityRepository: activityRepository,
      );
      
      final result = await battleUseCase(HomeScreen.defaultPetId);
      
      // Pet 상태 새로고침
      await ref.read(petNotifierProvider(HomeScreen.defaultPetId).notifier).refresh();
      
      setState(() {
        battleResult = result.isVictory;
        todaySteps = result.todaySteps;
        todayExerciseMinutes = result.todayExerciseMinutes;
        expGained = result.expGained;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        isLoading = false;
      });
    }
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
            data: (pet) => _buildBattleContent(context, pet),
          ),
        ),
      ),
    );
  }
  
  Widget _buildBattleContent(BuildContext context, pet) {
    // 일일 목표 달성률 계산
    final stepsProgress = (todaySteps / BattleWithActivityUseCase.dailyGoalSteps).clamp(0.0, 1.0);
    final exerciseProgress = (todayExerciseMinutes / BattleWithActivityUseCase.dailyGoalExerciseMinutes).clamp(0.0, 1.0);
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 16),
          // 헤더
          Column(
            children: [
              Text(
                AppStrings.battleArena,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '일일 목표 달성 대결',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textTertiary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
          // 목표 달성 현황
          GlassCard(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '오늘의 활동',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 16),
                // 걸음 수
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '걸음 수',
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    Text(
                      '$todaySteps / ${BattleWithActivityUseCase.dailyGoalSteps}보',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: stepsProgress,
                  backgroundColor: AppColors.glassBackground,
                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                ),
                const SizedBox(height: 16),
                // 운동 시간
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '운동 시간',
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    Text(
                      '$todayExerciseMinutes / ${BattleWithActivityUseCase.dailyGoalExerciseMinutes}분',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: exerciseProgress,
                  backgroundColor: AppColors.glassBackground,
                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.accentPink),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          // 대결 버튼
          if (battleResult == null)
            PetButton(
              variant: PetButtonVariant.primary,
              icon: Icons.sports_martial_arts,
              onPressed: isLoading ? null : _startBattle,
              disabled: isLoading,
              child: Text(isLoading ? '대결 중...' : '대결 시작'),
            ),
          // 대결 결과
          if (battleResult != null) ...[
            GlassCard(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Icon(
                    battleResult! ? Icons.celebration : Icons.sentiment_dissatisfied,
                    size: 64,
                    color: battleResult! ? AppColors.accentPink : AppColors.textSecondary,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    battleResult! ? AppStrings.battleVictory : AppStrings.battleDefeat,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    battleResult!
                        ? AppStrings.battleWon
                        : AppStrings.battleLost,
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '획득 경험치: +$expGained',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: AppColors.accentPink,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            PetButton(
              variant: PetButtonVariant.secondary,
              icon: Icons.refresh,
              onPressed: () {
                setState(() {
                  battleResult = null;
                  expGained = 0;
                });
                _loadTodayActivity();
              },
              child: const Text('다시 대결하기'),
            ),
          ],
        ],
      ),
    );
  }
}
