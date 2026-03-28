import 'dart:async';
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
import '../../domain/usecases/alternative_feed_pet_usecase.dart';
import '../../domain/usecases/alternative_sleep_pet_usecase.dart';
import '../../domain/usecases/alternative_exercise_pet_usecase.dart';
import '../../domain/usecases/calculate_daily_goals_score_usecase.dart';
import '../../core/utils/pet_image_helper.dart';
import '../widgets/gravestone_widget.dart';

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
  Timer? _exerciseTimer;
  int _exerciseRemainingSeconds = 0;
  Timer? _napTimer;
  int _napRemainingSeconds = 0;
  
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
      case PetMood.dead:
        return AppStrings.moodDead;
    }
  }

  /// 일일 목표 점수 조회
  ///
  /// [ref] WidgetRef
  /// [pet] 현재 Pet 엔티티
  ///
  /// 반환: DailyGoalsScore
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
  ///
  /// [label] 목표 라벨 (포만감, 수면, 운동)
  /// [progress] 현재 진행도
  /// [goal] 목표값
  /// [achieved] 달성 여부
  /// [icon] 아이콘
  ///
  /// 반환: 목표 항목 위젯
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
      case PetMood.dead:
        return Colors.grey;
    }
  }

  /// 사망 상태 비석 UI
  Widget _buildDeadPetContent(BuildContext context, WidgetRef ref, Pet pet) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: GravestoneWidget(
          pet: pet,
          isAdLoaded: true,
          onResurrectPressed: () async {
            // 광고 시청 후 부활 처리
            final notifier = ref.read(
              petNotifierProvider(HomeScreen.defaultPetId).notifier,
            );
            await notifier.resurrect();
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(AppStrings.resurrectSuccess),
                  backgroundColor: AppColors.primary,
                ),
              );
            }
          },
        ),
      ),
    );
  }

  @override
  void dispose() {
    _exerciseTimer?.cancel();
    _napTimer?.cancel();
    super.dispose();
  }

  /// 실내 운동 1분 타이머 시작
  ///
  /// 타이머가 0이 되면 대체 운동 보상을 적용
  void _startIndoorExerciseTimer(WidgetRef ref) {
    if (_exerciseTimer != null) {
      return;
    }

    setState(() {
      _exerciseRemainingSeconds = 60;
    });

    _exerciseTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        _exerciseTimer = null;
        return;
      }

      if (_exerciseRemainingSeconds <= 1) {
        timer.cancel();
        _exerciseTimer = null;
        setState(() {
          _exerciseRemainingSeconds = 0;
        });
        ref.read(petNotifierProvider(HomeScreen.defaultPetId).notifier).performAlternativeExercise();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('실내 운동 1분 완료! 대체 운동 보상이 적용됐어요.')),
        );
        return;
      }

      setState(() {
        _exerciseRemainingSeconds -= 1;
      });
    });
  }

  /// 낮잠 모드 15분 시작
  ///
  /// 진행 중에는 전체 화면을 잠금 처리하여 다른 조작을 막는다.
  void _startNapMode(WidgetRef ref) {
    if (_napTimer != null) {
      return;
    }

    _napRemainingSeconds = 15 * 60;
    final remainingNotifier = ValueNotifier<int>(_napRemainingSeconds);

    _napTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        _napTimer = null;
        remainingNotifier.dispose();
        return;
      }

      if (_napRemainingSeconds <= 1) {
        timer.cancel();
        _napTimer = null;
        _napRemainingSeconds = 0;
        remainingNotifier.value = 0;
        if (Navigator.of(context, rootNavigator: true).canPop()) {
          Navigator.of(context, rootNavigator: true).pop();
        }
        ref.read(petNotifierProvider(HomeScreen.defaultPetId).notifier).performAlternativeSleep();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('낮잠 모드 15분 완료! 수면 보상이 적용됐어요.')),
        );
        remainingNotifier.dispose();
        return;
      }

      _napRemainingSeconds -= 1;
      remainingNotifier.value = _napRemainingSeconds;
    });

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return PopScope(
          canPop: false,
          child: Material(
            color: Colors.black.withValues(alpha: 0.85),
            child: Center(
              child: ValueListenableBuilder<int>(
                valueListenable: remainingNotifier,
                builder: (context, remaining, _) {
                  final minutes = (remaining ~/ 60).toString().padLeft(2, '0');
                  final seconds = (remaining % 60).toString().padLeft(2, '0');
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.bedtime,
                        color: AppColors.primary,
                        size: 56,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        AppStrings.napModeRunning,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        '$minutes:$seconds',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 42,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 2,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        '낮잠 모드가 끝날 때까지 잠시 휴식해 주세요.',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }

  /// 대체 케어 바텀시트 표시
  void _showAlternativeCareSheet(BuildContext context, WidgetRef ref, Pet pet) {
    final alternativeFeedUseCase = ref.read(alternativeFeedPetUseCaseProvider);
    final alternativeSleepUseCase = ref.read(alternativeSleepPetUseCaseProvider);
    final alternativeExerciseUseCase = ref.read(alternativeExercisePetUseCaseProvider);

    final canAlternativeFeed = alternativeFeedUseCase.canUse(pet);
    final canAlternativeSleep = alternativeSleepUseCase.canUse(pet) && _napTimer == null;
    final canAlternativeExercise = alternativeExerciseUseCase.canUse(pet) && _exerciseTimer == null;

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.backgroundDarkSecondary,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (bottomSheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  AppStrings.alternativeCareTitle,
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  AppStrings.snackTimeGuide,
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 12),
                PetButton(
                  variant: PetButtonVariant.secondary,
                  icon: Icons.local_dining,
                  disabled: !canAlternativeFeed,
                  onPressed: canAlternativeFeed
                      ? () {
                          Navigator.of(bottomSheetContext).pop();
                          ref.read(petNotifierProvider(HomeScreen.defaultPetId).notifier).performAlternativeFeed();
                        }
                      : null,
                  child: Text(
                    '${AppStrings.alternativeFeed} '
                    '(${pet.todayAlternativeFeedCount}/${AlternativeFeedPetUseCase.maxAlternativeFeedsPerDay})',
                  ),
                ),
                const SizedBox(height: 8),
                PetButton(
                  variant: PetButtonVariant.secondary,
                  icon: Icons.bedtime,
                  disabled: !canAlternativeSleep,
                  onPressed: canAlternativeSleep
                      ? () {
                          Navigator.of(bottomSheetContext).pop();
                          _startNapMode(ref);
                        }
                      : null,
                  child: Text(
                    '${AppStrings.alternativeSleep} '
                    '(${pet.todayAlternativeSleepCount}/${AlternativeSleepPetUseCase.maxAlternativeSleepsPerDay})',
                  ),
                ),
                const SizedBox(height: 8),
                PetButton(
                  variant: PetButtonVariant.secondary,
                  icon: Icons.timer,
                  disabled: !canAlternativeExercise,
                  onPressed: canAlternativeExercise
                      ? () {
                          Navigator.of(bottomSheetContext).pop();
                          _startIndoorExerciseTimer(ref);
                        }
                      : null,
                  child: Text(
                    '${AppStrings.alternativeExercise} '
                    '(${pet.todayAlternativeExerciseCount}/${AlternativeExercisePetUseCase.maxAlternativeExercisesPerDay})',
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
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
    // 사망 상태면 비석 UI 표시
    if (pet.isDead) {
      return _buildDeadPetContent(context, ref, pet);
    }

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
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppColors.accentCyan,
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
                        icon: const Icon(
                          Icons.health_and_safety,
                          color: AppColors.primary,
                          size: 20,
                        ),
                        onPressed: () => _showAlternativeCareSheet(context, ref, pet),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppColors.accentCyan,
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
                          color: AppColors.primary,
                          size: 20,
                        ),
                        onPressed: () {
                          // TODO: 설정 화면
                        },
                      ),
                    ),
                  ],
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
            const SizedBox(height: 24),
            // 오늘의 목표
            FutureBuilder<DailyGoalsScore>(
              key: ValueKey('daily_goals_home_${pet.todayFeedCount}_${pet.todaySleepHours}_${pet.lastUpdated}_${pet.level}'),
              future: _getDailyGoalsScore(ref, pet),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return GlassCard(
                    gradient: true,
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '오늘의 목표',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Center(
                          child: CircularProgressIndicator(color: AppColors.primary),
                        ),
                      ],
                    ),
                  );
                }

                if (snapshot.hasError) {
                  return const SizedBox.shrink();
                }

                if (snapshot.hasData) {
                  final scoreResult = snapshot.data!;
                  final dailyGoals = scoreResult.dailyGoals;

                  return GlassCard(
                    gradient: true,
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                const Text(
                                  '목표',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: scoreResult.isExpired
                                        ? AppColors.danger.withValues(alpha: 0.2)
                                        : AppColors.primary.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    'D+${scoreResult.goalDaysElapsed}/7',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: scoreResult.isExpired
                                          ? AppColors.danger
                                          : AppColors.primary,
                                    ),
                                  ),
                                ),
                                if (scoreResult.goalStreakCount > 0) ...[
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: AppColors.accentPink.withValues(alpha: 0.2),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      '${scoreResult.goalStreakCount}연속',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.accentPink,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
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
                        Builder(
                          builder: (context) {
                            // 걸음 수 진행도
                            final stepsProgress = dailyGoals.exerciseSteps;
                            final stepsProgressPercent =
                                (stepsProgress / scoreResult.exerciseGoalSteps * 100)
                                    .clamp(0.0, 100.0);

                            // 운동 시간 진행도 (걸음 수 기준으로 변환)
                            final minutesProgressPercent =
                                (dailyGoals.exerciseMinutes /
                                        scoreResult.exerciseGoalMinutes *
                                        100)
                                    .clamp(0.0, 100.0);

                            // 더 높은 진행도 사용
                            final exerciseProgressPercent = stepsProgressPercent >
                                    minutesProgressPercent
                                ? stepsProgressPercent
                                : minutesProgressPercent;

                            // 목표 달성 여부에 따라 진행도 표시
                            final exerciseProgress =
                                dailyGoals.exerciseGoalAchieved
                                    ? scoreResult.exerciseGoalSteps
                                    : (exerciseProgressPercent / 100 *
                                            scoreResult.exerciseGoalSteps)
                                        .round();

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
                  );
                } else {
                  return const SizedBox.shrink();
                }
              },
            ),
            // Feed 버튼 (조건부 표시: 배고픔 상태 + 식사 시간대)
            Consumer(
              builder: (context, ref, _) {
                final canFeedUseCase = ref.watch(canFeedPetUseCaseProvider);
                final canFeed = canFeedUseCase.canFeed(pet);

                if (!canFeed) {
                  return const SizedBox(height: 12);
                }

                return Padding(
                  padding: const EdgeInsets.only(top: 20),
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
