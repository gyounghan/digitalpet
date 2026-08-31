/// PvP 배틀 시뮬레이션 — 클라이언트 규칙과 동일 (체감 일관성)
///
/// 원본: lib/domain/usecases/battle_with_activity_usecase.dart
/// docs/battle_server_protocol.md "서버 구현 시 주의" 참조.
/// - 데미지: atk×스킬배수 − def÷2 + rand(5)−2 (최소 1)
/// - 상성: bird→snake→turtle→tiger→bird, 유리한 쪽만 +20%
/// - 회피: 기본 5% + 기력/100×10% (최대 15%) — 양측 각자 stamina로
/// - 특수기: 쿨타임 2, 쿨 끝나면 특수기 우선
/// - 방어자세: 다음 1회 피격 데미지 50% 감소 (충전식)
/// - KO까지, 안전 상한 30턴 (도달 시 남은 HP 판정)

export const MAX_TURNS = 30;
export const AFFINITY_ADVANTAGE = 1.2;
export const SPECIAL_COOLDOWN = 2;

export const BASE_DODGE = 0.05;
export const MAX_STAMINA_DODGE_BONUS = 0.10;

export const EXP_WIN = 50;
export const EXP_DOMINANT_WIN = 70;
export const EXP_LOSS = 15;

/// 종별 스킬셋 (클라이언트 _skillSets와 동일)
const SKILL_SETS = {
  bird: [
    { name: '쪼기', special: false, mult: 1.0 },
    { name: '급강하', special: true, mult: 1.25 },
  ],
  snake: [
    { name: '물기', special: false, mult: 1.0 },
    { name: '조이기', special: true, mult: 1.2, defDebuff: 3, debuffTurns: 2 },
  ],
  tiger: [
    { name: '할퀴기', special: false, mult: 1.0 },
    { name: '포효', special: true, mult: 1.0, atkDebuff: 3, debuffTurns: 2 },
  ],
  turtle: [
    { name: '박치기', special: false, mult: 1.0 },
    { name: '방어자세', special: true, mult: 1.0, dmgReduction: 0.5, shieldCharges: 1 },
  ],
  // 설화 영물 (클라이언트 _skillSets와 동기화)
  samjoko: [
    { name: '홰치기', special: false, mult: 1.0 },
    { name: '일식', special: true, mult: 1.25 },
  ],
  gumiho: [
    { name: '할큄', special: false, mult: 1.0 },
    { name: '홀리기', special: true, mult: 1.05, atkDebuff: 2, debuffTurns: 2 },
  ],
  moonrabbit: [
    { name: '떡방아', special: false, mult: 1.0 },
    { name: '보름달', special: true, mult: 1.0, dmgReduction: 0.4, shieldCharges: 1 },
  ],
  haetae: [
    { name: '들이받기', special: false, mult: 1.0 },
    { name: '심판', special: true, mult: 1.1, defDebuff: 3, debuffTurns: 2 },
  ],
  dokkaebi: [
    { name: '방망이질', special: false, mult: 1.0 },
    { name: '도깨비불', special: true, mult: 1.05, atkDebuff: 2, debuffTurns: 2 },
  ],
  hwangryong: [
    { name: '꼬리치기', special: false, mult: 1.0 },
    { name: '여의주', special: true, mult: 1.0, dmgReduction: 0.3, shieldCharges: 1 },
  ],
};
const DEFAULT_SKILLS = [{ name: '공격', special: false, mult: 1.0 }];

/// 공격자 종이 방어자 종에 유리한가
/// 사신수: bird→snake→turtle→tiger→bird
/// 설화 영물: samjoko→gumiho→moonrabbit→haetae→samjoko (그룹 간 중립)
const ADVANTAGE = {
  bird: 'snake', snake: 'turtle', turtle: 'tiger', tiger: 'bird',
  samjoko: 'gumiho', gumiho: 'moonrabbit', moonrabbit: 'haetae',
  haetae: 'dokkaebi', dokkaebi: 'hwangryong', hwangryong: 'samjoko',
};

export function affinityMultiplier(attackerType, defenderType) {
  if (!attackerType || !defenderType) return 1.0;
  return ADVANTAGE[attackerType] === defenderType ? AFFINITY_ADVANTAGE : 1.0;
}

export function dodgeChanceForStamina(stamina) {
  const s = Math.min(1, Math.max(0, (stamina ?? 50) / 100));
  return BASE_DODGE + MAX_STAMINA_DODGE_BONUS * s;
}

function makeFighter(payload) {
  const skills = SKILL_SETS[payload.evolutionType] ?? DEFAULT_SKILLS;
  return {
    name: payload.petName ?? '???',
    type: payload.evolutionType ?? null,
    baseAtk: payload.atk ?? 10,
    baseDef: payload.def ?? 10,
    maxHp: payload.hp ?? 100,
    hp: payload.hp ?? 100,
    dodge: dodgeChanceForStamina(payload.stamina),
    skills,
    atk: payload.atk ?? 10,
    def: payload.def ?? 10,
    atkDebuffTurns: 0,
    defDebuffTurns: 0,
    shieldReduction: 0,
    shieldCharges: 0,
    cooldown: 0,
  };
}

function selectSkill(fighter) {
  const special = fighter.skills.find((s) => s.special);
  if (special && fighter.cooldown === 0) {
    fighter.cooldown = SPECIAL_COOLDOWN;
    // 클라이언트와 동일: 설정 직후 같은 턴에 1 감소
    fighter.cooldown -= 1;
    return special;
  }
  if (fighter.cooldown > 0) fighter.cooldown -= 1;
  return fighter.skills[0];
}

/// attacker가 defender를 1회 공격. 데미지(회피 시 0)를 반환하고 상태를 갱신.
function performAttack(attacker, defender, affinity, rng) {
  if (rng() < defender.dodge) {
    // 회피 — 데미지 0, 디버프 미적용, 실드 미소모 (자기 버프는 호출부에서)
    return { damage: 0, skill: selectSkill(attacker) };
  }
  const skill = selectSkill(attacker);
  let raw = Math.round(
    attacker.atk * skill.mult - Math.floor(defender.def / 2) +
    Math.floor(rng() * 5) - 2,
  );
  raw = Math.round(raw * affinity);
  if (defender.shieldCharges > 0) {
    raw = Math.round(raw * (1 - defender.shieldReduction));
    defender.shieldCharges -= 1;
  }
  const damage = Math.max(1, raw);
  defender.hp = Math.max(0, defender.hp - damage);

  if (skill.defDebuff) {
    defender.def = Math.max(0, defender.baseDef - skill.defDebuff);
    defender.defDebuffTurns = skill.debuffTurns;
  }
  if (skill.atkDebuff) {
    defender.atk = Math.max(0, defender.baseAtk - skill.atkDebuff);
    defender.atkDebuffTurns = skill.debuffTurns;
  }
  return { damage, skill };
}

function tickDebuffs(fighter) {
  if (fighter.atkDebuffTurns > 0) fighter.atkDebuffTurns -= 1;
  else fighter.atk = fighter.baseAtk;
  if (fighter.defDebuffTurns > 0) fighter.defDebuffTurns -= 1;
  else fighter.def = fighter.baseDef;
}

function applySelfBuff(fighter, skill) {
  if (skill.dmgReduction) {
    fighter.shieldReduction = skill.dmgReduction;
    fighter.shieldCharges = skill.shieldCharges;
  }
}

/// PvP 배틀 시뮬레이션.
///
/// [payloadA]/[payloadB]: petPayload (프로토콜 문서 참조)
/// [rng]: 0~1 난수 함수 (테스트 주입용, 기본 Math.random)
///
/// 반환: {
///   turns: [{ turnNumber, aSkillName, aDamage, bSkillName, bDamage, aHp, bHp }],
///   aWins: bool, isDominant: bool, aExp: int, bExp: int
/// }
/// (관점 변환은 게이트웨이가 담당 — 여기서는 A/B 절대 관점)
export function simulateBattle(payloadA, payloadB, rng = Math.random) {
  const a = makeFighter(payloadA);
  const b = makeFighter(payloadB);
  const affAtoB = affinityMultiplier(a.type, b.type);
  const affBtoA = affinityMultiplier(b.type, a.type);

  // 선공 동전 던지기 — 랜덤 매칭에서 어느 쪽도 고정 이득이 없게
  const aFirst = rng() < 0.5;

  const turns = [];
  for (let turnNumber = 1; turnNumber <= MAX_TURNS; turnNumber++) {
    if (a.hp <= 0 || b.hp <= 0) break;
    tickDebuffs(a);
    tickDebuffs(b);

    let aDamage = 0;
    let bDamage = 0;
    let aSkill = null;
    let bSkill = null;

    const order = aFirst
      ? [[a, b, affAtoB], [b, a, affBtoA]]
      : [[b, a, affBtoA], [a, b, affAtoB]];

    for (const [attacker, defender, affinity] of order) {
      if (attacker.hp <= 0 || defender.hp <= 0) continue;
      const result = performAttack(attacker, defender, affinity, rng);
      applySelfBuff(attacker, result.skill);
      if (attacker === a) {
        aDamage = result.damage;
        aSkill = result.skill;
      } else {
        bDamage = result.damage;
        bSkill = result.skill;
      }
    }

    turns.push({
      turnNumber,
      aSkillName: aSkill?.name ?? a.skills[0].name,
      aDamage,
      bSkillName: bSkill?.name ?? b.skills[0].name,
      bDamage,
      aHp: a.hp,
      bHp: b.hp,
    });
  }

  // 승패 — KO 또는 30턴 후 남은 HP 판정 (동률이면 선공 아닌 쪽? → HP 비율 동일
  // 확률이 극히 낮아 단순히 A 우선하지 않고 HP 비교, 동률은 후공 승)
  const aWins = b.hp <= 0 ? true : a.hp <= 0 ? false : a.hp > b.hp;
  const winner = aWins ? a : b;
  const isDominant = winner.hp > Math.floor(winner.maxHp / 2);

  return {
    turns,
    aWins,
    isDominant,
    aExp: aWins ? (isDominant ? EXP_DOMINANT_WIN : EXP_WIN) : EXP_LOSS,
    bExp: !aWins ? (isDominant ? EXP_DOMINANT_WIN : EXP_WIN) : EXP_LOSS,
  };
}
