import 'package:flutter_test/flutter_test.dart';
import 'package:pocketfriend/domain/entities/pet.dart';
import 'package:pocketfriend/domain/repositories/pet_repository.dart';
import 'package:pocketfriend/domain/usecases/focus_session_usecase.dart';

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

Pet _pet({
  int happiness = 50,
  int exp = 0,
  int todayFocusCount = 0,
  bool isDead = false,
}) {
  final now = DateTime.now().millisecondsSinceEpoch;
  return Pet(
    id: 'p',
    hunger: 80,
    happiness: happiness,
    stamina: 80,
    level: 1,
    exp: exp,
    evolutionStage: 1,
    lastUpdated: now,
    lastStatusDecayUpdated: now,
    lastGoalResetDate: _today(),
    todayFocusCount: todayFocusCount,
    isDead: isDead,
  );
}

void main() {
  group('FocusSessionUseCase', () {
    test('세션 완료 → 카운트 +1, EXP·행복 보상', () async {
      final repo = _FakePetRepository()..setPet(_pet(happiness: 50, exp: 0));
      final r = await FocusSessionUseCase(repo)('p');
      expect(r.todayFocusCount, 1);
      expect(r.exp, FocusSessionUseCase.sessionExp);
      expect(r.happiness, 50 + FocusSessionUseCase.happinessReward);
    });

    test('행복 100 상한 클램프', () async {
      final repo = _FakePetRepository()..setPet(_pet(happiness: 98));
      final r = await FocusSessionUseCase(repo)('p');
      expect(r.happiness, 100);
    });

    test('목표(4회) 채운 순간 누적 달성 +1 (부엉이 각성 축)', () async {
      final repo = _FakePetRepository()..setPet(_pet(todayFocusCount: 3));
      final r = await FocusSessionUseCase(repo)('p');
      expect(r.todayFocusCount, 4);
      expect(r.focusAchievedCount, 1);
    });

    test('목표 이전 세션은 누적 달성 증가 없음', () async {
      final repo = _FakePetRepository()..setPet(_pet(todayFocusCount: 1));
      final r = await FocusSessionUseCase(repo)('p');
      expect(r.focusAchievedCount, 0);
    });

    test('하루 목표(4회) 소진 후 no-op', () async {
      final repo = _FakePetRepository()
        ..setPet(_pet(todayFocusCount: 4, exp: 5));
      final r = await FocusSessionUseCase(repo)('p');
      expect(r.todayFocusCount, 4);
      expect(r.exp, 5, reason: '초과 세션 보상 없음');
    });

    test('죽은 펫은 집중 불가', () async {
      final repo = _FakePetRepository()..setPet(_pet(isDead: true));
      final r = await FocusSessionUseCase(repo)('p');
      expect(r.todayFocusCount, 0);
    });

    test('canFocus — 4회면 false', () {
      expect(_pet(todayFocusCount: 0).canFocus, isTrue);
      expect(_pet(todayFocusCount: 4).canFocus, isFalse);
    });
  });
}
