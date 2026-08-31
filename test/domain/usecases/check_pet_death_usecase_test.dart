import 'package:flutter_test/flutter_test.dart';
import 'package:pocketfriend/domain/entities/pet.dart';
import 'package:pocketfriend/domain/repositories/pet_repository.dart';
import 'package:pocketfriend/domain/usecases/check_pet_death_usecase.dart';

/// 간단한 Mock PetRepository
class MockPetRepository implements PetRepository {
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

  Future<void> deletePet(String id) async => _pet = null;

  Future<List<Pet>> getAllPets() async => _pet != null ? [_pet!] : [];
}

Pet _createPet({
  int hunger = 50,
  int happiness = 50,
  int stamina = 50,
  bool isDead = false,
  String? zeroStatStartDate,
}) {
  return Pet(
    id: 'test-pet',
    hunger: hunger,
    happiness: happiness,
    stamina: stamina,
    level: 1,
    exp: 0,
    evolutionStage: 1,
    lastUpdated: DateTime.now().millisecondsSinceEpoch,
    lastStatusDecayUpdated: DateTime.now().millisecondsSinceEpoch,
    isDead: isDead,
    zeroStatStartDate: zeroStatStartDate,
  );
}

void main() {
  late CheckPetDeathUseCase useCase;
  late MockPetRepository repository;

  setUp(() {
    repository = MockPetRepository();
    useCase = CheckPetDeathUseCase(repository);
  });

  group('CheckPetDeathUseCase', () {
    test('살아있는 펫 + 수치 정상이면 변경 없음', () async {
      final pet = _createPet(hunger: 50, happiness: 50, stamina: 50);
      repository.setPet(pet);

      final result = await useCase('test-pet');
      expect(result.isDead, false);
      expect(result.zeroStatStartDate, isNull);
    });

    test('포만감 0 + zeroStatStartDate null이면 굶기 시작 시각 기록', () async {
      final pet = _createPet(hunger: 0, happiness: 70, stamina: 70);
      repository.setPet(pet);

      final result = await useCase('test-pet');
      expect(result.isDead, false);
      expect(result.zeroStatStartDate, isNotNull);
    });

    test('포만감 0 + 임계(하루) 경과면 긴 잠 처리 — 행복·기력 남아있어도', () async {
      final overThreshold = DateTime.now().subtract(const Duration(
          days: CheckPetDeathUseCase.deathThresholdDays, hours: 1));
      final pet = _createPet(
        hunger: 0,
        happiness: 40,
        stamina: 60,
        zeroStatStartDate: overThreshold.toIso8601String(),
      );
      repository.setPet(pet);

      final result = await useCase('test-pet');
      expect(result.isDead, true);
      expect(result.deathDate, isNotNull);
    });

    test('포만감 0 + 하루 미만이면 아직 생존', () async {
      final underThreshold =
          DateTime.now().subtract(const Duration(hours: 23));
      final pet = _createPet(
        hunger: 0,
        happiness: 0,
        stamina: 0,
        zeroStatStartDate: underThreshold.toIso8601String(),
      );
      repository.setPet(pet);

      final result = await useCase('test-pet');
      expect(result.isDead, false);
    });

    test('포만감 회복 시 zeroStatStartDate null로 초기화', () async {
      final pet = _createPet(
        hunger: 10,
        happiness: 0,
        stamina: 0,
        zeroStatStartDate: '2024-01-01',
      );
      repository.setPet(pet);

      final result = await useCase('test-pet');
      expect(result.isDead, false);
      expect(result.zeroStatStartDate, isNull);
    });

    test('이미 사망한 펫은 그대로 반환', () async {
      final pet = _createPet(isDead: true);
      repository.setPet(pet);

      final result = await useCase('test-pet');
      expect(result.isDead, true);
    });
  });
}
