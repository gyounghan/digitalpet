import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:pocketfriend/domain/entities/activity_data.dart';
import 'package:pocketfriend/domain/entities/battle_history.dart';
import 'package:pocketfriend/domain/entities/evolution_type.dart';
import 'package:pocketfriend/domain/entities/pet.dart';
import 'package:pocketfriend/domain/repositories/activity_repository.dart';
import 'package:pocketfriend/domain/repositories/battle_history_repository.dart';
import 'package:pocketfriend/domain/repositories/pet_repository.dart';
import 'package:pocketfriend/domain/usecases/battle_with_activity_usecase.dart';

/// AI 상대 매칭 회귀 테스트.
///
/// 털뭉치(종 미결정)는 털뭉치끼리 만난다 — 상대 종이 랜덤이면
/// "야생의 백호"라는 이름에 털뭉치 스프라이트가 나오는 불일치가 생긴다.

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
  ActivityData _data() {
    final now = DateTime.now().millisecondsSinceEpoch;
    return ActivityData(
        steps: 1000, exerciseMinutes: 10, startTime: now, endTime: now);
  }

  @override
  Future<ActivityData> getTodayActivityData() async => _data();
  @override
  Future<ActivityData> getActivityData(
          {required int startTime, required int endTime}) async =>
      _data();
  @override
  Future<ActivityData> getLast24HoursActivityData() async => _data();
}

class _FakeHistoryRepo implements BattleHistoryRepository {
  @override
  Future<void> saveBattleHistory(BattleHistory history) async {}
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

Pet _pet({EvolutionType? type, int stage = 1}) {
  final now = DateTime.now().millisecondsSinceEpoch;
  return Pet(
    id: 'p',
    hunger: 80,
    happiness: 80,
    stamina: 80,
    level: 3,
    exp: 0,
    evolutionStage: stage,
    evolutionType: type,
    lastUpdated: now,
    lastStatusDecayUpdated: now,
    lastGoalResetDate: _today(),
  );
}

void main() {
  BattleWithActivityUseCase makeUseCase(_FakePetRepo repo) =>
      BattleWithActivityUseCase(
        petRepository: repo,
        activityRepository: _FakeActivityRepo(),
        battleHistoryRepository: _FakeHistoryRepo(),
      );

  test('털뭉치(종 미결정)의 AI 상대는 항상 털뭉치 — 종·상성 없음', () async {
    for (int seed = 0; seed < 10; seed++) {
      final repo = _FakePetRepo()..pet = _pet();
      final result = await makeUseCase(repo)('p', random: Random(seed));

      expect(result.opponentTypeName, isEmpty,
          reason: 'seed=$seed: 종 미결정이면 상대도 종 없음(털뭉치)');
      expect(result.affinityAdvantage, isFalse);
      expect(result.affinityDisadvantage, isFalse);
    }
  });

  test('종이 결정된 펫의 AI 상대는 종이 있다', () async {
    final repo = _FakePetRepo()..pet = _pet(type: EvolutionType.tiger, stage: 2);
    final result = await makeUseCase(repo)('p', random: Random(1));

    expect(result.opponentTypeName, isNotEmpty);
    expect(
      EvolutionType.values.map((t) => t.name),
      contains(result.opponentTypeName),
    );
  });

  test('털뭉치 상대도 스탯이 정상 생성된다 (종 보너스 0)', () {
    final base = BattleStats(attack: 20, defense: 15, hp: 100);
    final stats = BattleWithActivityUseCase.generateOpponentStats(
        base, 3, null, Random(1));
    expect(stats.attack, greaterThan(0));
    expect(stats.defense, greaterThan(0));
    expect(stats.hp, greaterThan(0));
  });
}
