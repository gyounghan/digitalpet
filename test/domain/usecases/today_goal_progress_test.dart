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
      lastFeedAchievedDate: lastFeedAchievedDate,
      lastSleepAchievedDate: lastSleepAchievedDate,
      lastExerciseAchievedDate: lastExerciseAchievedDate,
    );
  }

  group('TodayGoalProgress — 레벨별 목표치', () {
    test('레벨 1: 식사 1회 / 3000보 / 수면 5시간', () {
      final g = TodayGoalProgress.fromPet(makePet(level: 1));
      expect(g.feedGoal, 1);
      expect(g.stepsGoal, 3000);
      expect(g.sleepGoalMinutes, 5 * 60);
    });

    test('레벨 21+: 식사 3회 / 8000보 / 수면 7시간', () {
      final g = TodayGoalProgress.fromPet(makePet(level: 25));
      expect(g.feedGoal, 3);
      expect(g.stepsGoal, 8000);
      expect(g.sleepGoalMinutes, 7 * 60);
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

    test('목표치 도달 시 done=true, ratio=1.0', () {
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

    test('달성 후 차감돼도 last*AchievedDate가 오늘이면 done 유지', () {
      // Apply 유스케이스가 진행도를 차감한 직후 상태 재현:
      // 진행도는 0이지만 오늘 이미 달성함
      final pet = makePet(level: 1);
      final today = pet.todayDateString;
      final g = TodayGoalProgress.fromPet(makePet(
        level: 1,
        lastFeedAchievedDate: today,
        lastSleepAchievedDate: today,
        lastExerciseAchievedDate: today,
      ));
      expect(g.feedDone, isTrue);
      expect(g.sleepDone, isTrue);
      expect(g.exerciseDone, isTrue);
      expect(g.allDone, isTrue);
      // 달성 상태면 진행바는 가득
      expect(g.feedRatio, 1.0);
    });

    test('어제 달성 기록은 오늘 done으로 치지 않는다', () {
      final g = TodayGoalProgress.fromPet(makePet(
        level: 1,
        lastFeedAchievedDate: '2000-01-01',
      ));
      expect(g.feedDone, isFalse);
    });

    test('운동은 걸음이 부족해도 분 축으로 달성 가능', () {
      // 레벨 1: 3000보 또는 10분
      final g = TodayGoalProgress.fromPet(makePet(
        level: 1,
        totalSteps: 100,
        totalExerciseMinutes: 10,
      ));
      expect(g.exerciseDone, isTrue);
      expect(g.exerciseRatio, 1.0);
    });

    test('걸음 진행은 lastExerciseGoalSteps 차감 후 증가분 기준', () {
      final g = TodayGoalProgress.fromPet(makePet(
        level: 1,
        totalSteps: 5000,
        lastExerciseGoalSteps: 3000, // 이미 1회 달성분 차감
      ));
      expect(g.steps, 2000);
    });

    test('ratio는 1.0을 넘지 않는다 (목표 초과분 클램프)', () {
      final g = TodayGoalProgress.fromPet(makePet(
        level: 1,
        todayFeedCount: 5,
      ));
      expect(g.feedRatio, 1.0);
    });
  });
}
