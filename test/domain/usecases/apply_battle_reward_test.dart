import 'package:flutter_test/flutter_test.dart';
import 'package:pocketfriend/domain/entities/activity_data.dart';
import 'package:pocketfriend/domain/entities/battle_history.dart';
import 'package:pocketfriend/domain/entities/pet.dart';
import 'package:pocketfriend/domain/repositories/activity_repository.dart';
import 'package:pocketfriend/domain/repositories/battle_history_repository.dart';
import 'package:pocketfriend/domain/repositories/pet_repository.dart';
import 'package:pocketfriend/domain/usecases/apply_battle_reward.dart';
import 'package:pocketfriend/domain/usecases/apply_online_battle_reward_usecase.dart';

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

class _FakeActivityRepository implements ActivityRepository {
  final ActivityData data;
  _FakeActivityRepository(this.data);

  @override
  Future<ActivityData> getActivityData({
    required int startTime,
    required int endTime,
  }) async =>
      data;
  @override
  Future<ActivityData> getTodayActivityData() async => data;
  @override
  Future<ActivityData> getLast24HoursActivityData() async => data;
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
  int level = 5,
  int exp = 0,
  int hunger = 60,
  int happiness = 60,
  int stamina = 60,
  int todayBattleCount = 0,
  int battleVictoryCount = 0,
  String todayEvent = '',
  bool isDead = false,
  String? lastGoalResetDate,
}) {
  return Pet(
    id: 'test-pet',
    name: '테스트',
    hunger: hunger,
    happiness: happiness,
    stamina: stamina,
    exp: exp,
    level: level,
    evolutionStage: 2,
    lastUpdated: DateTime.now().millisecondsSinceEpoch,
    lastStatusDecayUpdated: DateTime.now().millisecondsSinceEpoch,
    todayBattleCount: todayBattleCount,
    battleVictoryCount: battleVictoryCount,
    todayEvent: todayEvent,
    isDead: isDead,
    lastGoalResetDate: lastGoalResetDate ?? _today(),
  );
}

void main() {
  const nowMs = 1000000;

  group('BattleReward.baseExpFor', () {
    test('압승 70 / 승리 50 / 패배 15', () {
      expect(
          BattleReward.baseExpFor(isVictory: true, isDominantVictory: true),
          70);
      expect(
          BattleReward.baseExpFor(isVictory: true, isDominantVictory: false),
          50);
      expect(
          BattleReward.baseExpFor(isVictory: false, isDominantVictory: false),
          15);
    });
  });

  group('BattleReward.apply — 보상 배수', () {
    test('하루 1번째 배틀은 기본 경험치 그대로 (×1.0)', () {
      final r = BattleReward.apply(_pet(todayBattleCount: 0),
          isVictory: true, isDominantVictory: false, nowMs: nowMs);
      expect(r.expGained, 50);
    });

    test('2번째 ×0.7, 3번째 ×0.5, 그 이상은 0.5로 클램프', () {
      final second = BattleReward.apply(_pet(todayBattleCount: 1),
          isVictory: true, isDominantVictory: false, nowMs: nowMs);
      expect(second.expGained, 35);

      final third = BattleReward.apply(_pet(todayBattleCount: 2),
          isVictory: true, isDominantVictory: false, nowMs: nowMs);
      expect(third.expGained, 25);

      final beyond = BattleReward.apply(_pet(todayBattleCount: 9),
          isVictory: true, isDominantVictory: false, nowMs: nowMs);
      expect(beyond.expGained, 25);
    });

    test('모험 이벤트(adventure)면 2배', () {
      final r = BattleReward.apply(_pet(todayEvent: 'adventure'),
          isVictory: true, isDominantVictory: false, nowMs: nowMs);
      expect(r.expGained, 100);
    });

    test('서버 baseExp 지정 시 그 값을 기준으로 배수 적용', () {
      final r = BattleReward.apply(_pet(todayBattleCount: 1),
          isVictory: true,
          isDominantVictory: true,
          baseExp: 70,
          nowMs: nowMs);
      expect(r.expGained, 49); // 70 × 0.7
    });
  });

  group('BattleReward.apply — 펫 상태 갱신', () {
    test('승리: 행복 +5, 배틀 카운트 +1, 승수 +1', () {
      final r = BattleReward.apply(_pet(happiness: 60, battleVictoryCount: 2),
          isVictory: true, isDominantVictory: false, nowMs: nowMs);
      expect(r.updatedPet.happiness, 65);
      expect(r.updatedPet.todayBattleCount, 1);
      expect(r.updatedPet.battleVictoryCount, 3);
      expect(r.updatedPet.lastUpdated, nowMs);
    });

    test('압승: 행복 +8', () {
      final r = BattleReward.apply(_pet(happiness: 60),
          isVictory: true, isDominantVictory: true, nowMs: nowMs);
      expect(r.updatedPet.happiness, 68);
    });

    test('패배: 행복 보너스 없음, 승수 유지, 카운트만 +1', () {
      final r = BattleReward.apply(_pet(happiness: 60, battleVictoryCount: 2),
          isVictory: false, isDominantVictory: false, nowMs: nowMs);
      expect(r.updatedPet.happiness, 60);
      expect(r.updatedPet.battleVictoryCount, 2);
      expect(r.updatedPet.todayBattleCount, 1);
      expect(r.expGained, 15);
    });

    test('레벨업: 필요 EXP 초과분 이월 + 레벨당 스탯 +10', () {
      // 레벨 1 필요 EXP 50 — 승리 50으로 정확히 1레벨업
      final r = BattleReward.apply(
          _pet(level: 1, exp: 0, hunger: 50, happiness: 50, stamina: 50),
          isVictory: true,
          isDominantVictory: false,
          nowMs: nowMs);
      expect(r.updatedPet.level, 2);
      expect(r.updatedPet.exp, 0);
      expect(r.updatedPet.hunger, 60);
      expect(r.updatedPet.happiness, 65); // +10 레벨업 +5 승리
      expect(r.updatedPet.stamina, 60);
    });
  });

  group('ApplyOnlineBattleRewardUseCase', () {
    late _FakePetRepository petRepo;
    late _FakeBattleHistoryRepository historyRepo;
    late ApplyOnlineBattleRewardUseCase usecase;

    setUp(() {
      petRepo = _FakePetRepository();
      historyRepo = _FakeBattleHistoryRepository();
      usecase = ApplyOnlineBattleRewardUseCase(
        petRepository: petRepo,
        activityRepository: _FakeActivityRepository(
          ActivityData(
              steps: 4000, exerciseMinutes: 12, startTime: 0, endTime: 0),
        ),
        battleHistoryRepository: historyRepo,
      );
    });

    test('보상을 펫에 저장하고 전적을 기록한다', () {
      petRepo.setPet(_pet(todayBattleCount: 0));
      return usecase('test-pet', isVictory: true, isDominantVictory: false)
          .then((reward) {
        expect(reward.expGained, 50);
        expect(petRepo.currentPet!.todayBattleCount, 1);
        expect(petRepo.currentPet!.battleVictoryCount, 1);
        expect(historyRepo.saved, hasLength(1));
        expect(historyRepo.saved.first.isVictory, isTrue);
        expect(historyRepo.saved.first.expGained, 50);
        expect(historyRepo.saved.first.steps, 4000);
      });
    });

    test('죽은 펫은 보상 없음', () async {
      petRepo.setPet(_pet(isDead: true));
      final reward =
          await usecase('test-pet', isVictory: true, isDominantVictory: false);
      expect(reward.expGained, 0);
      expect(historyRepo.saved, isEmpty);
    });

    test('자정이 지난 카운트는 리셋 후 1번째 배틀 배수(×1.0) 적용', () async {
      // 어제 3번 배틀한 상태 — 오늘 첫 배틀은 감쇠 없이 50
      petRepo.setPet(_pet(
        todayBattleCount: 3,
        lastGoalResetDate: '2000-01-01',
      ));
      final reward =
          await usecase('test-pet', isVictory: true, isDominantVictory: false);
      expect(reward.expGained, 50);
      expect(petRepo.currentPet!.todayBattleCount, 1);
    });

    test('서버 기본 경험치(baseExp)를 넘기면 그 값으로 계산', () async {
      petRepo.setPet(_pet(todayBattleCount: 1));
      final reward = await usecase('test-pet',
          isVictory: true, isDominantVictory: true, baseExp: 70);
      expect(reward.expGained, 49); // 70 × 0.7
    });
  });
}
