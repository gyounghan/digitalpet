import 'package:flutter_test/flutter_test.dart';
import 'package:pocketfriend/domain/entities/pet.dart';
import 'package:pocketfriend/domain/usecases/today_goal_progress.dart';

void main() {
  Pet makePet({
    int level = 1,
    int todayFeedCount = 0,
    int todaySleepMinutes = 0,
    int totalSteps = 0,
    int lastExerciseGoalSteps = 0,
    int totalExerciseMinutes = 0,
    int lastExerciseGoalMinutes = 0,
    int todayFeedAchievedCount = 0,
    int todaySleepAchievedCount = 0,
    int todayExerciseAchievedCount = 0,
    String lastFeedAchievedDate = '',
    String lastSleepAchievedDate = '',
    String lastExerciseAchievedDate = '',
  }) {
    return Pet(
      id: 'test-pet',
      name: '테스트',
      hunger: 80,
      happiness: 80,
      stamina: 80,
      exp: 0,
      evolutionStage: 1,
      lastUpdated: 0,
      lastStatusDecayUpdated: 0,
      level: level,
      todayFeedCount: todayFeedCount,
      todaySleepMinutes: todaySleepMinutes,
      todaySleepHours: todaySleepMinutes ~/ 60,
      totalSteps: totalSteps,
      lastExerciseGoalSteps: lastExerciseGoalSteps,
      totalExerciseMinutes: totalExerciseMinutes,
      lastExerciseGoalMinutes: lastExerciseGoalMinutes,
      todayFeedAchievedCount: todayFeedAchievedCount,
      todaySleepAchievedCount: todaySleepAchievedCount,
      todayExerciseAchievedCount: todayExerciseAchievedCount,
      lastFeedAchievedDate: lastFeedAchievedDate,
      lastSleepAchievedDate: lastSleepAchievedDate,
      lastExerciseAchievedDate: lastExerciseAchievedDate,
    );
  }

  group('TodayGoalProgress — 레벨별 목표치 (1세트 단위)', () {
    test('레벨 1: 식사 1회 / 3000보 / 수면 5시간', () {
      final g = TodayGoalProgress.fromPet(makePet(level: 1));
      expect(g.feedGoal, 1);
      expect(g.stepsGoal, 3000);
      expect(g.sleepGoalMinutes, 5 * 60);
    });

    test('고레벨도 목표 캡 고정: 식사 2회 / 4000보 / 수면 6시간', () {
      final g = TodayGoalProgress.fromPet(makePet(level: 25));
      expect(g.feedGoal, 2);
      expect(g.stepsGoal, 4000);
      expect(g.sleepGoalMinutes, 6 * 60);
    });
  });

  group('TodayGoalProgress — 진행/달성 판정', () {
    test('진행 중: 목표 미만이면 done=false, ratio는 비례', () {
      final g = TodayGoalProgress.fromPet(makePet(
        level: 10, // 식사 2회 / 4000보 / 수면 5h
        todayFeedCount: 1,
        totalSteps: 2000,
        todaySleepMinutes: 150, // 2.5h
      ));
      expect(g.feedDone, isFalse);
      expect(g.exerciseDone, isFalse);
      expect(g.sleepDone, isFalse);
      expect(g.feedRatio, closeTo(0.5, 0.001));
      expect(g.exerciseRatio, closeTo(0.5, 0.001));
      expect(g.sleepRatio, closeTo(0.5, 0.001));
      expect(g.allDone, isFalse);
    });

    test('목표치 도달 시 done=true, ratio=1.0 (Apply 차감 전 순간)', () {
      final g = TodayGoalProgress.fromPet(makePet(
        level: 1,
        todayFeedCount: 1,
        totalSteps: 3000,
        todaySleepMinutes: 5 * 60,
      ));
      expect(g.feedDone, isTrue);
      expect(g.exerciseDone, isTrue);
      expect(g.sleepDone, isTrue);
      expect(g.feedRatio, 1.0);
      expect(g.exerciseRatio, 1.0);
      expect(g.sleepRatio, 1.0);
      expect(g.allDone, isTrue);
    });

    test('어제 달성 기록은 오늘 done으로 치지 않는다', () {
      final g = TodayGoalProgress.fromPet(makePet(
        level: 1,
        lastFeedAchievedDate: '2000-01-01',
      ));
      expect(g.feedDone, isFalse);
    });

    test('운동은 걸음(steps)만으로 판정 — 운동분은 달성에 안 잡힌다', () {
      // 레벨 1: 3000보 목표. 운동분 10분이 있어도 걸음이 부족하면 미달성
      final g = TodayGoalProgress.fromPet(makePet(
        level: 1,
        totalSteps: 100,
        totalExerciseMinutes: 10,
      ));
      expect(g.exerciseDone, isFalse);
      // 걸음만 채우면 달성
      final g2 = TodayGoalProgress.fromPet(makePet(level: 1, totalSteps: 3000));
      expect(g2.exerciseDone, isTrue);
    });

    test('ratio는 1.0을 넘지 않는다 (목표 초과분 클램프)', () {
      final g = TodayGoalProgress.fromPet(makePet(
        level: 1,
        todayFeedCount: 5,
      ));
      expect(g.feedRatio, 1.0);
    });
  });

  group('TodayGoalProgress — 누적식 표시 (세트 완료 후 다음 목표)', () {
    test('1세트 달성 후: 식사 1/2회, 게이지는 다음 목표 진행률', () {
      // Apply가 잔여를 차감(1→0)하고 달성 횟수를 1로 올린 직후 상태
      final g = TodayGoalProgress.fromPet(makePet(
        level: 1, // 식사 단위 1회
        todayFeedCount: 0,
        todayFeedAchievedCount: 1,
      ));
      expect(g.feedProgress, 1, reason: '오늘 누적 1회');
      expect(g.feedGoal, 2, reason: '2회째 목표');
      expect(g.feedDone, isTrue, reason: '오늘 달성 체크 유지');
      expect(g.feedRatio, closeTo(0.5, 0.001));
    });

    test('걸음 1세트(3000) 달성 + 500보 추가 → 3500/6000', () {
      final g = TodayGoalProgress.fromPet(makePet(
        level: 1, // 걸음 단위 3000
        totalSteps: 3500,
        lastExerciseGoalSteps: 3000, // 1세트분 차감됨
        todayExerciseAchievedCount: 1,
      ));
      expect(g.steps, 3500);
      expect(g.stepsGoal, 6000);
      expect(g.exerciseDone, isTrue);
    });

    test('수면 2세트 달성 → 10/15시간 (3세트째 도전)', () {
      final g = TodayGoalProgress.fromPet(makePet(
        level: 1, // 수면 단위 5h
        todaySleepMinutes: 0,
        todaySleepAchievedCount: 2,
      ));
      expect(g.sleepMinutes, 10 * 60);
      expect(g.sleepGoalMinutes, 15 * 60);
    });

    test('미달성 상태(0세트)는 기존과 동일한 단일 목표 표시', () {
      final g = TodayGoalProgress.fromPet(makePet(
        level: 1,
        totalSteps: 1200,
      ));
      expect(g.steps, 1200);
      expect(g.stepsGoal, 3000);
      expect(g.exerciseDone, isFalse);
    });
  });
}
