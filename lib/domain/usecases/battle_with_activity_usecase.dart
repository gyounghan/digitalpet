import 'dart:math';
import '../entities/pet.dart';
import '../entities/battle_history.dart';
import '../entities/evolution_type.dart';
import '../repositories/pet_repository.dart';
import '../repositories/activity_repository.dart';
import '../repositories/battle_history_repository.dart';

/// 스탯 기반 배틀 유스케이스
/// 펫 상태 + 활동량 + 진화 보너스로 배틀 능력치를 결정하고 5턴 자동 진행
///
/// 능력치 계산:
/// - 공격력 = (happiness/10) + 활동보너스(max 5) + 진화보너스 + 방향보너스
/// - 방어력 = (stamina/10) + 활동보너스(max 5) + 진화보너스 + 방향보너스
/// - 체력 = 50 + (hunger/5) + (레벨*2) + 방향보너스
///
/// 하루 3회 제한 (1회차 100%, 2회차 70%, 3회차 50% 보상)
class BattleWithActivityUseCase {
  final PetRepository petRepository;
  final ActivityRepository activityRepository;
  final BattleHistoryRepository battleHistoryRepository;

  static const int maxBattlesPerDay = 3;
  static const int maxTurns = 5;

  /// 보상 EXP (기본)
  static const int victoryExp = 50;
  static const int defeatExp = 15;
  static const int dominantVictoryExp = 70;

  /// 보상 배율 (횟수별)
  static const List<double> rewardMultipliers = [1.0, 0.7, 0.5];

  /// 진화 단계별 보너스
  static const Map<int, int> evolutionStageBonus = {
    1: 0, 2: 2, 3: 4, 4: 7,
  };

  BattleWithActivityUseCase({
    required this.petRepository,
    required this.activityRepository,
    required this.battleHistoryRepository,
  });

  /// 배틀 실행
  Future<BattleResult> call(String petId) async {
    var pet = await petRepository.getPet(petId);

    if (pet.isDead) {
      return BattleResult(
        isVictory: false,
        isDominantVictory: false,
        expGained: 0,
        updatedPet: pet,
        turns: [],
        playerStats: _BattleStats.zero(),
        opponentStats: _BattleStats.zero(),
      );
    }

    // 일일 리셋 체크
    if (pet.needsGoalReset) {
      pet = pet.resetDailyGoals();
      await petRepository.updatePet(pet);
    }

    // 하루 3회 제한
    if (pet.todayBattleCount >= maxBattlesPerDay) {
      return BattleResult(
        isVictory: false,
        isDominantVictory: false,
        expGained: 0,
        updatedPet: pet,
        turns: [],
        playerStats: _BattleStats.zero(),
        opponentStats: _BattleStats.zero(),
        limitReached: true,
      );
    }

    final todayActivity = await activityRepository.getTodayActivityData();
    final random = Random();

    // 플레이어 스탯 계산
    final playerStats = _calculatePlayerStats(pet, todayActivity.steps, todayActivity.exerciseMinutes);

    // AI 상대 생성 (레벨 기반)
    final opponentLevel = max(1, pet.level - 2 + random.nextInt(4));
    final opponentStats = _generateOpponentStats(opponentLevel, random);

    // 5턴 배틀 시뮬레이션
    int playerHp = playerStats.hp;
    int opponentHp = opponentStats.hp;
    final turns = <BattleTurn>[];

    for (int turn = 1; turn <= maxTurns && playerHp > 0 && opponentHp > 0; turn++) {
      // 플레이어 공격
      final playerDamage = max(1, playerStats.attack - (opponentStats.defense ~/ 2) + random.nextInt(5) - 2);
      opponentHp = max(0, opponentHp - playerDamage);

      // 상대 공격 (상대가 아직 살아있으면)
      int opponentDamage = 0;
      if (opponentHp > 0) {
        opponentDamage = max(1, opponentStats.attack - (playerStats.defense ~/ 2) + random.nextInt(5) - 2);
        playerHp = max(0, playerHp - opponentDamage);
      }

      turns.add(BattleTurn(
        turnNumber: turn,
        playerDamage: playerDamage,
        opponentDamage: opponentDamage,
        playerHpRemaining: playerHp,
        opponentHpRemaining: opponentHp,
      ));
    }

    // 결과 판정
    final isVictory = playerHp > opponentHp;
    final isDominantVictory = isVictory && playerHp > (playerStats.hp ~/ 2);

    // 보상 계산 (횟수별 배율)
    final multiplierIndex = pet.todayBattleCount.clamp(0, rewardMultipliers.length - 1);
    final multiplier = rewardMultipliers[multiplierIndex];

    int baseExp;
    if (isDominantVictory) {
      baseExp = dominantVictoryExp;
    } else if (isVictory) {
      baseExp = victoryExp;
    } else {
      baseExp = defeatExp;
    }

    // 이벤트 보너스 (모험의 날)
    final eventMultiplier = pet.todayEvent == 'adventure' ? 2.0 : 1.0;
    final expGain = (baseExp * multiplier * eventMultiplier).round();

    // 레벨업 계산 (점진적)
    var currentExp = pet.exp + expGain;
    var currentLevel = pet.level;
    int levelUps = 0;
    while (true) {
      final required = Pet.getRequiredExpForLevel(currentLevel);
      if (currentExp >= required) {
        currentExp -= required;
        currentLevel++;
        levelUps++;
      } else {
        break;
      }
    }

    final levelUpStatBonus = levelUps * 10;
    final happinessBonus = isDominantVictory ? 8 : (isVictory ? 5 : 0);
    final currentTime = DateTime.now().millisecondsSinceEpoch;

    final updatedPet = pet.copyWith(
      exp: currentExp,
      level: currentLevel,
      happiness: (pet.happiness + happinessBonus + levelUpStatBonus).clamp(0, 100),
      hunger: (pet.hunger + levelUpStatBonus).clamp(0, 100),
      stamina: (pet.stamina + levelUpStatBonus).clamp(0, 100),
      todayBattleCount: pet.todayBattleCount + 1,
      battleVictoryCount: isVictory ? pet.battleVictoryCount + 1 : pet.battleVictoryCount,
      lastUpdated: currentTime,
    );

    await petRepository.updatePet(updatedPet);

    // 전적 저장
    final battleHistory = BattleHistory(
      id: '${petId}_$currentTime',
      date: currentTime,
      isVictory: isVictory,
      expGained: expGain,
      steps: todayActivity.steps,
      exerciseMinutes: todayActivity.exerciseMinutes,
    );
    await battleHistoryRepository.saveBattleHistory(battleHistory);

    return BattleResult(
      isVictory: isVictory,
      isDominantVictory: isDominantVictory,
      expGained: expGain,
      updatedPet: updatedPet,
      turns: turns,
      playerStats: playerStats,
      opponentStats: opponentStats,
    );
  }

  /// 플레이어 배틀 스탯 계산
  _BattleStats _calculatePlayerStats(Pet pet, int todaySteps, int todayExerciseMinutes) {
    final stageBonus = evolutionStageBonus[pet.evolutionStage] ?? 0;

    // 활동 보너스 (최대 5)
    final stepsBonus = min(todaySteps ~/ 2000, 5);
    final exerciseBonus = min(todayExerciseMinutes ~/ 6, 5);
    final activityBonus = max(stepsBonus, exerciseBonus);

    // 진화 방향 보너스
    int attackDirectionBonus = 0;
    int defenseDirectionBonus = 0;
    int hpDirectionBonus = 0;
    switch (pet.evolutionType) {
      case EvolutionType.bird:
        attackDirectionBonus = 3;
        break;
      case EvolutionType.snake:
        hpDirectionBonus = 10;
        defenseDirectionBonus = 2;
        break;
      case EvolutionType.tiger:
        attackDirectionBonus = 2;
        defenseDirectionBonus = 2;
        break;
      case EvolutionType.turtle:
        defenseDirectionBonus = 3;
        hpDirectionBonus = 10;
        break;
      default:
        break;
    }

    return _BattleStats(
      attack: (pet.happiness ~/ 10) + activityBonus + stageBonus + attackDirectionBonus,
      defense: (pet.stamina ~/ 10) + activityBonus + stageBonus + defenseDirectionBonus,
      hp: 50 + (pet.hunger ~/ 5) + (pet.level * 2) + hpDirectionBonus,
    );
  }

  /// AI 상대 스탯 생성
  _BattleStats _generateOpponentStats(int level, Random random) {
    final baseStatMin = 40;
    final baseStatMax = 80;
    final statRange = baseStatMax - baseStatMin;

    return _BattleStats(
      attack: (baseStatMin + random.nextInt(statRange)) ~/ 10 + level,
      defense: (baseStatMin + random.nextInt(statRange)) ~/ 10 + level,
      hp: 50 + (baseStatMin + random.nextInt(statRange)) ~/ 5 + (level * 2),
    );
  }
}

/// 배틀 스탯
class _BattleStats {
  final int attack;
  final int defense;
  final int hp;

  _BattleStats({required this.attack, required this.defense, required this.hp});

  factory _BattleStats.zero() => _BattleStats(attack: 0, defense: 0, hp: 0);
}

/// 배틀 턴 결과
class BattleTurn {
  final int turnNumber;
  final int playerDamage;
  final int opponentDamage;
  final int playerHpRemaining;
  final int opponentHpRemaining;

  BattleTurn({
    required this.turnNumber,
    required this.playerDamage,
    required this.opponentDamage,
    required this.playerHpRemaining,
    required this.opponentHpRemaining,
  });
}

/// 대결 결과
class BattleResult {
  final bool isVictory;
  final bool isDominantVictory;
  final int expGained;
  final Pet updatedPet;
  final List<BattleTurn> turns;
  final _BattleStats playerStats;
  final _BattleStats opponentStats;
  final bool limitReached;

  BattleResult({
    required this.isVictory,
    required this.isDominantVictory,
    required this.expGained,
    required this.updatedPet,
    required this.turns,
    required this.playerStats,
    required this.opponentStats,
    this.limitReached = false,
  });
}
