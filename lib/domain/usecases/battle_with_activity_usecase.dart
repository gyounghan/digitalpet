import 'dart:math';
import '../entities/pet.dart';
import '../entities/battle_history.dart';
import '../entities/evolution_type.dart';
import '../repositories/pet_repository.dart';
import '../repositories/activity_repository.dart';
import '../repositories/battle_history_repository.dart';

/// 상성 테이블: bird→snake→turtle→tiger→bird
const Map<EvolutionType, EvolutionType> _affinityAdvantage = {
  EvolutionType.bird: EvolutionType.snake,
  EvolutionType.snake: EvolutionType.turtle,
  EvolutionType.turtle: EvolutionType.tiger,
  EvolutionType.tiger: EvolutionType.bird,
};

/// 종별 스킬 정의
enum SkillType { basicAttack, special }

class BattleSkill {
  final String name;
  final SkillType type;
  final double damageMultiplier;
  final int defenseDebuff;
  final int attackDebuff;
  final int debuffDuration;
  final double damageReduction;
  final int reductionDuration;

  const BattleSkill({
    required this.name,
    this.type = SkillType.basicAttack,
    this.damageMultiplier = 1.0,
    this.defenseDebuff = 0,
    this.attackDebuff = 0,
    this.debuffDuration = 0,
    this.damageReduction = 0.0,
    this.reductionDuration = 0,
  });
}

/// 종별 스킬셋
const Map<EvolutionType, List<BattleSkill>> _skillSets = {
  EvolutionType.bird: [
    BattleSkill(name: '쪼기'),
    BattleSkill(name: '급강하', type: SkillType.special, damageMultiplier: 1.5),
  ],
  EvolutionType.snake: [
    BattleSkill(name: '물기'),
    BattleSkill(name: '조이기', type: SkillType.special, defenseDebuff: 3, debuffDuration: 2),
  ],
  EvolutionType.tiger: [
    BattleSkill(name: '할퀴기'),
    BattleSkill(name: '포효', type: SkillType.special, attackDebuff: 3, debuffDuration: 2),
  ],
  EvolutionType.turtle: [
    BattleSkill(name: '박치기'),
    BattleSkill(name: '방어자세', type: SkillType.special, damageReduction: 0.5, reductionDuration: 1),
  ],
};

const List<BattleSkill> _defaultSkills = [
  BattleSkill(name: '공격'),
];

/// 스탯 기반 + 상성 + 스킬 배틀 유스케이스
class BattleWithActivityUseCase {
  final PetRepository petRepository;
  final ActivityRepository activityRepository;
  final BattleHistoryRepository battleHistoryRepository;

  static const int maxBattlesPerDay = 3;
  static const int maxTurns = 7;
  static const double affinityAdvantageMultiplier = 1.3;
  static const double affinityDisadvantageMultiplier = 0.7;
  static const int specialCooldown = 2;

  static const int victoryExp = 50;
  static const int defeatExp = 15;
  static const int dominantVictoryExp = 70;
  static const List<double> rewardMultipliers = [1.0, 0.7, 0.5];

  static const Map<int, int> evolutionStageBonus = {1: 0, 2: 2, 3: 4, 4: 7};

  BattleWithActivityUseCase({
    required this.petRepository,
    required this.activityRepository,
    required this.battleHistoryRepository,
  });

  Future<BattleResult> call(String petId) async {
    var pet = await petRepository.getPet(petId);

    if (pet.isDead) {
      return BattleResult.empty(pet);
    }

    if (pet.needsGoalReset) {
      pet = pet.resetDailyGoals();
      await petRepository.updatePet(pet);
    }

    if (pet.todayBattleCount >= maxBattlesPerDay) {
      return BattleResult.empty(pet, limitReached: true);
    }

    final todayActivity = await activityRepository.getTodayActivityData();
    final random = Random();

    final playerType = pet.evolutionType;
    final playerStats = _calculateStats(pet, todayActivity.steps, todayActivity.exerciseMinutes);

    // AI 상대 생성 (종 랜덤)
    final opponentLevel = max(1, pet.level - 2 + random.nextInt(4));
    final opponentType = EvolutionType.values[random.nextInt(EvolutionType.values.length)];
    final opponentStats = _generateOpponentStats(opponentLevel, opponentType, random);

    // 상성 계산
    final affinityMultiplier = _getAffinityMultiplier(playerType, opponentType);
    final opponentAffinityMultiplier = _getAffinityMultiplier(opponentType, playerType);

    // 스킬셋
    final playerSkills = _skillSets[playerType] ?? _defaultSkills;
    final opponentSkills = _skillSets[opponentType] ?? _defaultSkills;

    // 배틀 시뮬레이션
    int playerHp = playerStats.hp;
    int opponentHp = opponentStats.hp;
    int playerAtk = playerStats.attack;
    int playerDef = playerStats.defense;
    int opponentAtk = opponentStats.attack;
    int opponentDef = opponentStats.defense;

    // 디버프/버프 타이머
    int playerDefDebuffTurns = 0;
    int playerAtkDebuffTurns = 0;
    int opponentDefDebuffTurns = 0;
    int opponentAtkDebuffTurns = 0;
    int playerDmgReductionTurns = 0;
    int opponentDmgReductionTurns = 0;
    double playerDmgReduction = 0.0;
    double opponentDmgReduction = 0.0;

    int playerSpecialCooldown = 0;
    int opponentSpecialCooldown = 0;

    final turns = <BattleTurn>[];

    for (int turn = 1; turn <= maxTurns && playerHp > 0 && opponentHp > 0; turn++) {
      // 디버프 만료 체크
      if (playerDefDebuffTurns > 0) { playerDefDebuffTurns--; } else { playerDef = playerStats.defense; }
      if (playerAtkDebuffTurns > 0) { playerAtkDebuffTurns--; } else { playerAtk = playerStats.attack; }
      if (opponentDefDebuffTurns > 0) { opponentDefDebuffTurns--; } else { opponentDef = opponentStats.defense; }
      if (opponentAtkDebuffTurns > 0) { opponentAtkDebuffTurns--; } else { opponentAtk = opponentStats.attack; }
      if (playerDmgReductionTurns > 0) { playerDmgReductionTurns--; } else { playerDmgReduction = 0.0; }
      if (opponentDmgReductionTurns > 0) { opponentDmgReductionTurns--; } else { opponentDmgReduction = 0.0; }

      // 플레이어 스킬 선택 (AI: 쿨타임 끝나면 특수기 우선)
      final playerSkill = _selectSkill(playerSkills, playerSpecialCooldown);
      if (playerSkill.type == SkillType.special) playerSpecialCooldown = specialCooldown;
      if (playerSpecialCooldown > 0) playerSpecialCooldown--;

      // 플레이어 공격
      var rawDamage = (playerAtk * playerSkill.damageMultiplier - opponentDef ~/ 2 + random.nextInt(5) - 2).round();
      rawDamage = (rawDamage * affinityMultiplier).round();
      if (opponentDmgReduction > 0) rawDamage = (rawDamage * (1.0 - opponentDmgReduction)).round();
      final playerDamage = max(1, rawDamage);
      opponentHp = max(0, opponentHp - playerDamage);

      // 플레이어 스킬 효과 적용 (상대에게)
      if (playerSkill.defenseDebuff > 0) {
        opponentDef = max(0, opponentStats.defense - playerSkill.defenseDebuff);
        opponentDefDebuffTurns = playerSkill.debuffDuration;
      }
      if (playerSkill.attackDebuff > 0) {
        opponentAtk = max(0, opponentStats.attack - playerSkill.attackDebuff);
        opponentAtkDebuffTurns = playerSkill.debuffDuration;
      }
      if (playerSkill.damageReduction > 0) {
        playerDmgReduction = playerSkill.damageReduction;
        playerDmgReductionTurns = playerSkill.reductionDuration;
      }

      // 상대 스킬 선택
      final opponentSkill = _selectSkill(opponentSkills, opponentSpecialCooldown);
      if (opponentSkill.type == SkillType.special) opponentSpecialCooldown = specialCooldown;
      if (opponentSpecialCooldown > 0) opponentSpecialCooldown--;

      // 상대 공격
      int opponentDamage = 0;
      if (opponentHp > 0) {
        var rawOppDmg = (opponentAtk * opponentSkill.damageMultiplier - playerDef ~/ 2 + random.nextInt(5) - 2).round();
        rawOppDmg = (rawOppDmg * opponentAffinityMultiplier).round();
        if (playerDmgReduction > 0) rawOppDmg = (rawOppDmg * (1.0 - playerDmgReduction)).round();
        opponentDamage = max(1, rawOppDmg);
        playerHp = max(0, playerHp - opponentDamage);

        if (opponentSkill.defenseDebuff > 0) {
          playerDef = max(0, playerStats.defense - opponentSkill.defenseDebuff);
          playerDefDebuffTurns = opponentSkill.debuffDuration;
        }
        if (opponentSkill.attackDebuff > 0) {
          playerAtk = max(0, playerStats.attack - opponentSkill.attackDebuff);
          playerAtkDebuffTurns = opponentSkill.debuffDuration;
        }
        if (opponentSkill.damageReduction > 0) {
          opponentDmgReduction = opponentSkill.damageReduction;
          opponentDmgReductionTurns = opponentSkill.reductionDuration;
        }
      }

      turns.add(BattleTurn(
        turnNumber: turn,
        playerSkillName: playerSkill.name,
        playerDamage: playerDamage,
        opponentSkillName: opponentSkill.name,
        opponentDamage: opponentDamage,
        playerHpRemaining: playerHp,
        opponentHpRemaining: opponentHp,
      ));
    }

    final isVictory = playerHp > opponentHp;
    final isDominantVictory = isVictory && playerHp > (playerStats.hp ~/ 2);

    final multiplierIndex = pet.todayBattleCount.clamp(0, rewardMultipliers.length - 1);
    final multiplier = rewardMultipliers[multiplierIndex];
    int baseExp = isDominantVictory ? dominantVictoryExp : (isVictory ? victoryExp : defeatExp);
    final eventMultiplier = pet.todayEvent == 'adventure' ? 2.0 : 1.0;
    final expGain = (baseExp * multiplier * eventMultiplier).round();

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
      playerTypeName: playerType?.name ?? '',
      opponentTypeName: opponentType.name,
      affinityAdvantage: affinityMultiplier > 1.0,
      affinityDisadvantage: affinityMultiplier < 1.0,
    );
  }

  double _getAffinityMultiplier(EvolutionType? attacker, EvolutionType? defender) {
    if (attacker == null || defender == null) return 1.0;
    if (_affinityAdvantage[attacker] == defender) return affinityAdvantageMultiplier;
    if (_affinityAdvantage[defender] == attacker) return affinityDisadvantageMultiplier;
    return 1.0;
  }

  BattleSkill _selectSkill(List<BattleSkill> skills, int currentCooldown) {
    if (skills.length > 1 && currentCooldown <= 0) {
      return skills[1]; // 특수기
    }
    return skills[0]; // 기본공격
  }

  BattleStats _calculateStats(Pet pet, int todaySteps, int todayExerciseMinutes) {
    final stageBonus = evolutionStageBonus[pet.evolutionStage] ?? 0;
    final stepsBonus = min(todaySteps ~/ 2000, 5);
    final exerciseBonus = min(todayExerciseMinutes ~/ 6, 5);
    final activityBonus = max(stepsBonus, exerciseBonus);

    int attackBonus = 0, defenseBonus = 0, hpBonus = 0;
    switch (pet.evolutionType) {
      case EvolutionType.bird: attackBonus = 3; break;
      case EvolutionType.snake: hpBonus = 10; defenseBonus = 2; break;
      case EvolutionType.tiger: attackBonus = 2; defenseBonus = 2; break;
      case EvolutionType.turtle: defenseBonus = 3; hpBonus = 10; break;
      default: break;
    }

    return BattleStats(
      attack: (pet.happiness ~/ 10) + activityBonus + stageBonus + attackBonus,
      defense: (pet.stamina ~/ 10) + activityBonus + stageBonus + defenseBonus,
      hp: 50 + (pet.hunger ~/ 5) + (pet.level * 2) + hpBonus,
    );
  }

  BattleStats _generateOpponentStats(int level, EvolutionType type, Random random) {
    final baseMin = 40, baseMax = 80;
    final range = baseMax - baseMin;
    int attackBonus = 0, defenseBonus = 0, hpBonus = 0;
    switch (type) {
      case EvolutionType.bird: attackBonus = 3; break;
      case EvolutionType.snake: hpBonus = 10; defenseBonus = 2; break;
      case EvolutionType.tiger: attackBonus = 2; defenseBonus = 2; break;
      case EvolutionType.turtle: defenseBonus = 3; hpBonus = 10; break;
    }

    return BattleStats(
      attack: (baseMin + random.nextInt(range)) ~/ 10 + level + attackBonus,
      defense: (baseMin + random.nextInt(range)) ~/ 10 + level + defenseBonus,
      hp: 50 + (baseMin + random.nextInt(range)) ~/ 5 + (level * 2) + hpBonus,
    );
  }
}

/// 배틀 스탯 (public)
class BattleStats {
  final int attack;
  final int defense;
  final int hp;

  BattleStats({required this.attack, required this.defense, required this.hp});
  factory BattleStats.zero() => BattleStats(attack: 0, defense: 0, hp: 0);
}

/// 배틀 턴 결과
class BattleTurn {
  final int turnNumber;
  final String playerSkillName;
  final int playerDamage;
  final String opponentSkillName;
  final int opponentDamage;
  final int playerHpRemaining;
  final int opponentHpRemaining;

  BattleTurn({
    required this.turnNumber,
    required this.playerSkillName,
    required this.playerDamage,
    required this.opponentSkillName,
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
  final String playerTypeName;
  final String opponentTypeName;
  final bool affinityAdvantage;
  final bool affinityDisadvantage;
  final bool limitReached;

  BattleResult({
    required this.isVictory,
    required this.isDominantVictory,
    required this.expGained,
    required this.updatedPet,
    required this.turns,
    this.playerTypeName = '',
    this.opponentTypeName = '',
    this.affinityAdvantage = false,
    this.affinityDisadvantage = false,
    this.limitReached = false,
  });

  factory BattleResult.empty(Pet pet, {bool limitReached = false}) => BattleResult(
    isVictory: false,
    isDominantVictory: false,
    expGained: 0,
    updatedPet: pet,
    turns: [],
    limitReached: limitReached,
  );
}
