import 'package:flutter_test/flutter_test.dart';
import 'package:pocketfriend/domain/entities/activity_data.dart';
import 'package:pocketfriend/domain/entities/pet.dart';
import 'package:pocketfriend/domain/repositories/activity_repository.dart';
import 'package:pocketfriend/domain/repositories/pet_repository.dart';
import 'package:pocketfriend/domain/usecases/apply_daily_goals_score_usecase.dart';
import 'package:pocketfriend/domain/usecases/calculate_daily_goals_score_usecase.dart';
import 'package:pocketfriend/domain/usecases/today_goal_progress.dart';

/// 급식 → 정산(Apply) → 홈 카드 표시 전체 사슬 회귀 테스트.
///
/// "식사 1회를 주면 0으로 보였다가 다음 액션에서야 1이 되던" 증상 방지:
/// 정산이 진행도를 차감(1→0)해도 오늘 달성 카운트가 함께 올라
/// 카드에는 누적 1/2회로 보여야 한다.

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
  ActivityData _empty() {
    final now = DateTime.now().millisecondsSinceEpoch;
    return ActivityData(
        steps: 0, exerciseMinutes: 0, startTime: now, endTime: now);
  }

  @override
  Future<ActivityData> getTodayActivityData() async => _empty();
  @override
  Future<ActivityData> getActivityData(
          {required int startTime, required int endTime}) async =>
      _empty();
  @override
  Future<ActivityData> getLast24HoursActivityData() async => _empty();
}

String _today() {
  final now = DateTime.now();
  return '${now.year}-${now.month.toString().padLeft(2, '0')}-'
      '${now.day.toString().padLeft(2, '0')}';
}

Pet _fedPet() {
  final now = DateTime.now().millisecondsSinceEpoch;
  return Pet(
    id: 'p',
    hunger: 80,
    happiness: 80,
    stamina: 80,
    level: 1, // 식사 목표 단위 1회
    exp: 0,
    evolutionStage: 1,
    lastUpdated: now,
    lastStatusDecayUpdated: now,
    todayFeedCount: 1, // 방금 급식 1회 완료 상태
    lastGoalResetDate: _today(),
  );
}

void main() {
  test('급식 1회 → 정산 직후 카드가 1/2회로 보인다 (0으로 떨어지지 않음)', () async {
    final repo = _FakePetRepo()..pet = _fedPet();
    final calculate = CalculateDailyGoalsScoreUseCase(
      petRepository: repo,
      activityRepository: _FakeActivityRepo(),
    );
    final apply = ApplyDailyGoalsScoreUseCase(
      petRepository: repo,
      calculateScoreUseCase: calculate,
    );

    // 정산 전: 1/1 가득
    final before = TodayGoalProgress.fromPet(repo.pet!);
    expect(before.feedProgress, 1);
    expect(before.feedGoal, 1);
    expect(before.feedDone, isTrue);

    // 정산 (feed() → _updateAndEvolve 내부에서 실행되는 것과 동일)
    final applied = await apply('p');

    // 내부 상태: 잔여 차감 + 오늘 달성 1회 기록
    expect(applied.todayFeedCount, 0);
    expect(applied.todayFeedAchievedCount, 1);
    expect(applied.exp, greaterThan(0), reason: '카테고리 EXP 지급');

    // 표시: 누적 1회 / 다음 목표 2회 — 절대 0으로 보이면 안 됨
    final after = TodayGoalProgress.fromPet(applied);
    expect(after.feedProgress, 1, reason: '정산 후에도 누적 1회 유지');
    expect(after.feedGoal, 2);
    expect(after.feedDone, isTrue);

    // 저장소의 펫(다음 화면 로드 기준)도 동일해야 한다
    final persisted = TodayGoalProgress.fromPet(repo.pet!);
    expect(persisted.feedProgress, 1);
  });

  test('두 번째 급식(다른 슬롯) → 2/3회로 이어진다', () async {
    final repo = _FakePetRepo()..pet = _fedPet();
    final calculate = CalculateDailyGoalsScoreUseCase(
      petRepository: repo,
      activityRepository: _FakeActivityRepo(),
    );
    final apply = ApplyDailyGoalsScoreUseCase(
      petRepository: repo,
      calculateScoreUseCase: calculate,
    );

    await apply('p'); // 1세트 정산
    repo.pet = repo.pet!.copyWith(todayFeedCount: 1); // 두 번째 급식
    final applied = await apply('p'); // 2세트 정산

    expect(applied.todayFeedAchievedCount, 2);
    final g = TodayGoalProgress.fromPet(applied);
    expect(g.feedProgress, 2);
    expect(g.feedGoal, 3);
  });
}
