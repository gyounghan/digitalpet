import 'package:flutter_test/flutter_test.dart';
import 'package:pocketfriend/domain/entities/activity_data.dart';
import 'package:pocketfriend/domain/entities/evolution_type.dart';
import 'package:pocketfriend/domain/entities/pet.dart';
import 'package:pocketfriend/domain/repositories/activity_repository.dart';
import 'package:pocketfriend/domain/repositories/pet_repository.dart';
import 'package:pocketfriend/domain/usecases/update_pet_from_activity_usecase.dart';

class _FakePetRepository implements PetRepository {
  Pet? _pet;
  void setPet(Pet pet) => _pet = pet;
  Pet? get currentPet => _pet;

  @override
  Future<Pet> getPet(String id) async => _pet!;
  @override
  Future<void> updatePet(Pet pet) async => _pet = pet;
  @override
  Future<void> savePet(Pet pet) async => _pet = pet;
  @override
  Future<bool> hasPet(String id) async => _pet != null;
  @override
  Future<List<Pet>> getAllPets() async => _pet != null ? [_pet!] : [];
}

class _FakeActivityRepository implements ActivityRepository {
  ActivityData today;
  _FakeActivityRepository(this.today);

  @override
  Future<ActivityData> getActivityData({
    required int startTime,
    required int endTime,
  }) async =>
      today;

  @override
  Future<ActivityData> getTodayActivityData() async => today;

  @override
  Future<ActivityData> getLast24HoursActivityData() async => today;
}

Pet _basePet({
  int happiness = 50,
  int stamina = 50,
  EvolutionType? evolutionType,
}) {
  return Pet(
    id: 'p',
    name: '테스트',
    hunger: 50,
    happiness: happiness,
    stamina: stamina,
    level: 1,
    exp: 0,
    evolutionStage: 1,
    evolutionType: evolutionType,
    lastUpdated: DateTime.now().millisecondsSinceEpoch,
    lastStatusDecayUpdated: DateTime.now().millisecondsSinceEpoch,
  );
}

void main() {
  group('UpdatePetFromActivityUseCase — 1:1 매핑 (운동 → happiness만)', () {
    test('걸음수 증가 시 stamina는 변하지 않고 happiness만 증가', () async {
      final petRepo = _FakePetRepository();
      final activityRepo = _FakeActivityRepository(
        ActivityData(
          steps: 3000,
          exerciseMinutes: 0,
          startTime: 0,
          endTime: 1,
        ),
      );
      petRepo.setPet(_basePet(happiness: 50, stamina: 50));

      final useCase = UpdatePetFromActivityUseCase(
        petRepository: petRepo,
        activityRepository: activityRepo,
      );
      final result = await useCase('p');

      // 3,000보 = 3 increment × happinessPer1000Steps(3) = +9 (배율 1.0 가정)
      expect(result.happiness, greaterThan(50));
      expect(result.stamina, 50, reason: '운동은 stamina에 영향이 없어야 함');
    });

    test('운동 시간 증가 시 stamina는 변하지 않고 happiness만 증가', () async {
      final petRepo = _FakePetRepository();
      final activityRepo = _FakeActivityRepository(
        ActivityData(
          steps: 0,
          exerciseMinutes: 20,
          startTime: 0,
          endTime: 1,
        ),
      );
      petRepo.setPet(_basePet(happiness: 50, stamina: 50));

      final useCase = UpdatePetFromActivityUseCase(
        petRepository: petRepo,
        activityRepository: activityRepo,
      );
      final result = await useCase('p');

      expect(result.happiness, greaterThan(50));
      expect(result.stamina, 50, reason: '운동 시간 누적도 stamina에 영향 없음');
    });

    test('5000보 단계 보너스도 happiness에만 적용', () async {
      final petRepo = _FakePetRepository();
      final activityRepo = _FakeActivityRepository(
        ActivityData(
          steps: 6000,
          exerciseMinutes: 0,
          startTime: 0,
          endTime: 1,
        ),
      );
      petRepo.setPet(_basePet(happiness: 30, stamina: 30));

      final useCase = UpdatePetFromActivityUseCase(
        petRepository: petRepo,
        activityRepository: activityRepo,
      );
      final result = await useCase('p');

      // 6000보 = 6 × 3(happinessPer1000Steps) + 10(stepsBonus5000) = +28 (배율 1.0)
      expect(result.happiness, 58);
      expect(result.stamina, 30, reason: '단계 보너스도 stamina 미영향');
    });

    test('delta 0이면 변동 없음', () async {
      final petRepo = _FakePetRepository();
      final activityRepo = _FakeActivityRepository(
        ActivityData(steps: 0, exerciseMinutes: 0, startTime: 0, endTime: 1),
      );
      petRepo.setPet(_basePet(happiness: 50, stamina: 50));

      final useCase = UpdatePetFromActivityUseCase(
        petRepository: petRepo,
        activityRepository: activityRepo,
      );
      final result = await useCase('p');

      expect(result.happiness, 50);
      expect(result.stamina, 50);
    });
  });
}
