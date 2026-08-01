import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/pet_provider.dart';
import '../widgets/app_design.dart';
import '../widgets/pet_motion_thumb.dart';
import '../widgets/pixel_motion_animation.dart';
import '../widgets/pixel_pet_image.dart';
import '../../core/pixel/pet_pixel_data.dart';
import '../../core/pixel/skill_effect_data.dart';
import '../../core/theme/species_theme.dart';
import '../../core/constants/app_strings.dart';
import '../../core/constants/feature_flags.dart';
import '../../domain/entities/battle_history.dart';
import '../../domain/entities/battle_style.dart';
import '../../domain/entities/evolution_type.dart';
import '../../domain/entities/pet.dart';
import '../../domain/usecases/battle_result_narrator.dart';
import '../../domain/usecases/battle_with_activity_usecase.dart'
    show BattleTurn, BattleWithActivityUseCase;
import '../../data/datasources/battle_socket_datasource.dart';
import 'home_screen.dart';

/// 배틀 화면
///
/// - 대기 상태: 내 펫 카드(단색 deep) + 스타일 선택 + 모드 버튼 + 최근 전적
///   (전적 요약은 최근 전적 섹션 타이틀에 표시 — 별도 카드 없음)
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

  /// 결과 카드 해설 — 승패보다 "오늘의 활동이 어떻게 기여했는지"를 보여준다
  BattleNarration? narration;

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

  /// 턴 내 액션 박자 — 0: 내 공격, 1: 상대 반격, -1: 동시 표시(온라인)
  int _actionPhase = -1;

  /// 친구 대전(방 코드) 모드 여부 / 생성된 초대 코드
  bool isFriendMode = false;
  String? friendRoomCode;

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

  /// 소켓 기반 대전 시작 — 온라인 매칭 / 친구방 생성 / 코드 참가 공용
  ///
  /// [friendRoom] true면 방을 만들어 초대 코드를 받고,
  /// [joinCode]가 있으면 해당 방에 참가한다. 둘 다 없으면 랜덤 매칭.
  Future<void> _startOnlineBattle(
    Pet pet, {
    bool friendRoom = false,
    String? joinCode,
  }) async {
    // 매칭 대기/진행 중 재진입 차단 (빠른 더블탭 시 소켓 중복 큐잉 방지)
    if (isLoading || isMatchmaking) return;

    // 긴 잠에 빠진 펫은 배틀 불가
    if (pet.isDead) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('펫이 깊은 잠에 빠져 있어요. 깨운 뒤 다시 시도해주세요.')),
      );
      return;
    }

    // AI 대전과 동일한 하루 배틀 횟수 제한 (자정 리셋 반영)
    final effectiveBattleCount = pet.needsGoalReset ? 0 : pet.todayBattleCount;
    if (effectiveBattleCount >= BattleWithActivityUseCase.maxBattlesPerDay) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('오늘 배틀 횟수를 모두 사용했습니다 (3/3)')),
      );
      return;
    }

    setState(() {
      isLoading = true;
      isMatchmaking = true;
      isFriendMode = friendRoom || joinCode != null;
      friendRoomCode = null;
      battleResult = null;
      turns = [];
      currentTurnIndex = -1;
      _actionPhase = -1;
      _opponentType = null;
      _affinityAdvantage = false;
      _affinityDisadvantage = false;
    });

    // 실전 스탯 = 도감 스탯 × 배틀 스타일 배수 (AI 대전과 동일 공식)
    final styledAtk = (pet.battleAtk * _battleStyle.attackMultiplier).round();
    final styledDef = (pet.battleDef * _battleStyle.defenseMultiplier).round();
    final maxHp = pet.battleHp;
    final deviceId =
        await ref.read(deviceIdDatasourceProvider).getOrCreateDeviceId();

    _socket = BattleSocketDatasource();
    _socket!.onQueued = () {
      if (mounted) setState(() {});
    };
    _socket!.onRoomCreated = (roomCode) {
      if (mounted) setState(() => friendRoomCode = roomCode);
    };
    _socket!.onRoomError = (message) {
      if (mounted) {
        _cancelOnlineMatch();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
      }
    };
    _socket!.onMatched = (roomId, opponent) {
      if (mounted) {
        setState(() {
          isMatchmaking = false;
          friendRoomCode = null;
          opponentName = opponent['petName'] as String? ?? '???';
          opponentLevel = opponent['level'] as int? ?? 1;
          _opponentType = _parseType(opponent['evolutionType'] as String?);
          ourMaxHp = maxHp;
          ourPetHp = maxHp;
          opponentMaxHp = opponent['maxHp'] as int? ?? 100;
          opponentPetHp = opponentMaxHp;
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
          // 구버전 서버가 maxHp를 안 내려주는 경우 관측치로 분모 보정
          if (ourPetHp > ourMaxHp) ourMaxHp = ourPetHp;
          if (opponentPetHp > opponentMaxHp) opponentMaxHp = opponentPetHp;
        });
      }
    };
    _socket!.onResult = (data) async {
      // 이미 결과가 처리됐다면 무시 (이탈 보상 후 result 도착 시 이중 보상 방지)
      if (battleResult != null) return;
      final isVictory = data['isVictory'] as bool? ?? false;
      final isDominant = data['isDominantVictory'] as bool? ?? false;
      // 서버 expGained는 기본 경험치 — 감쇠/이벤트 배수는 로컬에서 적용
      final reward = await ref.read(applyOnlineBattleRewardUseCaseProvider)(
        HomeScreen.defaultPetId,
        isVictory: isVictory,
        isDominantVictory: isDominant,
        baseExp: data['expGained'] as int?,
      );
      if (mounted) {
        setState(() {
          battleResult = isVictory;
          expGained = reward.expGained;
          narration = BattleResultNarrator.narrate(
            isVictory: isVictory,
            isDominantVictory: isDominant,
            playerHpRemaining: ourPetHp,
            playerMaxHp: ourMaxHp,
            hunger: pet.hunger,
            happiness: pet.happiness,
            stamina: pet.stamina,
            todaySteps: pet.todaySyncedSteps,
          );
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
    _socket!.onOpponentDisconnected = () async {
      // 결과 처리 후 도착한 이탈 이벤트는 무시 (이중 보상 방지)
      if (battleResult != null) return;
      final reward = await ref.read(applyOnlineBattleRewardUseCaseProvider)(
        HomeScreen.defaultPetId,
        isVictory: true,
        isDominantVictory: false,
      );
      if (mounted) {
        setState(() {
          battleResult = true;
          expGained = reward.expGained;
          isLoading = false;
          isMatchmaking = false;
        });
        // 몰수승 보상은 위에서 applyOnlineBattleRewardUseCase가 로컬 지급 —
        // 여기서는 갱신된 펫 상태만 다시 읽는다
        ref
            .read(petNotifierProvider(HomeScreen.defaultPetId).notifier)
            .refresh();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('상대가 연결을 끊었습니다. 승리!')),
        );
      }
    };

    await _socket!.connect();

    // 서버 미기동/주소 오류 시 무한 대기 방지 — 6초 내 연결 실패면 안내 후 종료
    Future.delayed(const Duration(seconds: 6), () {
      if (!mounted) return;
      if (isMatchmaking && !(_socket?.isConnected ?? false)) {
        _cancelOnlineMatch();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('서버에 연결할 수 없습니다. 잠시 후 다시 시도해주세요.')),
        );
      }
    });

    if (joinCode != null) {
      _socket!.joinRoom(
        roomCode: joinCode,
        deviceId: deviceId,
        petName: pet.name,
        level: pet.level,
        evolutionStage: pet.evolutionStage,
        evolutionType: pet.evolutionType?.name,
        atk: styledAtk,
        def: styledDef,
        hp: maxHp,
        todaySteps: pet.todaySyncedSteps,
      );
    } else if (friendRoom) {
      _socket!.createRoom(
        deviceId: deviceId,
        petName: pet.name,
        level: pet.level,
        evolutionStage: pet.evolutionStage,
        evolutionType: pet.evolutionType?.name,
        atk: styledAtk,
        def: styledDef,
        hp: maxHp,
        todaySteps: pet.todaySyncedSteps,
      );
    } else {
      _socket!.joinQueue(
        deviceId: deviceId,
        petName: pet.name,
        level: pet.level,
        evolutionStage: pet.evolutionStage,
        evolutionType: pet.evolutionType?.name,
        atk: styledAtk,
        def: styledDef,
        hp: maxHp,
        todaySteps: pet.todaySyncedSteps,
      );
    }
  }

  void _cancelOnlineMatch() {
    if (isFriendMode) _socket?.leaveRoom();
    _socket?.cancelQueue();
    _socket?.disconnect();
    setState(() {
      isLoading = false;
      isMatchmaking = false;
      isFriendMode = false;
      friendRoomCode = null;
    });
  }

  /// 초대 코드 입력 다이얼로그 → 친구 방 참가
  void _showJoinRoomDialog(Pet pet) {
    final controller = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: DesignTokens.surface,
          title: const Text(
            '초대 코드로 참가',
            style: TextStyle(
                color: DesignTokens.ink, fontWeight: FontWeight.w800),
          ),
          content: TextField(
            controller: controller,
            autofocus: true,
            textCapitalization: TextCapitalization.characters,
            decoration: InputDecoration(
              hintText: '친구에게 받은 코드 입력',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('취소'),
            ),
            TextButton(
              onPressed: () {
                final code = controller.text.trim().toUpperCase();
                Navigator.of(dialogContext).pop();
                if (code.isNotEmpty) {
                  _startOnlineBattle(pet, joinCode: code);
                }
              },
              child: const Text('참가'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _simulateTurns() async {
    setState(() {
      turns = [];
      currentTurnIndex = -1;
      ourPetHp = 100;
      opponentPetHp = 100;
    });

    try {
      // 해설용 전투 시점 컨디션 (보상 반영 전 스탯)
      final prePet =
          ref.read(petNotifierProvider(HomeScreen.defaultPetId)).valueOrNull;
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
          await Future.delayed(const Duration(milliseconds: 500));
          final turn = result.turns[i];
          if (!mounted) return;
          // 1박자: 내 공격 — 상대 HP만 깎이고 상대 피격 연출
          setState(() {
            turns.add(turn);
            currentTurnIndex = i;
            _actionPhase = 0;
            opponentPetHp = turn.opponentHpRemaining;
          });
          await Future.delayed(const Duration(milliseconds: 900));
          if (!mounted) return;
          // 2박자: 상대 반격 (상대가 이미 KO면 생략 — 회피로 데미지 0인 건 진행)
          if (turn.opponentHpRemaining > 0) {
            setState(() {
              _actionPhase = 1;
              ourPetHp = turn.playerHpRemaining;
            });
            await Future.delayed(const Duration(milliseconds: 900));
            if (!mounted) return;
          } else {
            setState(() => ourPetHp = turn.playerHpRemaining);
          }
        }
      }

      await ref
          .read(petNotifierProvider(HomeScreen.defaultPetId).notifier)
          .refresh();

      setState(() {
        battleResult = result.isVictory;
        expGained = result.expGained;
        narration = BattleResultNarrator.narrate(
          isVictory: result.isVictory,
          isDominantVictory: result.isDominantVictory,
          playerHpRemaining: result.turns.isNotEmpty
              ? result.turns.last.playerHpRemaining
              : result.playerMaxHp,
          playerMaxHp: result.playerMaxHp,
          hunger: prePet?.hunger ?? 50,
          happiness: prePet?.happiness ?? 50,
          stamina: prePet?.stamina ?? 50,
          todaySteps: prePet?.todaySyncedSteps ?? 0,
          affinityAdvantage: result.affinityAdvantage,
        );
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

    // 죽은 펫은 배틀 불가 (UseCase의 빈 결과 카드로 오해하지 않도록 사전 차단)
    final pet =
        ref.read(petNotifierProvider(HomeScreen.defaultPetId)).valueOrNull;
    if (pet != null && pet.isDead) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('펫이 깊은 잠에 빠져 있어요. 깨운 뒤 다시 시도해주세요.')),
      );
      return;
    }

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
      narration = null;
      turns = [];
      currentTurnIndex = -1;
      _actionPhase = -1;
      _opponentType = null;
      _affinityAdvantage = false;
      _affinityDisadvantage = false;
      opponentName = null;
      opponentLevel = null;
    });
  }

  /// 내 펫 도트 모션
  ///
  /// - 결과 확정: 승리 → joy(웃음), 패배 → hurt(쓰러짐)
  /// - 내 공격 박자(phase 0): attack / 상대 반격 박자(phase 1): hurt
  /// - 온라인(phase -1, 동시 표시): 피해 비교로 attack/hurt/dodge
  PixelMotion? _myTurnMotion() {
    if (battleResult != null) {
      return battleResult! ? PixelMotion.joy : PixelMotion.hurt;
    }
    if (currentTurnIndex < 0 || currentTurnIndex >= turns.length) return null;
    final turn = turns[currentTurnIndex];
    if (_actionPhase == 0) return PixelMotion.attack;
    if (_actionPhase == 1) {
      // 상대 공격이 빗나갔으면(데미지 0) 피하기, 아니면 아파하기
      return turn.opponentDamage == 0 ? PixelMotion.dodge : PixelMotion.hurt;
    }
    if (turn.opponentDamage == 0) return PixelMotion.dodge;
    if (turn.playerDamage >= turn.opponentDamage) return PixelMotion.attack;
    return PixelMotion.hurt;
  }

  /// 상대 펫 모션 — 내 모션의 미러 (결과 시 승패 반대)
  PixelMotion? _opponentTurnMotion() {
    if (battleResult != null) {
      return battleResult! ? PixelMotion.hurt : PixelMotion.joy;
    }
    if (currentTurnIndex < 0 || currentTurnIndex >= turns.length) return null;
    final turn = turns[currentTurnIndex];
    if (_actionPhase == 0) {
      // 내 공격이 빗나갔으면(데미지 0) 상대가 피하기, 아니면 아파하기
      return turn.playerDamage == 0 ? PixelMotion.dodge : PixelMotion.hurt;
    }
    if (_actionPhase == 1) return PixelMotion.attack;
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
      // 단색(primary) — 그라데이션 없이 종 테마색 그대로
      variant: AppCardVariant.deep,
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
                        const SizedBox(width: 10),
                        // 회피율 — 오늘 걸음수 연동 (많이 걸을수록 민첩)
                        Text(
                          '회피 ${(BattleWithActivityUseCase.dodgeChanceForSteps(pet.todaySyncedSteps as int? ?? 0) * 100).round()}%',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
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
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _BigButton(
                label: 'AI 대전',
                icon: Icons.smart_toy,
                theme: theme,
                onTap: _startBattle,
              ),
            ),
            // 실시간 온라인 대련은 MVP에서 숨김 (FeatureFlags 참조)
            if (FeatureFlags.enableRealtimeBattle) ...[
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
          ],
        ),
        // 친구 대전은 매칭 풀이 필요 없으므로 플래그와 무관하게 노출
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _BigButton(
                label: '친구방 만들기',
                icon: Icons.group_add,
                theme: theme,
                onTap: () => _startOnlineBattle(pet, friendRoom: true),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _BigButton(
                label: '코드로 참가',
                icon: Icons.pin,
                theme: theme,
                onTap: () => _showJoinRoomDialog(pet),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMatchingCard(SpeciesTheme theme) {
    final code = friendRoomCode;
    return AppCard(
      theme: theme,
      variant: AppCardVariant.tinted,
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          if (code != null) ...[
            // 방 생성 완료 — 초대 코드를 크게 보여주고 복사 지원
            Text(
              '초대 코드',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: theme.primaryDeep,
              ),
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  code,
                  style: const TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 4,
                    color: DesignTokens.ink,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: Icon(Icons.copy, size: 20, color: theme.primaryDeep),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: code));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('초대 코드를 복사했어요')),
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 6),
            const Text(
              '친구가 "코드로 참가"에 이 코드를 입력하면 시작돼요',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: DesignTokens.ink3,
              ),
            ),
          ] else ...[
            CircularProgressIndicator(color: theme.primary),
            const SizedBox(height: 12),
            Text(
              isFriendMode ? '방에 연결하는 중...' : '비슷한 레벨의 상대를 찾고 있어요...',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: theme.primaryDeep,
              ),
            ),
          ],
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
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        _arenaSprite(
                          type: _opponentType,
                          stage: pet.evolutionStage as int,
                          grade: '',
                          variant: 0,
                          theme: oppTheme,
                          motion: _opponentTurnMotion(),
                          size: 140,
                          flip: true,
                        ),
                        ..._panelEffectOverlay(
                            minePanel: false,
                            ownTheme: oppTheme,
                            attackerTheme: myTheme,
                            size: 120),
                      ],
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
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        _arenaSprite(
                          type: pet.evolutionType,
                          stage: pet.evolutionStage as int,
                          grade: (pet.evolutionGrade as String?) ?? '',
                          variant: colorVariantFor(pet),
                          theme: myTheme,
                          motion: _myTurnMotion(),
                          size: 160,
                        ),
                        ..._panelEffectOverlay(
                            minePanel: true,
                            ownTheme: myTheme,
                            attackerTheme: oppTheme,
                            size: 135),
                      ],
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

  /// 현재 박자에 이 패널 위에 얹을 스킬 이펙트 (0~1개)
  ///
  /// 투사체 방향은 캐릭터가 바라보는 방향을 따른다
  /// (위 캐릭은 오른쪽을, 아래 캐릭은 왼쪽을 봄):
  /// - 위 캐릭 공격: 위 패널에서 오른쪽으로 나감 / 아래 패널로 왼쪽에서 날아옴
  /// - 아래 캐릭 공격: 아래 패널에서 왼쪽으로 나감 / 위 패널로 오른쪽에서 날아옴
  /// 즉 공격 박자마다 공격자 패널(나감)·피격자 패널(들어옴) 양쪽에 표시된다.
  /// 방어자세는 시전자 자신 패널에 방패 (제자리).
  /// phase -1(온라인 동시)은 피격자 패널의 들어오는 투사체만.
  List<Widget> _panelEffectOverlay({
    required bool minePanel,
    required SpeciesTheme ownTheme,
    required SpeciesTheme attackerTheme,
    required double size,
  }) {
    if (currentTurnIndex < 0 || currentTurnIndex >= turns.length) return [];
    final turn = turns[currentTurnIndex];
    final ownSkill = minePanel ? turn.playerSkillName : turn.opponentSkillName;
    final incoming = minePanel ? turn.opponentSkillName : turn.playerSkillName;

    // 이 박자에 액션 중인 쪽: phase 0 = 나(아래), phase 1 = 상대(위)
    final actorIsMe = _actionPhase == 0;
    final panelIsActor = minePanel == actorIsMe;

    // 이동 범위를 크게 — 나가는 투사체는 화면 밖으로 멀리 날아가고,
    // 들어오는 투사체는 바깥 멀리서 날아와 캐릭터 "가장자리"에서 멈춘다
    // (몸에 닿으면 사라져야 하므로 중앙까지 오지 않음 — 끝에서 페이드아웃).
    // 위 패널: 오른쪽 방향 / 아래 패널: 왼쪽 방향.
    final dir = minePanel ? -1.0 : 1.0;
    final incomingBegin = dir * size * 1.8;
    final incomingEnd = dir * size * 0.55;
    final outgoingBegin = dir * size * 0.25;
    final outgoingEnd = dir * size * 1.9;

    List<PixelSprite>? frames;
    SpeciesTheme effectTheme;
    double beginDx = 0;
    double endDx = 0;
    if (_actionPhase >= 0) {
      final actingSkill = actorIsMe ? turn.playerSkillName : turn.opponentSkillName;
      frames = skillEffectForSkillName(actingSkill);
      if (isSelfSkillEffect(actingSkill)) {
        // 방어자세 — 시전자 자신 패널에 제자리 방패
        if (!panelIsActor) return [];
        effectTheme = ownTheme;
      } else if (panelIsActor) {
        // 공격자 패널 — 캐릭터 가장자리에서 바라보는 방향으로 멀리 날아나감
        effectTheme = ownTheme;
        beginDx = outgoingBegin;
        endDx = outgoingEnd;
      } else {
        // 피격자 패널 — 바깥 멀리서 날아와 캐릭터 가장자리에서 멈춤
        effectTheme = attackerTheme;
        beginDx = incomingBegin;
        endDx = incomingEnd;
      }
    } else {
      // 온라인 동시 표시 — 피격자 패널의 들어오는 투사체만
      if (isSelfSkillEffect(ownSkill)) {
        frames = skillEffectForSkillName(ownSkill);
        effectTheme = ownTheme;
      } else if (!isSelfSkillEffect(incoming)) {
        frames = skillEffectForSkillName(incoming);
        effectTheme = attackerTheme;
        beginDx = incomingBegin;
        endDx = incomingEnd;
      } else {
        return [];
      }
    }
    if (frames == null) return [];
    return [
      _SkillEffectBurst(
        // 턴·박자마다 새 키 → 이펙트 재생을 처음부터 다시 시작
        key: ValueKey('fx-$minePanel-$currentTurnIndex-$_actionPhase'),
        frames: frames,
        size: size,
        dotColor: effectTheme.primaryDeep,
        slideBeginDx: beginDx,
        slideEndDx: endDx,
      ),
    ];
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
                // 박자별로 액션 중인 쪽 한 줄만 (온라인 phase -1은 둘 다)
                if (_actionPhase != 1)
                  _skillLine(
                    actor: '나',
                    skillName: turn.playerSkillName,
                    damage: turn.playerDamage,
                    color: theme.primaryDeep,
                  ),
                if (_actionPhase == -1) const SizedBox(height: 2),
                if (_actionPhase != 0)
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
        const SizedBox(width: 6),
        if (damage > 0)
          Text(
            '-$damage',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: DesignTokens.bad,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          )
        else
          const Text(
            '빗나감!',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: DesignTokens.ink3,
            ),
          ),
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
          // 성장 확인 해설 — 승패 문구 대신 오늘의 활동이 어떻게 기여했는지
          Text(
            narration?.headline ??
                (win ? AppStrings.battleVictory : AppStrings.battleDefeat),
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: DesignTokens.ink3,
            ),
          ),
          if (narration != null && narration!.lines.isNotEmpty) ...[
            const SizedBox(height: 10),
            for (final line in narration!.lines) ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.chat_bubble_outline,
                      size: 13, color: theme.primaryDeep),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      line,
                      style: const TextStyle(
                        fontSize: 12,
                        height: 1.45,
                        fontWeight: FontWeight.w600,
                        color: DesignTokens.ink2,
                      ),
                    ),
                  ),
                ],
              ),
              if (line != narration!.lines.last) const SizedBox(height: 6),
            ],
          ],
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
    // 주요 버튼은 primaryDeep — primary는 종에 따라(특히 현무 라임색) 흰 글자
    // 대비가 부족하다. 글로우 그림자는 흰 서피스 위에서 얼룩처럼 보여 제거.
    final bg = primary ? theme.primaryDeep : DesignTokens.surface;
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
            // primary 버튼은 글로우 없이 순수 단색 플랫으로 둔다
            border: primary
                ? null
                : Border.all(color: DesignTokens.line2, width: 1),
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

/// 스킬 이펙트 1회 재생 — 3프레임을 순서대로 보여주고 마지막 프레임에서 정지.
/// slideBeginDx→slideEndDx로 가로 슬라이드하며 "날아가는" 궤적을 만든다.
/// 턴/박자가 바뀌면 호출부가 새 key로 다시 만들어 처음부터 재생된다.
class _SkillEffectBurst extends StatefulWidget {
  final List<PixelSprite> frames;
  final double size;
  final Color dotColor;

  /// 가로 슬라이드 시작/끝 오프셋 (0이면 제자리 재생 — 방어자세 등)
  final double slideBeginDx;
  final double slideEndDx;

  const _SkillEffectBurst({
    super.key,
    required this.frames,
    required this.size,
    required this.dotColor,
    this.slideBeginDx = 0,
    this.slideEndDx = 0,
  });

  @override
  State<_SkillEffectBurst> createState() => _SkillEffectBurstState();
}

class _SkillEffectBurstState extends State<_SkillEffectBurst>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 슬라이드하는 투사체는 도착 지점(몸에 닿는/화면 밖) 부근에서 사라진다.
    // 제자리 이펙트(방어자세)는 박자 끝까지 유지.
    final slides = widget.slideBeginDx != widget.slideEndDx;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = Curves.easeOut.transform(_controller.value);
        final idx = (_controller.value * widget.frames.length)
            .floor()
            .clamp(0, widget.frames.length - 1);
        final dx =
            widget.slideBeginDx + (widget.slideEndDx - widget.slideBeginDx) * t;
        final opacity = slides && _controller.value > 0.7
            ? (1 - (_controller.value - 0.7) / 0.3).clamp(0.0, 1.0)
            : 1.0;
        return Opacity(
          opacity: opacity,
          child: Transform.translate(
            offset: Offset(dx, 0),
            child: PixelSpriteView(
              sprite: widget.frames[idx],
              width: widget.size,
              height: widget.size,
              dotColor: widget.dotColor,
              // 반짝이('+')는 종과 무관한 스파크 노랑
              accentColor: const Color(0xFFFFC94D),
            ),
          ),
        );
      },
    );
  }
}
