import 'package:flutter_test/flutter_test.dart';
import 'package:pocketfriend/domain/entities/pet.dart';
import 'package:pocketfriend/domain/entities/pet_background.dart';

void main() {
  group('pet_background', () {
    test('기본 id는 에셋이 비어 있다 (그라데이션)', () {
      final def = backgroundForId(kDefaultBackgroundId);
      expect(def.assetPath, isEmpty);
    });

    test('알려진 id는 해당 배경, 없는 id는 기본으로 폴백', () {
      expect(backgroundForId('forest_pond').assetPath,
          'assets/backgrounds/forest_pond.png');
      expect(backgroundForId('없는배경').assetPath, isEmpty);
    });

    test('카탈로그에 숲속 연못·아늑한 방이 포함된다', () {
      final ids = backgroundCatalog.map((b) => b.id).toList();
      expect(ids, containsAll(<String>['forest_pond', 'cozy_room']));
    });

    test('Pet.equippedBackground는 copyWith로 갱신된다', () {
      final pet = Pet(
        id: 'p',
        name: '테스트',
        hunger: 50,
        happiness: 50,
        stamina: 50,
        exp: 0,
        level: 1,
        evolutionStage: 1,
        lastUpdated: 0,
        lastStatusDecayUpdated: 0,
      );
      expect(pet.equippedBackground, '');
      expect(pet.copyWith(equippedBackground: 'cozy_room').equippedBackground,
          'cozy_room');
    });
  });
}
