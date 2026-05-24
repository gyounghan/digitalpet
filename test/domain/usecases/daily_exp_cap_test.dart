import 'package:flutter_test/flutter_test.dart';
import 'package:pocketfriend/domain/entities/activity_data.dart';
import 'package:pocketfriend/domain/entities/pet.dart';
import 'package:pocketfriend/domain/repositories/activity_repository.dart';
import 'package:pocketfriend/domain/repositories/pet_repository.dart';
import 'package:pocketfriend/domain/usecases/apply_daily_goals_score_usecase.dart';
import 'package:pocketfriend/domain/usecases/calculate_daily_goals_score_usecase.dart';

/// 세트 클리어 EXP + EXP 곡선 + 현실적 목표 곡선 회귀 테스트.
///
/// 핵심 보증:
///  1. 세트 = 포만감+수면+운동 "모두" 달성해야 1세트 (하나라도 빠지면 0 EXP)
///  2. 오늘 N번째 세트마다 EXP 반감 (60→30→15→...)
///  3. 세트 마일스톤(10세트 누적)마다 +50 보너스
///  4. 자정 리셋: todaySetExpClaimed=0, totalSetsRewarded는 보존
///  5. RPG EXP 곡선 / 현실적 목표 곡선 정확

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
  ActivityData data;
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

String _today() {
  final now = DateTime.now();
  return '${now.year}-${now.month.toString().padLeft(2, '0')}-'
      '${now.day.toString().padLeft(2, '0')}';
}

Pet _pet({
  int level = 1,
  int exp = 0,
  int todayFeedCount = 0,
  int todaySleepMinutes = 0,
  int totalSteps = 0,
  int feedAchievedCount = 0,
  int sleepAchievedCount = 0,
  int exerciseAchievedCount = 0,
  int todaySetExpClaimed = 0,
  int totalSetsRewarded = 0,
}) {
  final now = DateTime.now().millisecondsSinceEpoch;
  final today = _today();
  return Pet(
    id: 'p',
    hunger: 50,
    happiness: 50,
    stamina: 50,
    level: level,
    exp: exp,
    evolutionStage: 1,
    lastUpdated: now,
    lastStatusDecayUpdated: now,
    todayFeedCount: todayFeedCount,
    todaySleepMinutes: todaySleepMinutes,
    todaySleepHours: todaySleepMinutes ~/ 60,
    totalSteps: totalSteps,
    lastGoalResetDate: today,
    feedAchievedCount: feedAchievedCount,
    sleepAchievedCount: sleepAchievedCount,
    exerciseAchievedCount: exerciseAchievedCount,
    todaySetExpClaimed: todaySetExpClaimed,
    totalSetsRewarded: totalSetsRewarded,
  );
}

ApplyDailyGoalsScoreUseCase _makeApply(_FakePetRepository petRepo) {
  final actRepo = _FakeActivityRepository(ActivityData.empty());
  final calc = CalculateDailyGoalsScoreUseCase(
    petRepository: petRepo,
    activityRepository: actRepo,
  );
  return ApplyDailyGoalsScoreUseCase(
    petRepository: petRepo,
    calculateScoreUseCase: calc,
  );
}

void main() {
  group('EXP 곡선 — RPG 후반 가파른 형태', () {
    test('각 구간 임계값', () {
      expect(Pet.getRequiredExpForLevel(1), 50);
      expect(Pet.getRequiredExpForLevel(3), 50);
      expect(Pet.getRequiredExpForLevel(4), 100);
      expect(Pet.getRequiredExpForLevel(7), 100);
      expect(Pet.getRequiredExpForLevel(8), 200);
      expect(Pet.getRequiredExpForLevel(12), 200);
      expect(Pet.getRequiredExpForLevel(13), 350);
      expect(Pet.getRequiredExpForLevel(17), 350);
      expect(Pet.getRequiredExpForLevel(18), 550);
      expect(Pet.getRequiredExpForLevel(22), 550);
      expect(Pet.getRequiredExpForLevel(23), 800);
      expect(Pet.getRequiredExpForLevel(27), 800);
      expect(Pet.getRequiredExpForLevel(28), 1100);
      expect(Pet.getRequiredExpForLevel(50), 1100);
    });

    test('단조 증가 (Lv1~30)', () {
      int prev = Pet.getRequiredExpForLevel(1);
      for (int lv = 2; lv <= 30; lv++) {
        final cur = Pet.getRequiredExpForLevel(lv);
        expect(cur >= prev, true,
            reason: 'Lv$lv 필요 EXP가 Lv${lv - 1}보다 작으면 안됨');
        prev = cur;
      }
    });
  });

  group('현실적 목표 곡선 — 비현실적 수치 제거', () {
    test('운동 걸음 최대 8000보까지 (10000보 폐기)', () {
      expect(CalculateDailyGoalsScoreUseCase.getExerciseGoalSteps(1), 3000);
      expect(CalculateDailyGoalsScoreUseCase.getExerciseGoalSteps(5), 3000);
      expect(CalculateDailyGoalsScoreUseCase.getExerciseGoalSteps(10), 4000);
      expect(CalculateDailyGoalsScoreUseCase.getExerciseGoalSteps(15), 5000);
      expect(CalculateDailyGoalsScoreUseCase.getExerciseGoalSteps(20), 6000);
      expect(CalculateDailyGoalsScoreUseCase.getExerciseGoalSteps(30), 8000);
      expect(CalculateDailyGoalsScoreUseCase.getExerciseGoalSteps(50) <= 8000,
          true);
    });

    test('수면 목표 5~7시간 (3시간 같은 너무 짧은 값 제거)', () {
      expect(CalculateDailyGoalsScoreUseCase.getSleepGoalHours(1), 5);
      expect(CalculateDailyGoalsScoreUseCase.getSleepGoalHours(10), 5);
      expect(CalculateDailyGoalsScoreUseCase.getSleepGoalHours(20), 6);
      expect(CalculateDailyGoalsScoreUseCase.getSleepGoalHours(30), 7);
      for (int lv = 1; lv <= 40; lv++) {
        expect(CalculateDailyGoalsScoreUseCase.getSleepGoalHours(lv) >= 5,
            true);
      }
    });

    test('운동 분 최대 30분 (현실적)', () {
      expect(CalculateDailyGoalsScoreUseCase.getExerciseGoalMinutes(5), 10);
      expect(CalculateDailyGoalsScoreUseCase.getExerciseGoalMinutes(30), 30);
      for (int lv = 1; lv <= 50; lv++) {
        expect(CalculateDailyGoalsScoreUseCase.getExerciseGoalMinutes(lv) <= 30,
            true);
      }
    });
  });

  group('세트 클리어 EXP — 셋 다 채워야 보상', () {
    test('포만감만 달성 → 세트 미완성, EXP 0', () async {
      // Lv1: feed 목표 1회만 채우고 수면/운동은 0
      final petRepo = _FakePetRepository()
        ..setPet(_pet(level: 1, exp: 0, todayFeedCount: 1));
      final apply = _makeApply(petRepo);

      final result = await apply('p');

      expect(result.exp, 0, reason: '세트 미완성이면 EXP 없음');
      expect(result.feedAchievedCount, 1, reason: '달성 카운트는 누적');
      expect(result.totalSetsRewarded, 0);
    });

    test('포만감+수면+운동 모두 첫 달성 → 1세트 +60 → 레벨업', () async {
      // Lv1 목표: feed 1회, sleep 5h(300분), 운동 3000보
      final petRepo = _FakePetRepository()
        ..setPet(_pet(
          level: 1,
          exp: 0,
          todayFeedCount: 1,
          todaySleepMinutes: 300,
          totalSteps: 3000,
        ));
      final apply = _makeApply(petRepo);

      final result = await apply('p');

      // 60 EXP, Lv1 필요 50 → Lv2, 남은 10
      expect(result.level, 2);
      expect(result.exp, 10);
      expect(result.todaySetExpClaimed, 1);
      expect(result.totalSetsRewarded, 1);
    });

    test('같은 날 2번째 세트 → 반감 +30', () async {
      // 이미 1세트 보상받은 상태에서 각 카테고리 1회씩 더 달성
      final petRepo = _FakePetRepository()
        ..setPet(_pet(
          level: 1,
          exp: 0,
          todayFeedCount: 1,
          todaySleepMinutes: 300,
          totalSteps: 3000,
          feedAchievedCount: 1,
          sleepAchievedCount: 1,
          exerciseAchievedCount: 1,
          totalSetsRewarded: 1,
          todaySetExpClaimed: 1,
        ));
      final apply = _makeApply(petRepo);

      final result = await apply('p');

      // 60 >> 1 = 30. 30 < 50 → 레벨 유지
      expect(result.exp, 30);
      expect(result.level, 1);
      expect(result.todaySetExpClaimed, 2);
      expect(result.totalSetsRewarded, 2);
    });

    test('한 사이클에 3세트 동시 완성 → 60+30+15 = 105', () async {
      // Lv1 목표 ×3씩: feed 3회, sleep 900분(3×5h), 운동 9000보(3×3000)
      final petRepo = _FakePetRepository()
        ..setPet(_pet(
          level: 1,
          exp: 0,
          todayFeedCount: 3,
          todaySleepMinutes: 900,
          totalSteps: 9000,
        ));
      final apply = _makeApply(petRepo);

      final result = await apply('p');

      // 105 → Lv1(50)→Lv2, Lv2(50)→Lv3, 남은 5
      expect(result.level, 3);
      expect(result.exp, 5);
      expect(result.todaySetExpClaimed, 3);
      expect(result.totalSetsRewarded, 3);
    });

    test('세트 마일스톤(10세트) → +50 보너스 (반감 0이어도 발동)', () async {
      // 누적 9세트 + 오늘 6세트 받아 반감 0인 상태에서 10번째 세트 완성
      final petRepo = _FakePetRepository()
        ..setPet(_pet(
          level: 1,
          exp: 0,
          todayFeedCount: 1,
          todaySleepMinutes: 300,
          totalSteps: 3000,
          feedAchievedCount: 9,
          sleepAchievedCount: 9,
          exerciseAchievedCount: 9,
          totalSetsRewarded: 9,
          todaySetExpClaimed: 6, // 60 >> 6 = 0
        ));
      final apply = _makeApply(petRepo);

      final result = await apply('p');

      // 세트 반감 0 + 마일스톤 50 = 50 → Lv1(50) 레벨업
      expect(result.totalSetsRewarded, 10);
      expect(result.level, 2);
      expect(result.exp, 0);
    });

    test('자정 리셋: todaySetExpClaimed=0, totalSetsRewarded 보존', () {
      final pet = _pet(todaySetExpClaimed: 5, totalSetsRewarded: 8);
      final yesterday = pet.copyWith(lastGoalResetDate: '2020-01-01');
      expect(yesterday.needsGoalReset, true);

      final reset = yesterday.resetDailyGoals();
      expect(reset.todaySetExpClaimed, 0, reason: '반감 카운터는 매일 리셋');
      expect(reset.totalSetsRewarded, 8, reason: '누적 워터마크는 보존');
    });
  });
}
