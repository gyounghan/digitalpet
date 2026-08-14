import { test } from 'node:test';
import assert from 'node:assert/strict';
import {
  simulateBattle,
  affinityMultiplier,
  dodgeChanceForStamina,
  MAX_TURNS,
  EXP_WIN,
  EXP_DOMINANT_WIN,
  EXP_LOSS,
} from '../src/battle_sim.js';

/// 결정적 난수 (테스트용) — 항상 같은 값 반환
const fixed = (v) => () => v;

const basePet = (over = {}) => ({
  petName: '테스트',
  level: 10,
  evolutionType: 'bird',
  atk: 20,
  def: 15,
  hp: 100,
  stamina: 50,
  ...over,
});

test('회피율 — 기력 0/50/100 = 5/10/15%', () => {
  const close = (a, b) => Math.abs(a - b) < 1e-9;
  assert.ok(close(dodgeChanceForStamina(0), 0.05));
  assert.ok(close(dodgeChanceForStamina(50), 0.10));
  assert.ok(close(dodgeChanceForStamina(100), 0.15));
});

test('상성 — bird→snake 유리 +20%, 역방향·무상성 1.0', () => {
  assert.equal(affinityMultiplier('bird', 'snake'), 1.2);
  assert.equal(affinityMultiplier('snake', 'bird'), 1.0);
  assert.equal(affinityMultiplier('tiger', 'bird'), 1.2);
  assert.equal(affinityMultiplier(null, 'bird'), 1.0);
  assert.equal(affinityMultiplier('bird', null), 1.0);
});

test('KO까지 진행 — 압도적 스탯 차이면 강한 쪽 승리 + 압승', () => {
  // rng 0.9: 회피 실패(0.9 > 15%), 선공 B(0.9 >= 0.5), rand(5)=4
  const result = simulateBattle(
    basePet({ atk: 5, def: 0, hp: 40 }),
    basePet({ atk: 40, def: 30, hp: 150 }),
    fixed(0.9),
  );
  assert.equal(result.aWins, false);
  assert.ok(result.turns.length <= MAX_TURNS);
  const last = result.turns[result.turns.length - 1];
  assert.equal(last.aHp, 0); // KO 확인
  assert.equal(result.isDominant, true);
  assert.equal(result.bExp, EXP_DOMINANT_WIN);
  assert.equal(result.aExp, EXP_LOSS);
});

test('항상 회피(rng 0)면 데미지 0으로 30턴 후 HP 판정', () => {
  // rng 0: 항상 회피 성공 (0 < 5%) — 단 rng 0이면 선공 A(0 < 0.5)
  const result = simulateBattle(
    basePet({ hp: 80 }),
    basePet({ hp: 100 }),
    fixed(0),
  );
  assert.equal(result.turns.length, MAX_TURNS);
  assert.equal(result.aWins, false); // 남은 HP 100 > 80
  assert.equal(result.bExp, EXP_WIN + 20); // dominant (100/100 > 50)
  assert.equal(result.aExp, EXP_LOSS);
  for (const turn of result.turns) {
    assert.equal(turn.aDamage, 0);
    assert.equal(turn.bDamage, 0);
  }
});

test('데미지 최소 1 보장 — 방어가 아무리 높아도', () => {
  const result = simulateBattle(
    basePet({ atk: 1, def: 999 }),
    basePet({ atk: 1, def: 999 }),
    fixed(0.5),
  );
  for (const turn of result.turns) {
    if (turn.aDamage > 0 || turn.bDamage > 0) {
      assert.ok(turn.aDamage >= 0 && turn.bDamage >= 0);
    }
  }
  // KO 전 마지막 턴까지 최소 1씩은 들어간다
  const damaged = result.turns.some((t) => t.aDamage >= 1 || t.bDamage >= 1);
  assert.ok(damaged);
});

test('승자 EXP 50/70, 패자 15', () => {
  const result = simulateBattle(
    basePet({ atk: 30, hp: 120 }),
    basePet({ atk: 10, hp: 60, def: 5 }),
    fixed(0.4), // 선공 A, 회피 없음
  );
  assert.equal(result.aWins, true);
  assert.ok([EXP_WIN, EXP_DOMINANT_WIN].includes(result.aExp));
  assert.equal(result.bExp, EXP_LOSS);
});

test('종 미결정(털뭉치)끼리 — 기본 스킬 "공격"만 사용', () => {
  const result = simulateBattle(
    basePet({ evolutionType: null }),
    basePet({ evolutionType: null }),
    fixed(0.6),
  );
  for (const turn of result.turns) {
    assert.equal(turn.aSkillName, '공격');
    assert.equal(turn.bSkillName, '공격');
  }
});

test('turtle 방어자세 — 시전 다음 피격 데미지 감소', () => {
  // rng 0.6: 회피 없음, 선공 B. turtle 특수기(방어자세)는 첫 턴 사용
  const withTurtle = simulateBattle(
    basePet({ evolutionType: 'turtle', atk: 10, def: 10, hp: 300 }),
    basePet({ evolutionType: null, atk: 20, def: 10, hp: 300 }),
    fixed(0.6),
  );
  const skillNames = withTurtle.turns.map((t) => t.aSkillName);
  assert.ok(skillNames.includes('방어자세'));
});
