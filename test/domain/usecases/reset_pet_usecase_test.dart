import 'package:flutter_test/flutter_test.dart';
import 'package:pocketfriend/domain/entities/pet.dart';
import 'package:pocketfriend/domain/repositories/pet_repository.dart';
import 'package:pocketfriend/domain/usecases/create_default_pet_usecase.dart';
import 'package:pocketfriend/domain/usecases/reset_pet_usecase.dart';

/// 간단한 Mock PetRepository
class MockPetRepository implements PetRepository {
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

  Future<void> deletePet(String id) async => _pet = null;

  Future<List<Pet>> getAllPets() async => _pet != null ? [_pet!] : [];
}

/// 충분히 성장한 기존 펫 (초기화 대상)
Pet _grownPet() {
  final now = DateTime.now().millisecondsSinceEpoch;
  return Pet(
    id: 'default-pet',
    name: '용용이',
    hunger: 80,
    happiness: 70,
    stamina: 60,
    level: 12,
    exp: 540,
    evolutionStage: 3,
    lastUpdated: now,
    lastStatusDecayUpdated: now,
    totalSteps: 50000,
    totalExerciseMinutes: 300,
    totalIdleHours: 120,
    battleVictoryCount: 9,
    resurrectCount: 2,
    totalSetsRewarded: 14,
  );
}

void main() {
  late ResetPetUseCase useCase;
  late MockPetRepository repository;

  setUp(() {
    repository = MockPetRepository();
    useCase = ResetPetUseCase(CreateDefaultPetUseCase(repository));
  });

  group('ResetPetUseCase', () {
    test('성장한 펫을 1단계 털뭉치 기본값으로 초기화', () async {
      repository.setPet(_grownPet());

      final result = await useCase('default-pet');

      expect(result.level, 1);
      expect(result.exp, 0);
      expect(result.evolutionStage, 1);
      expect(result.hunger, 100);
      expect(result.happiness, 100);
      expect(result.stamina, 100);
      expect(result.evolutionType, isNull);
    });

    test('누적 기록·진화 등급이 모두 리셋됨', () async {
      repository.setPet(_grownPet());

      final result = await useCase('default-pet');

      expect(result.totalSteps, 0);
      expect(result.totalExerciseMinutes, 0);
      expect(result.totalIdleHours, 0);
      expect(result.battleVictoryCount, 0);
      expect(result.resurrectCount, 0);
      expect(result.evolutionGrade, '');
    });

    test('초기화 결과가 repository에 저장됨', () async {
      repository.setPet(_grownPet());

      await useCase('default-pet');

      expect(repository.currentPet?.level, 1);
      expect(repository.currentPet?.evolutionStage, 1);
    });

    test('기존 펫이 없어도 기본 펫을 생성', () async {
      final result = await useCase('default-pet');

      expect(result.level, 1);
      expect(repository.currentPet, isNotNull);
    });
  });
}
