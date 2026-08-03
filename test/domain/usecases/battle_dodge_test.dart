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

/// 회피(빗나감) 메커니즘 회귀 테스트.
///
/// 핵심 보증:
///  1. 회피 성공 시 해당 공격 데미지 0 (최소 1 보장 규칙보다 우선)
///  2. 회피 실패 시 데미지 최소 1 보장 유지
///  3. 회피는 안전 상한(maxTurns)까지만 — 무한 배틀 없음

class _FixedRandom implements Random {
  final double value;
  _FixedRandom(this.value);
  @override
  double nextDouble() => value;
  @override
  int nextInt(int max) => 0;
  @override
  bool nextBool() => false;
}

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

Pet _pet() {
  final now = DateTime.now().millisecondsSinceEpoch;
  return Pet(
    id: 'p',
    hunger: 80,
    happiness: 80,
    stamina: 80,
    level: 10,
    exp: 0,
    evolutionStage: 3,
    evolutionType: EvolutionType.bird,
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

  test('항상 회피 성공(nextDouble=0) → 모든 턴 양측 데미지 0, 상한까지 진행', () async {
    final repo = _FakePetRepo()..pet = _pet();
    final result = await makeUseCase(repo)('p', random: _FixedRandom(0.0));

    expect(result.turns.length, BattleWithActivityUseCase.maxTurns,
        reason: '아무도 안 맞으면 안전 상한에서 판정 종료');
    for (final turn in result.turns) {
      expect(turn.playerDamage, 0, reason: 'T${turn.turnNumber} 플레이어 공격 회피됨');
      expect(turn.opponentDamage, 0, reason: 'T${turn.turnNumber} 상대 공격 회피됨');
    }
    // HP 무손실
    expect(result.turns.last.playerHpRemaining, result.playerMaxHp);
    expect(result.turns.last.opponentHpRemaining, result.opponentMaxHp);
  });

  test('회피 실패(nextDouble=0.99) → 모든 공격 데미지 최소 1', () async {
    final repo = _FakePetRepo()..pet = _pet();
    final result = await makeUseCase(repo)('p', random: _FixedRandom(0.99));

    expect(result.turns, isNotEmpty);
    for (final turn in result.turns) {
      expect(turn.playerDamage, greaterThanOrEqualTo(1));
      // 상대는 KO된 마지막 턴에만 0 허용
      if (turn.opponentHpRemaining > 0) {
        expect(turn.opponentDamage, greaterThanOrEqualTo(1));
      }
    }
  });

  group('회피 확률 — 기력(stamina) 연동', () {
    test('기력 0 = 기본 5%, 50 = 10%, 100 = 최대 15%', () {
      expect(BattleWithActivityUseCase.dodgeChanceForStamina(0),
          closeTo(0.05, 0.0001));
      expect(BattleWithActivityUseCase.dodgeChanceForStamina(50),
          closeTo(0.10, 0.0001));
      expect(BattleWithActivityUseCase.dodgeChanceForStamina(100),
          closeTo(0.15, 0.0001));
    });

    test('기력 만땅 펫은 AI(10%)보다 회피 우위, 지친 펫은 열세', () {
      expect(BattleWithActivityUseCase.dodgeChanceForStamina(100),
          greaterThan(BattleWithActivityUseCase.aiDodgeChance));
      expect(BattleWithActivityUseCase.dodgeChanceForStamina(20),
          lessThan(BattleWithActivityUseCase.aiDodgeChance));
    });
  });
}
