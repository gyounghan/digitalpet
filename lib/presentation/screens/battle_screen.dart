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

class _BattleScreenState extends ConsumerState<BattleScreen> {
  bool? battleResult; // true: 승리, false: 패배, null: 아직 대결 안 함
  bool isLoading = false;
  int expGained = 0;
  
  @override
  void initState() {
    super.initState();
  }
  
  /// 활동 기반 대결 실행
  Future<void> _startBattle() async {
    if (isLoading || battleResult != null) return;
    
    setState(() {
      isLoading = true;
    });
    
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
          
          // 대결 버튼 또는 결과
          if (battleResult == null)
            PetButton(
              variant: PetButtonVariant.primary,
              icon: Icons.sports_martial_arts,
              onPressed: isLoading ? null : _startBattle,
              disabled: isLoading,
              child: Text(isLoading ? '대결 중...' : '대결 시작'),
            ),
          
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
