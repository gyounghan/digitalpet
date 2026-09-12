import 'dart:async' show unawaited;
import 'package:flutter/foundation.dart' show kDebugMode, debugPrint;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'
    show MissingPluginException, PlatformException;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart' as kakao;
import '../providers/pet_provider.dart';
import '../providers/active_pet_provider.dart';
import '../widgets/app_design.dart';
import '../widgets/mock_ui_widgets.dart';
import '../widgets/pet_motion_thumb.dart';
import '../widgets/pixel_motion_animation.dart' show colorVariantFor;
import '../../core/theme/species_theme.dart';
import '../../core/constants/app_strings.dart';
import '../../data/datasources/auth_remote_datasource.dart';
import '../../data/datasources/auth_session.dart';
import '../../data/services/ad_service.dart';
import '../../domain/entities/pet.dart';
import '../../domain/entities/evolution_type.dart';
import 'debug_pixel_gallery_screen.dart';
import 'debug_cheat_screen.dart';

/// 도감 화면 — 펫 프로필 + 성장 단계 정보 + 수집 앨범.
///
/// 전투·누적·계정 정보와 진화 실행은 더보기 안에서 기존 기능을 유지한다.
/// 동기화 권한 진단은 홈 상단 배너(SyncPermissionBanner)로 이전했다.
class MeScreen extends ConsumerStatefulWidget {
  const MeScreen({super.key});

  @override
  ConsumerState<MeScreen> createState() => _MeScreenState();
}

class _MeScreenState extends ConsumerState<MeScreen> {
  /// 현재 활성 펫 ID (수집 그리드에서 전환). build가 구독하므로 전환 시 rebuild.
  String get _activePetId => ref.read(activePetIdProvider);

  bool _isEvolving = false;
  bool _isAdLoading = false;
  bool _isKakaoLoading = false;
  bool _showDexDetails = false;
  int? _selectedDexStage;

  Future<void> _handleEvolve() async {
    if (_isEvolving) return;
    setState(() => _isEvolving = true);
    final notifier = ref.read(petNotifierProvider(_activePetId).notifier);
    final success = await notifier.evolve();
    if (!mounted) return;
    setState(() => _isEvolving = false);
    if (success) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('진화 성공!')));
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
            color: DesignTokens.ink,
            fontWeight: FontWeight.w800,
          ),
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

    final notifier = ref.read(petNotifierProvider(_activePetId).notifier);
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
    ref.watch(activePetIdProvider); // 활성 펫 전환 시 rebuild 구독
    final petAsync = ref.watch(petNotifierProvider(_activePetId));
    return Scaffold(
      backgroundColor: MockUI.screenTop,
      body: SafeArea(
        child: petAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(
            child: Text(
              '오류: $e',
              style: const TextStyle(color: DesignTokens.bad),
            ),
          ),
          data: (pet) => _buildContent(pet),
        ),
      ),
    );
  }

  Widget _buildContent(Pet pet) {
    final theme = SpeciesTheme.forType(pet.evolutionType);
    final canEvolve = _canEvolve(pet);
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [MockUI.screenTop, MockUI.screenMid, MockUI.screenBottom],
          stops: [0.0, 0.72, 1.0],
        ),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
            child: MockScreenTop(
              eyebrow: '신화 펫 도감',
              title: '발견한 친구들',
              trailing: MockCoinPill(_dexProgressLabel(pet)),
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              children: [
                _buildFeaturedPet(pet, theme),
                const SizedBox(height: 14),
                const SectionTitle(title: '수집 앨범', trailing: '키우는 펫'),
                _buildCollectionGrid(theme),
                const SizedBox(height: 12),
                MockDisclosureButton(
                  title: '도감 더보기',
                  subtitle: '전적 · 누적 기록 · 계정',
                  expanded: _showDexDetails,
                  onTap: () =>
                      setState(() => _showDexDetails = !_showDexDetails),
                ),
                if (_showDexDetails) ...[
                  const SizedBox(height: 12),
                  _buildBattleStats(pet, theme),
                  const SizedBox(height: 10),
                  _buildLifetimeStats(pet, theme),
                  if (pet.evolutionStage < 4) ...[
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: (_isEvolving || !canEvolve)
                            ? null
                            : _handleEvolve,
                        icon: Icon(
                          _isEvolving
                              ? Icons.hourglass_top
                              : Icons.auto_awesome,
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
                          backgroundColor: theme.primaryDeep,
                          disabledBackgroundColor: theme.primaryDeep.withValues(
                            alpha: 0.35,
                          ),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          elevation: 0,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 14),
                  const SectionTitle(title: '계정'),
                  _buildAccountCard(theme),
                  const SizedBox(height: 18),
                  _buildRestartButton(),
                  if (kDebugMode) ...[
                    const SizedBox(height: 8),
                    _buildDebugGalleryButton(),
                    _buildDebugCheatButton(),
                  ],
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 도감 진행 라벨 — 발현한 종 수 / 전체(코인 필 자리).
  String _dexProgressLabel(Pet pet) {
    final discovered = pet.evolutionType != null ? 1 : 0;
    return '$discovered / 14';
  }

  /// 발견한 펫과 성장 단계별 정보를 한 카드에서 확인한다.
  Widget _buildFeaturedPet(Pet pet, SpeciesTheme theme) {
    final label = SpeciesTheme.labelFor(pet.evolutionType);
    final desc = _speciesBlurb(pet.evolutionType);
    final visibleStage = _visibleDexStage(pet);
    final stages = pet.evolutionType == null ? const [1] : const [2, 3, 4];
    return Column(
      children: [
        Container(
          clipBehavior: Clip.antiAlias,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [MockUI.stageSky, Color(0xFFFFF5DB), MockUI.stageGrass],
              stops: [0.0, 0.66, 1.0],
            ),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: MockUI.line),
          ),
          child: Stack(
            children: [
              Positioned(
                top: 6,
                right: 12,
                child: Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: MockUI.sun,
                    boxShadow: [
                      BoxShadow(
                        color: MockUI.sun.withValues(alpha: 0.35),
                        blurRadius: 16,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                ),
              ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 124,
                    height: 118,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Transform.translate(
                          offset: const Offset(0, 38),
                          child: Container(
                            width: 94,
                            height: 15,
                            decoration: BoxDecoration(
                              color: const Color(0x2A665C47),
                              borderRadius: BorderRadius.circular(999),
                            ),
                          ),
                        ),
                        PetMotionThumb(
                          type: pet.evolutionType,
                          stage: visibleStage,
                          grade: pet.evolutionGrade,
                          variant: colorVariantFor(pet),
                          size: 108,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 13),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          label,
                          style: const TextStyle(
                            fontSize: 23,
                            fontWeight: FontWeight.w800,
                            color: MockUI.ink,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          desc,
                          style: const TextStyle(
                            fontSize: 12,
                            height: 1.5,
                            fontWeight: FontWeight.w700,
                            color: MockUI.softInk,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            for (var i = 0; i < stages.length; i++) ...[
                              if (i > 0) const SizedBox(width: 5),
                              Expanded(
                                child: _stageButton(pet: pet, stage: stages[i]),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        if (_selectedDexStage != null) ...[
          const SizedBox(height: 8),
          _buildStageDetails(pet, visibleStage),
        ],
      ],
    );
  }

  int _visibleDexStage(Pet pet) {
    final minStage = pet.evolutionType == null ? 1 : 2;
    final selected = _selectedDexStage;
    if (selected == null ||
        selected < minStage ||
        selected > pet.evolutionStage) {
      return pet.evolutionStage;
    }
    return selected;
  }

  Widget _stageButton({required Pet pet, required int stage}) {
    final enabled = stage <= pet.evolutionStage;
    final selected = _selectedDexStage == stage;
    return Opacity(
      opacity: enabled ? 1 : 0.42,
      child: Material(
        color: selected ? const Color(0xFFE6F6FF) : Colors.white70,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: enabled
              ? () => setState(() => _selectedDexStage = stage)
              : null,
          child: Container(
            constraints: const BoxConstraints(minHeight: 38),
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: selected ? MockUI.blue : MockUI.actionBorder,
              ),
            ),
            child: Text(
              _stageLabel(stage),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w900,
                color: selected ? MockUI.actionInk : MockUI.softInk,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStageDetails(Pet pet, int stage) {
    final tags = _speciesTags(pet.evolutionType).join(' · ');
    final nextGrowth = stage >= 4
        ? '최종 단계'
        : 'Lv.${_requiredLevelForStage(stage)} 필요';

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: MockUI.actionBorder),
      ),
      child: Column(
        children: [
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: _stageDetailTile(
                    '성격',
                    _speciesBlurb(pet.evolutionType),
                  ),
                ),
                const SizedBox(width: 7),
                Expanded(child: _stageDetailTile('속성', tags)),
              ],
            ),
          ),
          const SizedBox(height: 7),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: _stageDetailTile('성장 단계', _stageLabel(stage))),
                const SizedBox(width: 7),
                Expanded(child: _stageDetailTile('다음 성장', nextGrowth)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _stageDetailTile(String label, String value) {
    return Container(
      constraints: const BoxConstraints(minHeight: 54),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: const Color(0xFFF6F8FB),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.w900,
              color: MockUI.muted,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 10.5,
              height: 1.35,
              fontWeight: FontWeight.w800,
              color: MockUI.ink,
            ),
          ),
        ],
      ),
    );
  }

  String _speciesBlurb(EvolutionType? type) {
    if (type == null) return '아직 종이 정해지지 않은 신비로운 털뭉치.';
    switch (type) {
      case EvolutionType.gumiho:
        return '호기심이 많고 애정 표현이 빠른 불꽃 꼬리 펫.';
      case EvolutionType.samjoko:
        return '태양을 향해 달리는 전설의 세 발 까마귀.';
      case EvolutionType.moonrabbit:
        return '달빛 아래 꿀잠이 특기인 몽글한 친구.';
      case EvolutionType.haetae:
        return '하루도 빠짐없이 곁을 지키는 수호수.';
      case EvolutionType.dokkaebi:
        return '싸움도 장난처럼 즐기는 개구쟁이.';
      case EvolutionType.hwangryong:
        return '무엇 하나 빠짐없는 오방의 중심.';
      case EvolutionType.bear:
        return '느긋하게 내공을 쌓는 인내의 곰.';
      case EvolutionType.otter:
        return '물과 노는 걸 좋아하는 장난꾸러기 정령.';
      case EvolutionType.owl:
        return '밤에 더 또렷해지는 집중의 지혜자.';
      case EvolutionType.crane:
        return '몸과 마음을 정갈히 가꾸는 균형의 선비.';
      case EvolutionType.bird:
        return '신나는 걸 좋아하는 기동형 주작.';
      case EvolutionType.snake:
        return '느긋하고 영리한 마법형 청룡.';
      case EvolutionType.tiger:
        return '몸 쓰는 걸 좋아하는 든든한 백호.';
      case EvolutionType.turtle:
        return '차분하고 묵직한 방어형 현무.';
    }
  }

  List<String> _speciesTags(EvolutionType? type) {
    switch (type) {
      case EvolutionType.bird:
        return ['활발', '자유'];
      case EvolutionType.snake:
        return ['차분', '자유'];
      case EvolutionType.tiger:
        return ['활발', '규칙'];
      case EvolutionType.turtle:
        return ['차분', '규칙'];
      case EvolutionType.samjoko:
        return ['걸음왕', '활발'];
      case EvolutionType.gumiho:
        return ['미식', '민첩'];
      case EvolutionType.moonrabbit:
        return ['꿀잠', '차분'];
      case EvolutionType.haetae:
        return ['개근', '수호'];
      case EvolutionType.dokkaebi:
        return ['싸움꾼', '장난'];
      case EvolutionType.hwangryong:
        return ['균형', '완벽'];
      case EvolutionType.bear:
        return ['인내', '디톡스'];
      case EvolutionType.otter:
        return ['물', '건강'];
      case EvolutionType.owl:
        return ['집중', '지혜'];
      case EvolutionType.crane:
        return ['정갈', '균형'];
      case null:
        return ['미결정'];
    }
  }

  /// 수집 그리드 — 키우는 펫 슬롯(최대 [kMaxPets]). 탭하면 활성 펫 전환,
  /// 빈 슬롯은 새 펫을 키우기 시작한다. (v1: 2마리)
  Widget _buildCollectionGrid(SpeciesTheme theme) {
    final repo = ref.read(petRepositoryProvider);
    return FutureBuilder<List<Pet>>(
      future: repo.getAllPets(),
      builder: (context, snapshot) {
        final byId = {
          for (final p in (snapshot.data ?? const <Pet>[])) p.id: p,
        };
        final activeId = _activePetId;
        return Row(
          children: [
            for (var i = 0; i < kPetSlotIds.length; i++) ...[
              if (i > 0) const SizedBox(width: 10),
              Expanded(
                child: _buildPetSlot(
                  kPetSlotIds[i],
                  byId[kPetSlotIds[i]],
                  activeId,
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  /// 펫 슬롯 카드 — [pet]이 있으면 프로필, 없으면 새 펫 추가 슬롯.
  Widget _buildPetSlot(String slotId, Pet? pet, String activeId) {
    if (pet == null) {
      return GestureDetector(
        onTap: _addSecondPet,
        behavior: HitTestBehavior.opaque,
        child: const _EmptyPetSlot(),
      );
    }
    final slotTheme = SpeciesTheme.forType(pet.evolutionType);
    final isActive = slotId == activeId;
    return GestureDetector(
      onTap: isActive ? null : () => _switchActivePet(slotId),
      behavior: HitTestBehavior.opaque,
      child: Container(
        clipBehavior: Clip.antiAlias,
        padding: const EdgeInsets.fromLTRB(10, 10, 10, 11),
        decoration: BoxDecoration(
          color: isActive ? null : MockUI.cardBg,
          gradient: isActive
              ? LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    MockUI.stageSky,
                    slotTheme.primarySoft,
                    MockUI.cardBg,
                  ],
                )
              : null,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isActive ? slotTheme.primaryDeep : DesignTokens.line,
            width: isActive ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            SizedBox(
              height: 70,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Transform.translate(
                    offset: const Offset(0, 25),
                    child: Container(
                      width: 58,
                      height: 9,
                      decoration: BoxDecoration(
                        color: const Color(0x24665C47),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                  PetMotionThumb(
                    type: pet.evolutionType,
                    stage: pet.evolutionStage,
                    grade: pet.evolutionGrade,
                    variant: colorVariantFor(pet),
                    size: 64,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            Text(
              pet.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: DesignTokens.ink,
              ),
            ),
            Text(
              isActive ? '활성 · Lv.${pet.level}' : 'Lv.${pet.level} · 탭하여 전환',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: isActive ? slotTheme.primaryDeep : DesignTokens.ink3,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 활성 펫 전환 — 홈·케어·배틀이 이 펫으로 바뀐다.
  Future<void> _switchActivePet(String slotId) async {
    await ref.read(activePetIdProvider.notifier).setActive(slotId);
    if (mounted) {
      setState(() {
        _selectedDexStage = null;
        _showDexDetails = false;
      });
    }
  }

  /// 두 번째 펫 키우기 시작 — 생성 후 활성 전환. (로컬 전용, 서버 미동기화)
  Future<void> _addSecondPet() async {
    await ref.read(createDefaultPetUseCaseProvider)(kSecondPetId);
    await ref.read(activePetIdProvider.notifier).setActive(kSecondPetId);
    if (!mounted) return;
    setState(() {
      _selectedDexStage = null;
      _showDexDetails = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('새 펫이 태어났어요! 홈에서 이름을 지어주세요.'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  /// 계정 카드 — 로그인하면 펫이 서버에 저장돼 기기를 바꿔도 유지된다
  ///
  /// 이메일 로그인/가입은 즉시 사용 가능. 카카오/네이버는 서버 검증이
  /// 준비돼 있고 앱 SDK 키 등록 후 활성화한다 (server/README.md 참조).
  Widget _buildAccountCard(SpeciesTheme theme) {
    return AppCard(
      theme: theme,
      variant: AppCardVariant.flat,
      padding: const EdgeInsets.all(14),
      child: AuthSession.isLoggedIn
          ? Row(
              children: [
                Icon(Icons.verified_user, size: 20, color: theme.primaryDeep),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        AuthSession.nickname ?? '',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: DesignTokens.ink,
                        ),
                      ),
                      Text(
                        AuthSession.email ?? '연동됨 · 펫이 서버에 저장돼요',
                        style: const TextStyle(
                          fontSize: 11,
                          color: DesignTokens.ink3,
                        ),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: _handleLogout,
                  child: const Text(
                    '로그아웃',
                    style: TextStyle(fontSize: 12, color: DesignTokens.ink3),
                  ),
                ),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '계정을 연동하면 기기를 바꿔도\n펫·랭킹·전적이 그대로 유지돼요',
                  style: TextStyle(
                    fontSize: 12.5,
                    height: 1.5,
                    color: DesignTokens.ink2,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _showEmailAuthDialog(theme),
                    icon: const Icon(Icons.mail_outline, size: 17),
                    label: const Text('이메일로 로그인 · 가입'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.primaryDeep,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      elevation: 0,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _isKakaoLoading ? null : _handleKakaoLogin,
                    icon: _isKakaoLoading
                        ? const SizedBox(
                            width: 15,
                            height: 15,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.black54,
                            ),
                          )
                        : const Icon(Icons.chat_bubble, size: 16),
                    label: Text(_isKakaoLoading ? '카카오 로그인 중...' : '카카오로 시작하기'),
                    style: ElevatedButton.styleFrom(
                      // 카카오 브랜드 가이드 — 옐로 배경 + 85% 블랙 텍스트
                      backgroundColor: const Color(0xFFFEE500),
                      foregroundColor: const Color(0xD9000000),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      elevation: 0,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  '네이버 로그인은 준비 중이에요',
                  style: TextStyle(fontSize: 11, color: DesignTokens.ink3),
                ),
              ],
            ),
    );
  }

  /// 카카오 로그인 — SDK로 access token 획득 → 서버 검증 → 세션 저장
  Future<void> _handleKakaoLogin() async {
    if (_isKakaoLoading) return;
    setState(() => _isKakaoLoading = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final String? accessToken;
      try {
        accessToken = await _getKakaoAccessToken();
      } on MissingPluginException {
        // 카카오 플러그인 추가 후 풀 리빌드 없이 구 빌드에서 실행한 경우
        messenger.showSnackBar(
          const SnackBar(
            content: Text('앱을 새로 빌드해야 카카오 로그인이 작동해요 (flutter run 재실행)'),
          ),
        );
        return;
      } catch (e) {
        // 콘솔 '카카오 로그인 활성화' OFF, 키 해시 미등록 등 — 원인을 그대로 노출
        if (kDebugMode) debugPrint('kakao login failed: $e');
        messenger.showSnackBar(SnackBar(content: Text('카카오 로그인 실패: $e')));
        return;
      }
      if (accessToken == null) return; // 사용자 취소 — 조용히 종료

      final result = await AuthRemoteDatasource().loginWithKakao(accessToken);
      if (!mounted) return;
      if (!result.isSuccess) {
        messenger.showSnackBar(
          SnackBar(content: Text(result.error ?? '카카오 로그인에 실패했어요')),
        );
        return;
      }

      await AuthSession.save(
        newToken: result.token!,
        newNickname: result.user!.nickname,
        newEmail: result.user!.email,
      );
      if (!mounted) return;
      setState(() {});
      // 서버에 저장된 펫이 있으면 동기화로 끌어온다 (기기 변경 시나리오)
      unawaited(ref.read(petNotifierProvider(_activePetId).notifier).refresh());
      messenger.showSnackBar(
        SnackBar(
          content: Text('${AuthSession.nickname}님, 연동 완료! 펫이 서버에 저장돼요.'),
        ),
      );
    } finally {
      if (mounted) setState(() => _isKakaoLoading = false);
    }
  }

  /// 카카오톡 앱이 있으면 앱 간편 로그인, 없으면 카카오계정 웹 로그인.
  /// 사용자가 취소하면 null. 그 외 실패는 예외를 그대로 던져
  /// [_handleKakaoLogin]이 스낵바로 원인을 보여준다 (무음 실패 금지).
  Future<String?> _getKakaoAccessToken() async {
    if (await kakao.isKakaoTalkInstalled()) {
      try {
        final token = await kakao.UserApi.instance.loginWithKakaoTalk();
        return token.accessToken;
      } on PlatformException catch (e) {
        if (e.code == 'CANCELED') return null;
        // 카카오톡은 있지만 연결 안 된 계정 등 — 웹 로그인으로 폴백
      }
    }
    try {
      final token = await kakao.UserApi.instance.loginWithKakaoAccount();
      return token.accessToken;
    } on PlatformException catch (e) {
      if (e.code == 'CANCELED') return null; // 웹 로그인 창 닫음
      rethrow;
    }
  }

  Future<void> _handleLogout() async {
    await AuthSession.clear();
    if (!mounted) return;
    setState(() {});
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('로그아웃했어요. 펫은 이 기기에 그대로 있어요.')));
  }

  /// 이메일 로그인/가입 다이얼로그 — 성공 시 세션 저장 + 서버 펫 동기화
  Future<void> _showEmailAuthDialog(SpeciesTheme theme) async {
    final emailController = TextEditingController();
    final passwordController = TextEditingController();
    final nicknameController = TextEditingController();
    var isRegisterMode = false;
    var isSubmitting = false;
    String? errorText;

    // 라이트 카드 위 filled 입력 필드 — 앱 카드 스타일과 톤 맞춤
    InputDecoration fieldDecoration(String label, IconData icon) {
      return InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 19, color: DesignTokens.ink3),
        labelStyle: const TextStyle(fontSize: 13, color: DesignTokens.ink3),
        floatingLabelStyle: TextStyle(fontSize: 13, color: theme.primaryDeep),
        filled: true,
        fillColor: DesignTokens.surfaceSoft,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: DesignTokens.line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: theme.primaryDeep, width: 1.4),
        ),
      );
    }

    final success = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          Future<void> submit() async {
            if (isSubmitting) return;
            setDialogState(() {
              isSubmitting = true;
              errorText = null;
            });
            final datasource = AuthRemoteDatasource();
            final result = isRegisterMode
                ? await datasource.register(
                    email: emailController.text.trim(),
                    password: passwordController.text,
                    nickname: nicknameController.text.trim().isEmpty
                        ? null
                        : nicknameController.text.trim(),
                  )
                : await datasource.login(
                    email: emailController.text.trim(),
                    password: passwordController.text,
                  );
            if (!dialogContext.mounted) return;
            if (result.isSuccess) {
              await AuthSession.save(
                newToken: result.token!,
                newNickname: result.user!.nickname,
                newEmail: result.user!.email,
              );
              if (dialogContext.mounted) {
                Navigator.of(dialogContext).pop(true);
              }
            } else {
              setDialogState(() {
                isSubmitting = false;
                errorText = result.error ?? '잠시 후 다시 시도해 주세요';
              });
            }
          }

          return Dialog(
            backgroundColor: DesignTokens.surface,
            insetPadding: const EdgeInsets.symmetric(horizontal: 28),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(22, 22, 22, 14),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: theme.primarySoft,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            isRegisterMode
                                ? Icons.person_add_alt_1
                                : Icons.mail_outline,
                            size: 20,
                            color: theme.primaryDeep,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isRegisterMode ? '이메일로 가입' : '이메일로 로그인',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: DesignTokens.ink,
                                ),
                              ),
                              const SizedBox(height: 2),
                              const Text(
                                '펫·랭킹·전적이 서버에 저장돼요',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  color: DesignTokens.ink3,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    TextField(
                      controller: emailController,
                      enabled: !isSubmitting,
                      keyboardType: TextInputType.emailAddress,
                      autofillHints: const [AutofillHints.email],
                      style: const TextStyle(
                        fontSize: 14,
                        color: DesignTokens.ink,
                      ),
                      decoration: fieldDecoration('이메일', Icons.alternate_email),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: passwordController,
                      enabled: !isSubmitting,
                      obscureText: true,
                      autofillHints: const [AutofillHints.password],
                      onSubmitted: (_) => submit(),
                      style: const TextStyle(
                        fontSize: 14,
                        color: DesignTokens.ink,
                      ),
                      decoration: fieldDecoration(
                        '비밀번호 (6자 이상)',
                        Icons.lock_outline,
                      ),
                    ),
                    if (isRegisterMode) ...[
                      const SizedBox(height: 10),
                      TextField(
                        controller: nicknameController,
                        enabled: !isSubmitting,
                        style: const TextStyle(
                          fontSize: 14,
                          color: DesignTokens.ink,
                        ),
                        decoration: fieldDecoration(
                          '닉네임 (선택)',
                          Icons.emoji_emotions_outlined,
                        ),
                      ),
                    ],
                    if (errorText != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: DesignTokens.bad.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.error_outline,
                              size: 15,
                              color: DesignTokens.bad,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                errorText!,
                                style: const TextStyle(
                                  fontSize: 12,
                                  height: 1.35,
                                  fontWeight: FontWeight.w600,
                                  color: DesignTokens.bad,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 18),
                    ElevatedButton(
                      onPressed: isSubmitting ? null : submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.primaryDeep,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: theme.primaryDeep.withValues(
                          alpha: 0.5,
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        elevation: 0,
                      ),
                      child: isSubmitting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              isRegisterMode ? '가입하기' : '로그인',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                    ),
                    const SizedBox(height: 4),
                    TextButton(
                      onPressed: isSubmitting
                          ? null
                          : () => setDialogState(() {
                              isRegisterMode = !isRegisterMode;
                              errorText = null;
                            }),
                      child: Text(
                        isRegisterMode ? '이미 계정이 있어요 · 로그인' : '처음이에요 · 가입하기',
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: DesignTokens.ink3,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );

    emailController.dispose();
    passwordController.dispose();
    nicknameController.dispose();

    if (success == true && mounted) {
      setState(() {});
      // 서버에 저장된 펫이 있으면 동기화로 끌어온다 (기기 변경 시나리오)
      unawaited(ref.read(petNotifierProvider(_activePetId).notifier).refresh());
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${AuthSession.nickname}님, 연동 완료! 펫이 서버에 저장돼요.'),
        ),
      );
    }
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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
            MaterialPageRoute(builder: (_) => const DebugPixelGalleryScreen()),
          );
        },
        icon: const Icon(Icons.grid_on, size: 16),
        label: const Text('픽셀 갤러리 (디버그)'),
        style: TextButton.styleFrom(foregroundColor: DesignTokens.ink3),
      ),
    );
  }

  /// [디버그 전용] 시나리오 치트 패널 진입 버튼 — 릴리스 전 화면과 함께 삭제
  Widget _buildDebugCheatButton() {
    return SizedBox(
      width: double.infinity,
      child: TextButton.icon(
        onPressed: () {
          Navigator.of(
            context,
          ).push(MaterialPageRoute(builder: (_) => const DebugCheatScreen()));
        },
        icon: const Icon(Icons.tune, size: 16),
        label: const Text('치트 패널 (디버그)'),
        style: TextButton.styleFrom(foregroundColor: DesignTokens.ink3),
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
                  letterSpacing: 0,
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
        color: MockUI.cardBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: MockUI.line),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              color: theme.primaryDeep,
              letterSpacing: 0,
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
      case EvolutionType.samjoko:
        return '삼족오 → 구미호에 강함';
      case EvolutionType.gumiho:
        return '구미호 → 달토끼에 강함';
      case EvolutionType.moonrabbit:
        return '달토끼 → 해태에 강함';
      case EvolutionType.haetae:
        return '해태 → 도깨비에 강함';
      case EvolutionType.dokkaebi:
        return '도깨비 → 황룡에 강함';
      case EvolutionType.hwangryong:
        return '황룡 → 삼족오에 강함';
      case EvolutionType.bear:
        return '곰 → 수달에 강함';
      case EvolutionType.otter:
        return '수달 → 부엉이에 강함';
      case EvolutionType.owl:
        return '부엉이 → 두루미에 강함';
      case EvolutionType.crane:
        return '두루미 → 곰에 강함';
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
                  letterSpacing: 0,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _lifeRow(
            Icons.directions_run,
            '걸음 수',
            _formatNumber(pet.totalSteps),
            '보',
          ),
          // '운동(분)'은 헬스커넥트 운동 세션이 있어야만 쌓여 대부분 0으로
          // 보이는 죽은 표시라 제거 (내부적으로는 행복/진화 축에 계속 반영)
          _lifeRow(
            Icons.bedtime,
            '수면',
            _formatNumber(pet.totalIdleHours),
            '시간',
          ),
          _lifeRow(
            Icons.emoji_events,
            '배틀 승리',
            _formatNumber(pet.battleVictoryCount),
            '회',
          ),
          _lifeRow(
            Icons.local_fire_department,
            '접속 연속',
            _formatNumber(pet.consecutiveLoginDays),
            '일',
          ),
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
}

/// 도감 수집 그리드의 빈 펫 슬롯 — 탭하면 새 펫을 키운다.
class _EmptyPetSlot extends StatelessWidget {
  const _EmptyPetSlot();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 11),
      decoration: BoxDecoration(
        color: MockUI.cardBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: MockUI.line),
      ),
      child: Column(
        children: [
          Container(
            height: 70,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: MockUI.actionBg,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: MockUI.actionBorder),
            ),
            child: Center(
              child: Icon(
                Icons.add_circle_outline,
                size: 30,
                color: MockUI.muted,
              ),
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            '새 펫 키우기',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: MockUI.ink,
            ),
          ),
          const Text(
            '털뭉치부터 시작',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: MockUI.muted,
            ),
          ),
        ],
      ),
    );
  }
}
