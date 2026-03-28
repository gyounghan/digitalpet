import 'package:flutter_test/flutter_test.dart';
import 'package:pocketfriend/domain/entities/pet.dart';

Pet _createPet({
  int hunger = 50,
  int happiness = 50,
  int stamina = 50,
  bool isDead = false,
  int? deathDate,
  String? zeroStatStartDate,
  int resurrectCount = 0,
  String goalStartDate = '',
  int goalStreakCount = 0,
  int totalSteps = 0,
  int totalExerciseMinutes = 0,
  int goalStartTotalSteps = 0,
  int goalStartTotalExerciseMinutes = 0,
  int level = 1,
}) {
  return Pet(
    id: 'test-pet',
    name: '테스트 펫',
    hunger: hunger,
    happiness: happiness,
    stamina: stamina,
    level: level,
    exp: 0,
    evolutionStage: 1,
    lastUpdated: DateTime.now().millisecondsSinceEpoch,
    lastStatusDecayUpdated: DateTime.now().millisecondsSinceEpoch,
    isDead: isDead,
    deathDate: deathDate,
    zeroStatStartDate: zeroStatStartDate,
    resurrectCount: resurrectCount,
    goalStartDate: goalStartDate,
    goalStreakCount: goalStreakCount,
    totalSteps: totalSteps,
    totalExerciseMinutes: totalExerciseMinutes,
    goalStartTotalSteps: goalStartTotalSteps,
    goalStartTotalExerciseMinutes: goalStartTotalExerciseMinutes,
  );
}

void main() {
  group('Pet.mood - 사망 상태', () {
    test('isDead가 true이면 PetMood.dead 반환', () {
      final pet = _createPet(
        isDead: true,
        hunger: 100,
        happiness: 100,
        stamina: 100,
      );
      expect(pet.mood, PetMood.dead);
    });

    test('isDead가 false이면 다른 mood 반환', () {
      final pet = _createPet(isDead: false, hunger: 100, happiness: 100, stamina: 100);
      expect(pet.mood, isNot(PetMood.dead));
    });
  });

  group('Pet.isAllStatsZero', () {
    test('모든 수치가 0이면 true', () {
      final pet = _createPet(hunger: 0, happiness: 0, stamina: 0);
      expect(pet.isAllStatsZero, true);
    });

    test('하나라도 0이 아니면 false', () {
      final pet = _createPet(hunger: 1, happiness: 0, stamina: 0);
      expect(pet.isAllStatsZero, false);
    });

    test('모든 수치가 양수이면 false', () {
      final pet = _createPet(hunger: 50, happiness: 50, stamina: 50);
      expect(pet.isAllStatsZero, false);
    });
  });

  group('Pet.shouldDie', () {
    test('모든 수치 0 + zeroStatStartDate 3일 전이면 true', () {
      final threeDaysAgo = DateTime.now().subtract(const Duration(days: 3));
      final dateStr =
          '${threeDaysAgo.year}-${threeDaysAgo.month.toString().padLeft(2, '0')}-${threeDaysAgo.day.toString().padLeft(2, '0')}';
      final pet = _createPet(
        hunger: 0,
        happiness: 0,
        stamina: 0,
        zeroStatStartDate: dateStr,
      );
      expect(pet.shouldDie, true);
    });

    test('모든 수치 0 + zeroStatStartDate 2일 전이면 false', () {
      final twoDaysAgo = DateTime.now().subtract(const Duration(days: 2));
      final dateStr =
          '${twoDaysAgo.year}-${twoDaysAgo.month.toString().padLeft(2, '0')}-${twoDaysAgo.day.toString().padLeft(2, '0')}';
      final pet = _createPet(
        hunger: 0,
        happiness: 0,
        stamina: 0,
        zeroStatStartDate: dateStr,
      );
      expect(pet.shouldDie, false);
    });

    test('이미 사망이면 false', () {
      final pet = _createPet(
        hunger: 0,
        happiness: 0,
        stamina: 0,
        isDead: true,
        zeroStatStartDate: '2020-01-01',
      );
      expect(pet.shouldDie, false);
    });

    test('zeroStatStartDate null이면 false', () {
      final pet = _createPet(hunger: 0, happiness: 0, stamina: 0);
      expect(pet.shouldDie, false);
    });

    test('수치가 0이 아니면 false', () {
      final pet = _createPet(
        hunger: 10,
        happiness: 0,
        stamina: 0,
        zeroStatStartDate: '2020-01-01',
      );
      expect(pet.shouldDie, false);
    });
  });

  group('Pet.die()', () {
    test('사망 처리 시 isDead=true, deathDate 설정', () {
      final pet = _createPet(hunger: 0, happiness: 0, stamina: 0);
      final deadPet = pet.die();
      expect(deadPet.isDead, true);
      expect(deadPet.deathDate, isNotNull);
      expect(deadPet.resurrectCount, 0);
    });
  });

  group('Pet.resurrect()', () {
    test('부활 시 isDead=false, 수치 50/50/50, resurrectCount 증가', () {
      final deadPet = _createPet(
        hunger: 0,
        happiness: 0,
        stamina: 0,
        isDead: true,
        deathDate: DateTime.now().millisecondsSinceEpoch,
        resurrectCount: 2,
      );
      final resurrectedPet = deadPet.resurrect();
      expect(resurrectedPet.isDead, false);
      expect(resurrectedPet.hunger, 50);
      expect(resurrectedPet.happiness, 50);
      expect(resurrectedPet.stamina, 50);
      expect(resurrectedPet.resurrectCount, 3);
      expect(resurrectedPet.deathDate, isNull);
      expect(resurrectedPet.zeroStatStartDate, isNull);
    });
  });

  group('Pet.clearZeroStatStartDate()', () {
    test('zeroStatStartDate를 null로 설정', () {
      final pet = _createPet(zeroStatStartDate: '2024-01-01');
      final cleared = pet.clearZeroStatStartDate();
      expect(cleared.zeroStatStartDate, isNull);
    });
  });

  group('Pet.needsGoalPeriodReset', () {
    test('goalStartDate로부터 7일 초과면 true', () {
      final eightDaysAgo = DateTime.now().subtract(const Duration(days: 8));
      final dateStr =
          '${eightDaysAgo.year}-${eightDaysAgo.month.toString().padLeft(2, '0')}-${eightDaysAgo.day.toString().padLeft(2, '0')}';
      final pet = _createPet(goalStartDate: dateStr);
      expect(pet.needsGoalPeriodReset, true);
    });

    test('goalStartDate로부터 7일 이내면 false', () {
      final sixDaysAgo = DateTime.now().subtract(const Duration(days: 6));
      final dateStr =
          '${sixDaysAgo.year}-${sixDaysAgo.month.toString().padLeft(2, '0')}-${sixDaysAgo.day.toString().padLeft(2, '0')}';
      final pet = _createPet(goalStartDate: dateStr);
      expect(pet.needsGoalPeriodReset, false);
    });

    test('goalStartDate 비어있으면 false', () {
      final pet = _createPet(goalStartDate: '');
      expect(pet.needsGoalPeriodReset, false);
    });
  });

  group('Pet.goalDaysElapsed', () {
    test('오늘 시작이면 0일', () {
      final now = DateTime.now();
      final dateStr =
          '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      final pet = _createPet(goalStartDate: dateStr);
      expect(pet.goalDaysElapsed, 0);
    });

    test('3일 전 시작이면 3일', () {
      final threeDaysAgo = DateTime.now().subtract(const Duration(days: 3));
      final dateStr =
          '${threeDaysAgo.year}-${threeDaysAgo.month.toString().padLeft(2, '0')}-${threeDaysAgo.day.toString().padLeft(2, '0')}';
      final pet = _createPet(goalStartDate: dateStr);
      expect(pet.goalDaysElapsed, 3);
    });
  });

  group('Pet.periodExerciseSteps', () {
    test('기간 내 운동 걸음 수 계산', () {
      final pet = _createPet(
        totalSteps: 10000,
        goalStartTotalSteps: 3000,
      );
      expect(pet.periodExerciseSteps, 7000);
    });
  });

  group('Pet.resetGoalPeriod', () {
    test('목표 완료 시 goalStartDate 갱신, streakCount 증가', () {
      final pet = _createPet(
        goalStreakCount: 2,
        totalSteps: 5000,
        totalExerciseMinutes: 30,
      );
      final reset = pet.resetGoalPeriod(completed: true);
      expect(reset.goalStreakCount, 3);
      expect(reset.todayFeedCount, 0);
      expect(reset.todaySleepHours, 0);
      expect(reset.goalStartTotalSteps, 5000);
      expect(reset.goalStartTotalExerciseMinutes, 30);
    });

    test('강제 리셋 시 streakCount 0으로 초기화', () {
      final pet = _createPet(goalStreakCount: 5);
      final reset = pet.resetGoalPeriod(completed: false);
      expect(reset.goalStreakCount, 0);
      expect(reset.todayFeedCount, 0);
      expect(reset.todaySleepHours, 0);
    });
  });

  group('Pet.resetDailyGoals', () {
    test('일일 항목만 리셋, 기간 누적은 유지', () {
      final pet = _createPet().copyWith(
        todayFeedCount: 3,
        todaySleepHours: 5,
        todayFedMealSlots: 7,
        todayAlternativeFeedCount: 2,
      );
      final reset = pet.resetDailyGoals();
      // 기간 누적은 유지
      expect(reset.todayFeedCount, 3);
      expect(reset.todaySleepHours, 5);
      // 일일 항목은 리셋
      expect(reset.todayFedMealSlots, 0);
      expect(reset.todayAlternativeFeedCount, 0);
    });
  });
}
