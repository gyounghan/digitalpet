import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:pocketfriend/domain/entities/battle_style.dart';
import 'package:pocketfriend/domain/entities/evolution_type.dart';
import 'package:pocketfriend/domain/usecases/battle_with_activity_usecase.dart';

/// 상성 배수 밸런스 — 한쪽만 보정(유리 +20%, 불리 페널티 없음)
///
/// 예전엔 유리 ×1.3 + 불리 ×0.7 조합이 데미지비 ~1.86배를 만들어
/// 상성이 스탯·스킬을 압도했다. 이제 유리한 쪽만 ×1.2, 불리한 쪽은 ×1.0.
void main() {
  // 상성 순환: bird→snake→turtle→tiger→bird
  const advantage = {
    EvolutionType.bird: EvolutionType.snake,
    EvolutionType.snake: EvolutionType.turtle,
    EvolutionType.turtle: EvolutionType.tiger,
    EvolutionType.tiger: EvolutionType.bird,
  };

  group('BattleWithActivityUseCase.affinityMultiplierFor', () {
    test('유리한 상성은 +20%(×1.2)', () {
      for (final entry in advantage.entries) {
        expect(
          BattleWithActivityUseCase.affinityMultiplierFor(
              entry.key, entry.value),
          1.2,
          reason: '${entry.key} → ${entry.value} 는 유리',
        );
      }
    });

    test('불리한 상성은 페널티 없음(×1.0)', () {
      for (final entry in advantage.entries) {
        // 방어자가 공격자에게 유리 = 공격자는 불리
        expect(
          BattleWithActivityUseCase.affinityMultiplierFor(
              entry.value, entry.key),
          1.0,
          reason: '${entry.value} → ${entry.key} 는 불리',
        );
      }
    });

    test('상성 무관계(마주보는 종·자기 자신)는 ×1.0', () {
      expect(
        BattleWithActivityUseCase.affinityMultiplierFor(
            EvolutionType.bird, EvolutionType.turtle),
        1.0,
      );
      expect(
        BattleWithActivityUseCase.affinityMultiplierFor(
            EvolutionType.bird, EvolutionType.bird),
        1.0,
      );
    });

    test('양측 데미지 스윙이 1.2배로 제한된다 (예전 1.86배 → 완화)', () {
      // 유리한 쪽: 내 배수 1.2 / 상대 배수 1.0 = 1.2배 (예전 1.3/0.7 ≈ 1.86)
      final mine = BattleWithActivityUseCase.affinityMultiplierFor(
          EvolutionType.bird, EvolutionType.snake);
      final theirs = BattleWithActivityUseCase.affinityMultiplierFor(
          EvolutionType.snake, EvolutionType.bird);
      expect(mine / theirs, closeTo(1.2, 1e-9));
    });

    test('null 타입(미진화)은 ×1.0', () {
      expect(
        BattleWithActivityUseCase.affinityMultiplierFor(
            null, EvolutionType.bird),
        1.0,
      );
      expect(
        BattleWithActivityUseCase.affinityMultiplierFor(
            EvolutionType.bird, null),
        1.0,
      );
    });
  });

  group('BattleWithActivityUseCase.applyDamageShield (방어자세)', () {
    test('충전이 있으면 피해를 감소율만큼 깎고 충전 1 소모', () {
      final r = BattleWithActivityUseCase.applyDamageShield(100, 0.5, 1);
      expect(r.damage, 50);
      expect(r.charges, 0);
      expect(r.reduction, 0.0); // 마지막 충전 소진 → 만료
    });

    test('reductionDuration만큼만 정확히 방어 — 1충전이면 딱 1회 피격 방어', () {
      // 시전 시 충전 1. 첫 피격에서 소모돼 만료됨.
      var reduction = 0.5;
      var charges = 1;
      final hit1 = BattleWithActivityUseCase.applyDamageShield(80, reduction, charges);
      expect(hit1.damage, 40); // 1회차 감소
      reduction = hit1.reduction;
      charges = hit1.charges;

      final hit2 = BattleWithActivityUseCase.applyDamageShield(80, reduction, charges);
      expect(hit2.damage, 80); // 2회차는 방어 없음 (충전 소진)
      expect(hit2.charges, 0);
    });

    test('2충전이면 연속 2회 피격 방어 후 만료', () {
      final h1 = BattleWithActivityUseCase.applyDamageShield(100, 0.5, 2);
      expect(h1.damage, 50);
      expect(h1.charges, 1);
      expect(h1.reduction, 0.5); // 아직 남음

      final h2 = BattleWithActivityUseCase.applyDamageShield(100, h1.reduction, h1.charges);
      expect(h2.damage, 50);
      expect(h2.charges, 0);
      expect(h2.reduction, 0.0); // 만료

      final h3 = BattleWithActivityUseCase.applyDamageShield(100, h2.reduction, h2.charges);
      expect(h3.damage, 100); // 방어 없음
    });

    test('충전 없거나 감소율 0이면 원본 피해 그대로 통과', () {
      expect(BattleWithActivityUseCase.applyDamageShield(70, 0.5, 0).damage, 70);
      expect(BattleWithActivityUseCase.applyDamageShield(70, 0.0, 3).damage, 70);
    });
  });

  group('BattleWithActivityUseCase.generateOpponentStats (AI 미러링)', () {
    BattleStats avgOpponent(BattleStats player, {int level = 10, int n = 500}) {
      int atk = 0, def = 0, hp = 0;
      final random = Random(42);
      for (int i = 0; i < n; i++) {
        final o = BattleWithActivityUseCase.generateOpponentStats(
            player, level, EvolutionType.tiger, random);
        atk += o.attack;
        def += o.defense;
        hp += o.hp;
      }
      return BattleStats(attack: atk ~/ n, defense: def ~/ n, hp: hp ~/ n);
    }

    test('상대 스탯은 플레이어 육성을 따라 스케일한다 (절대치 고정 아님)', () {
      final weak = BattleStats(attack: 15, defense: 15, hp: 60);
      final strong = BattleStats(attack: 45, defense: 45, hp: 110);
      final vsWeak = avgOpponent(weak);
      final vsStrong = avgOpponent(strong);
      // 강한 플레이어의 상대가 확실히 더 강해야 함 (예전엔 레벨만 반영돼 동일)
      expect(vsStrong.attack, greaterThan(vsWeak.attack + 15));
      expect(vsStrong.defense, greaterThan(vsWeak.defense + 15));
      expect(vsStrong.hp, greaterThan(vsWeak.hp + 25));
    });

    test('미러는 완전 복제가 아니다 — 골격 혼합으로 잘 키운 플레이어가 평균 우위', () {
      final strong = BattleStats(attack: 45, defense: 45, hp: 110);
      final o = avgOpponent(strong);
      // 골격(레벨10 ≈ atk 23)이 15% 섞여 상대 평균은 플레이어보다 낮다
      expect(o.attack, lessThan(strong.attack));
      expect(o.hp, lessThan(strong.hp));
    });

    test('변동 범위: 혼합 기대값의 ±15% 안에 있다', () {
      final player = BattleStats(attack: 30, defense: 30, hp: 90);
      const level = 10;
      // 골격 atk = 5 + 10 + 6 + 2(tiger) = 23, 혼합 = 23×0.15 + 30×0.85 = 28.95
      const blendedAtk = 23 * 0.15 + 30 * 0.85;
      final random = Random(7);
      for (int i = 0; i < 300; i++) {
        final o = BattleWithActivityUseCase.generateOpponentStats(
            player, level, EvolutionType.tiger, random);
        expect(o.attack, greaterThanOrEqualTo((blendedAtk * 0.85).floor()));
        expect(o.attack, lessThanOrEqualTo((blendedAtk * 1.15).ceil()));
      }
    });
  });

  group('BattleStyle — EV 중립 검증 (atk-def/2 공식 기준)', () {
    test('공격형·방어형의 (ATK증감 - DEF증감/2) 기대값이 균형형과 같다', () {
      // 데미지 교환 EV = atk×atkMul - (def×defMul)/2 를 스탯 30/30 기준으로 비교
      double ev(BattleStyle s) => 30 * s.attackMultiplier - (30 * s.defenseMultiplier) / 2;
      // 내 공격 이득(atk 증가분)과 내 피격 손실(def 감소분/2)이 상쇄 → net 0
      double net(BattleStyle s) =>
          (30 * s.attackMultiplier - 30) - (30 - 30 * s.defenseMultiplier) / 2;
      expect(net(BattleStyle.attacker), closeTo(net(BattleStyle.balanced), 0.01));
      expect(net(BattleStyle.defender), closeTo(net(BattleStyle.balanced), 0.01));
      // EV 함수 자체도 대칭 확인 (attacker와 defender가 balanced 대비 등거리)
      final base = ev(BattleStyle.balanced);
      expect(ev(BattleStyle.attacker) - base,
          closeTo(base - ev(BattleStyle.defender), 0.01));
    });
  });
}
