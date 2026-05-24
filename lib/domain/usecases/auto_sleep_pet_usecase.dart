import '../entities/pet.dart';
import '../repositories/pet_repository.dart';
import '../repositories/phone_usage_repository.dart';
import '../constants/species_growth_config.dart';

/// 자동 펫 재우기 유스케이스
/// 폰 미사용 시간에 따라 자동으로 stamina와 수면 시간을 누적시키는 비즈니스 로직
///
/// 규칙:
/// - 30분당 stamina +3 (최대 100)
/// - 미사용 시간이 30분 이상일 때만 적용
/// - todaySleepMinutes에 분 단위로 정확히 누적
/// - todaySleepHours = todaySleepMinutes ~/ 60 으로 파생 계산
///
/// 중요:
/// - 시간 기준은 phoneUsage.lastForegroundTime만 사용 (pet.lastUpdated는 다른 작업이
///   덮어쓰므로 sleep 추적에 부적합)
/// - 크레딧 후 lastForegroundTime을 크레딧된 분만큼 앞으로 이동시켜
///   다음 호출에서 중복 계산을 방지하면서 30분 미만 잔여 시간은 보존
class AutoSleepPetUseCase {
  final PetRepository petRepository;
  final PhoneUsageRepository phoneUsageRepository;

  /// 30분당 stamina 증가량
  static const int staminaIncreasePer30Minutes = 3;

  /// 미사용으로 간주할 최소 시간 (분)
  static const int idleThresholdMinutes = 30;

  AutoSleepPetUseCase({
    required this.petRepository,
    required this.phoneUsageRepository,
  });

  /// 자동으로 펫 재우기
  ///
  /// [petId] 재울 반려동물 ID
  /// [isInBackground] 앱이 현재 백그라운드에 있는지 여부
  ///
  /// 반환: 업데이트된 Pet 엔티티 (미사용 시간이 부족하면 원래 Pet 반환)
  Future<Pet> call(String petId, {required bool isInBackground}) async {
    // 1. 현재 Pet 조회
    var pet = await petRepository.getPet(petId);

    // 2. 일일 목표 리셋 확인
    if (pet.needsGoalReset) {
      pet = pet.resetDailyGoals();
    }

    // 3. phoneUsage 조회
    final phoneUsage = await phoneUsageRepository.getPhoneUsage();

    // 4. lastForegroundTime을 단일 anchor로 사용
    //    (pet.lastUpdated는 다른 usecase가 덮어쓰므로 sleep 추적에 부적합)
    final currentTimeMillis = DateTime.now().millisecondsSinceEpoch;
    final effectiveIdleMillis = currentTimeMillis - phoneUsage.lastForegroundTime;
    final effectiveIdleMinutes = effectiveIdleMillis ~/ (1000 * 60);

    // 5. 30분 미만이면 업데이트하지 않음
    if (effectiveIdleMinutes < idleThresholdMinutes) {
      return pet;
    }

    // 6. 30분 단위로 stamina 증가 계산
    final increments = effectiveIdleMinutes ~/ idleThresholdMinutes;
    final creditedMinutes = increments * idleThresholdMinutes;
    final m = SpeciesGrowthConfig.getGainMultipliers(pet.evolutionType);
    final staminaIncrease = (increments * staminaIncreasePer30Minutes * m.stamina).round();
    final newStamina = (pet.stamina + staminaIncrease).clamp(0, 100);

    // 7. 분 단위 정확 누적 → 시간 파생
    final newTodaySleepMinutes = pet.todaySleepMinutes + creditedMinutes;
    final newTodaySleepHours = newTodaySleepMinutes ~/ 60;

    // 8. 누적 미사용 시간 (시간 단위)
    final addedHours = newTodaySleepHours - pet.todaySleepHours;
    final newTotalIdleHours = pet.totalIdleHours + addedHours;

    // 9. 업데이트된 Pet 생성
    final updatedPet = pet.copyWith(
      stamina: newStamina,
      lastUpdated: currentTimeMillis,
      totalIdleHours: newTotalIdleHours,
      todaySleepHours: newTodaySleepHours,
      todaySleepMinutes: newTodaySleepMinutes,
    );

    // 10. 저장
    await petRepository.updatePet(updatedPet);

    // 11. phoneUsage.lastForegroundTime을 creditedMinutes만큼 앞으로 이동
    //     (다음 호출에서 중복 계산 방지, 30분 미만 잔여 시간은 보존)
    final advancedForegroundTime =
        phoneUsage.lastForegroundTime + creditedMinutes * 60 * 1000;
    final updatedPhoneUsage = phoneUsage.copyWith(
      lastForegroundTime: advancedForegroundTime,
    );
    await phoneUsageRepository.savePhoneUsage(updatedPhoneUsage);

    return updatedPet;
  }
}
