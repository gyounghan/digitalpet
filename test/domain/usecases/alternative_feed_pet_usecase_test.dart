import 'package:flutter_test/flutter_test.dart';
import 'package:pocketfriend/domain/constants/meal_times.dart';
import 'package:pocketfriend/domain/entities/pet.dart';
import 'package:pocketfriend/domain/repositories/pet_repository.dart';
import 'package:pocketfriend/domain/usecases/alternative_feed_pet_usecase.dart';

/// 간편 급식 — 식사 슬롯 공유 회귀 테스트.
///
/// 핵심 보증 (한 식사시간대에 여러 번 먹이던 버그 방지):
///  1. 식사 시간대에만 사용 가능
///  2. 정식 급식과 슬롯을 공유 — 같은 시간대에 합쳐서 1회만
///  3. 사용 시 식사 목표(todayFeedCount)에 1회로 인정
///  4. 하루 최대 3회

class _FakePetRepository implements PetRepository {
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
  @override
  Future<List<Pet>> getAllPets() async => _pet != null ? [_pet!] : [];
}

String _today() {
  final now = DateTime.now();
  return '${now.year}-${now.month.toString().padLeft(2, '0')}-'
      '${now.day.toString().padLeft(2, '0')}';
}

Pet _pet({
  int hunger = 50,
  int todayFeedCount = 0,
  int todayFedMealSlots = 0,
  int todayAlternativeFeedCount = 0,
}) {
  final now = DateTime.now().millisecondsSinceEpoch;
  return Pet(
    id: 'p',
    hunger: hunger,
    happiness: 50,
    stamina: 50,
    level: 1,
    exp: 0,
    evolutionStage: 1,
    lastUpdated: now,
    lastStatusDecayUpdated: now,
    todayFeedCount: todayFeedCount,
    todayFedMealSlots: todayFedMealSlots,
    todayAlternativeFeedCount: todayAlternativeFeedCount,
    lastGoalResetDate: _today(),
  );
}

void main() {
  // 오늘 날짜의 점심 시간대(12:00) / 시간대 밖(15:00) 시각
  final base = DateTime.now();
  final lunch = DateTime(base.year, base.month, base.day, 12, 0);
  final offMeal = DateTime(base.year, base.month, base.day, 15, 0);
  final breakfast = DateTime(base.year, base.month, base.day, 8, 0);

  group('MealTimes', () {
    test('슬롯 판정 — 아침/점심/저녁/시간대 밖', () {
      expect(MealTimes.slotAt(breakfast), 1);
      expect(MealTimes.slotAt(lunch), 2);
      expect(
          MealTimes.slotAt(DateTime(base.year, base.month, base.day, 18, 0)),
          3);
      expect(MealTimes.slotAt(offMeal), 0);
    });

    test('경계값 — 시작 포함, 끝 미포함', () {
      expect(
          MealTimes.slotAt(DateTime(base.year, base.month, base.day, 6, 30)),
          1);
      expect(
          MealTimes.slotAt(DateTime(base.year, base.month, base.day, 10, 0)),
          0);
      expect(
          MealTimes.slotAt(DateTime(base.year, base.month, base.day, 21, 0)),
          0);
    });

    test('비트마스크 사용/기록', () {
      expect(MealTimes.hasFedInSlot(0, 2), isFalse);
      final marked = MealTimes.markFed(0, 2);
      expect(MealTimes.hasFedInSlot(marked, 2), isTrue);
      expect(MealTimes.hasFedInSlot(marked, 1), isFalse);
      expect(MealTimes.hasFedInSlot(marked, 3), isFalse);
    });
  });

  group('AlternativeFeedPetUseCase — 식사 슬롯 공유', () {
    test('식사 시간대 + 슬롯 미사용 → 급식 성공 (+8, 슬롯 소비, 목표 +1)', () async {
      final repo = _FakePetRepository()..setPet(_pet(hunger: 50));
      final useCase = AlternativeFeedPetUseCase(repo);

      final result = await useCase('p', now: lunch);

      expect(result.hunger, 58);
      expect(result.todayFeedCount, 1, reason: '식사 목표에 1회로 인정');
      expect(result.todayAlternativeFeedCount, 1);
      expect(MealTimes.hasFedInSlot(result.todayFedMealSlots, 2), isTrue,
          reason: '점심 슬롯 소비');
    });

    test('식사 시간대 밖 → no-op', () async {
      final repo = _FakePetRepository()..setPet(_pet(hunger: 50));
      final useCase = AlternativeFeedPetUseCase(repo);

      final result = await useCase('p', now: offMeal);

      expect(result.hunger, 50);
      expect(result.todayFeedCount, 0);
      expect(result.todayAlternativeFeedCount, 0);
    });

    test('같은 슬롯에서 두 번째 시도 → no-op (다회 급식 방지)', () async {
      final repo = _FakePetRepository()..setPet(_pet(hunger: 50));
      final useCase = AlternativeFeedPetUseCase(repo);

      await useCase('p', now: lunch);
      final second = await useCase('p', now: lunch);

      expect(second.hunger, 58, reason: '첫 급식분만 반영');
      expect(second.todayFeedCount, 1);
      expect(second.todayAlternativeFeedCount, 1);
    });

    test('정식 급식으로 슬롯이 이미 사용됨 → 간편 급식 불가', () async {
      // 점심 슬롯(2)이 정식 급식으로 사용된 상태
      final repo = _FakePetRepository()
        ..setPet(_pet(
          hunger: 70,
          todayFeedCount: 1,
          todayFedMealSlots: MealTimes.markFed(0, 2),
        ));
      final useCase = AlternativeFeedPetUseCase(repo);

      final result = await useCase('p', now: lunch);

      expect(result.hunger, 70);
      expect(result.todayAlternativeFeedCount, 0);
    });

    test('다른 슬롯은 사용 가능 (아침 사용 후 점심 OK)', () async {
      final repo = _FakePetRepository()
        ..setPet(_pet(
          hunger: 50,
          todayFeedCount: 1,
          todayFedMealSlots: MealTimes.markFed(0, 1),
          todayAlternativeFeedCount: 1,
        ));
      final useCase = AlternativeFeedPetUseCase(repo);

      final result = await useCase('p', now: lunch);

      expect(result.hunger, 58);
      expect(result.todayFeedCount, 2);
      expect(result.todayAlternativeFeedCount, 2);
    });

    test('일일 3회 제한 도달 → no-op', () async {
      final repo = _FakePetRepository()
        ..setPet(_pet(hunger: 50, todayAlternativeFeedCount: 3));
      final useCase = AlternativeFeedPetUseCase(repo);

      final result = await useCase('p', now: lunch);

      expect(result.hunger, 50);
      expect(result.todayAlternativeFeedCount, 3);
    });
  });

  group('AlternativeFeedPetUseCase.canUse — 버튼 활성 판정 (call과 동일 규칙)', () {
    final useCase = AlternativeFeedPetUseCase(_FakePetRepository());

    test('식사 시간대 + 슬롯 미사용 + 횟수 남음 → true', () {
      expect(useCase.canUse(_pet(), now: lunch), isTrue);
    });

    test('식사 시간대 밖 → false (횟수가 남아도)', () {
      expect(useCase.canUse(_pet(), now: offMeal), isFalse);
    });

    test('이 슬롯 이미 급식(정식/간편 공유) → false', () {
      final slot = MealTimes.slotAt(lunch);
      final pet = _pet(todayFedMealSlots: MealTimes.markFed(0, slot));
      expect(useCase.canUse(pet, now: lunch), isFalse);
      // 다른 슬롯(아침)이 사용된 경우엔 점심 사용 가능
      final morningUsed =
          _pet(todayFedMealSlots: MealTimes.markFed(0, MealTimes.slotAt(breakfast)));
      expect(useCase.canUse(morningUsed, now: lunch), isTrue);
    });

    test('일일 3회 소진 → false', () {
      expect(
          useCase.canUse(_pet(todayAlternativeFeedCount: 3), now: lunch),
          isFalse);
    });
  });
}
