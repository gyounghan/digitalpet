import 'package:flutter_test/flutter_test.dart';
import 'package:pocketfriend/core/theme/species_theme.dart';
import 'package:pocketfriend/domain/entities/evolution_type.dart';

void main() {
  group('SpeciesTheme.forType', () {
    test('tiger → tiger 테마 (blue-gray)', () {
      final theme = SpeciesTheme.forType(EvolutionType.tiger);
      expect(theme.primary, SpeciesTheme.tiger.primary);
      expect(theme.primaryDeep, SpeciesTheme.tiger.primaryDeep);
    });

    test('bird → bird 테마 (red-orange)', () {
      final theme = SpeciesTheme.forType(EvolutionType.bird);
      expect(theme.primary, SpeciesTheme.bird.primary);
    });

    test('turtle → turtle 테마 (green)', () {
      final theme = SpeciesTheme.forType(EvolutionType.turtle);
      expect(theme.primary, SpeciesTheme.turtle.primary);
    });

    test('snake → snake 테마 (blue)', () {
      final theme = SpeciesTheme.forType(EvolutionType.snake);
      expect(theme.primary, SpeciesTheme.snake.primary);
    });

    test('null → defaultTheme', () {
      final theme = SpeciesTheme.forType(null);
      expect(theme.primary, SpeciesTheme.defaultTheme.primary);
    });

    test('각 종 테마는 서로 다른 primary 색상을 가진다', () {
      final colors = <int>{
        SpeciesTheme.tiger.primary.toARGB32(),
        SpeciesTheme.bird.primary.toARGB32(),
        SpeciesTheme.turtle.primary.toARGB32(),
        SpeciesTheme.snake.primary.toARGB32(),
      };
      expect(colors.length, 4);
    });
  });

  group('SpeciesTheme.labelFor', () {
    test('각 사신수 한국어 라벨', () {
      expect(SpeciesTheme.labelFor(EvolutionType.tiger), '백호');
      expect(SpeciesTheme.labelFor(EvolutionType.bird), '주작');
      expect(SpeciesTheme.labelFor(EvolutionType.turtle), '현무');
      expect(SpeciesTheme.labelFor(EvolutionType.snake), '청룡');
      // 종 미결정(털뭉치 단계)은 '???' 대신 '털뭉치'로 표기
      expect(SpeciesTheme.labelFor(null), '털뭉치');
    });
  });
}
