import 'package:flutter_test/flutter_test.dart';
import 'package:pocketfriend/domain/entities/pet.dart';
import 'package:pocketfriend/domain/repositories/pet_remote_repository.dart';
import 'package:pocketfriend/domain/repositories/pet_repository.dart';
import 'package:pocketfriend/domain/usecases/sync_pet_usecase.dart';

/// 간단한 Mock PetRepository (로컬)
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

  @override
  Future<List<Pet>> getAllPets() async => _pet != null ? [_pet!] : [];
}

/// 간단한 Mock PetRemoteRepository (서버)
class MockPetRemoteRepository implements PetRemoteRepository {
  Pet? _pet;
  int saveCallCount = 0;

  void setPet(Pet? pet) => _pet = pet;
  Pet? get currentPet => _pet;

  @override
  Future<Pet?> getPet(String petId) async => _pet;

  @override
  Future<void> savePet(Pet pet) async {
    _pet = pet;
    saveCallCount++;
  }

  @override
  Future<Pet> syncPet(String petId) async => _pet!;
}

/// 막 만든 초기 펫 (새 폰 첫 실행 상태)
Pet _freshPet({int? lastUpdated}) {
  final now = lastUpdated ?? DateTime.now().millisecondsSinceEpoch;
  return Pet(
    id: 'default-pet',
    hunger: 100,
    happiness: 100,
    stamina: 100,
    level: 1,
    exp: 0,
    evolutionStage: 1,
    lastUpdated: now,
    lastStatusDecayUpdated: now,
  );
}

/// 오래 키운 펫 (서버에 저장돼 있던 상태)
Pet _grownPet({int? lastUpdated}) {
  final ts = lastUpdated ??
      DateTime.now().millisecondsSinceEpoch - const Duration(days: 7).inMilliseconds;
  return Pet(
    id: 'default-pet',
    name: '용용이',
    hunger: 60,
    happiness: 70,
    stamina: 50,
    level: 12,
    exp: 540,
    evolutionStage: 3,
    lastUpdated: ts,
    lastStatusDecayUpdated: ts,
    totalSteps: 50000,
    totalExerciseMinutes: 300,
    feedAchievedCount: 20,
    sleepAchievedCount: 15,
    exerciseAchievedCount: 18,
    battleVictoryCount: 9,
    totalSetsRewarded: 14,
  );
}

void main() {
  late MockPetRepository local;
  late MockPetRemoteRepository remote;
  late SyncPetUseCase useCase;

  setUp(() {
    local = MockPetRepository();
    remote = MockPetRemoteRepository();
    useCase = SyncPetUseCase(localRepository: local, remoteRepository: remote);
  });

  group('SyncPetUseCase — 기기 이전 보호', () {
    test('로컬이 빈 펫이고 서버에 키우던 펫이 있으면 서버 펫 채택 (타임스탬프 무시)', () async {
      // 새 폰: 방금 생성된 빈 펫이라 lastUpdated가 서버 펫보다 최신
      local.setPet(_freshPet());
      remote.setPet(_grownPet());

      final result = await useCase('default-pet');

      expect(result.level, 12);
      expect(result.evolutionStage, 3);
      expect(local.currentPet!.level, 12, reason: '서버 펫이 로컬에 저장돼야 함');
      expect(remote.currentPet!.level, 12, reason: '서버 펫이 빈 펫으로 덮어써지면 안 됨');
    });

    test('새 폰에서 하루 걷고(exp·걸음만 쌓임) 로그인해도 서버 펫 채택', () async {
      final now = DateTime.now().millisecondsSinceEpoch;
      // 걸음·exp는 헬스 자동 동기화만으로 생기므로 durable 진척이 아님
      local.setPet(_freshPet(lastUpdated: now).copyWith(
        totalSteps: 8000,
        exp: 30,
        hunger: 70,
      ));
      remote.setPet(_grownPet());

      final result = await useCase('default-pet');

      expect(result.level, 12);
      expect(local.currentPet!.evolutionStage, 3);
    });

    test('양쪽 다 키우던 펫이면 기존 타임스탬프 규칙 유지 (최신 쪽 승)', () async {
      final now = DateTime.now().millisecondsSinceEpoch;
      local.setPet(_grownPet(lastUpdated: now - 10000).copyWith(level: 12));
      remote.setPet(_grownPet(lastUpdated: now).copyWith(level: 13));

      final result = await useCase('default-pet');

      expect(result.level, 13, reason: '서버가 최신이면 서버 승');
      expect(local.currentPet!.level, 13);
    });

    test('양쪽 다 키우던 펫이고 로컬이 최신이면 로컬 승', () async {
      final now = DateTime.now().millisecondsSinceEpoch;
      local.setPet(_grownPet(lastUpdated: now).copyWith(level: 13));
      remote.setPet(_grownPet(lastUpdated: now - 10000).copyWith(level: 12));

      final result = await useCase('default-pet');

      expect(result.level, 13);
      expect(remote.currentPet!.level, 13, reason: '로컬 최신본이 서버에 업로드돼야 함');
    });

    test('양쪽 다 빈 펫이면 타임스탬프 규칙으로 처리 (새로 키우기 전파 시나리오)', () async {
      final now = DateTime.now().millisecondsSinceEpoch;
      // '새로 키우기'는 초기화 펫을 서버에도 push하므로 양쪽 다 빈 펫이 됨
      local.setPet(_freshPet(lastUpdated: now));
      remote.setPet(_freshPet(lastUpdated: now - 5000).copyWith(name: '서버쪽'));

      final result = await useCase('default-pet');

      expect(result.name, '펫', reason: '동률/로컬 최신이면 로컬 우선');
    });

    test('서버에 펫이 없으면 로컬 펫 업로드', () async {
      local.setPet(_grownPet());
      remote.setPet(null);

      final result = await useCase('default-pet');

      expect(result.level, 12);
      expect(remote.currentPet!.level, 12);
      expect(remote.saveCallCount, 1);
    });

    test('remoteRepository가 없으면 로컬 펫 그대로 반환', () async {
      final offlineUseCase = SyncPetUseCase(localRepository: local);
      local.setPet(_grownPet());

      final result = await offlineUseCase('default-pet');

      expect(result.level, 12);
    });
  });

  group('SyncPetUseCase.hasDurableProgress', () {
    test('막 만든 펫은 false', () {
      expect(SyncPetUseCase.hasDurableProgress(_freshPet()), isFalse);
    });

    test('걸음·exp·수치 변화만으로는 false (헬스 자동 동기화 허용)', () {
      final pet = _freshPet().copyWith(
        totalSteps: 12000,
        totalExerciseMinutes: 40,
        exp: 45,
        hunger: 30,
        happiness: 20,
        stamina: 10,
      );
      expect(SyncPetUseCase.hasDurableProgress(pet), isFalse);
    });

    test('durable 지표는 각각 단독으로 true', () {
      final base = _freshPet();
      expect(
          SyncPetUseCase.hasDurableProgress(base.copyWith(level: 2)), isTrue);
      expect(SyncPetUseCase.hasDurableProgress(base.copyWith(evolutionStage: 2)),
          isTrue);
      expect(
          SyncPetUseCase.hasDurableProgress(
              base.copyWith(feedAchievedCount: 1)),
          isTrue);
      expect(
          SyncPetUseCase.hasDurableProgress(
              base.copyWith(sleepAchievedCount: 1)),
          isTrue);
      expect(
          SyncPetUseCase.hasDurableProgress(
              base.copyWith(exerciseAchievedCount: 1)),
          isTrue);
      expect(
          SyncPetUseCase.hasDurableProgress(
              base.copyWith(totalSetsRewarded: 1)),
          isTrue);
      expect(
          SyncPetUseCase.hasDurableProgress(
              base.copyWith(battleVictoryCount: 1)),
          isTrue);
      expect(
          SyncPetUseCase.hasDurableProgress(base.copyWith(resurrectCount: 1)),
          isTrue);
    });
  });
}
