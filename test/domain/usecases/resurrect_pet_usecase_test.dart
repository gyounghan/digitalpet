import 'package:flutter_test/flutter_test.dart';
import 'package:pocketfriend/domain/entities/pet.dart';
import 'package:pocketfriend/domain/repositories/pet_repository.dart';
import 'package:pocketfriend/domain/usecases/resurrect_pet_usecase.dart';

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

Pet _createPet({
  bool isDead = false,
  int resurrectCount = 0,
}) {
  return Pet(
    id: 'test-pet',
    hunger: 0,
    happiness: 0,
    stamina: 0,
    level: 5,
    exp: 200,
    evolutionStage: 2,
    lastUpdated: DateTime.now().millisecondsSinceEpoch,
    lastStatusDecayUpdated: DateTime.now().millisecondsSinceEpoch,
    isDead: isDead,
    deathDate: isDead ? DateTime.now().millisecondsSinceEpoch : null,
    zeroStatStartDate: isDead ? '2024-01-01' : null,
    resurrectCount: resurrectCount,
  );
}

void main() {
  late ResurrectPetUseCase useCase;
  late MockPetRepository repository;

  setUp(() {
    repository = MockPetRepository();
    useCase = ResurrectPetUseCase(repository);
  });

  group('ResurrectPetUseCase', () {
    test('사망한 펫 부활 시 isDead=false, 수치 50/50/50', () async {
      final deadPet = _createPet(isDead: true, resurrectCount: 0);
      repository.setPet(deadPet);

      final result = await useCase('test-pet');
      expect(result.isDead, false);
      expect(result.hunger, 50);
      expect(result.happiness, 50);
      expect(result.stamina, 50);
    });

    test('부활 시 resurrectCount 증가', () async {
      final deadPet = _createPet(isDead: true, resurrectCount: 3);
      repository.setPet(deadPet);

      final result = await useCase('test-pet');
      expect(result.resurrectCount, 4);
    });

    test('부활 시 레벨과 경험치는 유지', () async {
      final deadPet = _createPet(isDead: true);
      repository.setPet(deadPet);

      final result = await useCase('test-pet');
      expect(result.level, 5);
      expect(result.exp, 200);
      expect(result.evolutionStage, 2);
    });

    test('살아있는 펫에 호출하면 예외 발생', () async {
      final alivePet = _createPet(isDead: false);
      repository.setPet(alivePet);

      expect(
        () => useCase('test-pet'),
        throwsException,
      );
    });

    test('부활 후 repository에 저장됨', () async {
      final deadPet = _createPet(isDead: true);
      repository.setPet(deadPet);

      await useCase('test-pet');
      expect(repository.currentPet?.isDead, false);
      expect(repository.currentPet?.hunger, 50);
    });
  });
}
