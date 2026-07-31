import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/pet_provider.dart';
import '../widgets/app_design.dart';
import '../widgets/pet_motion_thumb.dart';
import '../widgets/pixel_motion_animation.dart';
import '../../core/theme/species_theme.dart';
import '../../core/constants/app_strings.dart';
import '../../domain/entities/battle_history.dart';
import '../../domain/entities/battle_style.dart';
import '../../domain/entities/evolution_type.dart';
import '../../domain/usecases/battle_with_activity_usecase.dart'
    show BattleTurn;
import '../../data/datasources/battle_socket_datasource.dart';
import 'home_screen.dart';

/// 배틀 화면
///
/// - 대기 상태: 내 펫 카드 + 스타일 선택 + 모드 버튼 + 최근 전적
/// - 배틀 중/결과: 다마고치식 풀스크린 아레나 (상단 상대 ↔ 하단 내 펫,
///   중앙 턴 로그/결과 밴드) — 다른 정보는 모두 숨긴다.
class BattleScreen extends ConsumerStatefulWidget {
  const BattleScreen({super.key});

  @override
  ConsumerState<BattleScreen> createState() => _BattleScreenState();
}

class _BattleScreenState extends ConsumerState<BattleScreen> {
  bool? battleResult;
  bool isLoading = false;
  int expGained = 0;

  List<BattleTurn> turns = [];
  int currentTurnIndex = -1;
  int ourPetHp = 100;
  int opponentPetHp = 100;
  int ourMaxHp = 100;
  int opponentMaxHp = 100;

  bool isMatchmaking = false;
  String? opponentName;
  int? opponentLevel;

  /// 상대 종 (AI: 결과에서, 온라인: 매칭 정보에서) — 아레나 스프라이트용
  EvolutionType? _opponentType;
  bool _affinityAdvantage = false;
  bool _affinityDisadvantage = false;

  BattleSocketDatasource? _socket;

  /// 선택된 배틀 스타일 (기본 균형형)
  BattleStyle _battleStyle = BattleStyle.balanced;

  @override
  void dispose() {
    _socket?.disconnect();
    super.dispose();
  }

  static EvolutionType? _parseType(String? name) {
    if (name == null || name.isEmpty) return null;
    for (final t in EvolutionType.values) {
      if (t.name == name) return t;
    }
    return null;
  }

  Future<void> _startOnlineBattle(dynamic pet) async {
    setState(() {
      isLoading = true;
      isMatchmaking = true;
      battleResult = null;
      turns = [];
      currentTurnIndex = -1;
      _opponentType = null;
      _affinityAdvantage = false;
      _affinityDisadvantage = false;
    });

    _socket = BattleSocketDatasource();
    _socket!.onQueued = () {
      if (mounted) setState(() {});
    };
    _socket!.onMatched = (roomId, opponent) {
      if (mounted) {
        setState(() {
          isMatchmaking = false;
          opponentName = opponent['petName'] as String? ?? '???';
          opponentLevel = opponent['level'] as int? ?? 1;
          _opponentType = _parseType(opponent['evolutionType'] as String?);
          ourPetHp = 100;
          opponentPetHp = 100;
        });
      }
    };
    _socket!.onTurn = (turn) {
      if (mounted) {
        setState(() {
          turns.add(turn);
          currentTurnIndex = turns.length - 1;
          ourPetHp = turn.playerHpRemaining;
          opponentPetHp = turn.opponentHpRemaining;
          // 온라인은 최대 HP를 모르므로 관측된 최대치로 분모 보정 (바 넘침 방지)
          if (ourPetHp > ourMaxHp) ourMaxHp = ourPetHp;
          if (opponentPetHp > opponentMaxHp) opponentMaxHp = opponentPetHp;
        });
      }
    };
    _socket!.onResult = (data) {
      if (mounted) {
        setState(() {
          battleResult = data['isVictory'] as bool? ?? false;
          expGained = data['expGained'] as int? ?? 0;
          isLoading = false;
        });
        ref
            .read(petNotifierProvider(HomeScreen.defaultPetId).notifier)
            .refresh();
      }
    };
    _socket!.onTimeout = () {
      if (mounted) {
        setState(() {
          isLoading = false;
          isMatchmaking = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('매칭 시간 초과. 다시 시도해주세요.')),
        );
      }
    };
    _socket!.onOpponentDisconnected = () {
      if (mounted) {
        setState(() {
          battleResult = true;
          expGained = 50;
          isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('상대가 연결을 끊었습니다. 승리!')),
        );
      }
    };

    await _socket!.connect();
    _socket!.joinQueue(
      petName: pet.name ?? '펫',
      level: pet.level ?? 1,
      hunger: pet.hunger ?? 50,
      happiness: pet.happiness ?? 50,
      stamina: pet.stamina ?? 50,
      evolutionStage: pet.evolutionStage ?? 1,
      evolutionType: pet.evolutionType?.name,
      todaySteps: 0,
      todayExerciseMinutes: 0,
    );
  }

  void _cancelOnlineMatch() {
    _socket?.cancelQueue();
    _socket?.disconnect();
    setState(() {
      isLoading = false;
      isMatchmaking = false;
    });
  }

  Future<void> _simulateTurns() async {
    setState(() {
      turns = [];
      currentTurnIndex = -1;
      ourPetHp = 100;
      opponentPetHp = 100;
    });

    try {
      final battleUseCase = ref.read(battleWithActivityUseCaseProvider);
      final result =
          await battleUseCase(HomeScreen.defaultPetId, style: _battleStyle);

      if (result.limitReached) {
        setState(() {
          isLoading = false;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('오늘 배틀 횟수를 모두 사용했습니다 (3/3)')),
          );
        }
        return;
      }

      if (result.turns.isNotEmpty) {
        final oppType = _parseType(result.opponentTypeName);
        setState(() {
          _opponentType = oppType;
          opponentName = '야생의 ${SpeciesTheme.labelFor(oppType)}';
          opponentLevel = result.opponentLevel;
          _affinityAdvantage = result.affinityAdvantage;
          _affinityDisadvantage = result.affinityDisadvantage;
          ourMaxHp = result.playerMaxHp;
          opponentMaxHp = result.opponentMaxHp;
          ourPetHp = result.playerMaxHp;
          opponentPetHp = result.opponentMaxHp;
        });

        for (int i = 0; i < result.turns.length; i++) {
          await Future.delayed(const Duration(milliseconds: 800));
          final turn = result.turns[i];
          if (!mounted) return;
          setState(() {
            turns.add(turn);
            currentTurnIndex = i;
            ourPetHp = turn.playerHpRemaining;
            opponentPetHp = turn.opponentHpRemaining;
          });
        }
      }

      await ref
          .read(petNotifierProvider(HomeScreen.defaultPetId).notifier)
          .refresh();

      setState(() {
        battleResult = result.isVictory;
        expGained = result.expGained;
        isLoading = false;
      });
    } catch (_) {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> _startBattle() async {
    if (isLoading || battleResult != null) return;
    setState(() {
      isLoading = true;
      isMatchmaking = false;
      _opponentType = null;
      _affinityAdvantage = false;
      _affinityDisadvantage = false;
      opponentName = null;
      opponentLevel = null;
    });
    await _simulateTurns();
  }

  void _resetBattle() {
    setState(() {
      battleResult = null;
      expGained = 0;
      turns = [];
      currentTurnIndex = -1;
      _opponentType = null;
      _affinityAdvantage = false;
      _affinityDisadvantage = false;
      opponentName = null;
      opponentLevel = null;
    });
  }

  /// 현재 턴 상황에 따른 내 펫 도트 모션
  ///
  /// - 상대 공격을 피함(피해 0) → dodge
  /// - 주고받은 피해가 크거나 같음 → attack
  /// - 더 큰 피해를 입음 → hurt
  PixelMotion? _myTurnMotion() {
    if (currentTurnIndex < 0 || currentTurnIndex >= turns.length) return null;
    final turn = turns[currentTurnIndex];
    if (turn.opponentDamage == 0) return PixelMotion.dodge;
    if (turn.playerDamage >= turn.opponentDamage) return PixelMotion.attack;
    return PixelMotion.hurt;
  }

  /// 상대 펫 모션 — 내 모션의 미러
  PixelMotion? _opponentTurnMotion() {
    if (currentTurnIndex < 0 || currentTurnIndex >= turns.length) return null;
    final turn = turns[currentTurnIndex];
    if (turn.playerDamage == 0) return PixelMotion.dodge;
    if (turn.opponentDamage >= turn.playerDamage) return PixelMotion.attack;
    return PixelMotion.hurt;
  }

  /// 배틀 진행/결과 중인지 — 이때는 풀스크린 아레나만 보여준다
  bool get _inArena =>
      (isLoading && !isMatchmaking) || battleResult != null;

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
          data: (pet) =>
              _inArena ? _buildBattleArena(pet) : _buildLobby(pet),
        ),
      ),
    );
  }

  // ── 로비 (배틀 전) ─────────────────────────────────────────

  Widget _buildLobby(dynamic pet) {
    final theme = SpeciesTheme.forType(pet.evolutionType);

    return Column(
      children: [
        const ScreenTop(title: '배틀'),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
            children: [
              _buildMyPetCard(pet, theme),
              const SizedBox(height: 10),
              if (!isLoading) ...[
                _buildStyleSelector(theme),
                const SizedBox(height: 10),
                _buildModeButtons(pet, theme),
              ] else if (isMatchmaking)
                _buildMatchingCard(theme),
              const SizedBox(height: 18),
              // 전적 요약(N승 N패)을 섹션 타이틀 우측에 함께 표시
              FutureBuilder<_BattleStats>(
                future: _getBattleStats(),
                builder: (context, snapshot) {
                  final stats = snapshot.data;
                  return SectionTitle(
                    title: '최근 전적',
                    trailing: stats == null
                        ? null
                        : '${stats.victories}승 ${stats.defeats}패',
                  );
                },
              ),
              _buildHistorySection(theme),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMyPetCard(dynamic pet, SpeciesTheme theme) {
    // 도감/실제 전투와 동일한 Pet 전투 스탯 getter 사용 (배틀 스타일 반영)
    final myAtk = (pet.battleAtk * _battleStyle.attackMultiplier).round();
    final myDef = (pet.battleDef * _battleStyle.defenseMultiplier).round();
    final myHp = pet.battleHp as int;

    return AppCard(
      theme: theme,
      // 그라데이션 완화: primary→primaryDeep 강한 대비 대신 절반 톤까지만
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          theme.primary,
          Color.lerp(theme.primary, theme.primaryDeep, 0.5)!,
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '내 펫',
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: Colors.white.withValues(alpha: 0.7),
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  // 밝은 배경 위에 실제 테마색 도트 모션 프레임을 그린다
                  color: Colors.white.withValues(alpha: 0.92),
                  borderRadius: BorderRadius.circular(14),
                ),
                alignment: Alignment.center,
                child: PetMotionThumb(
                  type: pet.evolutionType,
                  stage: pet.evolutionStage,
                  grade: pet.evolutionGrade,
                  variant: colorVariantFor(pet),
                  size: 62,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      pet.name,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      'Lv.${pet.level} · ${SpeciesTheme.labelFor(pet.evolutionType)}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.white.withValues(alpha: 0.85),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        _statBadge('HP', myHp),
                        const SizedBox(width: 10),
                        _statBadge('ATK', myAtk),
                        const SizedBox(width: 10),
                        _statBadge('DEF', myDef),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statBadge(String label, int value) {
    return Text(
      '$label $value',
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: Colors.white,
      ),
    );
  }

  /// 공격형/균형형/방어형 선택 카드
  Widget _buildStyleSelector(SpeciesTheme theme) {
    return AppCard(
      theme: theme,
      variant: AppCardVariant.flat,
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.tune, size: 14, color: theme.primaryDeep),
              const SizedBox(width: 6),
              Text(
                '배틀 스타일',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: theme.primaryDeep,
                  letterSpacing: 0.4,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              for (final s in BattleStyle.values) ...[
                Expanded(child: _styleButton(s, theme)),
                if (s != BattleStyle.values.last) const SizedBox(width: 6),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _styleButton(BattleStyle style, SpeciesTheme theme) {
    final selected = _battleStyle == style;
    final icon = switch (style) {
      BattleStyle.attacker => Icons.flash_on,
      BattleStyle.balanced => Icons.balance,
      BattleStyle.defender => Icons.shield,
    };
    return GestureDetector(
      onTap: () => setState(() => _battleStyle = style),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: selected ? theme.primarySoft : DesignTokens.surfaceSoft,
          borderRadius: BorderRadius.circular(10),
          border: selected
              ? Border.all(color: theme.primary, width: 1.5)
              : Border.all(color: DesignTokens.line, width: 1),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 18,
                color: selected ? theme.primaryDeep : DesignTokens.ink3),
            const SizedBox(height: 4),
            Text(
              style.label,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
                color: selected ? theme.primaryDeep : DesignTokens.ink2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModeButtons(dynamic pet, SpeciesTheme theme) {
    return Row(
      children: [
        Expanded(
          child: _BigButton(
            label: 'AI 대전',
            icon: Icons.smart_toy,
            theme: theme,
            onTap: _startBattle,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _BigButton(
            label: '온라인 대전',
            icon: Icons.wifi,
            theme: theme,
            onTap: () => _startOnlineBattle(pet),
          ),
        ),
      ],
    );
  }

  Widget _buildMatchingCard(SpeciesTheme theme) {
    return AppCard(
      theme: theme,
      variant: AppCardVariant.tinted,
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          CircularProgressIndicator(color: theme.primary),
          const SizedBox(height: 12),
          Text(
            '비슷한 레벨의 상대를 찾고 있어요...',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: theme.primaryDeep,
            ),
          ),
          const SizedBox(height: 16),
          _BigButton(
            label: '취소',
            theme: theme,
            onTap: _cancelOnlineMatch,
          ),
        ],
      ),
    );
  }

  // ── 아레나 (배틀 중 — 다마고치식 상하 2분할 풀스크린) ────────

  Widget _buildBattleArena(dynamic pet) {
    final myTheme = SpeciesTheme.forType(pet.evolutionType);
    final oppTheme = SpeciesTheme.forType(_opponentType);

    return Column(
      children: [
        // 상단: 상대 진영 (정보 위 → 스프라이트 아래, 마주보도록 반전)
        Expanded(
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [oppTheme.gradStart, DesignTokens.bg],
              ),
            ),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                  child: _fighterInfoBar(
                    name: opponentName ?? '상대',
                    level: opponentLevel ?? (pet.level as int),
                    hp: opponentPetHp,
                    maxHp: opponentMaxHp,
                    theme: oppTheme,
                    mine: false,
                  ),
                ),
                Expanded(
                  child: Center(
                    child: _arenaSprite(
                      type: _opponentType,
                      stage: pet.evolutionStage as int,
                      grade: '',
                      variant: 0,
                      theme: oppTheme,
                      motion: _opponentTurnMotion(),
                      size: 140,
                      flip: true,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        // 중앙: 턴 로그 / 결과 밴드
        battleResult == null
            ? _buildTurnBand(myTheme)
            : _buildResultBand(myTheme),
        // 하단: 내 펫 진영 (스프라이트 위 → 정보 아래)
        Expanded(
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [myTheme.gradStart, DesignTokens.bg],
              ),
            ),
            child: Column(
              children: [
                Expanded(
                  child: Center(
                    child: _arenaSprite(
                      type: pet.evolutionType,
                      stage: pet.evolutionStage as int,
                      grade: (pet.evolutionGrade as String?) ?? '',
                      variant: colorVariantFor(pet),
                      theme: myTheme,
                      motion: _myTurnMotion(),
                      size: 160,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
                  child: _fighterInfoBar(
                    name: '${pet.name} (나)',
                    level: pet.level as int,
                    hp: ourPetHp,
                    maxHp: ourMaxHp,
                    theme: myTheme,
                    mine: true,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// 아레나 대형 도트 스프라이트 — 홈과 동일한 등급/개체변이 색 규칙 적용
  Widget _arenaSprite({
    required EvolutionType? type,
    required int stage,
    required String grade,
    required int variant,
    required SpeciesTheme theme,
    required PixelMotion? motion,
    required double size,
    bool flip = false,
  }) {
    final key = motionSpriteKeyForStage(type, stage, grade);
    if (key == null) {
      return Icon(Icons.pets, size: size * 0.5, color: DesignTokens.ink3);
    }
    final (dotColor, accentColor) = dotColorsForKey(key, type, theme, variant);
    final sprite = PixelMotionAnimation(
      spriteKey: key,
      motion: motion ?? PixelMotion.walk,
      duration: const Duration(milliseconds: 600),
      width: size,
      height: size,
      dotColor: dotColor,
      accentColor: accentColor,
    );
    if (!flip) return sprite;
    return Transform.flip(flipX: true, child: sprite);
  }

  /// 이름 + Lv + HP 바 한 줄 (아레나 상/하단 공용)
  Widget _fighterInfoBar({
    required String name,
    required int level,
    required int hp,
    required int maxHp,
    required SpeciesTheme theme,
    required bool mine,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                name,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: DesignTokens.ink,
                ),
              ),
            ),
            Text(
              'Lv.$level',
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: DesignTokens.ink2,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: AppMeter(
                value:
                    maxHp > 0 ? (hp / maxHp * 100).clamp(0.0, 100.0) : 0.0,
                theme: theme,
                tone: mine ? AppMeterTone.themed : AppMeterTone.bad,
                height: 12,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '$hp/$maxHp',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: DesignTokens.ink3,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// 중앙 턴 로그 밴드 — 라운드/상성 + 양측 스킬 한 줄씩
  Widget _buildTurnBand(SpeciesTheme theme) {
    final turn = (currentTurnIndex >= 0 && currentTurnIndex < turns.length)
        ? turns[currentTurnIndex]
        : null;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: const BoxDecoration(
        color: DesignTokens.surface,
        border: Border(
          top: BorderSide(color: DesignTokens.line, width: 1),
          bottom: BorderSide(color: DesignTokens.line, width: 1),
        ),
      ),
      child: turn == null
          ? Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: theme.primary),
                ),
                const SizedBox(width: 10),
                const Text(
                  '전투 시작!',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: DesignTokens.ink2,
                  ),
                ),
              ],
            )
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    AppPill(
                      text: 'R${currentTurnIndex + 1}',
                      theme: theme,
                      variant: AppPillVariant.solid,
                      fontSize: 10,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                    ),
                    if (_affinityAdvantage || _affinityDisadvantage) ...[
                      const SizedBox(width: 6),
                      AppPill(
                        text: _affinityAdvantage ? '상성 유리' : '상성 불리',
                        theme: theme,
                        variant: _affinityAdvantage
                            ? AppPillVariant.themed
                            : AppPillVariant.outline,
                        fontSize: 10,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 6),
                _skillLine(
                  actor: '나',
                  skillName: turn.playerSkillName,
                  damage: turn.playerDamage,
                  color: theme.primaryDeep,
                ),
                const SizedBox(height: 2),
                _skillLine(
                  actor: '상대',
                  skillName: turn.opponentSkillName,
                  damage: turn.opponentDamage,
                  color: DesignTokens.ink2,
                ),
              ],
            ),
    );
  }

  Widget _skillLine({
    required String actor,
    required String skillName,
    required int damage,
    required Color color,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          '$actor: $skillName!',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
        if (damage > 0) ...[
          const SizedBox(width: 6),
          Text(
            '-$damage',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: DesignTokens.bad,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ],
    );
  }

  /// 중앙 결과 밴드 — 승패 + EXP + 버튼 (펫들은 그대로 보이게 유지)
  Widget _buildResultBand(SpeciesTheme theme) {
    final win = battleResult == true;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: const BoxDecoration(
        color: DesignTokens.surface,
        border: Border(
          top: BorderSide(color: DesignTokens.line, width: 1),
          bottom: BorderSide(color: DesignTokens.line, width: 1),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AppPill(
                text: win ? '승리' : '패배',
                theme: theme,
                variant: win ? AppPillVariant.solid : AppPillVariant.dark,
                fontSize: 14,
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
              ),
              const SizedBox(width: 10),
              Text(
                expGained > 0 ? '+$expGained EXP' : '경험치 없음',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: win ? theme.primaryDeep : DesignTokens.ink,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            win ? AppStrings.battleVictory : AppStrings.battleDefeat,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: DesignTokens.ink3,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _BigButton(
                  label: '나가기',
                  theme: theme,
                  onTap: _resetBattle,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _BigButton(
                  label: '한번 더',
                  theme: theme,
                  primary: true,
                  onTap: () {
                    _resetBattle();
                    _startBattle();
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── 전적 ───────────────────────────────────────────────────

  Widget _buildHistorySection(SpeciesTheme theme) {
    return FutureBuilder<List<BattleHistory>>(
      future: _getRecentBattleHistory(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return AppCard(
            theme: theme,
            variant: AppCardVariant.flat,
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: const Center(
              child: Text(
                '아직 전적이 없어요',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: DesignTokens.ink3,
                ),
              ),
            ),
          );
        }
        return Column(
          children: [
            for (final h in snapshot.data!) ...[
              _buildHistoryRow(h, theme),
              const SizedBox(height: 6),
            ],
          ],
        );
      },
    );
  }

  Widget _buildHistoryRow(BattleHistory history, SpeciesTheme theme) {
    return AppListRow(
      theme: theme,
      tinted: false,
      leading: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: history.isVictory
              ? theme.primarySoft
              : DesignTokens.surfaceSoft,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(
          history.isVictory ? Icons.check_circle : Icons.cancel,
          size: 20,
          color: history.isVictory ? theme.primaryDeep : DesignTokens.ink3,
        ),
      ),
      title: history.isVictory ? '승리' : '패배',
      subtitle: '${history.dateString} ${history.timeString} · ${history.steps}보',
      trailing: Text(
        '+${history.expGained} EXP',
        style: TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.w800,
          color: history.isVictory ? theme.primaryDeep : DesignTokens.ink3,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
  }

  Future<_BattleStats> _getBattleStats() async {
    final repository = ref.read(battleHistoryRepositoryProvider);
    final victories = await repository.getVictoryCount();
    final defeats = await repository.getDefeatCount();
    return _BattleStats(victories: victories, defeats: defeats);
  }

  Future<List<BattleHistory>> _getRecentBattleHistory() async {
    final repository = ref.read(battleHistoryRepositoryProvider);
    return repository.getRecentBattleHistory(10);
  }
}

class _BigButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final SpeciesTheme theme;
  final bool primary;
  final VoidCallback? onTap;

  const _BigButton({
    required this.label,
    required this.theme,
    this.icon,
    this.primary = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bg = primary ? theme.primary : DesignTokens.surface;
    final fg = primary ? Colors.white : DesignTokens.ink;
    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: primary
                ? null
                : Border.all(color: DesignTokens.line2, width: 1),
            boxShadow: primary
                ? [
                    BoxShadow(
                      color: theme.primarySoft,
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 18, color: fg),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: fg,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BattleStats {
  final int victories;
  final int defeats;
  _BattleStats({required this.victories, required this.defeats});
}
