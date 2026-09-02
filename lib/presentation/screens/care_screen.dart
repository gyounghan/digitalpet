import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/pet_provider.dart';
import '../widgets/app_design.dart';
import '../widgets/pet_motion_thumb.dart';
import '../widgets/pixel_motion_animation.dart' show colorVariantFor;
import '../../core/theme/species_theme.dart';
import '../../core/constants/app_strings.dart';
import '../../domain/entities/pet.dart';
import '../../domain/entities/mission.dart';
import '../../domain/constants/meal_times.dart';
import '../../domain/constants/mission_catalog.dart';
import '../../domain/usecases/alternative_feed_pet_usecase.dart';
import '../../domain/usecases/drink_water_usecase.dart';
import '../../domain/usecases/focus_session_usecase.dart';
import '../../domain/usecases/alternative_sleep_pet_usecase.dart';
import '../../domain/usecases/shake_step_bonus_usecase.dart';
import '../../data/datasources/shake_detector.dart';
import 'home_screen.dart';

/// 케어 화면 — "바쁠 때 쓰는 대체 행동" 한 가지 목적
///
/// 간편 급식 / 낮잠 모드 / 흔들기만 제공한다.
/// 자동 감지(걸음·수면)는 홈의 세트 카드, 진화 트리는 도감 탭에 있으므로
/// 중복을 피해 여기서는 제거했다.
class CareScreen extends ConsumerStatefulWidget {
  const CareScreen({super.key});

  @override
  ConsumerState<CareScreen> createState() => _CareScreenState();
}

class _CareScreenState extends ConsumerState<CareScreen> {
  Timer? _shakeTimer;
  int _shakeRemainingSeconds = 0;
  int _shakeCount = 0;
  ShakeDetector? _shakeDetector;
  Timer? _napTimer;

  /// 낮잠 종료 시각 — 틱 카운트가 아닌 시각 기준.
  /// 낮잠 취지가 "폰 내려놓기"라 앱이 백그라운드로 가면 타이머 틱이 멈추는데,
  /// 시각 기준이면 복귀 시 경과 시간이 그대로 인정된다.
  DateTime? _napEndsAt;

  Timer? _focusTimer;

  /// 집중 세션 종료 시각 (낮잠과 동일하게 시각 기준 — 폰 내려놓기 취지)
  DateTime? _focusEndsAt;

  /// 미션 전체 펼침 여부 (기본: 진행 중 상위 3개만)
  bool _showAllMissions = false;

  @override
  void dispose() {
    _shakeTimer?.cancel();
    _shakeDetector?.stop();
    _napTimer?.cancel();
    _focusTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final petAsync = ref.watch(petNotifierProvider(HomeScreen.defaultPetId));
    return Scaffold(
      backgroundColor: DesignTokens.bg,
      body: AppScaffoldBackground(
        child: SafeArea(
          child: petAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('오류: $e')),
            data: (pet) => _buildContent(pet),
          ),
        ),
      ),
    );
  }

  Widget _buildContent(Pet pet) {
    final theme = SpeciesTheme.forType(pet.evolutionType);
    return Column(
      children: [
        ScreenTop(
          title: '케어',
          trailing: AppPill(
            text: '자동',
            theme: theme,
            variant: AppPillVariant.outline,
            icon: Icons.auto_awesome,
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
            children: [
              const SizedBox(height: 4),
              // 현재 상태 — 대체 행동의 효과를 보는 화면이므로 여기서 노출
              _buildStatusCard(pet, theme),
              const SizedBox(height: 14),
              // 능동 건강 습관 — 갓생몬 컨셉
              _buildFocusRow(pet, theme),
              const SizedBox(height: 6),
              _buildWaterRow(pet, theme),
              const SizedBox(height: 6),
              // 대체 케어 — 바쁠 때 직접 채우는 행동
              _buildAltFeedRow(pet, theme),
              const SizedBox(height: 6),
              _buildAltSleepRow(pet, theme),
              const SizedBox(height: 6),
              _buildShakeRow(pet, theme),
              const SizedBox(height: 16),
              const SectionTitle(title: '미션'),
              _buildMissionsCard(pet, theme),
            ],
          ),
        ),
      ],
    );
  }

  /// 현재 상태 카드 — 포만감/행복/기력 실제 스탯 3줄 (홈에서 이동).
  /// 대체 행동(급식/낮잠/흔들기)의 효과가 바로 반영되는 곳이라 여기에 둔다.
  Widget _buildStatusCard(Pet pet, SpeciesTheme theme) {
    return AppCard(
      theme: theme,
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [theme.gradStart, DesignTokens.surface],
      ),
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            width: 118,
            height: 122,
            decoration: BoxDecoration(
              color: DesignTokens.sky.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: DesignTokens.line, width: 1),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Positioned(
                  left: 20,
                  right: 20,
                  bottom: 22,
                  child: Container(
                    height: 12,
                    decoration: BoxDecoration(
                      color: DesignTokens.ink.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                PetMotionThumb(
                  type: pet.evolutionType,
                  stage: pet.evolutionStage,
                  grade: pet.evolutionGrade,
                  variant: colorVariantFor(pet),
                  size: 96,
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${SpeciesTheme.labelFor(pet.evolutionType)} 케어',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: theme.primaryDeep,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '지금 상태를 보고 돌봐주세요',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: DesignTokens.ink,
                  ),
                ),
                const SizedBox(height: 12),
                _statusRow(Icons.restaurant, '포만감', pet.hunger, theme),
                const SizedBox(height: 8),
                _statusRow(Icons.favorite, '행복', pet.happiness, theme),
                const SizedBox(height: 8),
                _statusRow(Icons.bolt, '기력', pet.stamina, theme),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusRow(
    IconData icon,
    String label,
    int value,
    SpeciesTheme theme,
  ) {
    return Row(
      children: [
        Icon(icon, size: 15, color: theme.primaryDeep),
        const SizedBox(width: 7),
        SizedBox(
          width: 44,
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
            value: value.toDouble().clamp(0, 100),
            theme: theme,
            tone: AppMeterTone.themed,
            height: 7,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '$value',
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: DesignTokens.ink3,
            fontFeatures: [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }

  /// 미션 카드 — 성향 축별 도전과제 진행도. 완료 시 유아기 진화 종에 기여.
  ///
  /// 기본은 미완료 중 진행률 상위 3개만 보여주고, "전체 보기"로 펼친다.
  Widget _buildMissionsCard(Pet pet, SpeciesTheme theme) {
    final done = MissionCatalog.completedCount(pet);
    final total = MissionCatalog.all.length;

    final incomplete =
        MissionCatalog.all.where((m) => !m.isComplete(pet)).toList()
          ..sort((a, b) => b.ratio(pet).compareTo(a.ratio(pet)));
    final visible = _showAllMissions
        ? MissionCatalog.all
        : incomplete.take(3).toList();
    final hiddenCount = total - visible.length;

    return AppCard(
      theme: theme,
      variant: AppCardVariant.flat,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '미션을 달성하면 그 성향의 종으로 자란다',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: DesignTokens.ink3,
                ),
              ),
              Text(
                '$done/$total',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: theme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          for (final m in visible) _missionRow(m, pet, theme),
          if (total > 3)
            Center(
              child: TextButton(
                onPressed: () =>
                    setState(() => _showAllMissions = !_showAllMissions),
                style: TextButton.styleFrom(
                  foregroundColor: theme.primaryDeep,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  _showAllMissions ? '접기' : '전체 보기 ($hiddenCount)',
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _missionRow(Mission m, Pet pet, SpeciesTheme theme) {
    final complete = m.isComplete(pet);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                complete ? Icons.check_circle : Icons.radio_button_unchecked,
                size: 16,
                color: complete ? DesignTokens.good : DesignTokens.ink3,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  m.title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: complete ? DesignTokens.ink2 : DesignTokens.ink3,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: theme.primarySoft,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  m.axis.label,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: theme.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: AppMeter(
                  value: m.progress(pet).toDouble(),
                  max: m.target.toDouble(),
                  theme: theme,
                  tone: complete ? AppMeterTone.good : AppMeterTone.themed,
                  height: 6,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${m.progress(pet)}/${m.target}',
                style: const TextStyle(fontSize: 10, color: DesignTokens.ink3),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── 섹션 1 컴포넌트 ────────────────────────────────────────

  /// 물마시기 — 하루 수분 목표(8잔). 능동 건강 습관(갓생몬 컨셉).
  /// 집중 모드(뽀모도로) — 25분 폰 내려놓고 집중하면 펫이 함께 성장.
  /// 갓생 정체성의 핵심: 생산성·디지털 웰빙. 낮잠(기력)과 달리 성장(EXP·행복).
  Widget _buildFocusRow(Pet pet, SpeciesTheme theme) {
    final used = pet.needsGoalReset ? 0 : pet.todayFocusCount;
    final goal = Pet.focusGoalCount;
    final done = used >= goal;
    final enabled = !pet.isDead && !done && _focusTimer == null;

    return AppListRow(
      theme: theme,
      tinted: enabled,
      leading: Icon(
        Icons.self_improvement,
        color: enabled ? theme.primaryDeep : DesignTokens.ink3,
        size: 20,
      ),
      title: '집중 모드 (${FocusSessionUseCase.sessionMinutes}분)',
      subtitle: _focusTimer != null
          ? '집중 중... 폰을 내려놓아요'
          : done
          ? '오늘 집중 목표 달성! 🎯 ($used/$goal)'
          : '폰 내려놓고 집중하면 성장 · 오늘 $used/$goal회',
      trailing: _trailingPill(enabled, theme),
      onTap: enabled ? () => _startFocusMode(ref) : null,
    );
  }

  void _startFocusMode(WidgetRef ref) {
    if (_focusTimer != null) return;
    setState(() {});
    _focusEndsAt = DateTime.now().add(
      const Duration(minutes: FocusSessionUseCase.sessionMinutes),
    );
    final remainingNotifier = ValueNotifier<int>(
      FocusSessionUseCase.sessionMinutes * 60,
    );

    Future<void> completeFocus() async {
      if (Navigator.of(context, rootNavigator: true).canPop()) {
        Navigator.of(context, rootNavigator: true).pop();
      }
      final applied = await ref
          .read(petNotifierProvider(HomeScreen.defaultPetId).notifier)
          .performFocusSession();
      if (!mounted) {
        remainingNotifier.dispose();
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            applied
                ? '집중 완료! 펫이 함께 성장했어요 (+${FocusSessionUseCase.sessionExp} EXP · 행복 +${FocusSessionUseCase.happinessReward})'
                : '오늘 집중 목표를 모두 채웠어요.',
          ),
        ),
      );
      remainingNotifier.dispose();
      setState(() {});
    }

    _focusTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        _focusTimer = null;
        _focusEndsAt = null;
        remainingNotifier.dispose();
        return;
      }
      final remaining = _focusEndsAt!.difference(DateTime.now()).inSeconds;
      if (remaining <= 0) {
        timer.cancel();
        _focusTimer = null;
        _focusEndsAt = null;
        remainingNotifier.value = 0;
        completeFocus();
        return;
      }
      remainingNotifier.value = remaining;
    });

    // 집중 포기 — 보상 없음, 사용 횟수 미차감
    void giveUpFocus() {
      _focusTimer?.cancel();
      _focusTimer = null;
      _focusEndsAt = null;
      if (Navigator.of(context, rootNavigator: true).canPop()) {
        Navigator.of(context, rootNavigator: true).pop();
      }
      remainingNotifier.dispose();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('집중을 중단했어요. (보상 없음)')));
      setState(() {});
    }

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return PopScope(
          canPop: false,
          child: Material(
            color: Colors.black.withValues(alpha: 0.88),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ValueListenableBuilder<int>(
                    valueListenable: remainingNotifier,
                    builder: (context, remaining, _) {
                      final minutes = (remaining ~/ 60).toString().padLeft(
                        2,
                        '0',
                      );
                      final seconds = (remaining % 60).toString().padLeft(
                        2,
                        '0',
                      );
                      return Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.self_improvement,
                            color: Colors.white,
                            size: 56,
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            '집중하는 중',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            '폰을 내려놓고 펫과 함께 몰입해요',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 13,
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
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 24),
                  TextButton(
                    onPressed: giveUpFocus,
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.white70,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 8,
                      ),
                    ),
                    child: const Text(
                      '중단하기',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        decoration: TextDecoration.underline,
                        decorationColor: Colors.white38,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildWaterRow(Pet pet, SpeciesTheme theme) {
    final used = pet.needsGoalReset ? 0 : pet.todayWaterCount;
    final goal = Pet.waterGoalCount;
    final done = used >= goal;
    final enabled = !pet.isDead && !done;

    return AppListRow(
      theme: theme,
      tinted: enabled,
      leading: Icon(
        Icons.local_drink,
        color: enabled ? theme.primaryDeep : DesignTokens.ink3,
        size: 20,
      ),
      title: '물마시기',
      subtitle: done
          ? '오늘 수분 목표 달성! 💧 ($used/$goal잔)'
          : '한 잔당 기력 +${DrinkWaterUseCase.staminaPerCup} · 오늘 $used/$goal잔',
      trailing: _trailingPill(enabled, theme),
      onTap: enabled
          ? () async {
              final before = pet.todayWaterCount;
              final applied = await ref
                  .read(petNotifierProvider(HomeScreen.defaultPetId).notifier)
                  .performDrinkWater();
              if (!mounted) return;
              final reachedGoal = before + 1 >= goal;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    !applied
                        ? '오늘 수분 목표를 이미 채웠어요'
                        : reachedGoal
                        ? '수분 목표 달성! 완료 보너스 +${DrinkWaterUseCase.completionExp} EXP 💧'
                        : '꿀꺽꿀꺽 · 기력 +${DrinkWaterUseCase.staminaPerCup}',
                  ),
                ),
              );
            }
          : null,
    );
  }

  Widget _buildAltFeedRow(Pet pet, SpeciesTheme theme) {
    final useCase = ref.read(alternativeFeedPetUseCaseProvider);
    // 정식 급식과 동일 규칙: 식사 시간대 + 슬롯 공유(시간대당 정식/간편 합쳐
    // 1회) + 하루 3회. 버튼 활성과 실제 적용 조건이 항상 일치해야 한다.
    final enabled = useCase.canUse(pet);
    final used = pet.todayAlternativeFeedCount;
    final max = AlternativeFeedPetUseCase.maxAlternativeFeedsPerDay;

    final String subtitle;
    if (enabled) {
      subtitle = '식사 시간대에 1회 · 오늘 $used/$max회 사용';
    } else if (used >= max) {
      subtitle = '오늘 모두 사용 ($used/$max)';
    } else if (MealTimes.slotAt(DateTime.now()) == 0) {
      subtitle = '식사 시간이 아니에요 (아침·점심·저녁)';
    } else {
      subtitle = '이 시간대는 이미 급식했어요';
    }

    return AppListRow(
      theme: theme,
      tinted: enabled,
      leading: Icon(
        Icons.local_dining,
        color: enabled ? theme.primaryDeep : DesignTokens.ink3,
        size: 20,
      ),
      title: '간편 급식',
      subtitle: subtitle,
      trailing: _trailingPill(enabled, theme),
      onTap: enabled
          ? () async {
              final applied = await ref
                  .read(petNotifierProvider(HomeScreen.defaultPetId).notifier)
                  .performAlternativeFeed();
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    applied ? '간편 급식 완료 · 포만감 +' : '지금은 간편 급식을 할 수 없어요',
                  ),
                ),
              );
            }
          : null,
    );
  }

  Widget _buildAltSleepRow(Pet pet, SpeciesTheme theme) {
    final useCase = ref.read(alternativeSleepPetUseCaseProvider);
    final enabled = useCase.canUse(pet) && _napTimer == null;
    final used = pet.todayAlternativeSleepCount;
    final max = AlternativeSleepPetUseCase.maxAlternativeSleepsPerDay;

    return AppListRow(
      theme: theme,
      leading: Icon(
        Icons.bedtime,
        color: enabled ? theme.primaryDeep : DesignTokens.ink3,
        size: 20,
      ),
      title: '낮잠 모드 (15분)',
      subtitle: _napTimer != null ? '진행 중...' : '오늘 $used/$max회 사용 · 끝나면 기력 회복',
      trailing: _trailingPill(enabled, theme),
      onTap: enabled ? () => _startNapMode(ref) : null,
    );
  }

  Widget _buildShakeRow(Pet pet, SpeciesTheme theme) {
    final useCase = ref.read(shakeStepBonusUseCaseProvider);
    final enabled = useCase.canUse(pet) && _shakeTimer == null;
    final used = pet.todayAlternativeExerciseCount;
    final max = ShakeStepBonusUseCase.maxSessionsPerDay;

    return AppListRow(
      theme: theme,
      leading: Icon(
        Icons.vibration,
        color: enabled ? theme.primaryDeep : DesignTokens.ink3,
        size: 20,
      ),
      title: '흔들기 보너스 (30초)',
      subtitle: _shakeTimer != null
          ? '흔드는 중...'
          : '오늘 $used/$max회 · 1회 = ${ShakeStepBonusUseCase.stepsPerShake}걸음',
      trailing: _trailingPill(enabled, theme),
      onTap: enabled ? () => _startShakeSession(ref) : null,
    );
  }

  Widget _trailingPill(bool enabled, SpeciesTheme theme) {
    return AppPill(
      text: enabled ? '시작' : '대기',
      theme: theme,
      variant: enabled ? AppPillVariant.solid : AppPillVariant.outline,
      fontSize: 10,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    );
  }

  // ── 흔들기 / 낮잠 (홈에서 이관) ─────────────────────────────

  void _startShakeSession(WidgetRef ref) {
    if (_shakeTimer != null) return;
    setState(() {});
    _shakeRemainingSeconds = 30;
    _shakeCount = 0;
    final remainingNotifier = ValueNotifier<int>(_shakeRemainingSeconds);
    final countNotifier = ValueNotifier<int>(0);

    _shakeDetector = ShakeDetector(
      onShake: () {
        if (_shakeCount < ShakeStepBonusUseCase.maxShakesPerSession) {
          _shakeCount += 1;
          countNotifier.value = _shakeCount;
        }
      },
    )..start();

    void cleanup() {
      _shakeTimer?.cancel();
      _shakeTimer = null;
      _shakeDetector?.stop();
      _shakeDetector = null;
      remainingNotifier.dispose();
      countNotifier.dispose();
    }

    _shakeTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        cleanup();
        return;
      }
      if (_shakeRemainingSeconds <= 1) {
        final finalCount = _shakeCount;
        cleanup();
        if (Navigator.of(context, rootNavigator: true).canPop()) {
          Navigator.of(context, rootNavigator: true).pop();
        }
        // 적용 결과에 따라 메시지 구분 — 0회는 사용 횟수를 차감하지 않고,
        // 한도 초과 등 no-op일 때 완료 메시지를 띄우지 않는다
        Future<void> completeShake() async {
          final applied = await ref
              .read(petNotifierProvider(HomeScreen.defaultPetId).notifier)
              .performShakeBonus(finalCount);
          if (!mounted) return;
          final String message;
          if (applied) {
            message =
                '${AppStrings.shakeBonusComplete}: $finalCount회 → '
                '+${finalCount * ShakeStepBonusUseCase.stepsPerShake}걸음';
          } else if (finalCount <= 0) {
            message = '흔들기가 감지되지 않았어요. (횟수 차감 없음)';
          } else {
            message = '오늘 흔들기 보너스를 이미 사용했어요.';
          }
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(message)));
          setState(() {});
        }

        completeShake();
        return;
      }
      _shakeRemainingSeconds -= 1;
      remainingNotifier.value = _shakeRemainingSeconds;
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
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.vibration, color: Colors.white, size: 56),
                    const SizedBox(height: 16),
                    const Text(
                      AppStrings.shakeBonusInProgress,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ValueListenableBuilder<int>(
                      valueListenable: countNotifier,
                      builder: (context, count, _) {
                        return Text(
                          '$count회',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 48,
                            fontWeight: FontWeight.w800,
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                    ValueListenableBuilder<int>(
                      valueListenable: remainingNotifier,
                      builder: (context, remaining, _) {
                        return Text(
                          '남은 시간 $remaining초',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _startNapMode(WidgetRef ref) {
    if (_napTimer != null) return;
    setState(() {});
    _napEndsAt = DateTime.now().add(const Duration(minutes: 15));
    final remainingNotifier = ValueNotifier<int>(15 * 60);

    Future<void> completeNap() async {
      if (Navigator.of(context, rootNavigator: true).canPop()) {
        Navigator.of(context, rootNavigator: true).pop();
      }
      final applied = await ref
          .read(petNotifierProvider(HomeScreen.defaultPetId).notifier)
          .performAlternativeSleep();
      if (!mounted) {
        remainingNotifier.dispose();
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            applied ? '낮잠 모드 15분 완료! 기력이 회복됐어요.' : '오늘 낮잠 횟수를 모두 사용했어요.',
          ),
        ),
      );
      remainingNotifier.dispose();
      setState(() {});
    }

    _napTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        _napTimer = null;
        _napEndsAt = null;
        remainingNotifier.dispose();
        return;
      }
      // 백그라운드 다녀오면 틱이 밀려 있어도 시각 기준으로 즉시 완료 판정
      final remaining = _napEndsAt!.difference(DateTime.now()).inSeconds;
      if (remaining <= 0) {
        timer.cancel();
        _napTimer = null;
        _napEndsAt = null;
        remainingNotifier.value = 0;
        completeNap();
        return;
      }
      remainingNotifier.value = remaining;
    });

    // 낮잠 포기 — 타이머 정리 후 다이얼로그 닫기 (보상 없음, 사용 횟수 미차감)
    void giveUpNap() {
      _napTimer?.cancel();
      _napTimer = null;
      _napEndsAt = null;
      if (Navigator.of(context, rootNavigator: true).canPop()) {
        Navigator.of(context, rootNavigator: true).pop();
      }
      remainingNotifier.dispose();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('낮잠 모드를 포기했어요. (보상 없음)')));
      setState(() {});
    }

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return PopScope(
          canPop: false,
          child: Material(
            color: Colors.black.withValues(alpha: 0.85),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ValueListenableBuilder<int>(
                    valueListenable: remainingNotifier,
                    builder: (context, remaining, _) {
                      final minutes = (remaining ~/ 60).toString().padLeft(
                        2,
                        '0',
                      );
                      final seconds = (remaining % 60).toString().padLeft(
                        2,
                        '0',
                      );
                      return Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.bedtime,
                            color: Colors.white,
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
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 24),
                  TextButton(
                    onPressed: giveUpNap,
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.white70,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 8,
                      ),
                    ),
                    child: const Text(
                      '포기하기',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        decoration: TextDecoration.underline,
                        decorationColor: Colors.white38,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
