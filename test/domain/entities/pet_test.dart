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

  group('Pet.isStarving', () {
    test('포만감 0이면 true (행복·기력 무관)', () {
      expect(_createPet(hunger: 0, happiness: 0, stamina: 0).isStarving, true);
      expect(
          _createPet(hunger: 0, happiness: 80, stamina: 80).isStarving, true);
    });

    test('포만감이 1 이상이면 false', () {
      expect(_createPet(hunger: 1, happiness: 0, stamina: 0).isStarving, false);
      expect(
          _createPet(hunger: 50, happiness: 50, stamina: 50).isStarving, false);
    });
  });

  group('Pet.shouldDie', () {
    test('포만감 0 + 굶기 시작 하루(임계) 경과면 true — 행복·기력 남아있어도', () {
      final overThreshold = DateTime.now().subtract(
          const Duration(days: Pet.deathThresholdDays, hours: 1));
      final pet = _createPet(
        hunger: 0,
        happiness: 60,
        stamina: 60,
        zeroStatStartDate: overThreshold.toIso8601String(),
      );
      expect(pet.shouldDie, true);
    });

    test('포만감 0이어도 하루 미만이면 false', () {
      final underThreshold =
          DateTime.now().subtract(const Duration(hours: 23));
      final pet = _createPet(
        hunger: 0,
        happiness: 0,
        stamina: 0,
        zeroStatStartDate: underThreshold.toIso8601String(),
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

    test('포만감이 0이 아니면 false (행복·기력 0이어도)', () {
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

  group('Pet.wakeUp()', () {
    test('무료 깨우기 시 isDead=false, 수치 30/30/30', () {
      final sleepingPet = _createPet(
        hunger: 0, happiness: 0, stamina: 0,
        isDead: true,
        deathDate: DateTime.now().millisecondsSinceEpoch,
        resurrectCount: 0,
      );
      final awakenedPet = sleepingPet.wakeUp();
      expect(awakenedPet.isDead, false);
      expect(awakenedPet.hunger, 30);
      expect(awakenedPet.happiness, 30);
      expect(awakenedPet.stamina, 30);
      expect(awakenedPet.resurrectCount, 1);
    });

    test('완전 회복 깨우기(광고) 시 100/100/100', () {
      final sleepingPet = _createPet(
        hunger: 0, happiness: 0, stamina: 0,
        isDead: true, resurrectCount: 1,
      );
      final awakenedPet = sleepingPet.wakeUp(fullRecovery: true);
      expect(awakenedPet.hunger, 100);
      expect(awakenedPet.happiness, 100);
      expect(awakenedPet.stamina, 100);
      expect(awakenedPet.resurrectCount, 2);
    });

    test('여러 번 깨워도 레벨 패널티 없음', () {
      final sleepingPet = _createPet(
        hunger: 0, happiness: 0, stamina: 0,
        isDead: true, resurrectCount: 2, level: 5,
      );
      final awakenedPet = sleepingPet.wakeUp();
      expect(awakenedPet.hunger, 30);
      expect(awakenedPet.level, 5);
      expect(awakenedPet.resurrectCount, 3);
    });
  });

  group('Pet.clearZeroStatStartDate()', () {
    test('zeroStatStartDate를 null로 설정', () {
      final pet = _createPet(zeroStatStartDate: '2024-01-01');
      final cleared = pet.clearZeroStatStartDate();
      expect(cleared.zeroStatStartDate, isNull);
    });
  });

  // 참고: needsGoalPeriodReset(주간 리셋)은 폐기되어 항상 false를 반환한다.
  // 관련 테스트는 파일 하단의 'Pet.needsGoalPeriodReset' 그룹 참조.

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

  group('Pet.resetDailyGoals', () {
    test('보조 카운터만 리셋, 목표 진행도는 유지 (달성 시에만 차감)', () {
      final pet = _createPet().copyWith(
        todayFeedCount: 3,
        todaySleepHours: 5,
        todayFedMealSlots: 7,
        todayAlternativeFeedCount: 2,
        todayBattleCount: 3,
        feedAchievedCount: 12,
        sleepAchievedCount: 8,
      );
      final reset = pet.resetDailyGoals();
      // 목표 진행도는 유지 (달성 시에만 차감됨)
      expect(reset.todayFeedCount, 3);
      expect(reset.todaySleepHours, 5);
      // 보조 카운터는 일일 리셋
      expect(reset.todayFedMealSlots, 0);
      expect(reset.todayAlternativeFeedCount, 0);
      // 배틀 횟수도 자정 리셋 (하루 3회 제한이 종신 캡이 되지 않도록)
      expect(reset.todayBattleCount, 0);
      // 누적 달성 카운트 유지
      expect(reset.feedAchievedCount, 12);
      expect(reset.sleepAchievedCount, 8);
    });
  });

  group('Pet.exerciseProgress', () {
    test('totalSteps - lastExerciseGoalSteps = 현재 운동 진행 걸음수', () {
      final pet = _createPet().copyWith(
        totalSteps: 12000,
        lastExerciseGoalSteps: 5000,
        totalExerciseMinutes: 45,
        lastExerciseGoalMinutes: 20,
      );
      expect(pet.exerciseProgressSteps, 7000);
      expect(pet.exerciseProgressMinutes, 25);
    });

    test('lastExerciseGoalSteps가 totalSteps보다 크면 0으로 클램프', () {
      final pet = _createPet().copyWith(
        totalSteps: 1000,
        lastExerciseGoalSteps: 2000,
      );
      expect(pet.exerciseProgressSteps, 0);
    });
  });

  group('Pet.categoryTiers', () {
    test('feedAchievedCount 25 → feedTier 2, 다음 티어까지 5', () {
      final pet = _createPet().copyWith(feedAchievedCount: 25);
      expect(pet.feedTier, 2);
      expect(pet.feedRemainingToNextTier, 5);
    });

    test('sleepAchievedCount 0 → sleepTier 0, 다음 티어까지 10', () {
      final pet = _createPet();
      expect(pet.sleepTier, 0);
      expect(pet.sleepRemainingToNextTier, 10);
    });

    test('exerciseAchievedCount 10 → exerciseTier 1, 다음 티어까지 10', () {
      final pet = _createPet().copyWith(exerciseAchievedCount: 10);
      expect(pet.exerciseTier, 1);
      expect(pet.exerciseRemainingToNextTier, 10);
    });
  });

  group('Pet.needsGoalPeriodReset', () {
    test('주간 리셋이 제거되어 항상 false', () {
      final pet = _createPet().copyWith(goalStartDate: '2020-01-01');
      expect(pet.needsGoalPeriodReset, false);
    });
  });
}
