import '../entities/pet.dart';
import '../repositories/pet_repository.dart';
import '../repositories/phone_usage_repository.dart';

/// 자동 펫 재우기 유스케이스
/// 폰 미사용 시간에 따라 자동으로 stamina를 증가시키는 비즈니스 로직
/// 
/// 규칙:
/// - 30분당 stamina +5 (최대 100)
/// - 미사용 시간이 30분 이상일 때만 적용
class AutoSleepPetUseCase {
  final PetRepository petRepository;
  final PhoneUsageRepository phoneUsageRepository;
  
  /// 미사용 시간당 stamina 증가량
  static const int staminaIncreasePer30Minutes = 5;
  
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
  /// 
  /// 동작:
  /// 1. 현재 Pet 조회
  /// 2. 일일 목표 리셋 확인 (날짜 변경 시)
  /// 3. 미사용 시간 계산
  /// 4. 30분 이상이면 stamina 증가 (30분당 +5)
  /// 5. 오늘의 수면 시간 업데이트
  /// 6. 업데이트된 Pet 저장
  Future<Pet> call(String petId, {required bool isInBackground}) async {
    // 1. 현재 Pet 조회
    var pet = await petRepository.getPet(petId);
    
    // 2. 일일 목표 리셋 확인
    if (pet.needsGoalReset) {
      pet = pet.resetDailyGoals();
    }
    
    // 3. 미사용 시간 계산
    final phoneUsage = await phoneUsageRepository.getPhoneUsage();
    final idleMinutes = phoneUsage.getIdleMinutes(isInBackground: isInBackground);
    
    // 4. 미사용 시간이 30분 미만이면 업데이트하지 않음
    if (idleMinutes < idleThresholdMinutes) {
      return pet;
    }
    
    // 5. 마지막 업데이트 시간 이후의 미사용 시간만 계산하여 중복 누적 방지
    // phoneUsage의 lastForegroundTime과 pet의 lastUpdated를 비교하여
    // 이미 처리된 시간은 제외
    final lastUpdateTime = DateTime.fromMillisecondsSinceEpoch(pet.lastUpdated);
    final lastForegroundTime = DateTime.fromMillisecondsSinceEpoch(phoneUsage.lastForegroundTime);
    
    // 마지막 업데이트 시간이 마지막 포그라운드 시간보다 이전이면,
    // 마지막 포그라운드 시간부터의 미사용 시간을 사용
    // 그렇지 않으면 마지막 업데이트 시간부터의 미사용 시간을 사용
    final effectiveStartTime = lastUpdateTime.isBefore(lastForegroundTime) 
        ? lastForegroundTime 
        : lastUpdateTime;
    
    final currentTime = DateTime.now();
    final effectiveIdleMinutes = currentTime.difference(effectiveStartTime).inMinutes;
    
    // 유효한 미사용 시간이 30분 미만이면 업데이트하지 않음
    if (effectiveIdleMinutes < idleThresholdMinutes) {
      return pet;
    }
    
    // 6. 30분 단위로 stamina 증가 계산
    final increments = effectiveIdleMinutes ~/ idleThresholdMinutes;
    final staminaIncrease = increments * staminaIncreasePer30Minutes;
    final newStamina = (pet.stamina + staminaIncrease).clamp(0, 100);
    
    // 7. 누적 미사용 시간 업데이트 (시간 단위, 중복 방지)
    final effectiveIdleHours = effectiveIdleMinutes ~/ 60;
    final newTotalIdleHours = pet.totalIdleHours + effectiveIdleHours;
    
    // 8. 오늘의 수면 시간 업데이트 (시간 단위, 중복 방지)
    final newTodaySleepHours = pet.todaySleepHours + effectiveIdleHours;
    
    // 9. 현재 시간으로 업데이트
    final currentTimeMillis = DateTime.now().millisecondsSinceEpoch;
    
    // 10. 업데이트된 Pet 생성
    final updatedPet = pet.copyWith(
      stamina: newStamina,
      lastUpdated: currentTimeMillis,
      totalIdleHours: newTotalIdleHours,
      todaySleepHours: newTodaySleepHours,
    );
    
    // 11. 저장
    await petRepository.updatePet(updatedPet);
    
    return updatedPet;
  }
}
