import 'package:flutter_test/flutter_test.dart';
import 'package:pocketfriend/domain/entities/activity_data.dart';
import 'package:pocketfriend/domain/entities/pet.dart';
import 'package:pocketfriend/domain/repositories/activity_repository.dart';
import 'package:pocketfriend/domain/repositories/pet_repository.dart';
import 'package:pocketfriend/domain/usecases/update_pet_from_activity_usecase.dart';

/// Retroactive 동기화 단위 테스트.
/// 백그라운드 동기화가 실패해 며칠 만에 앱을 켰을 때, 그 사이 활동량이
/// 한꺼번에 happiness/totalSteps로 catch-up되는지 검증.

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

/// 시간 범위에 따라 다른 활동값을 반환하는 fake.
/// retroactive 호출 = startTime이 오늘 0시 이전 → retroData 반환.
/// 그 외(getTodayActivityData) = todayData 반환.
class _RangeAwareActivityRepository implements ActivityRepository {
  final ActivityData todayData;
  final ActivityData retroData;
  int retroCallCount = 0;
  int todayCallCount = 0;

  _RangeAwareActivityRepository({
    required this.todayData,
    required this.retroData,
  });

  @override
  Future<ActivityData> getActivityData({
    required int startTime,
    required int endTime,
  }) async {
    retroCallCount++;
    return retroData;
  }

  @override
  Future<ActivityData> getTodayActivityData() async {
    todayCallCount++;
    return todayData;
  }

  @override
  Future<ActivityData> getLast24HoursActivityData() async => todayData;
}

Pet _basePet({
  int happiness = 50,
  int totalSteps = 0,
  int lastActivitySyncTime = 0,
  int todaySyncedSteps = 0,
}) {
  return Pet(
    id: 'p',
    name: '테스트',
    hunger: 50,
    happiness: happiness,
    stamina: 50,
    level: 1,
    exp: 0,
    evolutionStage: 1,
    lastUpdated: DateTime.now().millisecondsSinceEpoch,
    lastStatusDecayUpdated: DateTime.now().millisecondsSinceEpoch,
    totalSteps: totalSteps,
    todaySyncedSteps: todaySyncedSteps,
    lastActivitySyncTime: lastActivitySyncTime,
  );
}

void main() {
  group('Retroactive 동기화', () {
    test('lastActivitySyncTime == 0 (최초) → retroactive fetch 호출하지 않음',
        () async {
      final petRepo = _FakePetRepository();
      final activityRepo = _RangeAwareActivityRepository(
        todayData: ActivityData(
          steps: 1000,
          exerciseMinutes: 0,
          startTime: 0,
          endTime: 1,
        ),
        retroData: ActivityData(
          steps: 999999,
          exerciseMinutes: 0,
          startTime: 0,
          endTime: 1,
        ),
      );
      petRepo.setPet(_basePet(lastActivitySyncTime: 0));

      final useCase = UpdatePetFromActivityUseCase(
        petRepository: petRepo,
        activityRepository: activityRepo,
      );
      await useCase('p');

      expect(activityRepo.retroCallCount, 0,
          reason: '최초 동기화는 retroactive fetch 없이 처리되어야 함');
      expect(activityRepo.todayCallCount, 1);
    });

    test('lastActivitySyncTime이 어제 → retroactive fetch 호출 + 누적 반영', () async {
      final petRepo = _FakePetRepository();
      // 어제 12시를 마지막 sync로 설정
      final yesterday = DateTime.now()
          .subtract(const Duration(days: 1))
          .copyWith(hour: 12, minute: 0, second: 0, millisecond: 0);

      final activityRepo = _RangeAwareActivityRepository(
        todayData: ActivityData(
          steps: 0,
          exerciseMinutes: 0,
          startTime: 0,
          endTime: 1,
        ),
        // retroactive 구간 (어제 12시 ~ 오늘 0시) 동안 4,000보 누적
        retroData: ActivityData(
          steps: 4000,
          exerciseMinutes: 0,
          startTime: 0,
          endTime: 1,
        ),
      );
      petRepo.setPet(_basePet(
        happiness: 50,
        totalSteps: 1000,
        lastActivitySyncTime: yesterday.millisecondsSinceEpoch,
      ));

      final useCase = UpdatePetFromActivityUseCase(
        petRepository: petRepo,
        activityRepository: activityRepo,
      );
      final result = await useCase('p');

      expect(activityRepo.retroCallCount, 1,
          reason: '어제 sync면 retroactive fetch가 1번 호출되어야 함');
      // 4000보 → 4 increment × 3 = +12 happiness (보너스 X, 5000 미만)
      expect(result.happiness, greaterThan(50));
      // 누적 걸음: 기존 1000 + retroactive 4000 = 5000
      expect(result.totalSteps, 5000);
    });

    test('retroactive fetch 후 lastActivitySyncTime이 현재로 갱신', () async {
      final petRepo = _FakePetRepository();
      final yesterday =
          DateTime.now().subtract(const Duration(days: 1)).millisecondsSinceEpoch;
      final beforeCall = DateTime.now().millisecondsSinceEpoch;

      final activityRepo = _RangeAwareActivityRepository(
        todayData: ActivityData(
          steps: 0,
          exerciseMinutes: 0,
          startTime: 0,
          endTime: 1,
        ),
        retroData: ActivityData(
          steps: 1000,
          exerciseMinutes: 0,
          startTime: 0,
          endTime: 1,
        ),
      );
      petRepo.setPet(_basePet(lastActivitySyncTime: yesterday));

      final useCase = UpdatePetFromActivityUseCase(
        petRepository: petRepo,
        activityRepository: activityRepo,
      );
      final result = await useCase('p');

      expect(result.lastActivitySyncTime, greaterThanOrEqualTo(beforeCall),
          reason: 'lastActivitySyncTime은 현재 시각으로 갱신되어야 함');
    });

    test('오늘 sync된 펫은 retroactive fetch 안 함 (이미 오늘 0시 이후)', () async {
      final petRepo = _FakePetRepository();
      final today2hAgo =
          DateTime.now().subtract(const Duration(hours: 2)).millisecondsSinceEpoch;

      final activityRepo = _RangeAwareActivityRepository(
        todayData: ActivityData(
          steps: 500,
          exerciseMinutes: 0,
          startTime: 0,
          endTime: 1,
        ),
        retroData: ActivityData(
          steps: 99999,
          exerciseMinutes: 0,
          startTime: 0,
          endTime: 1,
        ),
      );
      petRepo.setPet(_basePet(lastActivitySyncTime: today2hAgo));

      final useCase = UpdatePetFromActivityUseCase(
        petRepository: petRepo,
        activityRepository: activityRepo,
      );
      await useCase('p');

      expect(activityRepo.retroCallCount, 0,
          reason: '오늘 0시 이후 sync는 retroactive 불필요');
    });

    test('retroactive + 오늘 활동량 합산해 totalSteps에 누적', () async {
      final petRepo = _FakePetRepository();
      final yesterday =
          DateTime.now().subtract(const Duration(days: 1)).millisecondsSinceEpoch;

      final activityRepo = _RangeAwareActivityRepository(
        todayData: ActivityData(
          steps: 2000,
          exerciseMinutes: 0,
          startTime: 0,
          endTime: 1,
        ),
        retroData: ActivityData(
          steps: 3000,
          exerciseMinutes: 0,
          startTime: 0,
          endTime: 1,
        ),
      );
      petRepo.setPet(_basePet(
        totalSteps: 100,
        lastActivitySyncTime: yesterday,
        todaySyncedSteps: 0, // 자정 통과로 리셋된 상태
      ));

      final useCase = UpdatePetFromActivityUseCase(
        petRepository: petRepo,
        activityRepository: activityRepo,
      );
      final result = await useCase('p');

      // 기존 100 + retro 3000 + today 2000 = 5100
      expect(result.totalSteps, 5100);
    });
  });
}
