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
import '../../core/utils/pet_image_helper.dart';
import '../../data/services/ad_service.dart';
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
            // 펫 스테이지를 더 크게 (flex=5)
            Expanded(flex: 5, child: _buildPetStage(pet, theme)),
            // Feed 버튼 + 현재 상태 3카드
            _buildFeedButton(ref, pet, theme),
            _buildStatCards(pet, theme),
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
            Center(child: _buildPetSprite(pet, theme)),
          ],
        ),
      ),
    );
  }

  /// 도트 모션 스프라이트 키 (없으면 정적 렌더)
  ///
  /// - stage 1 (털뭉치)  → 'fluff'
  /// - stage 2 (유아기)  → '{종}1'
  /// - stage 3 (성장기)  → '{종}2'
  /// - stage 4 (사신수)  → null (정적 mood 이미지)
  String? _motionSpriteKey(Pet pet) {
    if (pet.evolutionStage == 1) return 'fluff';
    final species = evolutionSpeciesImagePrefix(pet.evolutionType);
    if (species != null &&
        (pet.evolutionStage == 2 || pet.evolutionStage == 3)) {
      return '$species${pet.evolutionStage - 1}';
    }
    return null;
  }

  /// 펫 스테이지 스프라이트
  ///
  /// - 도트 모션 스테이지(털뭉치·유아기·성장기): mood 기반 도트 모션 루프
  ///   + 액션 시 일시 모션(밥먹기)
  /// - 사신수(stage 4): 기존 mood 정적 도트 렌더
  Widget _buildPetSprite(Pet pet, SpeciesTheme theme) {
    final spriteKey = _motionSpriteKey(pet);
    if (spriteKey != null) {
      final motion = _transientMotion ?? motionForMood(pet.mood);
      // 털뭉치는 종 미결정 → 밝은 베이지 단색
      final isFluff = spriteKey == 'fluff';
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
            dotColor: isFluff ? SpeciesTheme.fluffBody : theme.primary,
            accentColor:
                isFluff ? SpeciesTheme.fluffBody : theme.spriteAccent,
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

  /// 오늘의 세트 카드 — 포만감+수면+운동을 모두 채우면 1세트 완성.
  /// 아직 안 채운 항목만 강조되고, 셋 다 완료되면 세트 보상(반감 EXP)을 받는다.
  /// pet 데이터만으로 동기 계산 (FutureBuilder 불필요).
  /// 현재 상태 3카드 (포만감=hunger · 수면=stamina · 운동=happiness)
  /// 실제 스탯을 그대로 보여줘 펫의 mood(기분)와 항상 일치한다.
  /// 하단에 오늘의 세트 진행을 한 줄로 덧붙여 보상 동기를 유지.
  Widget _buildStatCards(Pet pet, SpeciesTheme theme) {
    final todaySets = pet.todaySetExpClaimed;
    final nextReward =
        CalculateDailyGoalsScoreUseCase.setExpBase >> todaySets.clamp(0, 31);

    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 0, 18, 14),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _statCard('포만감', Icons.restaurant, pet.hunger, theme),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _statCard('수면', Icons.bedtime, pet.stamina, theme),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _statCard(
                    '운동', Icons.directions_run, pet.happiness, theme),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // 오늘의 세트 진행 (포만감+수면+운동 목표를 모두 채우면 1세트)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.task_alt, size: 13, color: theme.primaryDeep),
              const SizedBox(width: 5),
              Text(
                todaySets > 0
                    ? '오늘 $todaySets세트 완성 · 다음 +$nextReward EXP'
                    : '오늘의 세트 완성 시 +$nextReward EXP',
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
    );
  }

  /// 단일 스탯 카드 (원형 게이지 + 수치)
  Widget _statCard(String label, IconData icon, int value, SpeciesTheme theme) {
    return AppCard(
      theme: theme,
      variant: AppCardVariant.flat,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      radius: 16,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppCircularGauge(
            value: value.toDouble().clamp(0, 100),
            theme: theme,
            size: 60,
            strokeWidth: 6,
            child: Icon(icon, size: 18, color: theme.primaryDeep),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: DesignTokens.ink,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '$value/100',
            style: const TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              color: DesignTokens.ink3,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
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

