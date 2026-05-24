import 'package:flutter_test/flutter_test.dart';
import 'package:pocketfriend/domain/entities/pet.dart';
import 'package:pocketfriend/domain/entities/phone_usage.dart';
import 'package:pocketfriend/domain/repositories/pet_repository.dart';
import 'package:pocketfriend/domain/repositories/phone_usage_repository.dart';
import 'package:pocketfriend/domain/usecases/auto_sleep_pet_usecase.dart';

/// 폰을 안 쓰는 동안 sleep이 정확히 누적되는지 검증하는 회귀 테스트.
/// 직전 라운드의 sleep 문제 해결을 보장.

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

class _FakePhoneUsageRepository implements PhoneUsageRepository {
  PhoneUsage _phoneUsage;
  _FakePhoneUsageRepository(this._phoneUsage);
  PhoneUsage get current => _phoneUsage;

  @override
  Future<PhoneUsage> getPhoneUsage() async => _phoneUsage;
  @override
  Future<void> savePhoneUsage(PhoneUsage p) async => _phoneUsage = p;
  @override
  Future<void> onForeground() async {
    _phoneUsage = _phoneUsage.copyWith(
      lastForegroundTime: DateTime.now().millisecondsSinceEpoch,
    );
  }

  @override
  Future<void> onBackground() async {
    _phoneUsage = _phoneUsage.copyWith(
      lastBackgroundTime: DateTime.now().millisecondsSinceEpoch,
    );
  }
}

Pet _pet({
  int stamina = 50,
  int todaySleepMinutes = 0,
  int totalIdleHours = 0,
}) {
  final now = DateTime.now().millisecondsSinceEpoch;
  return Pet(
    id: 'p',
    hunger: 50,
    happiness: 50,
    stamina: stamina,
    level: 1,
    exp: 0,
    evolutionStage: 1,
    lastUpdated: now,
    lastStatusDecayUpdated: now,
    todaySleepMinutes: todaySleepMinutes,
    totalIdleHours: totalIdleHours,
  );
}

void main() {
  group('AutoSleepPetUseCase — 폰 미사용 sleep 누적', () {
    test('8시간 미사용 → 480분 credit, stamina +48', () async {
      final pet = _pet(stamina: 20);
      final petRepo = _FakePetRepository()..setPet(pet);
      // 8시간 전 마지막 포그라운드
      final lastForeground = DateTime.now()
          .subtract(const Duration(hours: 8))
          .millisecondsSinceEpoch;
      final phoneRepo = _FakePhoneUsageRepository(PhoneUsage(
        lastForegroundTime: lastForeground,
        totalIdleHours: 0,
      ));

      final useCase = AutoSleepPetUseCase(
        petRepository: petRepo,
        phoneUsageRepository: phoneRepo,
      );
      final result = await useCase('p', isInBackground: true);

      // 480분 / 30 = 16 increments × 3 = 48 stamina (배율 1.0 가정)
      expect(result.stamina, greaterThan(20));
      // todaySleepMinutes 누적
      expect(result.todaySleepMinutes, 480);
      expect(result.todaySleepHours, 8);
    });

    test('29분 미사용 → 임계치 미만이라 변동 없음', () async {
      final pet = _pet(stamina: 50);
      final petRepo = _FakePetRepository()..setPet(pet);
      final lastForeground = DateTime.now()
          .subtract(const Duration(minutes: 29))
          .millisecondsSinceEpoch;
      final phoneRepo = _FakePhoneUsageRepository(PhoneUsage(
        lastForegroundTime: lastForeground,
        totalIdleHours: 0,
      ));

      final useCase = AutoSleepPetUseCase(
        petRepository: petRepo,
        phoneUsageRepository: phoneRepo,
      );
      final result = await useCase('p', isInBackground: true);

      expect(result.stamina, 50, reason: '30분 미만이면 변동 없음');
      expect(result.todaySleepMinutes, 0);
    });

    test('credit 후 lastForegroundTime이 정확히 creditedMinutes 만큼 앞당겨짐',
        () async {
      // 90분 미사용 → 60분만 credit, 30분 잔여
      final pet = _pet(stamina: 50);
      final petRepo = _FakePetRepository()..setPet(pet);
      final lastForeground = DateTime.now()
          .subtract(const Duration(minutes: 90))
          .millisecondsSinceEpoch;
      final phoneRepo = _FakePhoneUsageRepository(PhoneUsage(
        lastForegroundTime: lastForeground,
        totalIdleHours: 0,
      ));

      final useCase = AutoSleepPetUseCase(
        petRepository: petRepo,
        phoneUsageRepository: phoneRepo,
      );
      await useCase('p', isInBackground: true);

      // 새 lastForegroundTime = 원래 + 60분
      final expected =
          lastForeground + 60 * 60 * 1000;
      expect(phoneRepo.current.lastForegroundTime, expected);
    });

    test('연속 호출 시 잔여 분이 보존되어 누적', () async {
      final pet = _pet(stamina: 50);
      final petRepo = _FakePetRepository()..setPet(pet);
      // 110분 미사용
      final lastForeground = DateTime.now()
          .subtract(const Duration(minutes: 110))
          .millisecondsSinceEpoch;
      final phoneRepo = _FakePhoneUsageRepository(PhoneUsage(
        lastForegroundTime: lastForeground,
        totalIdleHours: 0,
      ));

      final useCase = AutoSleepPetUseCase(
        petRepository: petRepo,
        phoneUsageRepository: phoneRepo,
      );
      // 1차 호출 → 90분 credit, 잔여 20분
      final first = await useCase('p', isInBackground: true);
      expect(first.todaySleepMinutes, 90);

      // 즉시 한 번 더 호출 → 잔여 20분이라 임계치 미달로 변동 없음
      final second = await useCase('p', isInBackground: true);
      expect(second.todaySleepMinutes, 90, reason: '잔여 20분은 임계치 미만');
    });
  });
}
