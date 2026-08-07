import 'package:flutter_test/flutter_test.dart';
import 'package:pocketfriend/domain/entities/pet.dart';
import 'package:pocketfriend/domain/repositories/pet_remote_repository.dart';
import 'package:pocketfriend/domain/repositories/pet_repository.dart';
import 'package:pocketfriend/domain/usecases/sync_pet_usecase.dart';

/// 서버 동기화 중 낡은 스냅샷 역행 방지 회귀 테스트.
///
/// "급식 직후 먹이주기 버튼이 다시 살아나던" 고질병의 원인 중 하나:
/// 동기화가 시작 시점의 로컬 스냅샷을 들고 원격 조회(최대 5초 타임아웃)를
/// 기다린 뒤 그 스냅샷 기준으로 비교·저장하면, 그 사이 사용자의
/// 급식 기록(todayFedMealSlots 등)이 되돌아간다.
/// → 원격 조회가 끝난 뒤 로컬을 재조회해 비교해야 한다.

class _FakePetRepo implements PetRepository {
  Pet? pet;
  @override
  Future<Pet> getPet(String id) async => pet!;
  @override
  Future<void> updatePet(Pet p) async => pet = p;
  @override
  Future<void> savePet(Pet p) async => pet = p;
  @override
  Future<bool> hasPet(String id) async => pet != null;
  @override
  Future<List<Pet>> getAllPets() async => pet != null ? [pet!] : [];
}

/// getPet이 호출되는 순간 [onGetPet]을 실행해 "원격 조회 중 로컬 변경"을
/// 재현하는 가짜 원격 저장소.
class _FakeRemoteRepo implements PetRemoteRepository {
  final Pet? remotePet;
  final void Function()? onGetPet;
  Pet? lastSaved;

  _FakeRemoteRepo({this.remotePet, this.onGetPet});

  @override
  Future<Pet?> getPet(String petId) async {
    onGetPet?.call();
    return remotePet;
  }

  @override
  Future<void> savePet(Pet pet) async => lastSaved = pet;

  @override
  Future<Pet> syncPet(String petId) async => remotePet!;
}

Pet _pet({required int lastUpdated, int fedSlots = 0, int hunger = 50}) {
  return Pet(
    id: 'p',
    hunger: hunger,
    happiness: 80,
    stamina: 80,
    level: 1,
    exp: 0,
    evolutionStage: 1,
    lastUpdated: lastUpdated,
    lastStatusDecayUpdated: lastUpdated,
    todayFedMealSlots: fedSlots,
  );
}

void main() {
  test('원격 조회 중 급식이 발생해도 급식 기록이 보존된다', () async {
    final local = _FakePetRepo()..pet = _pet(lastUpdated: 1000);

    // 원격 getPet이 도는 동안(타임아웃 대기 재현) 사용자가 급식:
    // 슬롯 마킹 + lastUpdated 갱신
    final remote = _FakeRemoteRepo(
      remotePet: null, // 서버에 데이터 없음 (첫 업로드 경로)
      onGetPet: () {
        local.pet = _pet(lastUpdated: 2000, fedSlots: 1, hunger: 70);
      },
    );

    final sync =
        SyncPetUseCase(localRepository: local, remoteRepository: remote);
    final result = await sync('p');

    expect(result.todayFedMealSlots, 1, reason: '급식 기록이 역행하면 안 됨');
    expect(result.hunger, 70);
    expect(local.pet!.todayFedMealSlots, 1);
    expect(remote.lastSaved!.todayFedMealSlots, 1,
        reason: '서버 업로드도 최신 로컬 기준');
  });

  test('원격이 더 낡았으면 조회 중 변경된 로컬이 이긴다', () async {
    final local = _FakePetRepo()..pet = _pet(lastUpdated: 1000);
    final remote = _FakeRemoteRepo(
      remotePet: _pet(lastUpdated: 1500), // 스냅샷(1000)보다는 새것
      onGetPet: () {
        // 조회 중 급식 → 로컬이 최신(2000)이 됨
        local.pet = _pet(lastUpdated: 2000, fedSlots: 1);
      },
    );

    final sync =
        SyncPetUseCase(localRepository: local, remoteRepository: remote);
    final result = await sync('p');

    expect(result.lastUpdated, 2000, reason: '재조회한 로컬(2000) > 원격(1500)');
    expect(result.todayFedMealSlots, 1);
    expect(local.pet!.todayFedMealSlots, 1);
  });

  test('타임스탬프 동률이면 로컬 우선 (서버가 로컬 기록을 덮지 않는다)', () async {
    final local =
        _FakePetRepo()..pet = _pet(lastUpdated: 3000, fedSlots: 1);
    final remote = _FakeRemoteRepo(remotePet: _pet(lastUpdated: 3000));

    final sync =
        SyncPetUseCase(localRepository: local, remoteRepository: remote);
    final result = await sync('p');

    expect(result.todayFedMealSlots, 1);
    expect(local.pet!.todayFedMealSlots, 1);
  });

  test('원격이 진짜 최신이면 원격 데이터를 채택한다 (기기 이전 복원 경로)', () async {
    final local = _FakePetRepo()..pet = _pet(lastUpdated: 1000);
    final remote =
        _FakeRemoteRepo(remotePet: _pet(lastUpdated: 9000, hunger: 90));

    final sync =
        SyncPetUseCase(localRepository: local, remoteRepository: remote);
    final result = await sync('p');

    expect(result.lastUpdated, 9000);
    expect(result.hunger, 90);
    expect(local.pet!.lastUpdated, 9000, reason: '로컬에 원격 최신본 반영');
  });
}
