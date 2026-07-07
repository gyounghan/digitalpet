import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/pet_provider.dart';
import '../widgets/app_design.dart';
import '../widgets/pixel_pet_image.dart';
import '../widgets/pixel_motion_animation.dart';
import '../../core/theme/species_theme.dart';
import '../../core/constants/app_strings.dart';
import '../../core/utils/pet_image_helper.dart';
import '../../domain/entities/battle_history.dart';
import '../../domain/entities/battle_style.dart';
import '../../domain/usecases/battle_with_activity_usecase.dart'
    show BattleTurn;
import '../../data/datasources/battle_socket_datasource.dart';
import 'home_screen.dart';

/// 배틀 화면 — 프로토타입 디자인 적용
/// 상단 내 펫 카드(deep gradient) + 전적/랭킹 카드 + 액션 버튼 + 최근 전적
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

  bool isOnlineMode = false;
  bool isMatchmaking = false;
  String? opponentName;
  int? opponentLevel;
  BattleSocketDatasource? _socket;

  /// 선택된 배틀 스타일 (기본 균형형)
  BattleStyle _battleStyle = BattleStyle.balanced;

  @override
  void dispose() {
    _socket?.disconnect();
    super.dispose();
  }

  Future<void> _startOnlineBattle(dynamic pet) async {
    setState(() {
      isLoading = true;
      isMatchmaking = true;
      battleResult = null;
      turns = [];
      currentTurnIndex = -1;
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
        setState(() {
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
    });
    await _simulateTurns();
  }

  void _resetBattle() {
    setState(() {
      battleResult = null;
      expGained = 0;
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

  Widget _buildContent(dynamic pet) {
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
              _buildStatsAndRanking(pet, theme),
              const SizedBox(height: 10),
              if (battleResult == null) ...[
                if (!isLoading) ...[
                  _buildStyleSelector(theme),
                  const SizedBox(height: 10),
                  _buildModeButtons(pet, theme),
                ] else if (isMatchmaking)
                  _buildMatchingCard(theme)
                else
                  _buildArenaCard(pet, theme),
              ] else
                _buildResultCard(theme),
              const SizedBox(height: 18),
              const SectionTitle(title: '최근 전적'),
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
    final imagePath = getEvolutionImagePath(pet.evolutionType, pet.evolutionStage);

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
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(14),
                ),
                alignment: Alignment.center,
                child: imagePath != null
                    // 컬러 그라데이션 배경 위라 흰 몸통 도트가 잘 보인다
                    ? PixelPetImage(
                        assetPath: imagePath,
                        width: 60,
                        height: 60,
                        dotColor: Colors.white.withValues(alpha: 0.95),
                      )
                    : const Icon(Icons.pets, size: 40, color: Colors.white),
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

  Widget _buildStatsAndRanking(dynamic pet, SpeciesTheme theme) {
    return Row(
      children: [
        Expanded(
          child: FutureBuilder<_BattleStats>(
            future: _getBattleStats(),
            builder: (context, snapshot) {
              final stats = snapshot.data;
              return AppCard(
                theme: theme,
                variant: AppCardVariant.flat,
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '전적',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: DesignTokens.ink3,
                        letterSpacing: 0.6,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      stats == null
                          ? '— —'
                          : '${stats.victories}승 ${stats.defeats}패',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: DesignTokens.ink,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: AppCard(
            theme: theme,
            variant: AppCardVariant.flat,
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '랭킹',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: DesignTokens.ink3,
                    letterSpacing: 0.6,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '#${(1000 - pet.level * 5 - pet.battleVictoryCount * 2).clamp(4, 999)}'
                  ' · ${(pet.level * 100 + pet.battleVictoryCount * 30)}RP',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: DesignTokens.ink,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
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
              const Spacer(),
              Text(
                _battleStyle.description,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: DesignTokens.ink3,
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
            primary: true,
            onTap: () {
              setState(() => isOnlineMode = false);
              _startBattle();
            },
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _BigButton(
            label: '온라인 대전',
            icon: Icons.wifi,
            theme: theme,
            onTap: () {
              setState(() => isOnlineMode = true);
              _startOnlineBattle(pet);
            },
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

  Widget _buildArenaCard(dynamic pet, SpeciesTheme theme) {
    return AppCard(
      theme: theme,
      variant: AppCardVariant.flat,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (currentTurnIndex >= 0)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: AppPill(
                text: 'R${(currentTurnIndex + 1)}',
                theme: theme,
                variant: AppPillVariant.solid,
              ),
            ),
          _FighterRow(
            name: '${pet.name} (나)',
            level: pet.level,
            hp: ourPetHp,
            maxHp: ourMaxHp,
            imagePath:
                getEvolutionImagePath(pet.evolutionType, pet.evolutionStage),
            mine: true,
            theme: theme,
            motion: _myTurnMotion(),
          ),
          const SizedBox(height: 8),
          _FighterRow(
            name: opponentName ?? '상대',
            level: opponentLevel ?? pet.level,
            hp: opponentPetHp,
            maxHp: opponentMaxHp,
            imagePath: null,
            mine: false,
            theme: theme,
          ),
          if (currentTurnIndex >= 0 && currentTurnIndex < turns.length) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: theme.primarySoft,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${pet.name}: ${turns[currentTurnIndex].playerSkillName}!',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: theme.primaryDeep,
                    ),
                  ),
                  if (turns[currentTurnIndex].playerDamage > 0)
                    Text(
                      '→ -${turns[currentTurnIndex].playerDamage} 대미지!',
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: DesignTokens.bad,
                      ),
                    ),
                  const SizedBox(height: 4),
                  Text(
                    '상대: ${turns[currentTurnIndex].opponentSkillName}!',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: DesignTokens.ink2,
                    ),
                  ),
                  if (turns[currentTurnIndex].opponentDamage > 0)
                    Text(
                      '→ -${turns[currentTurnIndex].opponentDamage} 대미지!',
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: DesignTokens.bad,
                      ),
                    ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
          Center(
            child: CircularProgressIndicator(color: theme.primary),
          ),
        ],
      ),
    );
  }

  Widget _buildResultCard(SpeciesTheme theme) {
    final win = battleResult == true;
    return Column(
      children: [
        Center(
          child: AppPill(
            text: win ? '승리' : '패배',
            theme: theme,
            variant: win ? AppPillVariant.solid : AppPillVariant.dark,
            fontSize: 14,
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          win ? '+$expGained EXP' : '경험치 없음',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w900,
            color: win ? theme.primaryDeep : DesignTokens.ink,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
        const SizedBox(height: 4),
        Text(
          win ? AppStrings.battleVictory : AppStrings.battleDefeat,
          style: const TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: DesignTokens.ink3,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _BigButton(
                label: '홈으로',
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
    );
  }

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
    final total = await repository.getTotalBattleCount();
    final victories = await repository.getVictoryCount();
    final defeats = await repository.getDefeatCount();
    return _BattleStats(
        total: total, victories: victories, defeats: defeats);
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

class _FighterRow extends StatelessWidget {
  final String name;
  final int level;
  final int hp;
  final int maxHp;
  final String? imagePath;
  final bool mine;
  final SpeciesTheme theme;

  /// 턴 진행 중 재생할 도트 모션 (베이비 스프라이트일 때만 적용)
  final PixelMotion? motion;

  const _FighterRow({
    required this.name,
    required this.level,
    required this.hp,
    required this.maxHp,
    required this.theme,
    required this.imagePath,
    this.mine = false,
    this.motion,
  });

  /// 파이터 아이콘 — 모션 데이터가 있는 스프라이트면 도트 모션, 아니면 정적 도트
  Widget _buildSprite() {
    final path = imagePath;
    if (path == null) {
      return const Icon(Icons.pets, color: DesignTokens.ink3);
    }
    final spriteKey = motionSpriteKeyFromAssetPath(path);
    if (spriteKey != null && motion != null) {
      final isFluff = spriteKey == 'fluff';
      return Padding(
        padding: const EdgeInsets.all(3),
        child: PixelMotionAnimation(
          spriteKey: spriteKey,
          motion: motion!,
          duration: const Duration(milliseconds: 600),
          dotColor: isFluff ? SpeciesTheme.fluffBody : theme.primary,
          accentColor: isFluff ? SpeciesTheme.fluffBody : theme.spriteAccent,
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.all(3),
      child: PixelPetImage(
        assetPath: path,
        dotColor: theme.primary,
        accentColor: theme.spriteAccent,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: DesignTokens.surfaceSoft,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(11),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: _buildSprite(),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        name,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: DesignTokens.ink,
                        ),
                      ),
                    ),
                    Text(
                      'Lv.$level',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: DesignTokens.ink2,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                AppMeter(
                  value: maxHp > 0
                      ? (hp / maxHp * 100).clamp(0.0, 100.0)
                      : 0.0,
                  theme: theme,
                  tone: mine ? AppMeterTone.themed : AppMeterTone.bad,
                  height: 10,
                ),
                const SizedBox(height: 2),
                Text(
                  'HP $hp/$maxHp',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: DesignTokens.ink3,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BattleStats {
  final int total;
  final int victories;
  final int defeats;
  _BattleStats({
    required this.total,
    required this.victories,
    required this.defeats,
  });
}
