import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:pocketfriend/domain/entities/activity_data.dart';
import 'package:pocketfriend/domain/entities/battle_history.dart';
import 'package:pocketfriend/domain/entities/evolution_type.dart';
import 'package:pocketfriend/domain/entities/pet.dart';
import 'package:pocketfriend/domain/entities/wild_encounter.dart';
import 'package:pocketfriend/domain/repositories/activity_repository.dart';
import 'package:pocketfriend/domain/repositories/battle_history_repository.dart';
import 'package:pocketfriend/domain/repositories/pet_repository.dart';
import 'package:pocketfriend/domain/usecases/battle_with_activity_usecase.dart';
import 'package:pocketfriend/domain/usecases/wild_encounter_spawner.dart';

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

class _FakeActivityRepo implements ActivityRepository {
  ActivityData _d() {
    final now = DateTime.now().millisecondsSinceEpoch;
    return ActivityData(
        steps: 1000, exerciseMinutes: 10, startTime: now, endTime: now);
  }

  @override
  Future<ActivityData> getTodayActivityData() async => _d();
  @override
  Future<ActivityData> getActivityData(
          {required int startTime, required int endTime}) async =>
      _d();
  @override
  Future<ActivityData> getLast24HoursActivityData() async => _d();
}

class _FakeHistoryRepo implements BattleHistoryRepository {
  int saved = 0;
  @override
  Future<void> saveBattleHistory(BattleHistory h) async => saved++;
  @override
  Future<List<BattleHistory>> getAllBattleHistory() async => [];
  @override
  Future<List<BattleHistory>> getRecentBattleHistory(int limit) async => [];
  @override
  Future<int> getVictoryCount() async => 0;
  @override
  Future<int> getDefeatCount() async => 0;
  @override
  Future<int> getTotalBattleCount() async => 0;
}

String _today() {
  final now = DateTime.now();
  return '${now.year}-${now.month.toString().padLeft(2, '0')}-'
      '${now.day.toString().padLeft(2, '0')}';
}

Pet _pet({
  EvolutionType? type,
  int stage = 2,
  int level = 6,
  int todaySyncedSteps = 3000,
  int todayBattleCount = 5, // AI 한도 소진 상태
  bool isDead = false,
}) {
  final now = DateTime.now().millisecondsSinceEpoch;
  return Pet(
    id: 'p',
    hunger: 80,
    happiness: 80,
    stamina: 80,
    level: level,
    exp: 0,
    evolutionStage: stage,
    evolutionType: type,
    lastUpdated: now,
    lastStatusDecayUpdated: now,
    lastGoalResetDate: _today(),
    todaySyncedSteps: todaySyncedSteps,
    todayBattleCount: todayBattleCount,
    isDead: isDead,
  );
}

void main() {
  group('WildEncounterSpawner', () {
    test('걸음이 임계 미만이면 후보 아님', () {
      expect(WildEncounterSpawner.isEligible(_pet(todaySyncedSteps: 500)),
          isFalse);
      expect(WildEncounterSpawner.isEligible(_pet(todaySyncedSteps: 3000)),
          isTrue);
    });

    test('죽은 펫은 후보 아님', () {
      expect(WildEncounterSpawner.isEligible(_pet(isDead: true)), isFalse);
    });

    test('종 결정된 펫 → 상대 종이 있고 레벨은 ±1', () {
      // spawnChance 통과하는 시드로 여러 번 굴려 종/레벨 범위 검증
      var spawned = 0;
      for (int seed = 0; seed < 30; seed++) {
        final e = WildEncounterSpawner.roll(
            _pet(type: EvolutionType.tiger, level: 6),
            random: Random(seed));
        if (e == null) continue;
        spawned++;
        expect(e.level, inInclusiveRange(5, 7));
        // 종이 있으면 사신수 or 설화 영물 중 하나
        if (e.speciesName != null) {
          expect(EvolutionType.values.map((t) => t.name),
              contains(e.speciesName));
        }
      }
      expect(spawned, greaterThan(0));
    });

    test('털뭉치(종 미결정) → 상대도 종 없음', () {
      for (int seed = 0; seed < 20; seed++) {
        final e = WildEncounterSpawner.roll(_pet(type: null, stage: 1),
            random: Random(seed));
        if (e != null) expect(e.speciesName, isNull);
      }
    });
  });

  group('야생 조우 배틀 (BattleWithActivityUseCase wild)', () {
    BattleWithActivityUseCase make(_FakePetRepo repo, _FakeHistoryRepo h) =>
        BattleWithActivityUseCase(
          petRepository: repo,
          activityRepository: _FakeActivityRepo(),
          battleHistoryRepository: h,
        );

    WildEncounter wildOf(EvolutionType type, int level) => WildEncounter(
          speciesName: type.name,
          level: level,
          spawnedAtMs: DateTime.now().millisecondsSinceEpoch,
          dateString: _today(),
        );

    test('AI 한도 소진 상태여도 야생 조우는 진행된다 (limitReached 아님)', () async {
      final repo = _FakePetRepo()
        ..pet = _pet(type: EvolutionType.tiger, todayBattleCount: 5);
      final result = await make(repo, _FakeHistoryRepo())(
        'p',
        random: Random(1),
        wild: wildOf(EvolutionType.snake, 6),
      );
      expect(result.limitReached, isFalse);
      expect(result.turns, isNotEmpty);
    });

    test('상대 종·레벨은 조우 정보로 고정된다', () async {
      final repo = _FakePetRepo()..pet = _pet(type: EvolutionType.tiger);
      final result = await make(repo, _FakeHistoryRepo())(
        'p',
        random: Random(3),
        wild: wildOf(EvolutionType.turtle, 9),
      );
      expect(result.opponentTypeName, EvolutionType.turtle.name);
      expect(result.opponentLevel, 9);
    });

    test('야생 조우는 AI 배틀 카운트를 소모하지 않는다', () async {
      final repo = _FakePetRepo()
        ..pet = _pet(type: EvolutionType.tiger, todayBattleCount: 2);
      await make(repo, _FakeHistoryRepo())(
        'p',
        random: Random(2),
        wild: wildOf(EvolutionType.bird, 6),
      );
      expect(repo.pet!.todayBattleCount, 2, reason: '한도 미소모');
    });

    test('일반 AI 배틀은 카운트를 소모한다 (대조)', () async {
      final repo = _FakePetRepo()
        ..pet = _pet(type: EvolutionType.tiger, todayBattleCount: 2);
      await make(repo, _FakeHistoryRepo())('p', random: Random(2));
      expect(repo.pet!.todayBattleCount, 3);
    });
  });
}
