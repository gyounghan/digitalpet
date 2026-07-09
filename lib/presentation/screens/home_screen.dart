import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/pet_provider.dart';
import '../widgets/pet_image_animation.dart';
import '../widgets/pixel_motion_animation.dart';
import '../widgets/app_design.dart';
import '../../core/theme/species_theme.dart';
import '../../core/constants/app_strings.dart';
import '../../domain/entities/pet.dart';
import '../../domain/usecases/calculate_daily_goals_score_usecase.dart';
import '../../domain/usecases/today_goal_progress.dart';
import '../../core/utils/pet_image_helper.dart';
import '../../data/services/ad_service.dart';
import '../widgets/gravestone_widget.dart';
import '../widgets/sync_permission_banner.dart';

/// 홈 화면 — "펫이 주인공, 정보는 행동 가능한 것만"
///
/// 상단 펫명(종·기분) + Lv/EXP 미터 + 펫 스테이지 + 밥주기 + 오늘의 목표 카드.
/// 종/기분 라벨은 헤더 한 곳에만, 스탯 상세 수치는 케어 화면에서 확인한다.
class HomeScreen extends ConsumerStatefulWidget {
  static const String defaultPetId = 'default-pet';

  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  /// 액션 직후 잠깐 재생하는 모션 (밥먹기 등). null이면 mood 기반 대기 모션.
  PixelMotion? _transientMotion;
  Timer? _transientTimer;

  @override
  void dispose() {
    _transientTimer?.cancel();
    super.dispose();
  }

  /// 일시 모션 재생 — [duration] 후 mood 기반 대기 모션으로 복귀
  void _playTransientMotion(
    PixelMotion motion, {
    Duration duration = const Duration(milliseconds: 2700),
  }) {
    _transientTimer?.cancel();
    setState(() => _transientMotion = motion);
    _transientTimer = Timer(duration, () {
      if (mounted) setState(() => _transientMotion = null);
    });
  }

  String _getMoodText(PetMood mood) {
    switch (mood) {
      case PetMood.happy:
        return AppStrings.moodHappy;
      case PetMood.normal:
        return AppStrings.moodNormal;
      case PetMood.hungry:
        return AppStrings.moodHungry;
      case PetMood.sleepy:
        return AppStrings.moodSleepy;
      case PetMood.tired:
        return AppStrings.moodTired;
      case PetMood.sad:
        return AppStrings.moodSad;
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
            // 펫 스테이지는 내용(300)에 맞춰 높이를 잡는다 (카드가 과하게
            // 늘어나지 않도록 Expanded 대신 Flexible — 남는 공간은 아래로).
            Flexible(child: _buildPetStage(pet, theme)),
            // Feed 버튼 + 현재 상태 3카드
            _buildFeedButton(ref, pet, theme),
            _buildTodayGoalsCard(pet, theme),
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
        // 종/기분 라벨은 상단 헤더에 이미 있으므로 카드는 순수 펫 무대로 둔다
        child: Center(child: _buildPetSprite(pet, theme)),
      ),
    );
  }

  /// 도트 모션 스프라이트 키 (공통 규칙 — 성숙기는 성장기 모션 재활용)
  String? _motionSpriteKey(Pet pet) =>
      motionSpriteKeyForStage(pet.evolutionType, pet.evolutionStage);

  /// 펫 스테이지 스프라이트
  ///
  /// 모든 단계가 mood 기반 도트 모션 루프 + 액션 시 일시 모션(밥먹기).
  /// 성숙기(stage 4)는 성장기 모션에 짙은 몸통색+금빛 보조색으로 격 구분.
  Widget _buildPetSprite(Pet pet, SpeciesTheme theme) {
    final spriteKey = _motionSpriteKey(pet);
    if (spriteKey != null) {
      final motion = _transientMotion ?? motionForMood(pet.mood);
      // 털뭉치는 종 미결정 → 밝은 베이지 단색
      final isFluff = spriteKey == 'fluff';
      final isMature = pet.evolutionStage >= 4;
      return SizedBox(
        width: 300,
        height: 300,
        child: Align(
          alignment: Alignment.bottomCenter,
          child: PixelMotionAnimation(
            spriteKey: spriteKey,
            motion: motion,
            width: 270,
            height: 270,
            dotColor: isFluff
                ? SpeciesTheme.fluffBody
                : (isMature ? theme.matureBody : theme.primary),
            accentColor: isFluff
                ? SpeciesTheme.fluffAccent
                : (isMature ? SpeciesTheme.matureAccent : theme.spriteAccent),
          ),
        ),
      );
    }
    return PetImageAnimation(
      type: getPetImageTypeFromMood(pet.mood),
      duration: const Duration(milliseconds: 800),
      dotColor: theme.primary,
      accentColor: theme.spriteAccent,
      evolutionImagePath: getEvolutionMoodImagePath(
            pet.evolutionType,
            pet.evolutionStage,
            pet.mood,
          ) ??
          getEvolutionImagePath(
            pet.evolutionType,
            pet.evolutionStage,
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
            // 도트 모션이 있는 단계면 밥먹는 모션을 잠깐 재생
            if (_motionSpriteKey(pet) != null) {
              _playTransientMotion(PixelMotion.eat);
            }
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

  /// 오늘의 목표 카드 — 식사/걸음/수면 목표 진행 3줄 + 세트 보상 1줄.
  ///
  /// "무엇을 채워야 세트가 완성되는지"를 보여주는 유일한 곳.
  /// [TodayGoalProgress]로 pet 데이터만으로 동기 계산 (FutureBuilder 불필요).
  /// 스탯(hunger 등) 상세 수치는 케어 화면으로 이동 — 홈은 기분 텍스트로 요약.
  Widget _buildTodayGoalsCard(Pet pet, SpeciesTheme theme) {
    final goals = TodayGoalProgress.fromPet(pet);
    final todaySets = pet.todaySetExpClaimed;
    final nextReward =
        CalculateDailyGoalsScoreUseCase.setExpBase >> todaySets.clamp(0, 31);

    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 0, 18, 14),
      child: AppCard(
        theme: theme,
        variant: AppCardVariant.flat,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        radius: 16,
        child: Column(
          children: [
            _goalRow(
              icon: Icons.restaurant,
              label: '식사',
              valueText: '${goals.feedProgress}/${goals.feedGoal}회',
              ratio: goals.feedRatio,
              done: goals.feedDone,
              theme: theme,
            ),
            const SizedBox(height: 8),
            _goalRow(
              icon: Icons.directions_run,
              label: '걸음',
              valueText:
                  '${_formatSteps(goals.steps)}/${_formatSteps(goals.stepsGoal)}보',
              ratio: goals.exerciseRatio,
              done: goals.exerciseDone,
              theme: theme,
            ),
            const SizedBox(height: 8),
            _goalRow(
              icon: Icons.bedtime,
              label: '수면',
              valueText:
                  '${goals.sleepMinutes ~/ 60}/${goals.sleepGoalMinutes ~/ 60}시간',
              ratio: goals.sleepRatio,
              done: goals.sleepDone,
              theme: theme,
            ),
            const SizedBox(height: 10),
            // 세트 진행 (셋 다 채우면 1세트 — 반감 EXP 보상)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.task_alt, size: 13, color: theme.primaryDeep),
                const SizedBox(width: 5),
                Text(
                  todaySets > 0
                      ? '오늘 $todaySets세트 완성 · 다음 +$nextReward EXP'
                      : '셋 다 채우면 +$nextReward EXP',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: theme.primaryDeep,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// 목표 한 줄 — 아이콘 + 라벨 + 진행바 + 수치 (달성 시 체크·good 톤)
  Widget _goalRow({
    required IconData icon,
    required String label,
    required String valueText,
    required double ratio,
    required bool done,
    required SpeciesTheme theme,
  }) {
    final color = done ? DesignTokens.good : theme.primaryDeep;
    return Row(
      children: [
        Icon(done ? Icons.check_circle : icon, size: 15, color: color),
        const SizedBox(width: 7),
        SizedBox(
          width: 34,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: DesignTokens.ink2,
            ),
          ),
        ),
        Expanded(
          child: AppMeter(
            value: ratio * 100,
            theme: theme,
            tone: done ? AppMeterTone.good : AppMeterTone.themed,
            height: 7,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          valueText,
          style: const TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w700,
            color: DesignTokens.ink3,
            fontFeatures: [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }

  /// 걸음 수 축약 표기 (3,200 → 3.2k)
  String _formatSteps(int steps) {
    if (steps < 1000) return '$steps';
    final k = steps / 1000.0;
    return k == k.roundToDouble() ? '${k.round()}k' : '${k.toStringAsFixed(1)}k';
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
          onResurrectPressed: () async {
            final notifier = ref.read(
              petNotifierProvider(HomeScreen.defaultPetId).notifier,
            );
            final messenger = ScaffoldMessenger.of(context);
            // 리워드 광고 시청 완료 시에만 부활
            await AdService().showRewardedAd(
              onRewarded: () async {
                await notifier.resurrect();
                if (context.mounted) {
                  messenger.showSnackBar(
                    const SnackBar(
                      content: Text(AppStrings.resurrectSuccess),
                    ),
                  );
                }
              },
              onAdFailed: () {
                messenger.showSnackBar(
                  const SnackBar(content: Text(AppStrings.adLoadFailed)),
                );
              },
            );
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

