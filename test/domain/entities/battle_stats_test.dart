import 'package:flutter_test/flutter_test.dart';
import 'package:pocketfriend/domain/entities/pet.dart';
import 'package:pocketfriend/domain/entities/evolution_type.dart';

/// 전투 스탯(battleAtk/battleDef/battleHp) 회귀 테스트.
///
/// 핵심 보증 — "잘 키운 질"이 전투력이 된다:
///  1. 레벨이 오르면 ATK/DEF/HP 모두 상승 (예전엔 ATK/DEF에 레벨 무반영이었음)
///  2. 누적 세트가 ATK/DEF 영구 성장, 누적 걸음이 HP 영구 성장
///  3. 컨디션은 ±20% 보정만 — 방치해도 레벨/누적 골격은 안 무너짐
///  4. 종/진화단계 보너스 반영

Pet _pet({
  int level = 1,
  int hunger = 50,
  int happiness = 50,
  int stamina = 50,
  int evolutionStage = 1,
  EvolutionType? evolutionType,
  int totalSteps = 0,
  int totalSetsRewarded = 0,
}) {
  final now = DateTime.now().millisecondsSinceEpoch;
  return Pet(
    id: 'p',
    hunger: hunger,
    happiness: happiness,
    stamina: stamina,
    level: level,
    exp: 0,
    evolutionStage: evolutionStage,
    evolutionType: evolutionType,
    lastUpdated: now,
    lastStatusDecayUpdated: now,
    totalSteps: totalSteps,
    totalSetsRewarded: totalSetsRewarded,
  );
}

void main() {
  group('전투 스탯 — 영구 성장 골격', () {
    test('중립 컨디션(50) 기본값', () {
      final pet = _pet();
      // ATK = (5 + 1 + 0세트 + 0단계 + 0종) × 1 = 6
      expect(pet.battleAtk, 6);
      expect(pet.battleDef, 6);
      // HP = (50 + 2 + 0걸음 + 0종) × 1 = 52
      expect(pet.battleHp, 52);
    });

    test('레벨이 오르면 ATK/DEF/HP 모두 상승 (레벨 반영 핵심 수정)', () {
      final lv1 = _pet(level: 1);
      final lv20 = _pet(level: 20);
      expect(lv20.battleAtk > lv1.battleAtk, true,
          reason: '레벨 20 ATK가 레벨 1보다 커야 함');
      expect(lv20.battleDef > lv1.battleDef, true);
      expect(lv20.battleHp > lv1.battleHp, true);
      // ATK = 5 + 20 = 25
      expect(lv20.battleAtk, 25);
    });

    test('누적 세트가 ATK/DEF 영구 성장 (5세트당 +1, 최대 +15)', () {
      final base = _pet(level: 1);
      final grown = _pet(level: 1, totalSetsRewarded: 50);
      // setBonus = min(50/5, 15) = 10 → ATK = 5+1+10 = 16
      expect(grown.battleAtk, base.battleAtk + 10);
      expect(grown.battleDef, base.battleDef + 10);

      // 상한 +15 (100세트여도 +15)
      final capped = _pet(level: 1, totalSetsRewarded: 100);
      expect(capped.battleAtk, 5 + 1 + 15);
    });

    test('누적 걸음이 HP 영구 성장 (5000보당 +1, 최대 +20)', () {
      final base = _pet(level: 1);
      final walker = _pet(level: 1, totalSteps: 50000);
      // stepBonus = min(50000/5000, 20) = 10 → HP = 50+2+10 = 62
      expect(walker.battleHp, base.battleHp + 10);

      final capped = _pet(level: 1, totalSteps: 99999999);
      expect(capped.battleHp, 50 + 2 + 20);
    });
  });

  group('전투 스탯 — 컨디션 ±보정', () {
    test('행복 100/50/0 → ATK 가산/중립/감산', () {
      final high = _pet(happiness: 100);
      final mid = _pet(happiness: 50);
      final low = _pet(happiness: 0);
      expect(high.battleAtk > mid.battleAtk, true);
      expect(mid.battleAtk > low.battleAtk, true);
      // base 6: 100→6×1.2=7.2→7, 0→6×0.8=4.8→5
      expect(high.battleAtk, 7);
      expect(low.battleAtk, 5);
    });

    test('방치(컨디션 0)해도 레벨/누적 골격은 무너지지 않음', () {
      // 레벨 20 + 누적 세트 50, 단 컨디션 전부 0
      final neglected = _pet(
        level: 20,
        happiness: 0,
        stamina: 0,
        hunger: 0,
        totalSetsRewarded: 50,
      );
      // base ATK = 5 + 20 + 10 = 35, ×0.8 = 28 → 여전히 높음
      expect(neglected.battleAtk, 28);
      // 레벨1 최상 컨디션 펫보다도 강해야 한다 (질의 우위)
      final freshButHappy = _pet(level: 1, happiness: 100);
      expect(neglected.battleAtk > freshButHappy.battleAtk, true);
    });
  });

  group('전투 스탯 — 종/진화단계 보너스', () {
    test('종 보너스: bird ATK+3, turtle DEF+2·HP+7 (밸런스 재조정)', () {
      final neutral = _pet();
      final bird = _pet(evolutionType: EvolutionType.bird);
      final turtle = _pet(evolutionType: EvolutionType.turtle);
      expect(bird.battleAtk, neutral.battleAtk + 3);
      expect(turtle.battleDef, neutral.battleDef + 2);
      expect(turtle.battleHp, neutral.battleHp + 7);
    });

    test('진화단계 보너스: stage4 ATK/DEF +7', () {
      final stage1 = _pet(evolutionStage: 1);
      final stage4 = _pet(evolutionStage: 4);
      expect(stage4.battleAtk, stage1.battleAtk + 7);
      expect(stage4.battleDef, stage1.battleDef + 7);
    });
  });
}
