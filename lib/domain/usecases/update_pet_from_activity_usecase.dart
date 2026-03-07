import '../entities/pet.dart';
import '../entities/activity_data.dart';
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
  /// 1. 최근 24시간 활동 데이터 조회
  /// 2. 걸음 수와 운동 시간에 따라 happiness, stamina 증가
  /// 3. 일일 목표 달성 시 보너스 경험치 추가
  /// 4. 업데이트된 Pet 저장
  Future<Pet> call(String petId) async {
    // 1. 현재 Pet 조회
    final pet = await petRepository.getPet(petId);
    
    // 2. 최근 24시간 활동 데이터 조회
    final activityData = await activityRepository.getLast24HoursActivityData();
    
    // 3. 걸음 수 기반 상태 업데이트 계산
    final stepsIncrement = activityData.steps ~/ 1000;
    final happinessFromSteps = stepsIncrement * happinessPer1000Steps;
    final staminaFromSteps = stepsIncrement * staminaPer1000Steps;
    
    // 4. 운동 시간 기반 상태 업데이트 계산
    final exerciseIncrement = activityData.exerciseMinutes ~/ 10;
    final happinessFromExercise = exerciseIncrement * happinessPer10Minutes;
    final staminaFromExercise = exerciseIncrement * staminaPer10Minutes;
    
    // 5. 총 증가량 계산
    final totalHappinessIncrease = happinessFromSteps + happinessFromExercise;
    final totalStaminaIncrease = staminaFromSteps + staminaFromExercise;
    
    // 6. 일일 목표 달성 여부 확인
    int bonusExp = 0;
    if (activityData.steps >= dailyGoalSteps || 
        activityData.exerciseMinutes >= dailyGoalExerciseMinutes) {
      bonusExp = bonusExpOnGoalAchievement;
    }
    
    // 7. 새로운 상태 값 계산 (최대 100)
    final newHappiness = (pet.happiness + totalHappinessIncrease).clamp(0, 100);
    final newStamina = (pet.stamina + totalStaminaIncrease).clamp(0, 100);
    final newExp = pet.exp + bonusExp;
    
    // 8. 레벨 업 계산 (100 경험치당 1 레벨)
    final oldLevel = pet.exp ~/ 100;
    final newLevel = newExp ~/ 100;
    final levelIncrease = newLevel - oldLevel;
    
    // 9. 현재 시간으로 업데이트
    final currentTime = DateTime.now().millisecondsSinceEpoch;
    
    // 10. 누적 활동 필드 업데이트
    // 최근 24시간 활동 데이터를 누적 (중복 방지를 위해 마지막 업데이트 시간 확인 필요하지만,
    // 여기서는 간단히 추가)
    final newTotalSteps = pet.totalSteps + activityData.steps;
    final newTotalExerciseMinutes = pet.totalExerciseMinutes + activityData.exerciseMinutes;
    
    // 11. 업데이트된 Pet 생성
    final updatedPet = pet.copyWith(
      happiness: newHappiness,
      stamina: newStamina,
      exp: newExp,
      level: pet.level + levelIncrease,
      lastUpdated: currentTime,
      totalSteps: newTotalSteps,
      totalExerciseMinutes: newTotalExerciseMinutes,
    );
    
    // 11. 저장
    await petRepository.updatePet(updatedPet);
    
    return updatedPet;
  }
}
