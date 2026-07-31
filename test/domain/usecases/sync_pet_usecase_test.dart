import 'package:flutter_test/flutter_test.dart';
import 'package:pocketfriend/domain/entities/pet.dart';
import 'package:pocketfriend/domain/repositories/pet_repository.dart';
import 'package:pocketfriend/domain/repositories/pet_remote_repository.dart';
import 'package:pocketfriend/domain/usecases/sync_pet_usecase.dart';

/// Fake Local Repository
class FakeLocalPetRepository implements PetRepository {
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

/// Fake Remote Repository
class FakeRemotePetRepository implements PetRemoteRepository {
  Pet? _pet;
  void setPet(Pet pet) => _pet = pet;
  Pet? get currentPet => _pet;

  @override
  Future<Pet?> getPet(String petId) async => _pet;
  @override
  Future<void> savePet(Pet pet) async => _pet = pet;
  @override
  Future<Pet> syncPet(String petId) async => _pet!;
}

Pet _createPet({
  required int lastUpdated,
  int hunger = 80,
  String name = '테스트',
}) {
  return Pet(
    id: 'test',
    name: name,
    hunger: hunger,
    happiness: 80,
    stamina: 80,
    level: 1,
    exp: 0,
    evolutionStage: 1,
    lastUpdated: lastUpdated,
    lastStatusDecayUpdated: lastUpdated,
  );
}

void main() {
  group('SyncPetUseCase', () {
    late FakeLocalPetRepository localRepo;
    late FakeRemotePetRepository remoteRepo;
    late SyncPetUseCase useCase;

    setUp(() {
      localRepo = FakeLocalPetRepository();
      remoteRepo = FakeRemotePetRepository();
      useCase = SyncPetUseCase(
        localRepository: localRepo,
        remoteRepository: remoteRepo,
      );
    });

    test('remoteRepository null이면 로컬 데이터만 반환', () async {
      final useCaseNoRemote = SyncPetUseCase(
        localRepository: localRepo,
        remoteRepository: null,
      );
      localRepo.setPet(_createPet(lastUpdated: 100));

      final result = await useCaseNoRemote('test');
      expect(result.lastUpdated, 100);
    });

    test('서버에 데이터 없으면 로컬 데이터를 서버에 업로드', () async {
      localRepo.setPet(_createPet(lastUpdated: 100));
      // remoteRepo._pet == null

      final result = await useCase('test');
      expect(result.lastUpdated, 100);
      expect(remoteRepo.currentPet, isNotNull);
      expect(remoteRepo.currentPet!.lastUpdated, 100);
    });

    test('로컬이 최신이면 로컬 데이터로 양쪽 업데이트', () async {
      localRepo.setPet(_createPet(lastUpdated: 200, name: '로컬'));
      remoteRepo.setPet(_createPet(lastUpdated: 100, name: '서버'));

      final result = await useCase('test');
      expect(result.lastUpdated, 200);
      expect(result.name, '로컬');
      expect(remoteRepo.currentPet!.name, '로컬');
    });

    test('서버가 최신이면 서버 데이터로 양쪽 업데이트', () async {
      localRepo.setPet(_createPet(lastUpdated: 100, name: '로컬'));
      remoteRepo.setPet(_createPet(lastUpdated: 200, name: '서버'));

      final result = await useCase('test');
      expect(result.lastUpdated, 200);
      expect(result.name, '서버');
      expect(localRepo.currentPet!.name, '서버');
    });
  });
}
