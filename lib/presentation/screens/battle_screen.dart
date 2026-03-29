import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/pet_provider.dart';
import '../widgets/pet_button.dart';
import '../widgets/glass_card.dart';
import '../../core/theme/app_colors.dart';
import '../../core/constants/app_strings.dart';
import '../../domain/entities/battle_history.dart';
import '../../domain/usecases/battle_with_activity_usecase.dart' show BattleTurn, BattleResult;
import '../../data/datasources/battle_socket_datasource.dart';
import 'home_screen.dart';

/// 배틀 화면
/// 활동 기반 대결 시스템
/// 일일 목표 달성 여부로 승부를 결정
class BattleScreen extends ConsumerStatefulWidget {
  const BattleScreen({super.key});
  
  @override
  ConsumerState<BattleScreen> createState() => _BattleScreenState();
}

class _BattleScreenState extends ConsumerState<BattleScreen>
    with TickerProviderStateMixin {
  // 배틀 상태
  bool? battleResult;
  bool isLoading = false;
  int expGained = 0;

  // 턴 기반 배틀 상태
  List<BattleTurn> turns = [];
  int currentTurnIndex = -1;
  int ourPetHp = 100;
  int opponentPetHp = 100;
  late AnimationController _attackAnimationController;

  // 온라인 PvP 상태
  bool isOnlineMode = false;
  bool isMatchmaking = false;
  String? opponentName;
  int? opponentLevel;
  BattleSocketDatasource? _socket;

  @override
  void initState() {
    super.initState();
    _attackAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
  }

  @override
  void dispose() {
    _attackAnimationController.dispose();
    _socket?.disconnect();
    super.dispose();
  }

  /// 온라인 매칭 시작
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
        // 펫 상태 새로고침
        ref.read(petNotifierProvider(HomeScreen.defaultPetId).notifier).refresh();
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

    // 매칭 큐 입장
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

  /// 온라인 매칭 취소
  void _cancelOnlineMatch() {
    _socket?.cancelQueue();
    _socket?.disconnect();
    setState(() {
      isLoading = false;
      isMatchmaking = false;
    });
  }
  
  /// 스탯 기반 배틀 시뮬레이션
  Future<void> _simulateTurns() async {
    setState(() {
      turns = [];
      currentTurnIndex = -1;
      ourPetHp = 100;
      opponentPetHp = 100;
    });

    try {
      final battleUseCase = ref.read(battleWithActivityUseCaseProvider);
      final result = await battleUseCase(HomeScreen.defaultPetId);

      // 배틀 횟수 제한
      if (result.limitReached) {
        setState(() { isLoading = false; });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('오늘 배틀 횟수를 모두 사용했습니다 (3/3)')),
          );
        }
        return;
      }

      // 턴 결과를 애니메이션으로 표시
      if (result.turns.isNotEmpty) {
        final firstTurn = result.turns.first;
        setState(() {
          ourPetHp = firstTurn.playerHpRemaining + firstTurn.opponentDamage;
          opponentPetHp = firstTurn.opponentHpRemaining + firstTurn.playerDamage;
        });

        for (int i = 0; i < result.turns.length; i++) {
          await Future.delayed(const Duration(milliseconds: 800));
          final turn = result.turns[i];
          setState(() {
            turns.add(turn);
            currentTurnIndex = i;
            ourPetHp = turn.playerHpRemaining;
            opponentPetHp = turn.opponentHpRemaining;
          });
        }
      }

      await ref.read(petNotifierProvider(HomeScreen.defaultPetId).notifier).refresh();

      setState(() {
        battleResult = result.isVictory;
        expGained = result.expGained;
        isLoading = false;
      });
    } catch (e) {
      setState(() { isLoading = false; });
    }
  }

  /// 배틀 시작 (턴 애니메이션 포함)
  Future<void> _startBattle() async {
    if (isLoading || battleResult != null) return;

    setState(() {
      isLoading = true;
    });

    await _simulateTurns();
  }
  
  /// 대결 초기화
  void _resetBattle() {
    setState(() {
      battleResult = null;
      expGained = 0;
    });
  }
  
  @override
  Widget build(BuildContext context) {
    final petAsync = ref.watch(petNotifierProvider(HomeScreen.defaultPetId));
    
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppColors.backgroundGradient,
        ),
        child: SafeArea(
          child: petAsync.when(
            loading: () => const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            ),
            error: (error, stackTrace) => Center(
              child: Text(
                'Error: $error',
                style: const TextStyle(color: AppColors.danger),
              ),
            ),
            data: (pet) => _buildBattleContent(context, pet),
          ),
        ),
      ),
    );
  }
  
  Widget _buildBattleContent(BuildContext context, pet) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 16),
          // 헤더
          Text(
            AppStrings.battleArena,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          
          // 전적 통계 카드
          FutureBuilder<BattleStats>(
            future: _getBattleStats(),
            builder: (context, snapshot) {
              if (snapshot.hasData) {
                final stats = snapshot.data!;
                return GlassCard(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildStatItem('총 대결', '${stats.total}', AppColors.textPrimary),
                          Container(
                            width: 1,
                            height: 40,
                            color: AppColors.glassBorder,
                          ),
                          _buildStatItem('승리', '${stats.victories}', AppColors.accentPink),
                          Container(
                            width: 1,
                            height: 40,
                            color: AppColors.glassBorder,
                          ),
                          _buildStatItem('패배', '${stats.defeats}', AppColors.textSecondary),
                        ],
                      ),
                      if (stats.total > 0) ...[
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '승률: ${((stats.victories / stats.total) * 100).toStringAsFixed(1)}%',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              } else {
                return const SizedBox.shrink();
              }
            },
          ),
          
          const SizedBox(height: 24),
          
          // 배틀 진행 상황 또는 버튼
          if (battleResult == null) ...[
            if (!isLoading) ...[
              Row(
                children: [
                  Expanded(
                    child: PetButton(
                      variant: PetButtonVariant.primary,
                      icon: Icons.smart_toy,
                      onPressed: () {
                        setState(() => isOnlineMode = false);
                        _startBattle();
                      },
                      child: const Text('AI 대전'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: PetButton(
                      variant: PetButtonVariant.secondary,
                      icon: Icons.wifi,
                      onPressed: () {
                        setState(() => isOnlineMode = true);
                        _startOnlineBattle(pet);
                      },
                      child: const Text('온라인 대전'),
                    ),
                  ),
                ],
              ),
            ] else if (isMatchmaking) ...[
              GlassCard(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    const CircularProgressIndicator(color: AppColors.primary),
                    const SizedBox(height: 16),
                    const Text(
                      '상대를 찾고 있습니다...',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    PetButton(
                      variant: PetButtonVariant.secondary,
                      onPressed: _cancelOnlineMatch,
                      child: const Text('취소'),
                    ),
                  ],
                ),
              ),
            ] else ...[
              if (opponentName != null) ...[
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    'VS $opponentName (Lv.$opponentLevel)',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.accentPink,
                    ),
                  ),
                ),
              ],
              _buildBattleInProgress(pet),
            ],
          ],
          
          if (battleResult != null) ...[
            GlassCard(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Icon(
                    battleResult! ? Icons.celebration : Icons.sentiment_dissatisfied,
                    size: 80,
                    color: battleResult! ? AppColors.accentPink : AppColors.textSecondary,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    battleResult! ? AppStrings.battleVictory : AppStrings.battleDefeat,
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w600,
                      color: battleResult! ? AppColors.accentPink : AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    battleResult!
                        ? '축하합니다! 목표를 달성했습니다!'
                        : '아쉽네요. 다음에는 목표를 달성해보세요!',
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    decoration: BoxDecoration(
                      color: AppColors.accentPink.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '획득 경험치: +$expGained',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: AppColors.accentPink,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            PetButton(
              variant: PetButtonVariant.secondary,
              icon: Icons.refresh,
              onPressed: _resetBattle,
              child: const Text('다시 대결하기'),
            ),
          ],
          
          const SizedBox(height: 32),
          
          // 최근 전적 목록
          FutureBuilder<List<BattleHistory>>(
            future: _getRecentBattleHistory(),
            builder: (context, snapshot) {
              if (snapshot.hasData && snapshot.data!.isNotEmpty) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '최근 전적',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ...snapshot.data!.map((history) => _buildHistoryItem(history)),
                  ],
                );
              } else {
                return const SizedBox.shrink();
              }
            },
          ),
        ],
      ),
    );
  }
  
  /// 배틀 진행 중 UI 빌드
  Widget _buildBattleInProgress(dynamic pet) {
    return GlassCard(
      gradient: true,
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          // 턴 번호
          if (currentTurnIndex >= 0)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Text(
                '턴 ${currentTurnIndex + 1}',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              ),
            ),

          // 우리 펫
          Padding(
            padding: const EdgeInsets.only(bottom: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${pet.name} (우리)',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      'HP: $ourPetHp/100',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: ourPetHp / 100,
                  backgroundColor: AppColors.glassBackground,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    ourPetHp > 50
                        ? Colors.green
                        : ourPetHp > 25
                            ? Colors.orange
                            : Colors.red,
                  ),
                ),
              ],
            ),
          ),

          // VS
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Text(
              '⚔️ VS ⚔️',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: AppColors.primary,
              ),
            ),
          ),

          // 상대 펫
          Padding(
            padding: const EdgeInsets.only(bottom: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      '상대 펫 (AI)',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    Text(
                      'HP: $opponentPetHp/100',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: opponentPetHp / 100,
                  backgroundColor: AppColors.glassBackground,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    opponentPetHp > 50
                        ? Colors.green
                        : opponentPetHp > 25
                            ? Colors.orange
                            : Colors.red,
                  ),
                ),
              ],
            ),
          ),

          // 현재 턴 액션 표시
          if (currentTurnIndex >= 0 && currentTurnIndex < turns.length) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Text(
                    '${pet.name}: ${turns[currentTurnIndex].playerSkillName}!',
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (turns[currentTurnIndex].playerDamage > 0) ...[
                    const SizedBox(height: 4),
                    Text(
                      '→ -${turns[currentTurnIndex].playerDamage} 대미지!',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.red,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Text(
                    '상대: ${turns[currentTurnIndex].opponentSkillName}!',
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (turns[currentTurnIndex].opponentDamage > 0) ...[
                    const SizedBox(height: 4),
                    Text(
                      '→ -${turns[currentTurnIndex].opponentDamage} 대미지!',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.red,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],

          const SizedBox(height: 16),
          const Center(
            child: CircularProgressIndicator(color: AppColors.primary),
          ),
        ],
      ),
    );
  }

  /// 통계 항목 빌드
  Widget _buildStatItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: AppColors.textTertiary,
          ),
        ),
      ],
    );
  }
  
  /// 전적 항목 빌드
  Widget _buildHistoryItem(BattleHistory history) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: GlassCard(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: history.isVictory
                    ? AppColors.accentPink.withValues(alpha: 0.2)
                    : AppColors.textSecondary.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                history.isVictory ? Icons.check_circle : Icons.cancel,
                color: history.isVictory ? AppColors.accentPink : AppColors.textSecondary,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    history.isVictory ? '승리' : '패배',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: history.isVictory ? AppColors.accentPink : AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${history.dateString} ${history.timeString}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textTertiary,
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '+${history.expGained} EXP',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppColors.accentPink,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${history.steps}보',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textTertiary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
  
  /// 전적 통계 조회
  Future<BattleStats> _getBattleStats() async {
    final repository = ref.read(battleHistoryRepositoryProvider);
    final total = await repository.getTotalBattleCount();
    final victories = await repository.getVictoryCount();
    final defeats = await repository.getDefeatCount();
    return BattleStats(
      total: total,
      victories: victories,
      defeats: defeats,
    );
  }
  
  /// 최근 전적 조회
  Future<List<BattleHistory>> _getRecentBattleHistory() async {
    final repository = ref.read(battleHistoryRepositoryProvider);
    return await repository.getRecentBattleHistory(10);
  }
}

/// 전적 통계
class BattleStats {
  final int total;
  final int victories;
  final int defeats;

  BattleStats({
    required this.total,
    required this.victories,
    required this.defeats,
  });
}

