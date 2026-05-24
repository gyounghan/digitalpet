import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/pet_provider.dart';
import '../widgets/pet_image_animation.dart';
import '../widgets/app_design.dart';
import '../../core/theme/species_theme.dart';
import '../../core/constants/app_strings.dart';
import '../../domain/entities/pet.dart';
import '../../domain/usecases/calculate_daily_goals_score_usecase.dart';
import '../../core/utils/pet_image_helper.dart';
import '../widgets/gravestone_widget.dart';
import '../widgets/sync_permission_banner.dart';

/// 홈 화면 — 단순화·확대된 디자인
/// 상단 펫명 + EXP strip + (확대) 펫 스테이지 + 카드형 목표 게이지(원형)
///
/// 변경사항:
/// - 메뉴/설정 아이콘 제거 (펫명 영역 + EXP만 상단)
/// - 펫 스테이지 영역 확대 (Expanded)
/// - 상태/목표 탭 전환 UI 제거 → 카드형 원형 게이지 3개로 통합
class HomeScreen extends ConsumerStatefulWidget {
  static const String defaultPetId = 'default-pet';

  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
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

  @override
  Widget build(BuildContext context) {
    final petAsync = ref.watch(petNotifierProvider(HomeScreen.defaultPetId));

    return Scaffold(
      backgroundColor: DesignTokens.bg,
      body: SafeArea(
        child: petAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline,
                      size: 56, color: DesignTokens.bad),
                  const SizedBox(height: 12),
                  Text(
                    '${AppStrings.error}: $error',
                    style: const TextStyle(color: DesignTokens.bad),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: () => ref
                        .read(petNotifierProvider(HomeScreen.defaultPetId)
                            .notifier)
                        .refresh(),
                    child: Text(AppStrings.retry),
                  ),
                ],
              ),
            ),
          ),
          data: (pet) {
            if (pet.isDead) {
              return _buildDeadPetContent(context, ref, pet);
            }
            return _buildPetContent(context, ref, pet);
          },
        ),
      ),
    );
  }

  Widget _buildPetContent(BuildContext context, WidgetRef ref, Pet pet) {
    final theme = SpeciesTheme.forType(pet.evolutionType);
    final expPct = _calcExpPct(pet.exp, pet.level);

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: Column(
          children: [
            _buildHeader(context, ref, pet),
            _buildExpStrip(pet, theme, expPct),
            const SizedBox(height: 4),
            SyncPermissionBanner(theme: theme),
            if (pet.todayEvent.isNotEmpty && pet.todayEvent != 'normal')
              _buildEventBanner(pet, theme),
            // 펫 스테이지를 더 크게 (flex=5)
            Expanded(flex: 5, child: _buildPetStage(pet, theme)),
            // Feed 버튼 + 오늘의 세트 카드
            _buildFeedButton(ref, pet, theme),
            _buildSetCard(pet, theme),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, WidgetRef ref, Pet pet) {
    // 메뉴/설정 아이콘 제거 → 펫 이름/종/기분만 단순 표시
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 10, 18, 6),
      child: GestureDetector(
        onTap: () => _showNameEditDialog(context, ref, pet),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          pet.name,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: DesignTokens.ink,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Icon(Icons.edit,
                          size: 14, color: DesignTokens.ink3),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${SpeciesTheme.labelFor(pet.evolutionType)} · ${_getMoodText(pet.mood)}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: DesignTokens.ink3,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExpStrip(Pet pet, SpeciesTheme theme, int expPct) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 0, 18, 8),
      child: Row(
        children: [
          AppPill(
            text: 'Lv.${pet.level}',
            theme: theme,
            variant: AppPillVariant.themed,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: AppMeter(
              value: expPct.toDouble(),
              theme: theme,
              tone: AppMeterTone.themed,
              height: 10,
            ),
          ),
          const SizedBox(width: 10),
          Text(
            '$expPct%',
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
              color: theme.primaryDeep,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEventBanner(Pet pet, SpeciesTheme theme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 0, 18, 8),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: theme.primarySoft,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.auto_awesome, size: 14, color: theme.primaryDeep),
            const SizedBox(width: 6),
            Text(
              AppStrings.eventNames[pet.todayEvent] ?? pet.todayEvent,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: theme.primaryDeep,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPetStage(Pet pet, SpeciesTheme theme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 0, 18, 12),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [theme.gradStart, theme.gradEnd],
          ),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: theme.primary.withValues(alpha: 0.08),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Stack(
          children: [
            Positioned(
              top: 14,
              left: 14,
              right: 14,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  AppPill(
                    text: SpeciesTheme.labelFor(pet.evolutionType),
                    theme: theme,
                    variant: AppPillVariant.themed,
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.92),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      _getMoodText(pet.mood),
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: DesignTokens.ink,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Center(
              child: PetImageAnimation(
                type: getPetImageTypeFromMood(pet.mood),
                duration: const Duration(milliseconds: 800),
                evolutionImagePath: getEvolutionMoodImagePath(
                      pet.evolutionType,
                      pet.evolutionStage,
                      pet.mood,
                    ) ??
                    getEvolutionImagePath(
                      pet.evolutionType,
                      pet.evolutionStage,
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeedButton(WidgetRef ref, Pet pet, SpeciesTheme theme) {
    final canFeedUseCase = ref.watch(canFeedPetUseCaseProvider);
    final canFeed = canFeedUseCase.canFeed(pet);
    if (!canFeed) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 0, 18, 8),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: () {
            ref
                .read(petNotifierProvider(HomeScreen.defaultPetId).notifier)
                .feed();
          },
          icon: const Icon(Icons.restaurant, size: 18),
          label: Text(AppStrings.feed),
          style: ElevatedButton.styleFrom(
            backgroundColor: theme.primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 13),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            elevation: 0,
          ),
        ),
      ),
    );
  }

  /// 오늘의 세트 카드 — 포만감+수면+운동을 모두 채우면 1세트 완성.
  /// 아직 안 채운 항목만 강조되고, 셋 다 완료되면 세트 보상(반감 EXP)을 받는다.
  /// pet 데이터만으로 동기 계산 (FutureBuilder 불필요).
  Widget _buildSetCard(Pet pet, SpeciesTheme theme) {
    final feedGoal =
        CalculateDailyGoalsScoreUseCase.getFeedGoalCount(pet.level);
    final sleepGoalH =
        CalculateDailyGoalsScoreUseCase.getSleepGoalHours(pet.level);
    final stepGoal =
        CalculateDailyGoalsScoreUseCase.getExerciseGoalSteps(pet.level);
    final minGoal =
        CalculateDailyGoalsScoreUseCase.getExerciseGoalMinutes(pet.level);

    // 완성 세트 총량 = min(달성 카운트 3종)
    final completedSets = [
      pet.feedAchievedCount,
      pet.sleepAchievedCount,
      pet.exerciseAchievedCount,
    ].reduce((a, b) => a < b ? a : b);

    // 현재 진행 중인 세트(=completedSets+1)에서 각 항목이 이미 기여했는지
    final feedDone = pet.feedAchievedCount > completedSets;
    final sleepDone = pet.sleepAchievedCount > completedSets;
    final exerciseDone = pet.exerciseAchievedCount > completedSets;

    // 아직 안 끝난 항목의 진행률 (다음 달성까지)
    final feedPct = feedDone
        ? 1.0
        : (pet.todayFeedCount % feedGoal) / feedGoal;
    final sleepPct = sleepDone
        ? 1.0
        : ((pet.todaySleepMinutes % (sleepGoalH * 60)) / (sleepGoalH * 60));
    final stepPct = stepGoal > 0
        ? (pet.exerciseProgressSteps % stepGoal) / stepGoal
        : 0.0;
    final minPct = minGoal > 0
        ? (pet.exerciseProgressMinutes % minGoal) / minGoal
        : 0.0;
    final exercisePct = exerciseDone ? 1.0 : (stepPct > minPct ? stepPct : minPct);

    final todaySets = pet.todaySetExpClaimed;
    final nextReward =
        (CalculateDailyGoalsScoreUseCase.setExpBase >> todaySets.clamp(0, 31));

    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 0, 18, 14),
      child: AppCard(
        theme: theme,
        variant: AppCardVariant.flat,
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        radius: 18,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.task_alt, size: 16, color: theme.primaryDeep),
                const SizedBox(width: 6),
                Text(
                  '오늘의 세트',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: theme.primaryDeep,
                  ),
                ),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: theme.primarySoft,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    todaySets > 0 ? '오늘 $todaySets세트 완성' : '세트 +$nextReward EXP',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                      color: theme.primaryDeep,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            _setRow('포만감', Icons.restaurant, feedPct, feedDone,
                '${pet.todayFeedCount % feedGoal}/$feedGoal회', theme),
            const SizedBox(height: 7),
            _setRow('수면', Icons.bedtime, sleepPct, sleepDone,
                '${(pet.todaySleepMinutes % (sleepGoalH * 60)) ~/ 60}/$sleepGoalH시간',
                theme),
            const SizedBox(height: 7),
            _setRow(
                '운동',
                Icons.directions_run,
                exercisePct,
                exerciseDone,
                stepPct >= minPct
                    ? '${pet.exerciseProgressSteps % stepGoal}/$stepGoal보'
                    : '${pet.exerciseProgressMinutes % minGoal}/$minGoal분',
                theme),
          ],
        ),
      ),
    );
  }

  /// 세트 항목 한 줄 (아이콘 · 라벨 · 진행바 · 수치/완료)
  Widget _setRow(String label, IconData icon, double pct, bool done,
      String detail, SpeciesTheme theme) {
    return Row(
      children: [
        Icon(icon,
            size: 16,
            color: done ? theme.primary : DesignTokens.ink3),
        const SizedBox(width: 8),
        SizedBox(
          width: 44,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: done ? theme.primaryDeep : DesignTokens.ink2,
            ),
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: AppMeter(
            value: (pct.clamp(0.0, 1.0)) * 100,
            theme: theme,
            height: 7,
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 64,
          child: Text(
            done ? '완료 ✓' : detail,
            textAlign: TextAlign.right,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              color: done ? theme.primary : DesignTokens.ink3,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ),
      ],
    );
  }

  /// 현재 레벨의 EXP 진행률 (%) — Pet.getRequiredExpForLevel 규칙과 동일
  int _calcExpPct(int exp, int level) {
    final needed = Pet.getRequiredExpForLevel(level);
    if (needed <= 0) return 0;
    return ((exp / needed) * 100).clamp(0, 100).round();
  }

  Widget _buildDeadPetContent(BuildContext context, WidgetRef ref, Pet pet) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: GravestoneWidget(
          pet: pet,
          isAdLoaded: true,
          onResurrectPressed: () async {
            final notifier = ref.read(
              petNotifierProvider(HomeScreen.defaultPetId).notifier,
            );
            await notifier.resurrect();
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(AppStrings.resurrectSuccess),
                ),
              );
            }
          },
        ),
      ),
    );
  }

  void _showNameEditDialog(BuildContext context, WidgetRef ref, Pet pet) {
    final controller = TextEditingController(text: pet.name);
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: DesignTokens.surface,
          title: const Text(
            '펫 이름 변경',
            style: TextStyle(
                color: DesignTokens.ink, fontWeight: FontWeight.w800),
          ),
          content: TextField(
            controller: controller,
            decoration: InputDecoration(
              hintText: '펫 이름을 입력하세요',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            maxLength: 20,
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('취소'),
            ),
            TextButton(
              onPressed: () {
                final newName = controller.text.trim();
                if (newName.isNotEmpty) {
                  ref
                      .read(petNotifierProvider(HomeScreen.defaultPetId)
                          .notifier)
                      .updateName(newName);
                }
                Navigator.of(context).pop();
              },
              child: const Text('확인'),
            ),
          ],
        );
      },
    );
  }
}

