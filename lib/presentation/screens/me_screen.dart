import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/pet_provider.dart';
import '../widgets/app_design.dart';
import '../widgets/pixel_pet_image.dart';
import '../widgets/pixel_motion_animation.dart';
import '../../core/theme/species_theme.dart';
import '../../core/constants/app_strings.dart';
import '../../core/utils/pet_image_helper.dart';
import '../../data/services/ad_service.dart';
import '../../domain/entities/pet.dart';
import '../../domain/entities/evolution_type.dart';
import 'debug_pixel_gallery_screen.dart';
import 'home_screen.dart';

/// 도감 화면 — 펫 프로필 + 전투 스탯 + 진화율 + 누적 통계 + 진화 트리
///
/// 펫의 정체성·성장을 한눈에 보는 페이지. 진화 트리/진화 실행을 포함한다.
/// 동기화 권한 진단은 홈 상단 배너(SyncPermissionBanner)로 이전했다.
class MeScreen extends ConsumerStatefulWidget {
  const MeScreen({super.key});

  @override
  ConsumerState<MeScreen> createState() => _MeScreenState();
}

class _MeScreenState extends ConsumerState<MeScreen> {
  bool _isEvolving = false;
  bool _isAdLoading = false;

  Future<void> _handleEvolve() async {
    if (_isEvolving) return;
    setState(() => _isEvolving = true);
    final notifier =
        ref.read(petNotifierProvider(HomeScreen.defaultPetId).notifier);
    final success = await notifier.evolve();
    if (!mounted) return;
    setState(() => _isEvolving = false);
    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('진화 성공!')),
      );
    }
  }

  /// 새로 키우기 — 확인 다이얼로그 → 리워드 광고 → 초기화
  Future<void> _handleRestart() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: DesignTokens.surface,
        title: const Text(
          AppStrings.restartConfirmTitle,
          style: TextStyle(
              color: DesignTokens.ink, fontWeight: FontWeight.w800),
        ),
        content: const Text(
          AppStrings.restartConfirmBody,
          style: TextStyle(color: DesignTokens.ink2, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text(AppStrings.restartCancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text(
              AppStrings.restartConfirm,
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final notifier =
        ref.read(petNotifierProvider(HomeScreen.defaultPetId).notifier);
    final messenger = ScaffoldMessenger.of(context);

    setState(() => _isAdLoading = true);
    try {
      // 리워드 광고 시청 완료 시에만 초기화
      await AdService().showRewardedAd(
        onRewarded: () async {
          await notifier.restart();
          messenger.showSnackBar(
            const SnackBar(content: Text(AppStrings.restartSuccess)),
          );
        },
        onAdFailed: () {
          messenger.showSnackBar(
            const SnackBar(content: Text(AppStrings.adLoadFailed)),
          );
        },
      );
    } finally {
      if (mounted) setState(() => _isAdLoading = false);
    }
  }

  String _stageLabel(int stage) =>
      AppStrings.stageLabels[stage.clamp(1, 4)] ?? '털뭉치';

  String _stageName(EvolutionType? type, int stage, String grade) {
    if (stage <= 1) return '털뭉치';
    if (type == null) return '???';
    final typeName = type.name;
    if (stage == 2) return AppStrings.stage2Names[typeName] ?? '???';
    if (stage == 3) {
      final g = grade.isNotEmpty ? grade : 'normal';
      return AppStrings.stage3Names[typeName]?[g] ?? '???';
    }
    if (stage >= 4) return AppStrings.stage4Names[typeName] ?? '???';
    return '???';
  }

  int _requiredLevelForStage(int currentStage) {
    switch (currentStage) {
      case 1:
        return 5;
      case 2:
        return 10;
      case 3:
        return 15;
      default:
        return 0;
    }
  }

  bool _canEvolve(Pet pet) {
    final evolvePetUseCase = ref.read(evolvePetUseCaseProvider);
    return evolvePetUseCase.canEvolve(pet);
  }

  @override
  Widget build(BuildContext context) {
    final petAsync = ref.watch(petNotifierProvider(HomeScreen.defaultPetId));
    return Scaffold(
      backgroundColor: DesignTokens.bg,
      body: SafeArea(
        child: petAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(
            child: Text('오류: $e',
                style: const TextStyle(color: DesignTokens.bad)),
          ),
          data: (pet) => _buildContent(pet),
        ),
      ),
    );
  }

  Widget _buildContent(Pet pet) {
    final theme = SpeciesTheme.forType(pet.evolutionType);
    final canEvolve = _canEvolve(pet);
    return Column(
      children: [
        const ScreenTop(title: '도감'),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
            children: [
              _buildProfileCard(pet, theme, canEvolve),
              const SizedBox(height: 10),
              _buildBattleStats(pet, theme),
              const SizedBox(height: 10),
              _buildLifetimeStats(pet, theme),
              const SizedBox(height: 14),
              const SectionTitle(title: '진화 트리'),
              _buildEvoTreeCard(pet, theme),
              const SizedBox(height: 14),
              if (pet.evolutionStage < 4)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed:
                        (_isEvolving || !canEvolve) ? null : _handleEvolve,
                    icon: Icon(
                      _isEvolving ? Icons.hourglass_top : Icons.auto_awesome,
                      size: 18,
                    ),
                    label: Text(
                      _isEvolving
                          ? AppStrings.evolutionEvolving
                          : canEvolve
                              ? AppStrings.evolutionEvolveNow
                              : 'Lv.${_requiredLevelForStage(pet.evolutionStage)} 필요',
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.primary,
                      disabledBackgroundColor:
                          theme.primary.withValues(alpha: 0.35),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: 0,
                    ),
                  ),
                ),
              const SizedBox(height: 18),
              _buildRestartButton(),
              if (kDebugMode) ...[
                const SizedBox(height: 8),
                _buildDebugGalleryButton(),
              ],
            ],
          ),
        ),
      ],
    );
  }

  /// 새로 키우기(초기화) 버튼 — 되돌릴 수 없는 동작이라 차분한 outlined 스타일
  /// 광고 로딩 중에는 비활성화하고 스피너를 표시한다.
  Widget _buildRestartButton() {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: _isAdLoading ? null : _handleRestart,
        icon: _isAdLoading
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: DesignTokens.ink3,
                ),
              )
            : const Icon(Icons.restart_alt, size: 18),
        label: Text(_isAdLoading ? '광고 로딩 중...' : AppStrings.restartButton),
        style: OutlinedButton.styleFrom(
          foregroundColor: DesignTokens.ink3,
          side: const BorderSide(color: DesignTokens.line),
          padding: const EdgeInsets.symmetric(vertical: 13),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    );
  }

  /// [디버그 전용] 픽셀 갤러리 진입 버튼 — 릴리스 전 화면과 함께 삭제
  Widget _buildDebugGalleryButton() {
    return SizedBox(
      width: double.infinity,
      child: TextButton.icon(
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => const DebugPixelGalleryScreen(),
            ),
          );
        },
        icon: const Icon(Icons.grid_on, size: 16),
        label: const Text('픽셀 갤러리 (디버그)'),
        style: TextButton.styleFrom(foregroundColor: DesignTokens.ink3),
      ),
    );
  }

  /// 상단 프로필 카드 (deep gradient)
  Widget _buildProfileCard(Pet pet, SpeciesTheme theme, bool canEvolve) {
    final stage = pet.evolutionStage;
    final requiredLevel = _requiredLevelForStage(stage);
    final stageName = _stageName(pet.evolutionType, stage, pet.evolutionGrade);
    final imagePath = getEvolutionImagePath(pet.evolutionType, stage);
    // 진화율: 다음 단계까지 레벨 진행도 (현재 stage가 최종이면 100%)
    final evoPct = stage >= 4
        ? 100
        : requiredLevel <= 0
            ? 0
            : ((pet.level / requiredLevel) * 100).clamp(0, 100).round();

    return AppCard(
      theme: theme,
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [theme.primary, theme.primaryDeep],
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(18),
                ),
                alignment: Alignment.center,
                child: imagePath != null
                    // 컬러 그라데이션 배경 위라 흰 몸통 도트가 잘 보인다
                    ? PixelPetImage(
                        assetPath: imagePath,
                        width: 78,
                        height: 78,
                        dotColor: Colors.white.withValues(alpha: 0.95),
                      )
                    : const Icon(Icons.pets, size: 44, color: Colors.white),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      SpeciesTheme.labelFor(pet.evolutionType),
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: Colors.white.withValues(alpha: 0.7),
                        letterSpacing: 0.6,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      stageName,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      '${pet.name} · Lv.${pet.level} · ${_stageLabel(stage)}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.white.withValues(alpha: 0.88),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // 진화율 게이지
          Row(
            children: [
              Text(
                '진화율',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: Colors.white.withValues(alpha: 0.85),
                ),
              ),
              const Spacer(),
              Text(
                stage >= 4
                    ? '최종 단계'
                    : '$evoPct% · Lv.${pet.level}/$requiredLevel',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: Colors.white.withValues(alpha: 0.88),
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: Container(
              height: 8,
              color: Colors.white.withValues(alpha: 0.18),
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: (evoPct / 100).clamp(0.0, 1.0),
                child: Container(color: Colors.white),
              ),
            ),
          ),
          if (canEvolve && stage < 4) ...[
            const SizedBox(height: 10),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.22),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(Icons.auto_awesome, size: 13, color: Colors.white),
                  SizedBox(width: 5),
                  Text(
                    '진화 가능!',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// 전투 스탯 카드 — HP/ATK/DEF + 종 특성
  /// 실제 전투(BattleWithActivityUseCase)와 동일한 Pet getter를 사용해 일치 보장.
  Widget _buildBattleStats(Pet pet, SpeciesTheme theme) {
    final atk = pet.battleAtk;
    final def = pet.battleDef;
    final hp = pet.battleHp;

    return AppCard(
      theme: theme,
      variant: AppCardVariant.flat,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.shield_moon, size: 14, color: theme.primaryDeep),
              const SizedBox(width: 6),
              Text(
                '전투 스탯',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                  color: theme.primaryDeep,
                  letterSpacing: 0.5,
                ),
              ),
              const Spacer(),
              Text(
                _affinityHint(pet.evolutionType),
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: DesignTokens.ink3,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _statBox('HP', hp, theme)),
              const SizedBox(width: 8),
              Expanded(child: _statBox('ATK', atk, theme)),
              const SizedBox(width: 8),
              Expanded(child: _statBox('DEF', def, theme)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statBox(String label, int value, SpeciesTheme theme) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: theme.primarySoft,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              color: theme.primaryDeep,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '$value',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: theme.primaryDeep,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }

  String _affinityHint(EvolutionType? type) {
    switch (type) {
      case EvolutionType.bird:
        return '주작 → 청룡에 강함';
      case EvolutionType.snake:
        return '청룡 → 현무에 강함';
      case EvolutionType.turtle:
        return '현무 → 백호에 강함';
      case EvolutionType.tiger:
        return '백호 → 주작에 강함';
      case null:
        return '진화 전';
    }
  }

  /// 누적 통계 카드
  Widget _buildLifetimeStats(Pet pet, SpeciesTheme theme) {
    return AppCard(
      theme: theme,
      variant: AppCardVariant.flat,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.insights, size: 14, color: theme.primaryDeep),
              const SizedBox(width: 6),
              Text(
                '누적 기록',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                  color: theme.primaryDeep,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _lifeRow(Icons.directions_run, '걸음 수',
              _formatNumber(pet.totalSteps), '보'),
          _lifeRow(Icons.fitness_center, '운동',
              _formatNumber(pet.totalExerciseMinutes), '분'),
          _lifeRow(Icons.bedtime, '수면', _formatNumber(pet.totalIdleHours), '시간'),
          _lifeRow(Icons.emoji_events, '배틀 승리',
              _formatNumber(pet.battleVictoryCount), '회'),
          _lifeRow(Icons.local_fire_department, '접속 연속',
              _formatNumber(pet.consecutiveLoginDays), '일'),
        ],
      ),
    );
  }

  Widget _lifeRow(IconData icon, String label, String value, String unit) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 14, color: DesignTokens.ink3),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: DesignTokens.ink2,
              ),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w800,
              color: DesignTokens.ink,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(width: 2),
          Text(
            unit,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: DesignTokens.ink3,
            ),
          ),
        ],
      ),
    );
  }

  String _formatNumber(int n) {
    if (n < 1000) return '$n';
    final s = n.toString();
    final buf = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
      buf.write(s[i]);
    }
    return buf.toString();
  }

  /// 진화 트리
  Widget _buildEvoTreeCard(Pet pet, SpeciesTheme theme) {
    final stages = const [
      (1, '털뭉치'),
      (2, '유아기'),
      (3, '성장기'),
      (4, '성숙기'),
    ];
    return AppCard(
      theme: theme,
      variant: AppCardVariant.flat,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (var i = 0; i < stages.length; i++) ...[
                _evoTreeNode(pet.evolutionType, stages[i].$1, stages[i].$2,
                    theme,
                    passed: pet.evolutionStage >= stages[i].$1,
                    current: pet.evolutionStage == stages[i].$1),
                if (i < stages.length - 1) _dashedConnector(),
              ],
            ],
          ),
          // 다음 진화 안내는 프로필 카드의 진화율 게이지(N% · Lv.n/m)가 담당
        ],
      ),
    );
  }

  Widget _evoTreeNode(
    EvolutionType? type,
    int stage,
    String name,
    SpeciesTheme theme, {
    required bool passed,
    required bool current,
  }) {
    return Opacity(
      opacity: passed ? 1.0 : 0.35,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: current ? theme.primarySoft : DesignTokens.surfaceSoft,
              borderRadius: BorderRadius.circular(14),
              border: current
                  ? Border.all(color: theme.primary, width: 2)
                  : Border.all(color: DesignTokens.line, width: 1),
            ),
            alignment: Alignment.center,
            child: _treeSprite(type, stage, theme),
          ),
          const SizedBox(height: 4),
          Text(
            name,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: current ? theme.primaryDeep : DesignTokens.ink3,
            ),
          ),
        ],
      ),
    );
  }

  /// 진화 트리 노드 스프라이트 — 우리가 만든 도트 모션(털뭉치·유아기·성장기)의
  /// 대표 프레임을 렌더한다. 모션이 없는 단계(사신수)·종 미결정은 정적 이미지로 폴백.
  Widget _treeSprite(EvolutionType? type, int stage, SpeciesTheme theme) {
    final key = _treeMotionKey(type, stage);
    if (key != null) {
      final frames = motionFramesFor(key, PixelMotion.walk);
      if (frames != null && frames.isNotEmpty) {
        final isFluff = key == 'fluff';
        return PixelSpriteView(
          sprite: frames.first,
          width: 40,
          height: 40,
          dotColor: isFluff ? SpeciesTheme.fluffBody : theme.primary,
          accentColor:
              isFluff ? SpeciesTheme.fluffAccent : theme.spriteAccent,
        );
      }
    }
    final imagePath = getEvolutionImagePath(type, stage);
    if (imagePath != null) {
      return PixelPetImage(
        assetPath: imagePath,
        width: 40,
        height: 40,
        dotColor: theme.primary,
        accentColor: theme.spriteAccent,
      );
    }
    return const Text('?',
        style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800));
  }

  /// 진화 단계 → 도트 모션 스프라이트 키 (홈 _motionSpriteKey와 동일).
  String? _treeMotionKey(EvolutionType? type, int stage) {
    if (stage == 1) return 'fluff';
    final species = evolutionSpeciesImagePrefix(type);
    if (species != null && (stage == 2 || stage == 3)) {
      return '$species${stage - 1}';
    }
    return null;
  }

  Widget _dashedConnector() {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 18),
        child: LayoutBuilder(
          builder: (context, constraints) {
            const dashWidth = 4.0;
            const dashSpace = 3.0;
            final count =
                (constraints.maxWidth / (dashWidth + dashSpace)).floor();
            return Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: List.generate(
                count,
                (_) => Container(
                  width: dashWidth,
                  height: 1.5,
                  color: DesignTokens.line2,
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
