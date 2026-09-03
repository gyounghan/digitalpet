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
    // 시안 홈 구조: 상단바 → 인사말+이름 → 말풍선(기분) → 펫 무대 →
    // 상태(포만감·기분·체력) → 액션(먹이·놀기·휴식) → 오늘의 케어 체크리스트.
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: Column(
          children: [
            _buildTopBar(),
            _buildGreetingHeader(context, ref, pet, theme),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(18, 0, 18, 16),
                children: [
                  _buildSpeechBubble(pet, theme),
                  const SizedBox(height: 8),
                  _buildPetStage(pet, theme),
                  const SizedBox(height: 10),
                  SyncPermissionBanner(theme: theme),
                  if (pet.todayEvent.isNotEmpty && pet.todayEvent != 'normal')
                    _buildEventBanner(pet, theme),
                  _buildStatusMiniRow(pet, theme),
                  const SizedBox(height: 12),
                  _buildActionRow(ref, pet, theme),
                  const SizedBox(height: 14),
                  _buildTodayCareCard(pet, theme),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 상단바 — 시안: 좌측 탭명 '홈' · 우측 부제 '관찰과 애착'.
  Widget _buildTopBar() {
    return const Padding(
      padding: EdgeInsets.fromLTRB(18, 12, 18, 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('홈',
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: DesignTokens.ink)),
          Text('관찰과 애착',
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: DesignTokens.ink3)),
        ],
      ),
    );
  }

  /// 인사말 헤더 — 시안: 시간대 인사말(작게) + 펫 이름(크게) + 우측 Lv 필.
  /// (코인/재화는 현재 없는 기능이라 Lv 필로 대체)
  Widget _buildGreetingHeader(
      BuildContext context, WidgetRef ref, Pet pet, SpeciesTheme theme) {
    final hour = DateTime.now().hour;
    final greeting = hour < 6
        ? '고요한 새벽'
        : hour < 12
            ? '오전 산책 후'
            : hour < 18
                ? '나른한 오후'
                : '포근한 저녁';
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 0, 18, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => _showNameEditDialog(context, ref, pet),
              behavior: HitTestBehavior.opaque,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(greeting,
                      style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: DesignTokens.ink3)),
                  const SizedBox(height: 1),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(pet.name,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w800,
                                color: DesignTokens.ink)),
                      ),
                      const SizedBox(width: 5),
                      const Icon(Icons.edit, size: 13, color: DesignTokens.ink3),
                    ],
                  ),
                ],
              ),
            ),
          ),
          AppPill(
              text: 'Lv.${pet.level}',
              theme: theme,
              variant: AppPillVariant.themed),
        ],
      ),
    );
  }

  /// 기분 말풍선 — 시안: 펫 위 흰 말풍선에 상태 한마디.
  Widget _buildSpeechBubble(Pet pet, SpeciesTheme theme) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(left: 4),
        constraints: const BoxConstraints(maxWidth: 300),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: DesignTokens.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: DesignTokens.line),
        ),
        child: Text(
          _moodMessage(pet.mood),
          style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: DesignTokens.ink2,
              height: 1.4),
        ),
      ),
    );
  }

  /// mood → 말풍선 대사 (기존 mood 데이터만 사용, 새 기능 아님).
  String _moodMessage(PetMood mood) {
    switch (mood) {
      case PetMood.happy:
        return '오늘은 기분이 좋아요. 꼬리도 살랑 흔드네요.';
      case PetMood.normal:
        return '평온한 하루예요. 함께 있어 좋아요.';
      case PetMood.hungry:
        return '배가 고파요… 먹이 좀 주실래요?';
      case PetMood.sleepy:
        return '눈이 슬슬 감겨요. 잠깐 쉬고 싶어요.';
      case PetMood.tired:
        return '오늘은 조금 지쳤어요. 쉬어갈까요?';
      case PetMood.sad:
        return '기운이 없어요… 놀아주면 좋겠어요.';
      case PetMood.dead:
        return '…';
    }
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
    // 시안 서식지 무대: 하늘→풀밭 + 우상단 해 + 바닥 플랫폼·그림자 + 큰 펫.
    return Container(
      height: 250,
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
          // 우상단 해
          Positioned(
            top: 14,
            right: 16,
            child: Icon(Icons.wb_sunny_rounded,
                size: 26, color: DesignTokens.gold.withValues(alpha: 0.9)),
          ),
          // 바닥 풀밭 밴드
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              height: 48,
              decoration: BoxDecoration(
                color: theme.primary.withValues(alpha: 0.10),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(70),
                  topRight: Radius.circular(70),
                ),
              ),
            ),
          ),
          // 발밑 그림자
          Positioned(
            bottom: 28,
            child: Container(
              width: 130,
              height: 18,
              decoration: BoxDecoration(
                color: theme.primaryDeep.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(100),
              ),
            ),
          ),
          // 펫 — 톡 건드리면 반응(기분 좋으면 joy, 나쁘면 angry)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: GestureDetector(
              onTap: () => _playTransientMotion(_pokeReaction(pet.mood)),
              child: _buildPetSprite(pet, theme),
            ),
          ),
        ],
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
        width: 210,
        height: 210,
        child: Align(
          alignment: Alignment.bottomCenter,
          child: PixelMotionAnimation(
            spriteKey: spriteKey,
            motion: motion,
            width: 195,
            height: 195,
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

  /// 상태 미니 행 — 시안: 포만감·기분·체력 3열, 라벨 + 짧은 컬러 바.
  Widget _buildStatusMiniRow(Pet pet, SpeciesTheme theme) {
    Widget stat(String label, int value, Color color) => Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: DesignTokens.ink3)),
              const SizedBox(height: 5),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: (value / 100).clamp(0.0, 1.0),
                  minHeight: 7,
                  backgroundColor: color.withValues(alpha: 0.18),
                  valueColor: AlwaysStoppedAnimation(color),
                ),
              ),
            ],
          ),
        );
    return Row(
      children: [
        stat('포만감', pet.hunger, DesignTokens.good),
        const SizedBox(width: 12),
        stat('기분', pet.happiness, DesignTokens.gold),
        const SizedBox(width: 12),
        stat('체력', pet.stamina, const Color(0xFF56A3EC)),
      ],
    );
  }

  /// 액션 행 — 시안: 먹이·놀기·휴식 3개의 정사각 파스텔 카드.
  /// 먹이=급식(기존), 놀기=joy 연출, 휴식=sleep 연출(수치 변화 없음).
  Widget _buildActionRow(WidgetRef ref, Pet pet, SpeciesTheme theme) {
    final canFeed = ref.watch(canFeedPetUseCaseProvider).canFeed(pet);
    final hasMotion = _motionSpriteKey(pet) != null;
    return Row(
      children: [
        Expanded(
          child: _ActionTile(
            icon: Icons.restaurant,
            label: '먹이',
            color: DesignTokens.good,
            enabled: canFeed,
            onTap: () {
              ref.read(petNotifierProvider(_activePetId).notifier).feed();
              if (hasMotion) _playTransientMotion(PixelMotion.eat);
            },
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _ActionTile(
            icon: Icons.sports_esports,
            label: '놀기',
            color: const Color(0xFF56A3EC),
            onTap: () => _playTransientMotion(PixelMotion.joy),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _ActionTile(
            icon: Icons.bedtime,
            label: '휴식',
            color: DesignTokens.gold,
            onTap: () => _playTransientMotion(PixelMotion.sleep),
          ),
        ),
      ],
    );
  }

  /// 오늘의 케어 — 시안: 제목 + 'N/M 완료' + 목표 체크리스트 행.
  /// 기존 오늘 목표(식사·걸음·수면) 데이터를 체크리스트로 표현.
  Widget _buildTodayCareCard(Pet pet, SpeciesTheme theme) {
    final goals = TodayGoalProgress.fromPet(pet);
    final items = <(String, bool)>[
      ('식사 목표 ${goals.feedProgress}/${goals.feedGoal}회', goals.feedDone),
      ('걸음 목표 ${_formatSteps(goals.steps)}/${_formatSteps(goals.stepsGoal)}보',
          goals.exerciseDone),
      ('수면 목표 ${goals.sleepMinutes ~/ 60}/${goals.sleepGoalMinutes ~/ 60}시간',
          goals.sleepDone),
    ];
    final doneCount = items.where((e) => e.$2).length;
    return AppCard(
      theme: theme,
      variant: AppCardVariant.flat,
      radius: 16,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('오늘의 케어',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: DesignTokens.ink)),
              Text('$doneCount / ${items.length} 완료',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: theme.primary)),
            ],
          ),
          const SizedBox(height: 8),
          for (final (label, done) in items)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                children: [
                  Icon(
                    done ? Icons.check_circle : Icons.radio_button_unchecked,
                    size: 17,
                    color: done ? DesignTokens.good : DesignTokens.ink3,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(label,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: done ? DesignTokens.ink3 : DesignTokens.ink2,
                          decoration:
                              done ? TextDecoration.lineThrough : null,
                        )),
                  ),
                ],
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

/// 홈 액션 타일 — 시안: 컬러 아이콘 정사각 + 라벨. 먹이/놀기/휴식 공용.
class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  final bool enabled;

  const _ActionTile({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1.0 : 0.4,
      child: GestureDetector(
        onTap: enabled ? onTap : null,
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: DesignTokens.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: DesignTokens.line),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, size: 21, color: color),
              ),
              const SizedBox(height: 6),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                  color: DesignTokens.ink2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

