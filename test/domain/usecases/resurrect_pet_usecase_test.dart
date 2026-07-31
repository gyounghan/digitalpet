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

  group('ResurrectPetUseCase (긴 잠 깨우기)', () {
    test('무료 깨우기 시 isDead=false, 수치 30/30/30', () async {
      final sleepingPet = _createPet(isDead: true, resurrectCount: 0);
      repository.setPet(sleepingPet);

      final result = await useCase('test-pet');
      expect(result.isDead, false);
      expect(result.hunger, 30);
      expect(result.happiness, 30);
      expect(result.stamina, 30);
    });

    test('완전 회복 깨우기(광고) 시 100/100/100', () async {
      final sleepingPet = _createPet(isDead: true, resurrectCount: 0);
      repository.setPet(sleepingPet);

      final result = await useCase('test-pet', fullRecovery: true);
      expect(result.hunger, 100);
      expect(result.happiness, 100);
      expect(result.stamina, 100);
    });

    test('깨우기 시 resurrectCount 증가', () async {
      final sleepingPet = _createPet(isDead: true, resurrectCount: 3);
      repository.setPet(sleepingPet);

      final result = await useCase('test-pet');
      expect(result.resurrectCount, 4);
    });

    test('여러 번 깨워도 레벨과 경험치는 유지 (패널티 없음)', () async {
      final sleepingPet = _createPet(isDead: true, resurrectCount: 5);
      repository.setPet(sleepingPet);

      final result = await useCase('test-pet');
      expect(result.level, 5);
      expect(result.exp, 200);
      expect(result.evolutionStage, 2);
    });

    test('잠들지 않은 펫에 호출하면 예외 발생', () async {
      final alivePet = _createPet(isDead: false);
      repository.setPet(alivePet);

      expect(
        () => useCase('test-pet'),
        throwsException,
      );
    });

    test('깨우기 후 repository에 저장됨', () async {
      final sleepingPet = _createPet(isDead: true);
      repository.setPet(sleepingPet);

      await useCase('test-pet');
      expect(repository.currentPet?.isDead, false);
      expect(repository.currentPet?.hunger, 30);
    });
  });
}
