import 'package:flutter_test/flutter_test.dart';
import 'package:pocketfriend/domain/entities/pet.dart';
import 'package:pocketfriend/domain/repositories/pet_repository.dart';
import 'package:pocketfriend/domain/usecases/drink_water_usecase.dart';

class _FakePetRepository implements PetRepository {
  Pet? _pet;
  void setPet(Pet p) => _pet = p;
  @override
  Future<Pet> getPet(String id) async => _pet!;
  @override
  Future<void> updatePet(Pet p) async => _pet = p;
  @override
  Future<void> savePet(Pet p) async => _pet = p;
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

Pet _pet({int stamina = 50, int todayWaterCount = 0, int exp = 0, bool isDead = false}) {
  final now = DateTime.now().millisecondsSinceEpoch;
  return Pet(
    id: 'p',
    hunger: 80,
    happiness: 80,
    stamina: stamina,
    level: 1,
    exp: exp,
    evolutionStage: 1,
    lastUpdated: now,
    lastStatusDecayUpdated: now,
    lastGoalResetDate: _today(),
    todayWaterCount: todayWaterCount,
    isDead: isDead,
  );
}

void main() {
  // 모든 슬롯(8잔)이 열린 저녁 시각 고정 — 시간 의존 없는 결정적 테스트
  final evening = DateTime(2026, 1, 1, 21);

  group('DrinkWaterUseCase', () {
    test('한 잔 → 카운트 +1, 기력 +2', () async {
      final repo = _FakePetRepository()..setPet(_pet(stamina: 50));
      final r = await DrinkWaterUseCase(repo)('p', now: evening);
      expect(r.todayWaterCount, 1);
      expect(r.stamina, 52);
    });

    test('기력 100 상한 클램프', () async {
      final repo = _FakePetRepository()..setPet(_pet(stamina: 99));
      final r = await DrinkWaterUseCase(repo)('p', now: evening);
      expect(r.stamina, 100);
    });

    test('목표(8잔) 달성 순간에만 완료 보너스 EXP + 누적 달성 +1', () async {
      final repo = _FakePetRepository()
        ..setPet(_pet(todayWaterCount: 7, exp: 0));
      final r = await DrinkWaterUseCase(repo)('p', now: evening);
      expect(r.todayWaterCount, 8);
      expect(r.exp, DrinkWaterUseCase.completionExp);
      expect(r.waterAchievedCount, 1, reason: '수달 각성 축 누적 카운터');
    });

    test('목표 이전 잔은 누적 달성 증가 없음', () async {
      final repo = _FakePetRepository()
        ..setPet(_pet(todayWaterCount: 3));
      final r = await DrinkWaterUseCase(repo)('p', now: evening);
      expect(r.waterAchievedCount, 0);
    });

    test('목표 이전 잔은 EXP 없음', () async {
      final repo = _FakePetRepository()
        ..setPet(_pet(todayWaterCount: 3, exp: 5));
      final r = await DrinkWaterUseCase(repo)('p', now: evening);
      expect(r.exp, 5, reason: '8잔 전에는 완료 보너스 없음');
    });

    test('하루 목표 소진 후 no-op', () async {
      final repo = _FakePetRepository()
        ..setPet(_pet(todayWaterCount: 8, stamina: 50));
      final r = await DrinkWaterUseCase(repo)('p', now: evening);
      expect(r.todayWaterCount, 8);
      expect(r.stamina, 50, reason: '초과 음용 불가');
    });

    test('죽은 펫은 물을 안 마신다', () async {
      final repo = _FakePetRepository()..setPet(_pet(isDead: true));
      final r = await DrinkWaterUseCase(repo)('p', now: evening);
      expect(r.todayWaterCount, 0);
    });

    test('같은 슬롯 연속 두 잔 금지 — 두 번째 호출은 no-op', () async {
      final repo = _FakePetRepository()..setPet(_pet(stamina: 50));
      final usecase = DrinkWaterUseCase(repo);
      final first = await usecase('p', now: evening);
      expect(first.todayWaterCount, 1);
      final second = await usecase('p', now: evening);
      expect(second.todayWaterCount, 1, reason: '같은 슬롯 재음수 차단');
      expect(second.stamina, first.stamina);
    });

    test('canDrinkWater — 8잔이면 false', () {
      expect(_pet(todayWaterCount: 0).canDrinkWater, isTrue);
      expect(_pet(todayWaterCount: 8).canDrinkWater, isFalse);
    });
  });
}
