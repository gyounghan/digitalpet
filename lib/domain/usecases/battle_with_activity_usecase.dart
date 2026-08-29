import 'dart:math';
import '../entities/pet.dart';
import '../entities/battle_history.dart';
import '../entities/battle_style.dart';
import '../entities/evolution_type.dart';
import '../repositories/pet_repository.dart';
import '../repositories/activity_repository.dart';
import '../repositories/battle_history_repository.dart';
import 'apply_battle_reward.dart';

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
// 시뮬레이션 밸런스 노트: 급강하 1.5는 bird가 불리 상성마저 뒤집는 최강 스킬이었고,
// 조이기는 데미지 없는 디버프라 snake만 유독 약했다(보통 육성 95% vs 53%).
// → 급강하 1.3 하향, 조이기에 소폭 데미지(1.2) 부여로 4종 승률 폭 축소.
const Map<EvolutionType, List<BattleSkill>> _skillSets = {
  EvolutionType.bird: [
    BattleSkill(name: '쪼기'),
    BattleSkill(name: '급강하', type: SkillType.special, damageMultiplier: 1.25),
  ],
  EvolutionType.snake: [
    BattleSkill(name: '물기'),
    BattleSkill(
        name: '조이기',
        type: SkillType.special,
        damageMultiplier: 1.2,
        defenseDebuff: 3,
        debuffDuration: 2),
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

  /// 하루 AI 대전 한도 (단일 소스: Pet.maxBattlesPerDay — 온라인 대전과 별도 적용)
  static const int maxBattlesPerDay = Pet.maxBattlesPerDay;

  /// 배틀은 한쪽 HP가 0이 될 때까지(KO) 진행한다.
  /// maxTurns는 무한 루프 방지용 안전 상한 — 도달 시 남은 HP로 판정승.
  /// (데미지 최저 1 보장이라 통상 5~10턴 내 KO, 상한 도달은 극단 케이스뿐)
  static const int maxTurns = 30;
  // 상성은 "한쪽만" 보정한다: 유리한 쪽 +20%만, 불리한 쪽은 페널티 없음(×1.0).
  // 예전 유리×1.3 + 불리×0.7 조합은 데미지비 ~1.86배로 스탯·스킬을 압도해
  // 상성이 승패를 사실상 결정했다 → 상성을 "edge"로만 남기고 육성/스킬을 주역으로.
  static const double affinityAdvantageMultiplier = 1.2;
  static const double affinityDisadvantageMultiplier = 1.0;
  static const int specialCooldown = 2;

  // 보상 상수는 [BattleReward]가 단일 소스 — 여기는 하위 호환 별칭.
  static const int victoryExp = BattleReward.victoryExp;
  static const int defeatExp = BattleReward.defeatExp;
  static const int dominantVictoryExp = BattleReward.dominantVictoryExp;
  static const List<double> rewardMultipliers = BattleReward.rewardMultipliers;

  BattleWithActivityUseCase({
    required this.petRepository,
    required this.activityRepository,
    required this.battleHistoryRepository,
  });

  /// 회피(빗나감) 확률 — 공격마다 독립 판정.
  ///
  /// 플레이어는 "기력(stamina)"에 비례해 민첩해진다:
  ///   기본 5% + (기력 / 100) × 10% (최대 15%)
  /// 잘 재우고 쉬게 해 기력을 채운 펫이 잘 피한다 — 수면 케어가 배틀의
  /// 회피 축으로 직결된다 (포만/행복은 컨디션 배수로 ATK/DEF에 이미 반영).
  /// AI 상대는 평균 컨디션을 가정한 고정 10% — 기력 관리로 우위/열세가 갈린다.
  static const double baseDodgeChance = 0.05;
  static const double maxStaminaDodgeBonus = 0.10;
  static const double aiDodgeChance = 0.10;

  /// 기력(0~100) → 플레이어 회피 확률
  static double dodgeChanceForStamina(int stamina) =>
      baseDodgeChance +
      maxStaminaDodgeBonus * (stamina / 100).clamp(0.0, 1.0);

  Future<BattleResult> call(
    String petId, {
    BattleStyle style = BattleStyle.balanced,
    Random? random,
  }) async {
    var pet = await petRepository.getPet(petId);

    if (pet.isDead) {
      return BattleResult.empty(pet);
    }

    if (pet.needsGoalReset) {
      pet = pet.resetDailyGoals();
      await petRepository.updatePet(pet);
    }

    // 한도 = 기본 5회 + 광고 시청 추가분 (AI 대전 전용 카운트)
    if (!pet.canBattleAi) {
      return BattleResult.empty(pet, limitReached: true);
    }

    final todayActivity = await activityRepository.getTodayActivityData();
    random ??= Random();

    final playerType = pet.evolutionType;
    // 전투 스탯은 Pet 엔티티의 영구 성장 + 컨디션 보정 getter를 단일 소스로 사용
    // (도감 표시와 실전 수치가 항상 일치). 배틀 스타일은 ATK/DEF에만 적용.
    final playerStats = BattleStats(
      attack: (pet.battleAtk * style.attackMultiplier).round(),
      defense: (pet.battleDef * style.defenseMultiplier).round(),
      hp: pet.battleHp,
    );

    // AI 상대 생성 (종 랜덤)
    // 미러 기준은 스타일 적용 "전" 스탯 — 스타일 선택은 플레이어만의 edge로 남긴다.
    // 털뭉치(종 미결정)는 털뭉치끼리 만난다 — 상대도 종 없음(상성·종 보너스 중립)
    final opponentLevel = max(1, pet.level - 2 + random.nextInt(4));
    final opponentType = playerType == null
        ? null
        : EvolutionType.values[random.nextInt(EvolutionType.values.length)];
    final baseStats = BattleStats(
      attack: pet.battleAtk,
      defense: pet.battleDef,
      hp: pet.battleHp,
    );
    final opponentStats =
        generateOpponentStats(baseStats, opponentLevel, opponentType, random);

    // 상성 계산
    final affinityMultiplier = affinityMultiplierFor(playerType, opponentType);
    final opponentAffinityMultiplier =
        affinityMultiplierFor(opponentType, playerType);

    // 스킬셋
    final playerSkills = _skillSets[playerType] ?? _defaultSkills;
    final opponentSkills = _skillSets[opponentType] ?? _defaultSkills;

    // 내 회피 확률 — 기력 연동 (잘 쉰 펫이 잘 피한다)
    final playerDodgeChance = dodgeChanceForStamina(pet.stamina);

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
      // 피해감소(방어자세)는 턴 타이머가 아니라 "다음 N회 피격 방어" 충전으로 관리한다.
      // → 시전자(플레이어/AI)·턴 순서와 무관하게 정확히 reductionDuration회만 적용.

      // 플레이어 스킬 선택 (AI: 쿨타임 끝나면 특수기 우선)
      final playerSkill = _selectSkill(playerSkills, playerSpecialCooldown);
      if (playerSkill.type == SkillType.special) playerSpecialCooldown = specialCooldown;
      if (playerSpecialCooldown > 0) playerSpecialCooldown--;

      // 플레이어 공격 — 회피 판정 성공 시 데미지 0, 디버프/실드 소모 없음
      int playerDamage = 0;
      final opponentDodged = random.nextDouble() < aiDodgeChance;
      if (!opponentDodged) {
        var rawDamage = (playerAtk * playerSkill.damageMultiplier - opponentDef ~/ 2 + random.nextInt(5) - 2).round();
        rawDamage = (rawDamage * affinityMultiplier).round();
        final oppShield =
            applyDamageShield(rawDamage, opponentDmgReduction, opponentDmgReductionTurns);
        rawDamage = oppShield.damage;
        opponentDmgReduction = oppShield.reduction;
        opponentDmgReductionTurns = oppShield.charges;
        playerDamage = max(1, rawDamage);
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
      }
      // 방어자세는 자기 버프라 상대 회피와 무관하게 적용
      if (playerSkill.damageReduction > 0) {
        playerDmgReduction = playerSkill.damageReduction;
        playerDmgReductionTurns = playerSkill.reductionDuration;
      }

      // 상대 스킬 선택
      final opponentSkill = _selectSkill(opponentSkills, opponentSpecialCooldown);
      if (opponentSkill.type == SkillType.special) opponentSpecialCooldown = specialCooldown;
      if (opponentSpecialCooldown > 0) opponentSpecialCooldown--;

      // 상대 공격 — 내 회피는 오늘 걸음수에 비례
      int opponentDamage = 0;
      if (opponentHp > 0) {
        final playerDodged = random.nextDouble() < playerDodgeChance;
        if (!playerDodged) {
          var rawOppDmg = (opponentAtk * opponentSkill.damageMultiplier - playerDef ~/ 2 + random.nextInt(5) - 2).round();
          rawOppDmg = (rawOppDmg * opponentAffinityMultiplier).round();
          final playerShield =
              applyDamageShield(rawOppDmg, playerDmgReduction, playerDmgReductionTurns);
          rawOppDmg = playerShield.damage;
          playerDmgReduction = playerShield.reduction;
          playerDmgReductionTurns = playerShield.charges;
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

    final currentTime = DateTime.now().millisecondsSinceEpoch;
    final reward = BattleReward.apply(
      pet,
      isVictory: isVictory,
      isDominantVictory: isDominantVictory,
      nowMs: currentTime,
    );
    final expGain = reward.expGained;
    final updatedPet = reward.updatedPet;

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
      opponentTypeName: opponentType?.name ?? '',
      // 유리 = 내가 상대에게 +20%, 불리 = 상대가 나에게 +20%(한쪽 보정 모델)
      affinityAdvantage: affinityMultiplier > 1.0,
      affinityDisadvantage: opponentAffinityMultiplier > 1.0,
      playerMaxHp: playerStats.hp,
      opponentMaxHp: opponentStats.hp,
      opponentLevel: opponentLevel,
    );
  }

  /// 공격자→방어자 상성 배수. 유리하면 +20%(advantage), 불리하면 페널티 없음(1.0).
  /// 인스턴스 상태를 쓰지 않으므로 static — 테스트/도감에서 직접 조회 가능.
  static double affinityMultiplierFor(
      EvolutionType? attacker, EvolutionType? defender) {
    if (attacker == null || defender == null) return 1.0;
    if (_affinityAdvantage[attacker] == defender) {
      return affinityAdvantageMultiplier;
    }
    if (_affinityAdvantage[defender] == attacker) {
      return affinityDisadvantageMultiplier;
    }
    return 1.0;
  }

  /// 방어자세 등 피해감소 "충전"을 1회 적용한다.
  ///
  /// 남은 충전([charges])이 있으면 [rawDamage]를 [reduction]만큼 깎고 충전을 1 소모한다.
  /// 충전이 없거나 감소율이 0이면 원본을 그대로 통과시키고 감소를 0으로 만료한다.
  /// 턴 타이머가 아니라 "다음 N회 피격 방어"라서 시전자·턴 순서와 무관하게
  /// 정확히 reductionDuration회만 적용된다.
  static DamageShieldResult applyDamageShield(
      int rawDamage, double reduction, int charges) {
    if (reduction <= 0 || charges <= 0) {
      return DamageShieldResult(damage: rawDamage, reduction: 0.0, charges: 0);
    }
    final reduced = (rawDamage * (1.0 - reduction)).round();
    final remaining = charges - 1;
    return DamageShieldResult(
      damage: reduced,
      reduction: remaining > 0 ? reduction : 0.0,
      charges: remaining,
    );
  }

  BattleSkill _selectSkill(List<BattleSkill> skills, int currentCooldown) {
    if (skills.length > 1 && currentCooldown <= 0) {
      return skills[1]; // 특수기
    }
    return skills[0]; // 기본공격
  }

  /// AI 상대 스탯 — "레벨 기준 골격"과 "플레이어 실측 스탯 미러"를 절반씩 섞고
  /// ±15% 변동을 준다.
  ///
  /// 플레이어의 육성(세트·걸음·진화단계·컨디션)이 절반만 상대에게 전이되므로:
  /// 잘 키우면 우위(승률 ~70%대), 방치하면 열세(~40%대)가 유지되면서도
  /// 예전처럼 상대가 절대치(레벨만)에 묶여 무조건 이기는 구조가 되지 않는다.
  /// 상성(+20%)·스킬·배틀 스타일이 그 안에서 승부를 흔든다.
  /// 인스턴스 상태를 쓰지 않으므로 static — 시뮬레이션/테스트에서 직접 호출 가능.
  static BattleStats generateOpponentStats(
      BattleStats player, int level, EvolutionType? type, Random random) {
    int attackBonus = 0, defenseBonus = 0, hpBonus = 0;
    switch (type) {
      case EvolutionType.bird: attackBonus = 3; break;
      case EvolutionType.snake: hpBonus = 10; defenseBonus = 2; break;
      case EvolutionType.tiger: attackBonus = 2; defenseBonus = 2; break;
      case EvolutionType.turtle: defenseBonus = 3; hpBonus = 10; break;
      case null: break; // 털뭉치 — 종 보너스 없음
    }

    // 레벨 기준 골격 (옛 랜덤 보너스의 기대값을 상수화: atk/def +6, hp +10)
    final baseAtk = Pet.battleFlatBase + level + 6 + attackBonus;
    final baseDef = Pet.battleFlatBase + level + 6 + defenseBonus;
    final baseHp = 50 + level * 2 + 10 + hpBonus;

    // 골격 15% : 미러 85% 혼합 후 ±15% 변동
    // (미러 비중이 낮으면 플레이어 스탯 우위가 7턴 HP 비교에서 증폭돼
    //  보통 육성도 90%+ 승률이 나온다 — 시뮬레이션 튜닝 결과:
    //  방치 ~40% / 보통 ~75% / 헤비 ~93%, 상성·스타일이 ±15%p 스윙)
    int mix(int base, int mirror) {
      final blended = base * 0.15 + mirror * 0.85;
      final vary = 0.85 + random.nextDouble() * 0.3;
      return (blended * vary).round().clamp(1, 1 << 30);
    }

    return BattleStats(
      attack: mix(baseAtk, player.attack),
      defense: mix(baseDef, player.defense),
      hp: mix(baseHp, player.hp),
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

/// 피해감소 충전 1회 적용 결과 (방어자세)
class DamageShieldResult {
  /// 감소가 적용된(또는 그대로 통과한) 피해량
  final int damage;

  /// 다음 피격에도 유효한 감소율 — 충전 소진 시 0.0
  final double reduction;

  /// 남은 방어 충전 수 — 소진 시 0
  final int charges;

  const DamageShieldResult({
    required this.damage,
    required this.reduction,
    required this.charges,
  });
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

  /// 양측 최대 HP (HP 바 표시용 분모 — 레벨에 따라 100을 넘을 수 있음)
  final int playerMaxHp;
  final int opponentMaxHp;

  /// AI 상대 레벨 (아레나 표시용)
  final int opponentLevel;

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
    this.playerMaxHp = 100,
    this.opponentMaxHp = 100,
    this.opponentLevel = 1,
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
