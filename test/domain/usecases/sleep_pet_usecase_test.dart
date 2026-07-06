import 'package:flutter_test/flutter_test.dart';
import 'package:pocketfriend/domain/entities/pet.dart';
import 'package:pocketfriend/domain/repositories/pet_repository.dart';
import 'package:pocketfriend/domain/usecases/sleep_pet_usecase.dart';

/// 수동 재우기(Sleep 버튼) 일일 제한 회귀 테스트.
///
/// 핵심 보증:
///  1. 1회당 stamina +10, 하루 최대 3회
///  2. 제한 도달 후 호출은 no-op (stamina/카운트 불변)
///  3. 날짜가 바뀌면 카운트 리셋되어 다시 사용 가능

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
  int stamina = 50,
  int todaySleepCount = 0,
  String? lastGoalResetDate,
}) {
  final now = DateTime.now().millisecondsSinceEpoch;
  return Pet(
    id: 'p',
    hunger: 50,
    happiness: 50,
    stamina: stamina,
    level: 1,
    exp: 0,
    evolutionStage: 1,
    lastUpdated: now,
    lastStatusDecayUpdated: now,
    todaySleepCount: todaySleepCount,
    lastGoalResetDate: lastGoalResetDate ?? _today(),
  );
}

void main() {
  group('SleepPetUseCase — 일일 제한', () {
    test('1회 사용 → stamina +10, 카운트 +1', () async {
      final repo = _FakePetRepository()..setPet(_pet(stamina: 50));
      final useCase = SleepPetUseCase(repo);

      final result = await useCase('p');

      expect(result.stamina, 60);
      expect(result.todaySleepCount, 1);
    });

    test('하루 3회까지 사용 가능, 4번째는 no-op', () async {
      final repo = _FakePetRepository()..setPet(_pet(stamina: 50));
      final useCase = SleepPetUseCase(repo);

      await useCase('p');
      await useCase('p');
      final third = await useCase('p');
      expect(third.stamina, 80);
      expect(third.todaySleepCount, 3);

      final fourth = await useCase('p');
      expect(fourth.stamina, 80, reason: '제한 도달 후엔 회복 없음');
      expect(fourth.todaySleepCount, 3, reason: '카운트도 증가하지 않음');
    });

    test('stamina는 100을 넘지 않는다', () async {
      final repo = _FakePetRepository()..setPet(_pet(stamina: 95));
      final useCase = SleepPetUseCase(repo);

      final result = await useCase('p');

      expect(result.stamina, 100);
    });

    test('날짜가 바뀌면 카운트가 리셋되어 다시 사용 가능', () async {
      // 어제 3회 다 쓴 상태
      final repo = _FakePetRepository()
        ..setPet(_pet(
          stamina: 50,
          todaySleepCount: 3,
          lastGoalResetDate: '2020-01-01',
        ));
      final useCase = SleepPetUseCase(repo);

      final result = await useCase('p');

      expect(result.stamina, 60, reason: '리셋 후 다시 회복 가능');
      expect(result.todaySleepCount, 1);
    });

    test('canUse — 제한 도달 여부 판단', () {
      final useCase = SleepPetUseCase(_FakePetRepository());

      expect(useCase.canUse(_pet(todaySleepCount: 0)), isTrue);
      expect(useCase.canUse(_pet(todaySleepCount: 2)), isTrue);
      expect(useCase.canUse(_pet(todaySleepCount: 3)), isFalse);
      // 날짜가 바뀌었으면 카운트가 남아 있어도 사용 가능
      expect(
        useCase.canUse(_pet(
          todaySleepCount: 3,
          lastGoalResetDate: '2020-01-01',
        )),
        isTrue,
      );
    });
  });
}
