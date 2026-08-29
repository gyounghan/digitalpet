import 'package:flutter_test/flutter_test.dart';
import 'package:pocketfriend/domain/entities/pet.dart';
import 'package:pocketfriend/domain/repositories/pet_repository.dart';
import 'package:pocketfriend/domain/usecases/grant_extra_battle_usecase.dart';

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

String _today() {
  final now = DateTime.now();
  return '${now.year}-${now.month.toString().padLeft(2, '0')}-'
      '${now.day.toString().padLeft(2, '0')}';
}

Pet _pet({
  int todayBattleCount = 0,
  int todayOnlineBattleCount = 0,
  int todayBattleAdBonus = 0,
  int todayOnlineBattleAdBonus = 0,
  String? lastGoalResetDate,
}) {
  final now = DateTime.now().millisecondsSinceEpoch;
  return Pet(
    id: 'test-pet',
    hunger: 60,
    happiness: 60,
    stamina: 60,
    level: 5,
    exp: 0,
    evolutionStage: 2,
    lastUpdated: now,
    lastStatusDecayUpdated: now,
    todayBattleCount: todayBattleCount,
    todayOnlineBattleCount: todayOnlineBattleCount,
    todayBattleAdBonus: todayBattleAdBonus,
    todayOnlineBattleAdBonus: todayOnlineBattleAdBonus,
    lastGoalResetDate: lastGoalResetDate ?? _today(),
  );
}

void main() {
  group('Pet — 하루 배틀 한도 (AI·온라인 분리)', () {
    test('기본 한도는 각각 5회', () {
      final pet = _pet();
      expect(Pet.maxBattlesPerDay, 5);
      expect(pet.remainingAiBattles, 5);
      expect(pet.remainingOnlineBattles, 5);
    });

    test('AI 5판 소모 시 AI만 불가, 온라인은 그대로 가능', () {
      final pet = _pet(todayBattleCount: 5);
      expect(pet.canBattleAi, isFalse);
      expect(pet.canBattleOnline, isTrue);
      expect(pet.remainingOnlineBattles, 5);
    });

    test('온라인 5판 소모 시 온라인만 불가, AI는 그대로 가능', () {
      final pet = _pet(todayOnlineBattleCount: 5);
      expect(pet.canBattleOnline, isFalse);
      expect(pet.canBattleAi, isTrue);
    });

    test('광고 추가분은 해당 모드 한도만 늘린다', () {
      final pet = _pet(
        todayBattleCount: 5,
        todayOnlineBattleCount: 5,
        todayBattleAdBonus: 1,
      );
      expect(pet.canBattleAi, isTrue, reason: 'AI는 광고 +1로 다시 가능');
      expect(pet.remainingAiBattles, 1);
      expect(pet.canBattleOnline, isFalse, reason: '온라인 광고분은 없음');
    });

    test('자정이 지나 리셋 대기 상태면 남은 횟수는 기본 한도로 표시', () {
      final pet = _pet(
        todayBattleCount: 5,
        todayBattleAdBonus: 2,
        lastGoalResetDate: '2000-01-01',
      );
      expect(pet.remainingAiBattles, 5);
      expect(pet.canBattleAi, isTrue);
    });

    test('resetDailyGoals는 배틀 카운트와 광고 추가분을 모두 리셋', () {
      final reset = _pet(
        todayBattleCount: 5,
        todayOnlineBattleCount: 3,
        todayBattleAdBonus: 2,
        todayOnlineBattleAdBonus: 1,
      ).resetDailyGoals();
      expect(reset.todayBattleCount, 0);
      expect(reset.todayOnlineBattleCount, 0);
      expect(reset.todayBattleAdBonus, 0);
      expect(reset.todayOnlineBattleAdBonus, 0);
    });
  });

  group('GrantExtraBattleUseCase', () {
    late _FakePetRepository repository;
    late GrantExtraBattleUseCase useCase;

    setUp(() {
      repository = _FakePetRepository();
      useCase = GrantExtraBattleUseCase(repository);
    });

    test('AI 모드: todayBattleAdBonus만 +1', () async {
      repository.setPet(_pet(todayBattleCount: 5));

      final result = await useCase('test-pet', online: false);

      expect(result.todayBattleAdBonus, 1);
      expect(result.todayOnlineBattleAdBonus, 0);
      expect(result.canBattleAi, isTrue, reason: '광고 후 한 판 더 가능해야 함');
      expect(repository.currentPet!.todayBattleAdBonus, 1,
          reason: '저장소에도 반영돼야 함');
    });

    test('온라인 모드: todayOnlineBattleAdBonus만 +1', () async {
      repository.setPet(_pet(todayOnlineBattleCount: 5));

      final result = await useCase('test-pet', online: true);

      expect(result.todayOnlineBattleAdBonus, 1);
      expect(result.todayBattleAdBonus, 0);
      expect(result.canBattleOnline, isTrue);
    });

    test('광고를 여러 번 보면 그만큼 누적', () async {
      repository.setPet(_pet(todayBattleCount: 5));

      await useCase('test-pet', online: false);
      await useCase('test-pet', online: false);
      final result = await useCase('test-pet', online: false);

      expect(result.todayBattleAdBonus, 3);
      expect(result.remainingAiBattles, 3);
    });

    test('자정이 지난 상태면 리셋 후 +1 — 어제 카운트·광고분 이월 없음', () async {
      repository.setPet(_pet(
        todayBattleCount: 5,
        todayBattleAdBonus: 3,
        lastGoalResetDate: '2000-01-01',
      ));

      final result = await useCase('test-pet', online: false);

      expect(result.todayBattleCount, 0);
      expect(result.todayBattleAdBonus, 1, reason: '어제 광고분 3은 버려짐');
    });
  });
}
