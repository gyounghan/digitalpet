import 'package:flutter_test/flutter_test.dart';
import 'package:pocketfriend/domain/entities/battle_history.dart';
import 'package:pocketfriend/domain/entities/pet.dart';
import 'package:pocketfriend/domain/repositories/battle_history_repository.dart';
import 'package:pocketfriend/domain/repositories/pet_repository.dart';
import 'package:pocketfriend/domain/usecases/award_battle_reward_usecase.dart';

/// 온라인 배틀 보상 로컬 지급 회귀 테스트.
///
/// 핵심 보증 (몰수승 EXP가 표시만 되던 버그 방지):
///  1. EXP가 실제 펫에 지급되고 레벨업 처리된다
///  2. 승리 시 행복 +5, 승수 +1, 전적이 기록된다
///  3. 사망 펫은 no-op
///  4. AI 대전 일일 제한 카운트(todayBattleCount)는 건드리지 않는다

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

class _FakeBattleHistoryRepository implements BattleHistoryRepository {
  final List<BattleHistory> saved = [];

  @override
  Future<void> saveBattleHistory(BattleHistory history) async =>
      saved.add(history);
  @override
  Future<List<BattleHistory>> getAllBattleHistory() async => saved;
  @override
  Future<List<BattleHistory>> getRecentBattleHistory(int limit) async =>
      saved.take(limit).toList();
  @override
  Future<int> getVictoryCount() async =>
      saved.where((h) => h.isVictory).length;
  @override
  Future<int> getDefeatCount() async =>
      saved.where((h) => !h.isVictory).length;
  @override
  Future<int> getTotalBattleCount() async => saved.length;
}

String _today() {
  final now = DateTime.now();
  return '${now.year}-${now.month.toString().padLeft(2, '0')}-'
      '${now.day.toString().padLeft(2, '0')}';
}

Pet _pet({
  int exp = 0,
  int level = 1,
  int happiness = 50,
  int todayBattleCount = 0,
  bool isDead = false,
}) {
  final now = DateTime.now().millisecondsSinceEpoch;
  return Pet(
    id: 'p',
    hunger: 50,
    happiness: happiness,
    stamina: 50,
    level: level,
    exp: exp,
    evolutionStage: 1,
    lastUpdated: now,
    lastStatusDecayUpdated: now,
    todayBattleCount: todayBattleCount,
    isDead: isDead,
    lastGoalResetDate: _today(),
  );
}

void main() {
  group('AwardBattleRewardUseCase', () {
    test('승리 보상 — EXP 지급, 행복 +5, 승수 +1, 전적 기록', () async {
      final petRepo = _FakePetRepository()..setPet(_pet());
      final historyRepo = _FakeBattleHistoryRepository();
      final useCase = AwardBattleRewardUseCase(
        petRepository: petRepo,
        battleHistoryRepository: historyRepo,
      );

      final result = await useCase('p', isVictory: true, exp: 30);

      expect(result.exp, 30);
      expect(result.happiness, 55);
      expect(result.battleVictoryCount, 1);
      expect(historyRepo.saved, hasLength(1));
      expect(historyRepo.saved.single.isVictory, isTrue);
      expect(historyRepo.saved.single.expGained, 30);
    });

    test('레벨업 처리 — Lv.1(필요 50)에서 +50 EXP → Lv.2, 스탯 +10', () async {
      final petRepo = _FakePetRepository()..setPet(_pet(happiness: 50));
      final historyRepo = _FakeBattleHistoryRepository();
      final useCase = AwardBattleRewardUseCase(
        petRepository: petRepo,
        battleHistoryRepository: historyRepo,
      );

      final result = await useCase('p', isVictory: true, exp: 50);

      expect(result.level, 2);
      expect(result.exp, 0);
      // 행복: 50 + 승리 5 + 레벨업 10 = 65
      expect(result.happiness, 65);
      expect(result.hunger, 60);
      expect(result.stamina, 60);
    });

    test('사망 펫 → no-op (지급/기록 없음)', () async {
      final petRepo = _FakePetRepository()..setPet(_pet(isDead: true));
      final historyRepo = _FakeBattleHistoryRepository();
      final useCase = AwardBattleRewardUseCase(
        petRepository: petRepo,
        battleHistoryRepository: historyRepo,
      );

      final result = await useCase('p', isVictory: true, exp: 50);

      expect(result.exp, 0);
      expect(historyRepo.saved, isEmpty);
    });

    test('AI 대전 일일 제한 카운트는 증가하지 않음', () async {
      final petRepo = _FakePetRepository()..setPet(_pet(todayBattleCount: 1));
      final historyRepo = _FakeBattleHistoryRepository();
      final useCase = AwardBattleRewardUseCase(
        petRepository: petRepo,
        battleHistoryRepository: historyRepo,
      );

      final result = await useCase('p', isVictory: true, exp: 50);

      expect(result.todayBattleCount, 1);
    });
  });
}
