import 'package:flutter_test/flutter_test.dart';
import 'package:pocketfriend/domain/entities/pet.dart';
import 'package:pocketfriend/domain/repositories/pet_repository.dart';
import 'package:pocketfriend/domain/usecases/shake_step_bonus_usecase.dart';

class FakePetRepository implements PetRepository {
  Pet? _pet;

  void setPet(Pet pet) => _pet = pet;

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

Pet _createPet({
  int totalSteps = 0,
  int todayAlternativeExerciseCount = 0,
}) {
  final now = DateTime.now().millisecondsSinceEpoch;
  return Pet(
    id: 'test-pet',
    hunger: 80,
    happiness: 80,
    stamina: 80,
    level: 1,
    exp: 0,
    evolutionStage: 1,
    lastUpdated: now,
    lastStatusDecayUpdated: now,
    totalSteps: totalSteps,
    todayAlternativeExerciseCount: todayAlternativeExerciseCount,
    lastGoalResetDate:
        '${DateTime.now().year}-${DateTime.now().month.toString().padLeft(2, '0')}-${DateTime.now().day.toString().padLeft(2, '0')}',
  );
}

void main() {
  group('ShakeStepBonusUseCase', () {
    late FakePetRepository repo;
    late ShakeStepBonusUseCase useCase;

    setUp(() {
      repo = FakePetRepository();
      useCase = ShakeStepBonusUseCase(repo);
    });

    test('흔들기 10회 → totalSteps +50 (10 * 5)', () async {
      repo.setPet(_createPet(totalSteps: 100));

      final result = await useCase('test-pet', 10);
      expect(result.totalSteps, 150);
      expect(result.todayAlternativeExerciseCount, 1);
    });

    test('흔들기 0회 → 변경 없음', () async {
      repo.setPet(_createPet(totalSteps: 100));

      final result = await useCase('test-pet', 0);
      expect(result.totalSteps, 100);
      expect(result.todayAlternativeExerciseCount, 0);
    });

    test('흔들기 200회 → 100회로 cap, totalSteps +500', () async {
      repo.setPet(_createPet(totalSteps: 0));

      final result = await useCase('test-pet', 200);
      expect(result.totalSteps, 500);
      expect(result.todayAlternativeExerciseCount, 1);
    });

    test('하루 1회 사용 후 더 이상 사용 불가', () async {
      final usedPet =
          _createPet(totalSteps: 0, todayAlternativeExerciseCount: 1);
      repo.setPet(usedPet);

      expect(useCase.canUse(usedPet), false);

      final result = await useCase('test-pet', 50);
      // 사용 한도 초과 시 변경 없음
      expect(result.totalSteps, 0);
      expect(result.todayAlternativeExerciseCount, 1);
    });

    test('canUse: 미사용이면 true', () {
      final pet = _createPet(todayAlternativeExerciseCount: 0);
      expect(useCase.canUse(pet), true);
    });
  });
}
