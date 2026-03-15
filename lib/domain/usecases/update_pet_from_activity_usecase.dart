import '../entities/pet.dart';
import '../repositories/pet_repository.dart';
import '../repositories/activity_repository.dart';

/// 활동 데이터 기반 펫 상태 업데이트 유스케이스
/// 걷기 수와 운동 시간을 기반으로 펫의 상태를 자동으로 업데이트
/// 
/// 규칙:
/// - 걸음 수: 1000보당 happiness +5, stamina +3
/// - 운동 시간: 10분당 happiness +10, stamina +5
/// - 일일 목표 달성 시 보너스 경험치
class UpdatePetFromActivityUseCase {
  final PetRepository petRepository;
  final ActivityRepository activityRepository;
  
  /// 걸음 수당 happiness 증가량 (1000보당)
  static const int happinessPer1000Steps = 5;
  
  /// 걸음 수당 stamina 증가량 (1000보당)
  static const int staminaPer1000Steps = 3;
  
  /// 운동 시간당 happiness 증가량 (10분당)
  static const int happinessPer10Minutes = 10;
  
  /// 운동 시간당 stamina 증가량 (10분당)
  static const int staminaPer10Minutes = 5;
  
  /// 일일 목표 걸음 수
  static const int dailyGoalSteps = 10000;
  
  /// 일일 목표 운동 시간 (분)
  static const int dailyGoalExerciseMinutes = 30;
  
  /// 일일 목표 달성 시 보너스 경험치
  static const int bonusExpOnGoalAchievement = 50;
  
  UpdatePetFromActivityUseCase({
    required this.petRepository,
    required this.activityRepository,
  });
  
  /// 활동 데이터를 기반으로 펫 상태 업데이트
  /// 
  /// [petId] 업데이트할 반려동물 ID
  /// 
  /// 반환: 업데이트된 Pet 엔티티
  /// 
  /// 동작:
  /// 1. 오늘 활동 데이터 조회
  /// 2. 일일 목표 리셋 확인 (날짜 변경 시)
  /// 3. 마지막 "오늘 동기화 기준값"과의 차이(delta)를 계산해 중복 반영 방지
  /// 4. 걸음 수와 운동 시간에 따라 happiness, stamina 증가
  /// 5. 일일 목표 달성 보너스는 별도 UseCase에서 처리
  /// 5. 업데이트된 Pet 저장
  Future<Pet> call(String petId) async {
    // 1. 현재 Pet 조회
    var pet = await petRepository.getPet(petId);
    
    // 2. 일일 목표 리셋 확인
    var hasDailyReset = false;
    if (pet.needsGoalReset) {
      pet = pet.resetDailyGoals();
      hasDailyReset = true;
    }
    
    // 3. 오늘 활동 데이터 조회
    final currentTime = DateTime.now().millisecondsSinceEpoch;
    final todayActivity = await activityRepository.getTodayActivityData();

    // 4. 마지막 오늘 동기화 값과의 차이(delta) 계산
    // todaySyncedSteps / todaySyncedExerciseMinutes는 "오늘 0시 이후 마지막 동기화 기준값"이다.
    // 음수가 되면(플랫폼 집계 리셋/오차) 0으로 보정한다.
    final stepsDelta = (todayActivity.steps - pet.todaySyncedSteps)
        .clamp(0, todayActivity.steps)
        .toInt();
    final exerciseMinutesDelta =
        (todayActivity.exerciseMinutes - pet.todaySyncedExerciseMinutes)
        .clamp(0, todayActivity.exerciseMinutes)
        .toInt();

    if (stepsDelta == 0 && exerciseMinutesDelta == 0) {
      // 날짜 변경으로 리셋만 필요한 경우에도 저장해 다음 계산 기준을 맞춘다.
      if (hasDailyReset) {
        await petRepository.updatePet(pet);
      }
      return pet;
    }
    
    // 5. 걸음 수 기반 상태 업데이트 계산
    final stepsIncrement = stepsDelta ~/ 1000;
    final happinessFromSteps = stepsIncrement * happinessPer1000Steps;
    final staminaFromSteps = stepsIncrement * staminaPer1000Steps;
    
    // 6. 운동 시간 기반 상태 업데이트 계산
    final exerciseIncrement = exerciseMinutesDelta ~/ 10;
    final happinessFromExercise = exerciseIncrement * happinessPer10Minutes;
    final staminaFromExercise = exerciseIncrement * staminaPer10Minutes;
    
    // 7. 총 증가량 계산
    final totalHappinessIncrease = happinessFromSteps + happinessFromExercise;
    final totalStaminaIncrease = staminaFromSteps + staminaFromExercise;
    
    // 8. 새로운 상태 값 계산 (최대 100)
    final newHappiness = (pet.happiness + totalHappinessIncrease).clamp(0, 100);
    final newStamina = (pet.stamina + totalStaminaIncrease).clamp(0, 100);
    
    // 9. 일일 목표 달성 보너스는 별도 UseCase에서 처리
    
    // 10. 누적 활동값/오늘 동기화 기준값 갱신
    final newTotalSteps = pet.totalSteps + stepsDelta;
    final newTotalExerciseMinutes = pet.totalExerciseMinutes + exerciseMinutesDelta;
    final newTodaySyncedSteps = todayActivity.steps;
    final newTodaySyncedExerciseMinutes = todayActivity.exerciseMinutes;
    
    // 11. 업데이트된 Pet 생성
    final updatedPet = pet.copyWith(
      happiness: newHappiness,
      stamina: newStamina,
      lastUpdated: currentTime,
      totalSteps: newTotalSteps,
      totalExerciseMinutes: newTotalExerciseMinutes,
      todaySyncedSteps: newTodaySyncedSteps,
      todaySyncedExerciseMinutes: newTodaySyncedExerciseMinutes,
    );
    
    // 12. 저장
    await petRepository.updatePet(updatedPet);
    
    return updatedPet;
  }
}
