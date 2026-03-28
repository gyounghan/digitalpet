import '../entities/pet.dart';
import '../repositories/pet_repository.dart';
import '../repositories/activity_repository.dart';
import 'package:flutter/foundation.dart';

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
  static const int happinessPer1000Steps = 3;

  /// 걸음 수당 stamina 증가량 (1000보당)
  static const int staminaPer1000Steps = 2;

  /// 운동 시간당 happiness 증가량 (10분당)
  static const int happinessPer10Minutes = 5;

  /// 운동 시간당 stamina 증가량 (10분당)
  static const int staminaPer10Minutes = 3;

  /// 단계별 걸음 보너스
  static const int stepsBonus5000 = 10; // 5,000보 달성 시 happiness
  static const int stepsBonus10000 = 15; // 10,000보 달성 시 추가 happiness

  /// 단계별 운동 보너스
  static const int exerciseBonus15min = 8; // 15분 달성 시 happiness
  static const int exerciseBonus30min = 12; // 30분 달성 시 추가 happiness
  
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
    if (kDebugMode) {
      debugPrint(
        'UpdatePetFromActivityUseCase: todayActivity '
        'steps=${todayActivity.steps}, exerciseMinutes=${todayActivity.exerciseMinutes}, '
        'pet.todaySyncedSteps=${pet.todaySyncedSteps}, '
        'pet.todaySyncedExerciseMinutes=${pet.todaySyncedExerciseMinutes}',
      );
    }

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
      if (kDebugMode) {
        debugPrint('UpdatePetFromActivityUseCase: delta is zero (no activity update)');
      }
      // 날짜 변경으로 리셋만 필요한 경우에도 저장해 다음 계산 기준을 맞춘다.
      if (hasDailyReset) {
        await petRepository.updatePet(pet);
      }
      return pet;
    }
    if (kDebugMode) {
      debugPrint(
        'UpdatePetFromActivityUseCase: stepsDelta=$stepsDelta, '
        'exerciseMinutesDelta=$exerciseMinutesDelta',
      );
    }
    
    // 5. 걸음 수 기반 상태 업데이트 계산
    final stepsIncrement = stepsDelta ~/ 1000;
    final happinessFromSteps = stepsIncrement * happinessPer1000Steps;
    final staminaFromSteps = stepsIncrement * staminaPer1000Steps;
    
    // 6. 운동 시간 기반 상태 업데이트 계산
    final exerciseIncrement = exerciseMinutesDelta ~/ 10;
    final happinessFromExercise = exerciseIncrement * happinessPer10Minutes;
    final staminaFromExercise = exerciseIncrement * staminaPer10Minutes;
    
    // 7. 단계별 보너스 계산 (오늘 전체 활동량 기준)
    int stepsBonusHappiness = 0;
    if (todayActivity.steps >= 10000) {
      stepsBonusHappiness = stepsBonus5000 + stepsBonus10000;
    } else if (todayActivity.steps >= 5000) {
      stepsBonusHappiness = stepsBonus5000;
    }

    int exerciseBonusHappiness = 0;
    if (todayActivity.exerciseMinutes >= 30) {
      exerciseBonusHappiness = exerciseBonus15min + exerciseBonus30min;
    } else if (todayActivity.exerciseMinutes >= 15) {
      exerciseBonusHappiness = exerciseBonus15min;
    }

    // 보너스는 delta가 있을 때만 적용 (중복 방지를 위해 delta와 함께 계산)
    final totalHappinessIncrease = happinessFromSteps + happinessFromExercise
        + (stepsDelta > 0 ? stepsBonusHappiness : 0)
        + (exerciseMinutesDelta > 0 ? exerciseBonusHappiness : 0);
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
