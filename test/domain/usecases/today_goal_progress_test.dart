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

    test('달성 후 차감 상태의 표시값은 목표치로 보정 (0/1 방지)', () {
      // Apply가 진행도를 차감해 원본은 0이지만 오늘 달성한 상태
      final today = makePet().todayDateString;
      final g = TodayGoalProgress.fromPet(makePet(
        level: 1, // 식사 1회 / 3000보 / 수면 5h
        lastFeedAchievedDate: today,
        lastSleepAchievedDate: today,
        lastExerciseAchievedDate: today,
      ));
      expect(g.feedProgress, 1, reason: '0/1이 아니라 1/1로 표시');
      expect(g.steps, 3000);
      expect(g.sleepMinutes, 5 * 60);
    });

    test('달성 상태여도 목표 초과 진행분은 그대로 표시', () {
      final today = makePet().todayDateString;
      final g = TodayGoalProgress.fromPet(makePet(
        level: 1,
        todayFeedCount: 5,
        totalSteps: 12000,
        lastFeedAchievedDate: today,
        lastExerciseAchievedDate: today,
      ));
      expect(g.feedProgress, 5);
      expect(g.steps, 12000);
    });
  });
}
