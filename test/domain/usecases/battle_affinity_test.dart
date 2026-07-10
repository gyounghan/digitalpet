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
}
