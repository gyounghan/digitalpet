import 'package:flutter_test/flutter_test.dart';
import 'package:pocketfriend/domain/constants/species_growth_config.dart';
import 'package:pocketfriend/domain/entities/evolution_type.dart';

void main() {
  group('SpeciesGrowthConfig', () {
    test('identity 배율은 모든 값이 1.0', () {
      final m = StatMultipliers.identity();
      expect(m.hunger, 1.0);
      expect(m.happiness, 1.0);
      expect(m.stamina, 1.0);
      expect(m.exp, 1.0);
    });

    test('evolutionType null이면 identity 반환', () {
      final gain = SpeciesGrowthConfig.getGainMultipliers(null);
      final decay = SpeciesGrowthConfig.getDecayMultipliers(null);
      expect(gain.hunger, 1.0);
      expect(gain.happiness, 1.0);
      expect(decay.stamina, 1.0);
    });

    group('증가 배율', () {
      test('bird: happiness 1.3, stamina 0.85', () {
        final m = SpeciesGrowthConfig.getGainMultipliers(EvolutionType.bird);
        expect(m.happiness, 1.3);
        expect(m.stamina, 0.85);
        expect(m.hunger, 1.0);
        expect(m.exp, 1.0);
      });

      test('snake: hunger 1.25, happiness 0.8', () {
        final m = SpeciesGrowthConfig.getGainMultipliers(EvolutionType.snake);
        expect(m.hunger, 1.25);
        expect(m.happiness, 0.8);
      });

      test('tiger: exp 1.3, 나머지 1.0', () {
        final m = SpeciesGrowthConfig.getGainMultipliers(EvolutionType.tiger);
        expect(m.exp, 1.3);
        expect(m.hunger, 1.0);
        expect(m.happiness, 1.0);
        expect(m.stamina, 1.0);
      });

      test('turtle: stamina 1.2', () {
        final m = SpeciesGrowthConfig.getGainMultipliers(EvolutionType.turtle);
        expect(m.stamina, 1.2);
      });
    });

    group('감소 배율', () {
      test('bird: stamina 1.2 (빨리 감소)', () {
        final m = SpeciesGrowthConfig.getDecayMultipliers(EvolutionType.bird);
        expect(m.stamina, 1.2);
        expect(m.hunger, 1.0);
      });

      test('snake: hunger 0.8 (느리게 감소), happiness 1.15 (빨리 감소)', () {
        final m = SpeciesGrowthConfig.getDecayMultipliers(EvolutionType.snake);
        expect(m.hunger, 0.8);
        expect(m.happiness, 1.15);
      });

      test('tiger: 모든 값 1.0 (균형형)', () {
        final m = SpeciesGrowthConfig.getDecayMultipliers(EvolutionType.tiger);
        expect(m.hunger, 1.0);
        expect(m.happiness, 1.0);
        expect(m.stamina, 1.0);
      });

      test('turtle: happiness 0.85, stamina 0.8 (안정형)', () {
        final m = SpeciesGrowthConfig.getDecayMultipliers(EvolutionType.turtle);
        expect(m.happiness, 0.85);
        expect(m.stamina, 0.8);
      });
    });

    test('모든 EvolutionType에 대해 gainMultipliers가 정의됨', () {
      for (final type in EvolutionType.values) {
        final m = SpeciesGrowthConfig.getGainMultipliers(type);
        expect(m.hunger, isNonZero);
        expect(m.happiness, isNonZero);
        expect(m.stamina, isNonZero);
        expect(m.exp, isNonZero);
      }
    });
  });
}
