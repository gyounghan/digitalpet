import 'package:flutter_test/flutter_test.dart';
import 'package:pocketfriend/data/models/pet_model.dart';
import 'package:pocketfriend/domain/entities/pet.dart';

void main() {
  /// 테스트용 기본 PetModel 생성 헬퍼
  PetModel createDefaultPetModel({
    String id = 'test-pet',
    String name = '테스트펫',
    int hunger = 80,
    int happiness = 80,
    int stamina = 80,
    int level = 5,
    int exp = 50,
    int evolutionStage = 1,
    int lastUpdated = 1000000,
    int lastStatusDecayUpdated = 1000000,
    int battleVictoryCount = 0,
    String todayEvent = '',
    String lastEventDate = '',
    int consecutiveLoginDays = 0,
    String lastLoginDate = '',
    int todayBattleCount = 0,
    int todayLoginCount = 0,
    int lastLoginTime = 0,
  }) {
    return PetModel(
      id: id,
      name: name,
      hunger: hunger,
      happiness: happiness,
      stamina: stamina,
      level: level,
      exp: exp,
      evolutionStage: evolutionStage,
      lastUpdated: lastUpdated,
      lastStatusDecayUpdated: lastStatusDecayUpdated,
      battleVictoryCount: battleVictoryCount,
      todayEvent: todayEvent,
      lastEventDate: lastEventDate,
      consecutiveLoginDays: consecutiveLoginDays,
      lastLoginDate: lastLoginDate,
      todayBattleCount: todayBattleCount,
      todayLoginCount: todayLoginCount,
      lastLoginTime: lastLoginTime,
    );
  }

  group('PetModel 생성자 - 새 필드 기본값 테스트', () {
    test('새 필드들이 기본값으로 초기화된다', () {
      final pet = PetModel(
        id: 'test',
        hunger: 80,
        happiness: 80,
        stamina: 80,
        level: 1,
        exp: 0,
        evolutionStage: 0,
        lastUpdated: 1000,
        lastStatusDecayUpdated: 1000,
      );

      expect(pet.battleVictoryCount, 0);
      expect(pet.todayEvent, '');
      expect(pet.lastEventDate, '');
      expect(pet.consecutiveLoginDays, 0);
      expect(pet.lastLoginDate, '');
      expect(pet.todayBattleCount, 0);
      expect(pet.todayLoginCount, 0);
      expect(pet.lastLoginTime, 0);
    });

    test('새 필드들에 값을 지정하면 해당 값이 사용된다', () {
      final pet = createDefaultPetModel(
        battleVictoryCount: 10,
        todayEvent: 'sunny',
        lastEventDate: '2026-03-28',
        consecutiveLoginDays: 5,
        lastLoginDate: '2026-03-28',
        todayBattleCount: 3,
        todayLoginCount: 2,
        lastLoginTime: 999999,
      );

      expect(pet.battleVictoryCount, 10);
      expect(pet.todayEvent, 'sunny');
      expect(pet.lastEventDate, '2026-03-28');
      expect(pet.consecutiveLoginDays, 5);
      expect(pet.lastLoginDate, '2026-03-28');
      expect(pet.todayBattleCount, 3);
      expect(pet.todayLoginCount, 2);
      expect(pet.lastLoginTime, 999999);
    });
  });

  group('PetModel.fromJson - 새 필드 테스트', () {
    test('JSON에 새 필드가 포함되면 정확히 파싱된다', () {
      final json = {
        'id': 'json-pet',
        'name': '제이슨펫',
        'hunger': 70,
        'happiness': 60,
        'stamina': 50,
        'level': 3,
        'exp': 20,
        'evolutionStage': 1,
        'lastUpdated': 2000,
        'lastStatusDecayUpdated': 2000,
        'battleVictoryCount': 7,
        'todayEvent': 'cozy',
        'lastEventDate': '2026-03-27',
        'consecutiveLoginDays': 3,
        'lastLoginDate': '2026-03-27',
        'todayBattleCount': 2,
        'todayLoginCount': 4,
        'lastLoginTime': 123456,
      };

      final pet = PetModel.fromJson(json);

      expect(pet.battleVictoryCount, 7);
      expect(pet.todayEvent, 'cozy');
      expect(pet.lastEventDate, '2026-03-27');
      expect(pet.consecutiveLoginDays, 3);
      expect(pet.lastLoginDate, '2026-03-27');
      expect(pet.todayBattleCount, 2);
      expect(pet.todayLoginCount, 4);
      expect(pet.lastLoginTime, 123456);
    });

    test('JSON에 새 필드가 없으면 기본값이 사용된다', () {
      final json = {
        'id': 'old-pet',
        'hunger': 50,
        'happiness': 50,
        'stamina': 50,
        'level': 1,
        'exp': 0,
        'evolutionStage': 0,
        'lastUpdated': 1000,
        'lastStatusDecayUpdated': 1000,
      };

      final pet = PetModel.fromJson(json);

      expect(pet.battleVictoryCount, 0);
      expect(pet.todayEvent, '');
      expect(pet.lastEventDate, '');
      expect(pet.consecutiveLoginDays, 0);
      expect(pet.lastLoginDate, '');
      expect(pet.todayBattleCount, 0);
      expect(pet.todayLoginCount, 0);
      expect(pet.lastLoginTime, 0);
    });
  });

  group('PetModel.toJson - 새 필드 테스트', () {
    test('toJson에 새 필드들이 모두 포함된다', () {
      final pet = createDefaultPetModel(
        battleVictoryCount: 5,
        todayEvent: 'adventure',
        lastEventDate: '2026-03-28',
        consecutiveLoginDays: 10,
        lastLoginDate: '2026-03-28',
        todayBattleCount: 1,
        todayLoginCount: 3,
        lastLoginTime: 555555,
      );

      final json = pet.toJson();

      expect(json['battleVictoryCount'], 5);
      expect(json['todayEvent'], 'adventure');
      expect(json['lastEventDate'], '2026-03-28');
      expect(json['consecutiveLoginDays'], 10);
      expect(json['lastLoginDate'], '2026-03-28');
      expect(json['todayBattleCount'], 1);
      expect(json['todayLoginCount'], 3);
      expect(json['lastLoginTime'], 555555);
    });

    test('fromJson -> toJson 라운드트립이 일관된다', () {
      final original = createDefaultPetModel(
        battleVictoryCount: 12,
        todayEvent: 'happy_day',
        lastEventDate: '2026-03-28',
        consecutiveLoginDays: 7,
        lastLoginDate: '2026-03-28',
        todayBattleCount: 5,
        todayLoginCount: 2,
        lastLoginTime: 888888,
      );

      final json = original.toJson();
      final restored = PetModel.fromJson(json);

      expect(restored.battleVictoryCount, original.battleVictoryCount);
      expect(restored.todayEvent, original.todayEvent);
      expect(restored.lastEventDate, original.lastEventDate);
      expect(restored.consecutiveLoginDays, original.consecutiveLoginDays);
      expect(restored.lastLoginDate, original.lastLoginDate);
      expect(restored.todayBattleCount, original.todayBattleCount);
      expect(restored.todayLoginCount, original.todayLoginCount);
      expect(restored.lastLoginTime, original.lastLoginTime);
    });
  });

  group('PetModel.fromEntity - 새 필드 테스트', () {
    test('Pet 엔티티에서 새 필드들이 올바르게 복사된다', () {
      final pet = Pet(
        id: 'entity-pet',
        name: '엔티티펫',
        hunger: 90,
        happiness: 85,
        stamina: 75,
        level: 10,
        exp: 100,
        evolutionStage: 2,
        lastUpdated: 3000,
        lastStatusDecayUpdated: 3000,
        battleVictoryCount: 15,
        todayEvent: 'tasty',
        lastEventDate: '2026-03-28',
        consecutiveLoginDays: 14,
        lastLoginDate: '2026-03-28',
        todayBattleCount: 4,
        todayLoginCount: 6,
        lastLoginTime: 777777,
      );

      final model = PetModel.fromEntity(pet);

      expect(model.battleVictoryCount, 15);
      expect(model.todayEvent, 'tasty');
      expect(model.lastEventDate, '2026-03-28');
      expect(model.consecutiveLoginDays, 14);
      expect(model.lastLoginDate, '2026-03-28');
      expect(model.todayBattleCount, 4);
      expect(model.todayLoginCount, 6);
      expect(model.lastLoginTime, 777777);
    });
  });

  group('PetModel.toEntity - 새 필드 테스트', () {
    test('toEntity에서 새 필드들이 올바르게 복사된다', () {
      final model = createDefaultPetModel(
        battleVictoryCount: 20,
        todayEvent: 'normal',
        lastEventDate: '2026-03-27',
        consecutiveLoginDays: 30,
        lastLoginDate: '2026-03-27',
        todayBattleCount: 2,
        todayLoginCount: 1,
        lastLoginTime: 444444,
      );

      final entity = model.toEntity();

      expect(entity.battleVictoryCount, 20);
      expect(entity.todayEvent, 'normal');
      expect(entity.lastEventDate, '2026-03-27');
      expect(entity.consecutiveLoginDays, 30);
      expect(entity.lastLoginDate, '2026-03-27');
      expect(entity.todayBattleCount, 2);
      expect(entity.todayLoginCount, 1);
      expect(entity.lastLoginTime, 444444);
    });

    test('fromEntity -> toEntity 라운드트립이 일관된다', () {
      final originalEntity = Pet(
        id: 'roundtrip',
        hunger: 50,
        happiness: 50,
        stamina: 50,
        level: 1,
        exp: 0,
        evolutionStage: 0,
        lastUpdated: 1000,
        lastStatusDecayUpdated: 1000,
        battleVictoryCount: 8,
        todayEvent: 'sunny',
        lastEventDate: '2026-03-28',
        consecutiveLoginDays: 2,
        lastLoginDate: '2026-03-28',
        todayBattleCount: 1,
        todayLoginCount: 3,
        lastLoginTime: 111111,
      );

      final model = PetModel.fromEntity(originalEntity);
      final restoredEntity = model.toEntity();

      expect(restoredEntity.battleVictoryCount, originalEntity.battleVictoryCount);
      expect(restoredEntity.todayEvent, originalEntity.todayEvent);
      expect(restoredEntity.lastEventDate, originalEntity.lastEventDate);
      expect(restoredEntity.consecutiveLoginDays, originalEntity.consecutiveLoginDays);
      expect(restoredEntity.lastLoginDate, originalEntity.lastLoginDate);
      expect(restoredEntity.todayBattleCount, originalEntity.todayBattleCount);
      expect(restoredEntity.todayLoginCount, originalEntity.todayLoginCount);
      expect(restoredEntity.lastLoginTime, originalEntity.lastLoginTime);
    });
  });

  group('PetModel.copyWith - 새 필드 테스트', () {
    test('copyWith으로 새 필드를 개별 변경할 수 있다', () {
      final original = createDefaultPetModel();

      final updated = original.copyWith(
        battleVictoryCount: 5,
        todayEvent: 'cozy',
        lastEventDate: '2026-03-28',
        consecutiveLoginDays: 7,
        lastLoginDate: '2026-03-28',
        todayBattleCount: 3,
        todayLoginCount: 2,
        lastLoginTime: 999999,
      );

      expect(updated.battleVictoryCount, 5);
      expect(updated.todayEvent, 'cozy');
      expect(updated.lastEventDate, '2026-03-28');
      expect(updated.consecutiveLoginDays, 7);
      expect(updated.lastLoginDate, '2026-03-28');
      expect(updated.todayBattleCount, 3);
      expect(updated.todayLoginCount, 2);
      expect(updated.lastLoginTime, 999999);

      // 기존 필드는 변경되지 않음
      expect(updated.id, original.id);
      expect(updated.name, original.name);
      expect(updated.hunger, original.hunger);
    });

    test('copyWith에서 지정하지 않은 새 필드는 원래 값을 유지한다', () {
      final original = createDefaultPetModel(
        battleVictoryCount: 10,
        todayEvent: 'sunny',
        lastEventDate: '2026-03-27',
        consecutiveLoginDays: 5,
        lastLoginDate: '2026-03-27',
        todayBattleCount: 2,
        todayLoginCount: 1,
        lastLoginTime: 333333,
      );

      final updated = original.copyWith(hunger: 50);

      expect(updated.hunger, 50);
      expect(updated.battleVictoryCount, 10);
      expect(updated.todayEvent, 'sunny');
      expect(updated.lastEventDate, '2026-03-27');
      expect(updated.consecutiveLoginDays, 5);
      expect(updated.lastLoginDate, '2026-03-27');
      expect(updated.todayBattleCount, 2);
      expect(updated.todayLoginCount, 1);
      expect(updated.lastLoginTime, 333333);
    });

    test('copyWith은 PetModel 타입을 반환한다', () {
      final original = createDefaultPetModel();
      final updated = original.copyWith(battleVictoryCount: 1);

      expect(updated, isA<PetModel>());
    });

    test('battleVictoryCount만 변경', () {
      final original = createDefaultPetModel(battleVictoryCount: 3);
      final updated = original.copyWith(battleVictoryCount: 4);

      expect(updated.battleVictoryCount, 4);
      expect(updated.todayEvent, original.todayEvent);
    });

    test('todayEvent만 변경', () {
      final original = createDefaultPetModel(todayEvent: 'sunny');
      final updated = original.copyWith(todayEvent: 'cozy');

      expect(updated.todayEvent, 'cozy');
      expect(updated.battleVictoryCount, original.battleVictoryCount);
    });

    test('consecutiveLoginDays만 변경', () {
      final original = createDefaultPetModel(consecutiveLoginDays: 3);
      final updated = original.copyWith(consecutiveLoginDays: 4);

      expect(updated.consecutiveLoginDays, 4);
    });

    test('todayBattleCount만 변경', () {
      final original = createDefaultPetModel(todayBattleCount: 1);
      final updated = original.copyWith(todayBattleCount: 2);

      expect(updated.todayBattleCount, 2);
    });

    test('todayLoginCount만 변경', () {
      final original = createDefaultPetModel(todayLoginCount: 0);
      final updated = original.copyWith(todayLoginCount: 1);

      expect(updated.todayLoginCount, 1);
    });

    test('lastLoginTime만 변경', () {
      final original = createDefaultPetModel(lastLoginTime: 100000);
      final updated = original.copyWith(lastLoginTime: 200000);

      expect(updated.lastLoginTime, 200000);
    });
  });

  group('PetModel super 호출 - 새 필드가 Pet 엔티티에 전달되는지 검증', () {
    test('PetModel은 Pet의 서브클래스이며 새 필드에 접근 가능하다', () {
      final model = createDefaultPetModel(
        battleVictoryCount: 99,
        todayEvent: 'adventure',
        consecutiveLoginDays: 365,
      );

      // Pet 타입으로 캐스팅해도 새 필드에 접근 가능
      final Pet pet = model;
      expect(pet.battleVictoryCount, 99);
      expect(pet.todayEvent, 'adventure');
      expect(pet.consecutiveLoginDays, 365);
    });
  });
}
