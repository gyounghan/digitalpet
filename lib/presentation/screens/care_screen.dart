import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/pet_provider.dart';
import '../widgets/app_design.dart';
import '../../core/theme/species_theme.dart';
import '../../core/constants/app_strings.dart';
import '../../domain/entities/pet.dart';
import '../../domain/entities/mission.dart';
import '../../domain/constants/mission_catalog.dart';
import '../../domain/usecases/alternative_feed_pet_usecase.dart';
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
  int _napRemainingSeconds = 0;

  @override
  void dispose() {
    _shakeTimer?.cancel();
    _shakeDetector?.stop();
    _napTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final petAsync = ref.watch(petNotifierProvider(HomeScreen.defaultPetId));
    return Scaffold(
      backgroundColor: DesignTokens.bg,
      body: SafeArea(
        child: petAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('오류: $e')),
          data: (pet) => _buildContent(pet),
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

  /// 미션 카드 — 성향 축별 도전과제 진행도. 완료 시 유아기 진화 종에 기여.
  Widget _buildMissionsCard(Pet pet, SpeciesTheme theme) {
    final done = MissionCatalog.completedCount(pet);
    final total = MissionCatalog.all.length;
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
                    color: DesignTokens.ink3),
              ),
              Text(
                '$done/$total',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: theme.primary),
              ),
            ],
          ),
          const SizedBox(height: 6),
          for (final m in MissionCatalog.all) _missionRow(m, pet, theme),
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
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
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

  Widget _buildAltFeedRow(Pet pet, SpeciesTheme theme) {
    final useCase = ref.read(alternativeFeedPetUseCaseProvider);
    final canFeedUseCase = ref.read(canFeedPetUseCaseProvider);
    final enabled = useCase.canUse(pet) && canFeedUseCase.canFeed(pet);
    final used = pet.todayAlternativeFeedCount;
    final max = AlternativeFeedPetUseCase.maxAlternativeFeedsPerDay;

    return AppListRow(
      theme: theme,
      tinted: enabled,
      leading: Icon(Icons.local_dining,
          color: enabled ? theme.primaryDeep : DesignTokens.ink3, size: 20),
      title: '간편 급식',
      subtitle: enabled
          ? '식사 시간대 · 오늘 $used/$max회 사용'
          : (canFeedUseCase.canFeed(pet)
              ? '오늘 모두 사용 ($used/$max)'
              : '식사 시간대 아님'),
      trailing: _trailingPill(enabled, theme),
      onTap: enabled
          ? () {
              ref
                  .read(petNotifierProvider(HomeScreen.defaultPetId).notifier)
                  .performAlternativeFeed();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('간편 급식 완료 · 포만감 +')),
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
      leading: Icon(Icons.bedtime,
          color: enabled ? theme.primaryDeep : DesignTokens.ink3, size: 20),
      title: '낮잠 모드 (15분)',
      subtitle: _napTimer != null
          ? '진행 중...'
          : '오늘 $used/$max회 사용 · 끝나면 수면 보상',
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
      leading: Icon(Icons.vibration,
          color: enabled ? theme.primaryDeep : DesignTokens.ink3, size: 20),
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
        ref
            .read(petNotifierProvider(HomeScreen.defaultPetId).notifier)
            .performShakeBonus(finalCount);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${AppStrings.shakeBonusComplete}: $finalCount회 → '
              '+${finalCount * ShakeStepBonusUseCase.stepsPerShake}걸음',
            ),
          ),
        );
        setState(() {});
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
                    const Icon(Icons.vibration,
                        color: Colors.white, size: 56),
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
                              color: Colors.white70, fontSize: 14),
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
        ref
            .read(petNotifierProvider(HomeScreen.defaultPetId).notifier)
            .performAlternativeSleep();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('낮잠 모드 15분 완료! 수면 보상이 적용됐어요.')),
        );
        remainingNotifier.dispose();
        setState(() {});
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
                  final minutes =
                      (remaining ~/ 60).toString().padLeft(2, '0');
                  final seconds = (remaining % 60).toString().padLeft(2, '0');
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.bedtime,
                          color: Colors.white, size: 56),
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
            ),
          ),
        );
      },
    );
  }
}

