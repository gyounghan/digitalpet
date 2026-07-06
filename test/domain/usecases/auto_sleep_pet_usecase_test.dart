import 'package:flutter_test/flutter_test.dart';
import 'package:pocketfriend/domain/entities/pet.dart';
import 'package:pocketfriend/domain/entities/phone_usage.dart';
import 'package:pocketfriend/domain/repositories/pet_repository.dart';
import 'package:pocketfriend/domain/repositories/phone_usage_repository.dart';
import 'package:pocketfriend/domain/usecases/auto_sleep_pet_usecase.dart';

/// Pet Repository fake
class FakePetRepository implements PetRepository {
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

/// PhoneUsage Repository fake (forgrounding 동작은 무시, 직접 조작용)
class FakePhoneUsageRepository implements PhoneUsageRepository {
  PhoneUsage _phoneUsage;

  FakePhoneUsageRepository(this._phoneUsage);

  PhoneUsage get current => _phoneUsage;

  @override
  Future<PhoneUsage> getPhoneUsage() async => _phoneUsage;

  @override
  Future<void> savePhoneUsage(PhoneUsage phoneUsage) async {
    _phoneUsage = phoneUsage;
  }

  @override
  Future<void> onForeground() async {
    _phoneUsage = _phoneUsage.copyWith(
      lastForegroundTime: DateTime.now().millisecondsSinceEpoch,
      lastBackgroundTime: null,
    );
  }

  @override
  Future<void> onBackground() async {
    _phoneUsage = _phoneUsage.copyWith(
      lastBackgroundTime: DateTime.now().millisecondsSinceEpoch,
    );
  }
}

Pet _createPet({
  int stamina = 50,
  int todaySleepHours = 0,
  int todaySleepMinutes = 0,
  int totalIdleHours = 0,
}) {
  final now = DateTime.now().millisecondsSinceEpoch;
  return Pet(
    id: 'test-pet',
    hunger: 80,
    happiness: 80,
    stamina: stamina,
    level: 1,
    exp: 0,
    evolutionStage: 1,
    lastUpdated: now,
    lastStatusDecayUpdated: now,
    todaySleepHours: todaySleepHours,
    todaySleepMinutes: todaySleepMinutes,
    totalIdleHours: totalIdleHours,
    lastGoalResetDate:
        '${DateTime.now().year}-${DateTime.now().month.toString().padLeft(2, '0')}-${DateTime.now().day.toString().padLeft(2, '0')}',
  );
}

void main() {
  group('AutoSleepPetUseCase', () {
    test('10분 미만 idle → 변경 없음', () async {
      final petRepo = FakePetRepository();
      final phoneRepo = FakePhoneUsageRepository(
        PhoneUsage(
          // 5분 전 (임계 10분 미만)
          lastForegroundTime:
              DateTime.now().millisecondsSinceEpoch - 5 * 60 * 1000,
          totalIdleHours: 0,
        ),
      );
      petRepo.setPet(_createPet(stamina: 50));

      final useCase = AutoSleepPetUseCase(
        petRepository: petRepo,
        phoneUsageRepository: phoneRepo,
      );

      final result = await useCase('test-pet', isInBackground: true);
      expect(result.stamina, 50);
      expect(result.todaySleepMinutes, 0);
      expect(result.todaySleepHours, 0);
    });

    test('31분 idle → 10분 단위 3회: stamina +3, sleepMinutes +30', () async {
      final petRepo = FakePetRepository();
      // 31분 전(slack 1분)으로 설정 → 10분 단위 3회 credit
      final foregroundMillis =
          DateTime.now().millisecondsSinceEpoch - 31 * 60 * 1000;
      final phoneRepo = FakePhoneUsageRepository(
        PhoneUsage(
          lastForegroundTime: foregroundMillis,
          totalIdleHours: 0,
        ),
      );
      petRepo.setPet(_createPet(stamina: 50));

      final useCase = AutoSleepPetUseCase(
        petRepository: petRepo,
        phoneUsageRepository: phoneRepo,
      );

      final result = await useCase('test-pet', isInBackground: true);
      expect(result.stamina, 53);
      expect(result.todaySleepMinutes, 30);
      expect(result.todaySleepHours, 0);
    });

    test('60분 idle → stamina +6, sleepMinutes +60, sleepHours +1', () async {
      final petRepo = FakePetRepository();
      final phoneRepo = FakePhoneUsageRepository(
        PhoneUsage(
          lastForegroundTime:
              DateTime.now().millisecondsSinceEpoch - 65 * 60 * 1000,
          totalIdleHours: 0,
        ),
      );
      petRepo.setPet(_createPet(stamina: 50));

      final useCase = AutoSleepPetUseCase(
        petRepository: petRepo,
        phoneUsageRepository: phoneRepo,
      );

      final result = await useCase('test-pet', isInBackground: true);
      expect(result.stamina, 56);
      expect(result.todaySleepMinutes, 60);
      expect(result.todaySleepHours, 1);
      expect(result.totalIdleHours, 1);
    });

    test('두 번 30분씩 누적 → sleepMinutes 60, sleepHours 1', () async {
      final petRepo = FakePetRepository();
      final phoneRepo = FakePhoneUsageRepository(
        PhoneUsage(
          lastForegroundTime:
              DateTime.now().millisecondsSinceEpoch - 31 * 60 * 1000,
          totalIdleHours: 0,
        ),
      );
      petRepo.setPet(_createPet(stamina: 50));

      final useCase = AutoSleepPetUseCase(
        petRepository: petRepo,
        phoneUsageRepository: phoneRepo,
      );

      // 첫 번째 호출: 30분
      var result = await useCase('test-pet', isInBackground: true);
      expect(result.todaySleepMinutes, 30);

      // 두 번째 호출 시뮬레이션: 30분이 더 지났다고 가정
      // 직전 호출이 lastForegroundTime을 30분 전진시켰으므로
      // 추가 30분이 지나도록 lastForegroundTime을 31분 더 과거로 옮긴다.
      final advanced = phoneRepo.current;
      phoneRepo.savePhoneUsage(
        advanced.copyWith(
          lastForegroundTime:
              advanced.lastForegroundTime - 31 * 60 * 1000,
        ),
      );

      result = await useCase('test-pet', isInBackground: true);
      expect(result.todaySleepMinutes, 60);
      expect(result.todaySleepHours, 1);
    });

    test('lastForegroundTime이 creditedMinutes 만큼 앞으로 이동', () async {
      final petRepo = FakePetRepository();
      final initial = DateTime.now().millisecondsSinceEpoch - 65 * 60 * 1000;
      final phoneRepo = FakePhoneUsageRepository(
        PhoneUsage(
          lastForegroundTime: initial,
          totalIdleHours: 0,
        ),
      );
      petRepo.setPet(_createPet(stamina: 50));

      final useCase = AutoSleepPetUseCase(
        petRepository: petRepo,
        phoneUsageRepository: phoneRepo,
      );

      await useCase('test-pet', isInBackground: true);

      // 65분 idle → increments=6 → creditedMinutes=60 → 60분 전진
      final expectedAdvanced = initial + 60 * 60 * 1000;
      expect(phoneRepo.current.lastForegroundTime, expectedAdvanced);
    });
  });
}
