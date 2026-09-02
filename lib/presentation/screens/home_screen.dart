import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/pet_provider.dart';
import '../providers/active_pet_provider.dart';
import '../widgets/pet_image_animation.dart';
import '../widgets/pixel_motion_animation.dart';
import '../widgets/app_design.dart';
import '../../core/theme/species_theme.dart';
import '../../core/constants/app_strings.dart';
import '../../domain/entities/pet.dart';
import '../../domain/usecases/calculate_daily_goals_score_usecase.dart';
import '../../domain/usecases/pet_transition_events.dart';
import '../../domain/usecases/today_goal_progress.dart';
import '../../core/utils/pet_image_helper.dart';
import '../../data/services/ad_service.dart';
import '../../data/datasources/app_prefs_datasource.dart';
import '../widgets/long_sleep_widget.dart';
import '../widgets/sync_permission_banner.dart';
import 'evolution_reveal_screen.dart';
import 'species_reveal_screen.dart';

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
  /// 현재 활성 펫 ID (도감에서 전환). build가 activePetIdProvider를 watch하므로
  /// 전환 시 화면이 rebuild되고, 콜백에서는 read로 현재 값을 읽는다.
  String get _activePetId => ref.read(activePetIdProvider);

  /// 액션 직후 잠깐 재생하는 모션 (밥먹기 등). null이면 mood 기반 대기 모션.
  PixelMotion? _transientMotion;
  Timer? _transientTimer;

  /// 종 결정 연출 중복 방지 — 플래그 확인/연출이 끝났으면 true
  bool _speciesRevealHandled = false;
  bool _speciesRevealChecking = false;

  /// 진화 연출(3·4단계) 재진입 방지
  bool _evolutionRevealChecking = false;

  /// 설화 영물 각성 연출(사신수→영물) 재진입 방지
  bool _awakeningRevealChecking = false;

  /// 목표 달성 순간 플래시 중인 카테고리 — 해당 줄을 금색 "목표 달성!"으로
  /// 잠깐 강조해 누적식 표시(자연스러운 다음 목표 전환)에 티를 낸다
  final Set<GoalCategory> _flashingGoals = {};
  final Map<GoalCategory, Timer> _goalFlashTimers = {};

  @override
  void dispose() {
    _transientTimer?.cancel();
    for (final timer in _goalFlashTimers.values) {
      timer.cancel();
    }
    super.dispose();
  }

  /// 펫 상태 전이에서 목표 달성·세트 완성 이벤트를 뽑아 축하 연출 시작
  void _onPetTransition(AsyncValue<Pet>? prev, AsyncValue<Pet> next) {
    final prevPet = prev?.valueOrNull;
    final nextPet = next.valueOrNull;
    if (prevPet == null || nextPet == null) return;

    final events = PetTransitionEvents.diff(prevPet, nextPet);
    if (!events.hasAny) return;

    for (final category in events.achievedNow) {
      _goalFlashTimers[category]?.cancel();
      _flashingGoals.add(category);
      _goalFlashTimers[category] =
          Timer(const Duration(milliseconds: 2600), () {
        if (mounted) setState(() => _flashingGoals.remove(category));
      });
    }
    if (events.achievedNow.isNotEmpty) setState(() {});

    if (events.setsCompleted > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: DesignTokens.ink,
          duration: const Duration(milliseconds: 3200),
          content: Row(
            children: [
              const Icon(Icons.celebration,
                  size: 18, color: DesignTokens.gold),
              const SizedBox(width: 8),
              Text(
                '오늘 목표 세트 완성! +${events.setRewardExp} EXP',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ],
          ),
        ),
      );
    }
  }

  /// 3·4단계 진화 연출 — 기기에 기록된 "마지막으로 본 단계"보다 높아졌으면
  /// 풀스크린으로 즉시 보여준다 (상호작용·틱·화면 진입 어느 경로든 커버)
  Future<void> _maybeShowEvolutionReveal(Pet pet) async {
    if (_evolutionRevealChecking) return;
    _evolutionRevealChecking = true;
    try {
      final prefs = AppPrefsDatasource();
      final seenStage = await prefs.getEvolutionSeenStage();

      // 기준 없음(최초 실행) 또는 새 펫(단계 하락) — 기준만 갱신
      if (seenStage == null || pet.evolutionStage < seenStage) {
        await prefs.setEvolutionSeenStage(pet.evolutionStage);
        return;
      }
      if (pet.evolutionStage == seenStage) return;

      await prefs.setEvolutionSeenStage(pet.evolutionStage);
      if (!PetTransitionEvents.shouldRevealEvolution(
          seenStage: seenStage, pet: pet)) {
        return; // 2단계 전이는 종 결정 연출이 전담 — 기록만
      }
      if (!mounted) return;
      await Navigator.of(context).push(
        PageRouteBuilder(
          fullscreenDialog: true,
          transitionDuration: const Duration(milliseconds: 450),
          pageBuilder: (_, __, ___) => EvolutionRevealScreen(pet: pet),
          transitionsBuilder: (_, animation, __, child) =>
              FadeTransition(opacity: animation, child: child),
        ),
      );
    } finally {
      _evolutionRevealChecking = false;
    }
  }

  /// 펫을 톡 건드렸을 때의 반응 모션.
  /// 기분 좋음/보통 → 기뻐함(joy), 배고픔·지침·시무룩 → 삐침(angry).
  /// (angry 감정을 실제 게임플레이에서 볼 수 있는 유일한 상호작용)
  PixelMotion _pokeReaction(PetMood mood) {
    switch (mood) {
      case PetMood.hungry:
      case PetMood.tired:
      case PetMood.sad:
        return PixelMotion.angry;
      default:
        return PixelMotion.joy;
    }
  }

  /// 일시 모션 재생 — [duration] 후 mood 기반 대기 모션으로 복귀
  /// (모션 1사이클 900ms — 기본 5400ms = 6회 반복. 900의 배수로 맞춰야
  ///  사이클 중간에 뚝 끊기지 않는다)
  void _playTransientMotion(
    PixelMotion motion, {
    Duration duration = const Duration(milliseconds: 5400),
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
    ref.watch(activePetIdProvider); // 활성 펫 전환 시 rebuild 구독
    ref.listen(petNotifierProvider(_activePetId), _onPetTransition);
    final petAsync = ref.watch(petNotifierProvider(_activePetId));

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
                        .read(petNotifierProvider(_activePetId)
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
            WidgetsBinding.instance.addPostFrameCallback((_) async {
              if (!mounted) return;
              await _maybeShowSpeciesReveal(pet);
              if (!mounted) return;
              // 각성(사신수→영물)이 떴으면 같은 틱의 단계 연출은 건너뛴다
              final awakened = await _maybeShowAwakeningReveal(pet);
              if (mounted && !awakened) await _maybeShowEvolutionReveal(pet);
            });
            return _buildPetContent(context, ref, pet);
          },
        ),
      ),
    );
  }

  /// 종 결정(2단계 진화) 풀스크린 연출 — 기기당 1회만
  ///
  /// 진화는 [PetNotifier._updateAndEvolve] 어디서든(백그라운드 포함) 일어날 수
  /// 있으므로, "전이 감지"가 아니라 "stage 2 도달 + 미노출 플래그"로 판정한다.
  /// 이 기능 추가 전에 이미 성장기(stage 3+)를 지난 펫은 뒤늦은 연출을
  /// 생략하고 플래그만 세운다.
  Future<void> _maybeShowSpeciesReveal(Pet pet) async {
    if (_speciesRevealHandled || _speciesRevealChecking) return;
    if (pet.evolutionStage < 2 || pet.evolutionType == null) return;

    _speciesRevealChecking = true;
    try {
      final prefs = AppPrefsDatasource();
      if (await prefs.isSpeciesRevealShown()) {
        _speciesRevealHandled = true;
        return;
      }
      await prefs.setSpeciesRevealShown();
      _speciesRevealHandled = true;
      // 각성 감지 기준(baseline) — 이 종을 보여줬다고 기록.
      // 이후 사신수→영물 각성 시 종 변경을 잡는다.
      await prefs.setRevealedSpeciesType(pet.evolutionType!.name);

      if (pet.evolutionStage > 2) return;
      if (!mounted) return;
      await Navigator.of(context).push(
        PageRouteBuilder(
          fullscreenDialog: true,
          transitionDuration: const Duration(milliseconds: 450),
          pageBuilder: (_, __, ___) => SpeciesRevealScreen(pet: pet),
          transitionsBuilder: (_, animation, __, child) =>
              FadeTransition(opacity: animation, child: child),
        ),
      );
    } finally {
      _speciesRevealChecking = false;
    }
  }

  /// 설화 영물 각성 풀스크린 연출 — 성장 중 사신수 → 영물로 종이 바뀐 순간
  ///
  /// 종 결정 연출은 기기당 1회뿐이고 진화 연출은 단계 변화에만 뜨므로,
  /// 같은 단계에서 종만 바뀌는 각성(예: Lv7에 12승으로 청룡→도깨비)은
  /// 둘 다 놓친다 — 조용히 스프라이트만 바뀌어 혼란스럽다. 이 핸들러가
  /// "마지막으로 보여준 종"과 현재 종을 비교해 각성을 전용 연출로 띄운다.
  /// 연출을 띄웠으면 true (호출부가 같은 틱의 단계 연출 중복을 피한다).
  Future<bool> _maybeShowAwakeningReveal(Pet pet) async {
    if (_awakeningRevealChecking) return false;
    if (pet.isDead || pet.evolutionType == null) return false;

    _awakeningRevealChecking = true;
    try {
      final prefs = AppPrefsDatasource();
      final seenType = await prefs.getRevealedSpeciesType();
      // 기준 없음(기능 도입 전 펫) — 현재 종을 기록만, 뒤늦은 연출 생략
      if (seenType == null) {
        await prefs.setRevealedSpeciesType(pet.evolutionType!.name);
        return false;
      }
      if (!PetTransitionEvents.shouldRevealAwakening(
          seenTypeName: seenType, pet: pet)) {
        return false;
      }
      await prefs.setRevealedSpeciesType(pet.evolutionType!.name);
      // 각성은 단계 변화 없이도 뜨지만, 마침 단계까지 올랐다면 같은 틱의
      // 단계 연출과 겹치지 않도록 본 단계도 현재로 당겨 기록한다.
      await prefs.setEvolutionSeenStage(pet.evolutionStage);
      if (!mounted) return false;
      await Navigator.of(context).push(
        PageRouteBuilder(
          fullscreenDialog: true,
          transitionDuration: const Duration(milliseconds: 450),
          pageBuilder: (_, __, ___) => SpeciesRevealScreen(pet: pet),
          transitionsBuilder: (_, animation, __, child) =>
              FadeTransition(opacity: animation, child: child),
        ),
      );
      return true;
    } finally {
      _awakeningRevealChecking = false;
    }
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
            // 상호작용 행: 밥주기(급식) · 쓰담(joy 연출) · 휴식(sleep 연출)
            _buildInteractionRow(ref, pet, theme),
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
    // 시안 톤: 하늘(위)→풀밭(아래) 서식지 무대. 펫을 크게 세우고 바닥
    // 플랫폼(둥근 잔디 밴드 + 그림자)으로 "진짜 키우는" 느낌을 준다.
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 0, 18, 12),
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
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
          alignment: Alignment.bottomCenter,
          children: [
            // 바닥 풀밭 밴드 (테마색을 옅게 깐 둥근 지면)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                height: 54,
                decoration: BoxDecoration(
                  color: theme.primary.withValues(alpha: 0.10),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(80),
                    topRight: Radius.circular(80),
                  ),
                ),
              ),
            ),
            // 펫 발밑 그림자 (접지감)
            Positioned(
              bottom: 30,
              child: Container(
                width: 150,
                height: 20,
                decoration: BoxDecoration(
                  color: theme.primaryDeep.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(100),
                ),
              ),
            ),
            // 펫 — 톡 건드리면 반응(기분 좋으면 joy, 나쁘면 angry)
            GestureDetector(
              onTap: () => _playTransientMotion(_pokeReaction(pet.mood)),
              child: _buildPetSprite(pet, theme),
            ),
          ],
        ),
      ),
    );
  }

  /// 도트 모션 스프라이트 키 (공통 규칙 — 성숙기 등급 분기 포함)
  String? _motionSpriteKey(Pet pet) => motionSpriteKeyForStage(
      pet.evolutionType, pet.evolutionStage, pet.evolutionGrade);

  /// 펫 스테이지 스프라이트
  ///
  /// 모든 단계가 mood 기반 도트 모션 루프 + 액션 시 일시 모션(밥먹기).
  Widget _buildPetSprite(Pet pet, SpeciesTheme theme) {
    final spriteKey = _motionSpriteKey(pet);
    if (spriteKey != null) {
      final motion = _transientMotion ?? motionForMood(pet.mood);
      // 털뭉치=베이지, 일반종=자연색(개체 변이), 사신수/그 외=테마색
      final (dotColor, accentColor) = dotColorsForKey(
          spriteKey, pet.evolutionType, theme, colorVariantFor(pet));
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
            dotColor: dotColor,
            accentColor: accentColor,
            colorVariant: colorVariantFor(pet),
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

  /// 홈 상호작용 행 — 밥주기(급식) · 쓰담(joy 연출) · 휴식(sleep 연출).
  /// 시안의 "직접 돌보는" 감을 위해 큰 펫 무대 바로 아래 3버튼으로 배치.
  /// 쓰담·휴식은 수치 변화 없는 순수 반응 모션(기존 톡 반응과 동일 방식).
  Widget _buildInteractionRow(WidgetRef ref, Pet pet, SpeciesTheme theme) {
    final canFeed = ref.watch(canFeedPetUseCaseProvider).canFeed(pet);
    final hasMotion = _motionSpriteKey(pet) != null;
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 0, 18, 8),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: _InteractionButton(
              icon: Icons.restaurant,
              label: AppStrings.feed,
              theme: theme,
              filled: true,
              enabled: canFeed,
              onTap: () {
                ref
                    .read(petNotifierProvider(_activePetId).notifier)
                    .feed();
                if (hasMotion) _playTransientMotion(PixelMotion.eat);
              },
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 2,
            child: _InteractionButton(
              icon: Icons.back_hand,
              label: '쓰담',
              theme: theme,
              onTap: () => _playTransientMotion(PixelMotion.joy),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 2,
            child: _InteractionButton(
              icon: Icons.bedtime,
              label: '휴식',
              theme: theme,
              onTap: () => _playTransientMotion(PixelMotion.sleep),
            ),
          ),
        ],
      ),
    );
  }

  /// 오늘의 목표 카드 — 식사/걸음/수면 목표 진행 3줄 + 보상 안내 1줄.
  ///
  /// 목표 하나마다 개별 EXP, 셋 다 채우면 세트 EXP가 추가된다.
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
              flash: _flashingGoals.contains(GoalCategory.feed),
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
              flash: _flashingGoals.contains(GoalCategory.exercise),
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
              flash: _flashingGoals.contains(GoalCategory.sleep),
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
                      ? '오늘 $todaySets세트 완성 · 다음 세트 +$nextReward EXP'
                      : '하나마다 +${CalculateDailyGoalsScoreUseCase.expPerCategory} EXP · 세트 +$nextReward EXP',
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
  ///
  /// [flash]가 true인 동안(달성 직후 2.6초) 줄 전체를 금색으로 강조하고
  /// 수치 대신 "목표 달성!"을 보여준다 — 누적식 표시가 다음 목표로 확장될 때
  /// 달성 순간이 묻히지 않도록.
  Widget _goalRow({
    required IconData icon,
    required String label,
    required String valueText,
    required double ratio,
    required bool done,
    required SpeciesTheme theme,
    bool flash = false,
  }) {
    final color = flash
        ? DesignTokens.gold
        : (done ? DesignTokens.good : theme.primaryDeep);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOut,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: BoxDecoration(
        color: flash
            ? DesignTokens.gold.withValues(alpha: 0.13)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(
            flash ? Icons.celebration : (done ? Icons.check_circle : icon),
            size: 15,
            color: color,
          ),
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
              value: flash ? 100 : ratio * 100,
              theme: theme,
              tone: done || flash ? AppMeterTone.good : AppMeterTone.themed,
              height: 7,
            ),
          ),
          const SizedBox(width: 8),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            child: flash
                ? Text(
                    AppStrings.goalAchievedFlash,
                    key: const ValueKey('flash'),
                    style: const TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                      color: DesignTokens.gold,
                    ),
                  )
                : Text(
                    valueText,
                    key: const ValueKey('value'),
                    style: const TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      color: DesignTokens.ink3,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
          ),
        ],
      ),
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

  /// 긴 잠에 빠진 펫 — 무료 깨우기(30/30/30) 또는 광고 깨우기(완전 회복)
  Widget _buildDeadPetContent(BuildContext context, WidgetRef ref, Pet pet) {
    final notifier = ref.read(
      petNotifierProvider(_activePetId).notifier,
    );
    void showWakeSuccess() {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text(AppStrings.wakeSuccess)),
        );
      }
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: LongSleepWidget(
          pet: pet,
          onWakeFree: () async {
            await notifier.resurrect();
            showWakeSuccess();
          },
          onWakeWithAd: () async {
            final messenger = ScaffoldMessenger.of(context);
            // 리워드 광고 시청 완료 시에만 완전 회복으로 깨움
            await AdService().showRewardedAd(
              onRewarded: () async {
                await notifier.resurrect(fullRecovery: true);
                showWakeSuccess();
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
                      .read(petNotifierProvider(_activePetId)
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

/// 홈 상호작용 버튼 — 시안 톤의 둥근 파스텔 버튼.
/// [filled]면 테마 딥컬러로 채운 주요 버튼(밥주기), 아니면 옅은 소프트 버튼.
class _InteractionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final SpeciesTheme theme;
  final VoidCallback onTap;
  final bool filled;
  final bool enabled;

  const _InteractionButton({
    required this.icon,
    required this.label,
    required this.theme,
    required this.onTap,
    this.filled = false,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final Color bg = filled ? theme.primaryDeep : theme.primarySoft;
    final Color fg = filled ? Colors.white : theme.primaryDeep;
    final content = Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 20, color: fg),
          const SizedBox(height: 3),
          Text(
            label,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
              color: fg,
            ),
          ),
        ],
      ),
    );
    return Opacity(
      opacity: enabled ? 1.0 : 0.4,
      child: GestureDetector(
        onTap: enabled ? onTap : null,
        behavior: HitTestBehavior.opaque,
        child: content,
      ),
    );
  }
}

