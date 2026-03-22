import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/pet_provider.dart';
import '../widgets/pet_button.dart';
import '../widgets/glass_card.dart';
import '../../core/theme/app_colors.dart';
import '../../core/constants/app_strings.dart';
import '../../domain/entities/battle_history.dart';
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
  bool? battleResult; // true: 승리, false: 패배, null: 아직 대결 안 함
  bool isLoading = false;
  int expGained = 0;

  // 턴 기반 배틀 상태
  List<BattleTurn> turns = [];
  int currentTurnIndex = -1;
  int ourPetHp = 100;
  int opponentPetHp = 100;
  late AnimationController _attackAnimationController;

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
    super.dispose();
  }
  
  /// 턴 기반 배틀 시뮬레이션
  Future<void> _simulateTurns() async {
    // 초기 상태 설정
    setState(() {
      turns = [];
      currentTurnIndex = -1;
      ourPetHp = 100;
      opponentPetHp = 100;
    });

    // 최대 5턴 진행
    for (int turn = 0; turn < 5; turn++) {
      await Future.delayed(const Duration(milliseconds: 800));

      // 우리 펫 행동
      final ourAction = _getRandomAction();
      int ourDamage = ourAction == '공격' ? _calculateDamage(true) : 0;

      // 상대 펫 행동
      final opponentAction = _getRandomAction();
      int opponentDamage = opponentAction == '공격' ? _calculateDamage(false) : 0;

      // 체력 업데이트
      setState(() {
        opponentPetHp = (opponentPetHp - ourDamage).clamp(0, 100);
        ourPetHp = (ourPetHp - opponentDamage).clamp(0, 100);

        turns.add(BattleTurn(
          turnNumber: turn + 1,
          ourAction: ourAction,
          ourDamage: ourDamage,
          opponentAction: opponentAction,
          opponentDamage: opponentDamage,
        ));
        currentTurnIndex = turn;
      });

      // 누군가 체력이 0이 되면 종료
      if (ourPetHp == 0 || opponentPetHp == 0) break;
    }

    // 배틀 결과 결정 및 저장
    await _finalizeBattle();
  }

  /// 배틀 결과 최종화
  Future<void> _finalizeBattle() async {
    // 활동 기반 승패 결정 (기존 로직)
    try {
      final battleUseCase = ref.read(battleWithActivityUseCaseProvider);
      final result = await battleUseCase(HomeScreen.defaultPetId);

      // Pet 상태 새로고침
      await ref.read(petNotifierProvider(HomeScreen.defaultPetId).notifier).refresh();

      setState(() {
        battleResult = result.isVictory;
        expGained = result.expGained;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        isLoading = false;
      });
    }
  }

  /// 랜덤 액션 선택
  String _getRandomAction() {
    final actions = ['공격', '방어'];
    return actions[DateTime.now().microsecond % 2];
  }

  /// 대미지 계산
  int _calculateDamage(bool isOurPet) {
    // 1~20 사이의 랜덤 대미지
    return 5 + (DateTime.now().microsecond % 16);
  }

  /// 활동 기반 대결 실행 (턴 애니메이션 포함)
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
            if (!isLoading)
              PetButton(
                variant: PetButtonVariant.primary,
                icon: Icons.sports_martial_arts,
                onPressed: _startBattle,
                child: const Text('대결 시작'),
              )
            else
              _buildBattleInProgress(pet),
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
                    '${pet.name}: ${turns[currentTurnIndex].ourAction}',
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (turns[currentTurnIndex].ourDamage > 0) ...[
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
                  const SizedBox(height: 8),
                  Text(
                    '상대: ${turns[currentTurnIndex].opponentAction}',
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (turns[currentTurnIndex].opponentDamage > 0) ...[
                    const SizedBox(height: 4),
                    Text(
                      '→ -${turns[currentTurnIndex].ourDamage} 대미지!',
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

/// 한 턴의 배틀 정보
class BattleTurn {
  final int turnNumber;
  final String ourAction;
  final int ourDamage;
  final String opponentAction;
  final int opponentDamage;

  BattleTurn({
    required this.turnNumber,
    required this.ourAction,
    required this.ourDamage,
    required this.opponentAction,
    required this.opponentDamage,
  });
}
