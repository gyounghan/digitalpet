import 'package:flutter_test/flutter_test.dart';
import 'package:pocketfriend/core/theme/species_theme.dart';
import 'package:pocketfriend/domain/entities/evolution_type.dart';

void main() {
  group('정식 로스터 (obtainableSpecies)', () {
    test('사신수 4 + 영물 6 = 10종', () {
      expect(obtainableSpecies.length, 10);
    });

    test('두꺼비는 포함, 은퇴 종은 제외', () {
      expect(obtainableSpecies, contains(EvolutionType.toad));
      expect(obtainableSpecies, contains(EvolutionType.bear));
      for (final retired in [
        EvolutionType.dokkaebi,
        EvolutionType.hwangryong,
        EvolutionType.otter,
        EvolutionType.owl,
        EvolutionType.crane,
      ]) {
        expect(obtainableSpecies, isNot(contains(retired)));
      }
    });
  });

  group('두꺼비 종 배선', () {
    test('테마·한글명이 두꺼비로 매핑된다', () {
      expect(SpeciesTheme.forType(EvolutionType.toad), SpeciesTheme.toad);
      expect(SpeciesTheme.labelFor(EvolutionType.toad), '두꺼비');
    });

    test('두꺼비는 히든(영물) 종으로 분류된다', () {
      expect(EvolutionType.toad.isHiddenSpecies, isTrue);
    });
  });
}
