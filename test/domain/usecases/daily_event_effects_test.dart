import 'package:flutter_test/flutter_test.dart';
import 'package:pocketfriend/domain/constants/daily_events.dart';
import 'package:pocketfriend/domain/entities/activity_data.dart';
import 'package:pocketfriend/domain/entities/pet.dart';
import 'package:pocketfriend/domain/entities/phone_usage.dart';
import 'package:pocketfriend/domain/repositories/activity_repository.dart';
import 'package:pocketfriend/domain/repositories/pet_repository.dart';
import 'package:pocketfriend/domain/repositories/phone_usage_repository.dart';
import 'package:pocketfriend/domain/usecases/auto_sleep_pet_usecase.dart';
import 'package:pocketfriend/domain/usecases/feed_pet_usecase.dart';
import 'package:pocketfriend/domain/usecases/update_pet_from_activity_usecase.dart';

/// 일일 이벤트 효과 테스트 — sunny/cozy/tasty
/// (happy_day는 update_pet_state_usecase_test, adventure는
///  apply_battle_reward_test에서 검증)

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

class _FakePhoneUsageRepository implements PhoneUsageRepository {
  PhoneUsage _phoneUsage;
  _FakePhoneUsageRepository(this._phoneUsage);

  @override
  Future<PhoneUsage> getPhoneUsage() async => _phoneUsage;
  @override
  Future<void> savePhoneUsage(PhoneUsage phoneUsage) async {
    _phoneUsage = phoneUsage;
  }

  @override
  Future<void> onForeground() async {}
  @override
  Future<void> onBackground() async {}
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
  int hunger = 50,
  int happiness = 50,
  int stamina = 50,
  String todayEvent = '',
}) {
  final now = DateTime.now().millisecondsSinceEpoch;
  return Pet(
    id: 'p',
    hunger: hunger,
    happiness: happiness,
    stamina: stamina,
    level: 1,
    exp: 0,
    evolutionStage: 1,
    lastUpdated: now,
    lastStatusDecayUpdated: now,
    lastGoalResetDate: _today(),
    lastActivitySyncTime: now,
    todayEvent: todayEvent,
    lastEventDate: _today(),
  );
}

void main() {
  group('cozy — 수면 stamina 회복 1.5배', () {
    Future<Pet> runAutoSleep(Pet pet) async {
      final petRepo = _FakePetRepository()..setPet(pet);
      final phoneRepo = _FakePhoneUsageRepository(
        PhoneUsage(
          // 30분 전부터 미사용 → 10분 단위 3크레딧
          lastForegroundTime:
              DateTime.now().millisecondsSinceEpoch - 30 * 60 * 1000,
          totalIdleHours: 0,
        ),
      );
      final useCase = AutoSleepPetUseCase(
        petRepository: petRepo,
        phoneUsageRepository: phoneRepo,
      );
      return useCase('p', isInBackground: true);
    }

    test('이벤트 없음: 30분 미사용 → stamina +3', () async {
      final result = await runAutoSleep(_pet(stamina: 50));
      expect(result.stamina, 53);
    });

    test('cozy: 30분 미사용 → stamina +5 (3 × 1.5 반올림)', () async {
      final result =
          await runAutoSleep(_pet(stamina: 50, todayEvent: DailyEvents.cozy));
      expect(result.stamina, 55);
      // 수면 목표 분 누적은 실제 시간 그대로 (배율 미적용)
      expect(result.todaySleepMinutes, 30);
    });
  });

  group('sunny — 걸음 happiness 보상 1.5배', () {
    Future<Pet> runActivity(Pet pet, int steps) async {
      final petRepo = _FakePetRepository()..setPet(pet);
      final actRepo = _FakeActivityRepository(ActivityData(
        steps: steps,
        exerciseMinutes: 0,
        startTime: 0,
        endTime: 0,
      ));
      final useCase = UpdatePetFromActivityUseCase(
        petRepository: petRepo,
        activityRepository: actRepo,
      );
      return useCase('p');
    }

    test('이벤트 없음: 2000보 → happiness +6', () async {
      final result = await runActivity(_pet(happiness: 50), 2000);
      expect(result.happiness, 56);
    });

    test('sunny: 2000보 → happiness +9 (6 × 1.5)', () async {
      final result = await runActivity(
        _pet(happiness: 50, todayEvent: DailyEvents.sunny),
        2000,
      );
      expect(result.happiness, 59);
      // 실제 걸음 수는 부풀리지 않는다 (운동 목표·전투력 왜곡 방지)
      expect(result.totalSteps, 2000);
    });
  });

  group('tasty — 식사 hunger 회복 +5', () {
    // FeedPetUseCase는 현재 시각의 식사 시간대에서만 동작하므로
    // 식사 시간대(6:30-10 / 11-14:30 / 17-21)일 때만 검증한다.
    bool isInMealTime() {
      final now = DateTime.now();
      final minutes = now.hour * 60 + now.minute;
      for (final range in FeedPetUseCase.mealTimeRanges) {
        final start = range['startHour']! * 60 + range['startMin']!;
        final end = range['endHour']! * 60 + range['endMin']!;
        if (minutes >= start && minutes < end) return true;
      }
      return false;
    }

    test('이벤트 없음: 밥주기 → hunger +20 / tasty: +25', () async {
      if (!isInMealTime()) return; // 시간대 밖이면 건너뜀

      final normalRepo = _FakePetRepository()..setPet(_pet(hunger: 50));
      final normalResult = await FeedPetUseCase(normalRepo)('p');
      expect(normalResult.hunger, 70);

      final tastyRepo = _FakePetRepository()
        ..setPet(_pet(hunger: 50, todayEvent: DailyEvents.tasty));
      final tastyResult = await FeedPetUseCase(tastyRepo)('p');
      expect(tastyResult.hunger, 75);
    });
  });
}
