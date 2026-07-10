import 'package:flutter_test/flutter_test.dart';
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
}
