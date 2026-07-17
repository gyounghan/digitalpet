import 'package:flutter_test/flutter_test.dart';
import 'package:pocketfriend/domain/entities/activity_data.dart';
import 'package:pocketfriend/domain/entities/pet.dart';
import 'package:pocketfriend/domain/repositories/activity_repository.dart';
import 'package:pocketfriend/domain/repositories/pet_repository.dart';
import 'package:pocketfriend/domain/usecases/apply_daily_goals_score_usecase.dart';
import 'package:pocketfriend/domain/usecases/calculate_daily_goals_score_usecase.dart';

/// 일일목표 EXP(카테고리 독립 + 세트 보너스) + EXP 곡선 + 목표 곡선 회귀 테스트.
///
/// 핵심 보증:
///  1. 카테고리 1개 달성만으로도 +20 EXP (한 카테고리만 꾸준히 해도 성장 가능)
///  2. 세트(포만감+수면+운동 모두 달성)는 추가 보너스 — 오늘 N번째 세트마다
///     반감 (60→30→15→...)
///  3. 세트 마일스톤(10세트 누적)마다 +50 보너스,
///     카테고리 티어업(카테고리별 10회 누적)마다 +50 보너스
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
  int todayFeedAchievedCount = 0,
  int todaySleepAchievedCount = 0,
  int todayExerciseAchievedCount = 0,
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
    todayFeedAchievedCount: todayFeedAchievedCount,
    todaySleepAchievedCount: todaySleepAchievedCount,
    todayExerciseAchievedCount: todayExerciseAchievedCount,
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

  group('일일목표 EXP — 카테고리 독립 + 세트 보너스', () {
    test('포만감만 달성 → 카테고리 EXP +20 (세트 보너스는 없음)', () async {
      // Lv1: feed 목표 1회만 채우고 수면/운동은 0
      final petRepo = _FakePetRepository()
        ..setPet(_pet(level: 1, exp: 0, todayFeedCount: 1));
      final apply = _makeApply(petRepo);

      final result = await apply('p');

      expect(result.exp, 20, reason: '카테고리 1개 달성 = +20');
      expect(result.level, 1);
      expect(result.feedAchievedCount, 1, reason: '달성 카운트는 누적');
      expect(result.totalSetsRewarded, 0, reason: '세트는 미완성');
    });

    test('포만감+수면+운동 모두 첫 달성 → 카테고리 60 + 세트 60 = 120', () async {
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

      // 3카테고리 × 20 + 세트 60 = 120 → Lv1(50)→Lv2(50)→Lv3, 남은 20
      expect(result.level, 3);
      expect(result.exp, 20);
      expect(result.todaySetExpClaimed, 1);
      expect(result.totalSetsRewarded, 1);
    });

    test('같은 날 2번째 세트 → 카테고리 60 + 반감 30 = 90', () async {
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

      // 3 × 20 + (60 >> 1 = 30) = 90 → Lv1(50)→Lv2, 남은 40
      expect(result.level, 2);
      expect(result.exp, 40);
      expect(result.todaySetExpClaimed, 2);
      expect(result.totalSetsRewarded, 2);
    });

    test('한 사이클에 3세트 동시 완성 → 카테고리 180 + 세트 105 = 285', () async {
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

      // 9카테고리 달성 × 20 + (60+30+15) = 285
      // → Lv1(50)→Lv2(50)→Lv3(50)→Lv4(100)→Lv5, 남은 35
      expect(result.level, 5);
      expect(result.exp, 35);
      expect(result.todaySetExpClaimed, 3);
      expect(result.totalSetsRewarded, 3);
    });

    test('세트 마일스톤(10세트)+카테고리 티어업 → 보너스 (반감 0이어도 발동)',
        () async {
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

      // 카테고리 3×20 + 카테고리 티어업(9→10) 3×50 + 세트 반감 0
      //   + 세트 마일스톤 50 = 260
      // → Lv1(50)→Lv2(50)→Lv3(50)→Lv4(100)→Lv5, 남은 10
      expect(result.totalSetsRewarded, 10);
      expect(result.level, 5);
      expect(result.exp, 10);
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

  group('카테고리당 하루 최대 3회 달성 캡', () {
    test('4회분 진행해도 하루 3회까지만 지급, 초과 진행분은 이월', () async {
      // Lv1 목표: feed 1회, sleep 300분, 운동 3000보 — 각 4회분 진행
      final petRepo = _FakePetRepository()
        ..setPet(_pet(
          level: 1,
          exp: 0,
          todayFeedCount: 4,
          todaySleepMinutes: 1200,
          totalSteps: 12000,
        ));
      final apply = _makeApply(petRepo);

      final result = await apply('p');

      expect(result.feedAchievedCount, 3, reason: '하루 캡 3회');
      expect(result.sleepAchievedCount, 3);
      expect(result.exerciseAchievedCount, 3);
      expect(result.todayFeedAchievedCount, 3);
      expect(result.todaySleepAchievedCount, 3);
      expect(result.todayExerciseAchievedCount, 3);
      // 초과 진행분은 차감되지 않고 이월
      expect(result.todayFeedCount, 1);
      expect(result.todaySleepMinutes, 300);
      expect(result.exerciseProgressSteps, 3000);
    });

    test('오늘 이미 3회 달성한 카테고리는 진행분이 있어도 추가 지급 없음', () async {
      final petRepo = _FakePetRepository()
        ..setPet(_pet(
          level: 1,
          exp: 0,
          todayFeedCount: 2,
          feedAchievedCount: 3,
          sleepAchievedCount: 3,
          exerciseAchievedCount: 3,
          totalSetsRewarded: 3,
          todayFeedAchievedCount: 3,
          todaySleepAchievedCount: 3,
          todayExerciseAchievedCount: 3,
        ));
      final apply = _makeApply(petRepo);

      final result = await apply('p');

      expect(result.exp, 0, reason: '캡 도달 후 EXP 미지급');
      expect(result.feedAchievedCount, 3, reason: '누적 카운트 불변');
      expect(result.todayFeedCount, 2, reason: '진행분은 이월 보존');
    });

    test('자정 리셋 후 이월 진행분이 다시 지급된다', () async {
      // 어제 캡을 다 쓴 상태에서 자정이 지남 (lastGoalResetDate 과거)
      final petRepo = _FakePetRepository()
        ..setPet(_pet(
          level: 1,
          exp: 0,
          todayFeedCount: 2,
          feedAchievedCount: 3,
          sleepAchievedCount: 3,
          exerciseAchievedCount: 3,
          totalSetsRewarded: 3,
          todayFeedAchievedCount: 3,
          todaySleepAchievedCount: 3,
          todayExerciseAchievedCount: 3,
        ).copyWith(lastGoalResetDate: '2020-01-01'));
      final apply = _makeApply(petRepo);

      final result = await apply('p');

      // 리셋으로 todayFeedAchievedCount=0 → 이월된 2회분 지급 (캡 3 이내)
      expect(result.feedAchievedCount, 5);
      expect(result.todayFeedAchievedCount, 2);
      expect(result.todayFeedCount, 0);
      expect(result.exp, 40, reason: '이월 2회 × 20 EXP');
    });

    test('resetDailyGoals: 오늘 달성 카운터 3종 리셋', () {
      final pet = _pet(
        todayFeedAchievedCount: 3,
        todaySleepAchievedCount: 2,
        todayExerciseAchievedCount: 1,
      ).copyWith(lastGoalResetDate: '2020-01-01');

      final reset = pet.resetDailyGoals();
      expect(reset.todayFeedAchievedCount, 0);
      expect(reset.todaySleepAchievedCount, 0);
      expect(reset.todayExerciseAchievedCount, 0);
    });
  });

  group('resetDailyGoals — todayEvent 이월 방지', () {
    test('어제 부여된 이벤트는 리셋에서 제거된다', () {
      final pet = _pet().copyWith(
        lastGoalResetDate: '2020-01-01',
        todayEvent: 'adventure',
        lastEventDate: '2020-01-01',
      );

      final reset = pet.resetDailyGoals();
      expect(reset.todayEvent, '',
          reason: '어제 adventure ×2가 오늘 배틀에 적용되면 안 됨');
    });

    test('오늘 부여된 이벤트는 리셋 후에도 유지된다', () {
      final pet = _pet().copyWith(
        lastGoalResetDate: '2020-01-01',
        todayEvent: 'sunny',
        lastEventDate: _today(),
      );

      final reset = pet.resetDailyGoals();
      expect(reset.todayEvent, 'sunny');
    });
  });

  group('변화 없으면 lastUpdated를 밀지 않는다 (서버 sync 회수 경로 보존)', () {
    test('달성·세트·레벨업이 전혀 없으면 pet이 저장되지 않는다', () async {
      final original = _pet(level: 5, exp: 10);
      final petRepo = _FakePetRepository()..setPet(original);
      final apply = _makeApply(petRepo);

      final result = await apply('p');

      expect(result.lastUpdated, original.lastUpdated,
          reason: 'no-op 호출이 lastUpdated를 갱신하면 서버 우선 분기가 죽는다');
    });

    test('미소화 EXP가 레벨업 임계를 넘으면 no-op이어도 레벨업 처리', () async {
      // feed(+5)/login(+3) 등이 쌓아둔 exp가 임계(Lv1=50)를 넘은 상태
      final petRepo = _FakePetRepository()..setPet(_pet(level: 1, exp: 60));
      final apply = _makeApply(petRepo);

      final result = await apply('p');

      expect(result.level, 2);
      expect(result.exp, 10);
    });
  });
}
