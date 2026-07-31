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

    test('모든 수치 0 + zeroStatStartDate null이면 시작일 기록', () async {
      final pet = _createPet(hunger: 0, happiness: 0, stamina: 0);
      repository.setPet(pet);

      final result = await useCase('test-pet');
      expect(result.isDead, false);
      expect(result.zeroStatStartDate, isNotNull);
    });

    test('모든 수치 0 + 5일 경과면 사망 처리', () async {
      final threeDaysAgo = DateTime.now().subtract(const Duration(days: 5));
      final dateStr =
          '${threeDaysAgo.year}-${threeDaysAgo.month.toString().padLeft(2, '0')}-${threeDaysAgo.day.toString().padLeft(2, '0')}';
      final pet = _createPet(
        hunger: 0,
        happiness: 0,
        stamina: 0,
        zeroStatStartDate: dateStr,
      );
      repository.setPet(pet);

      final result = await useCase('test-pet');
      expect(result.isDead, true);
      expect(result.deathDate, isNotNull);
    });

    test('모든 수치 0 + 4일 경과면 아직 생존', () async {
      final twoDaysAgo = DateTime.now().subtract(const Duration(days: 4));
      final dateStr =
          '${twoDaysAgo.year}-${twoDaysAgo.month.toString().padLeft(2, '0')}-${twoDaysAgo.day.toString().padLeft(2, '0')}';
      final pet = _createPet(
        hunger: 0,
        happiness: 0,
        stamina: 0,
        zeroStatStartDate: dateStr,
      );
      repository.setPet(pet);

      final result = await useCase('test-pet');
      expect(result.isDead, false);
    });

    test('수치 회복 시 zeroStatStartDate null로 초기화', () async {
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
