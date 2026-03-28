import '../entities/pet.dart';
import '../repositories/pet_repository.dart';

/// 대체 운동 유스케이스
/// 실내 운동 1분 완료 후 적용되는 저효율 보조 액션
class AlternativeExercisePetUseCase {
  final PetRepository petRepository;

  /// 대체 운동 1회 행복도 증가량 (실제 활동 연동보다 낮음)
  static const int happinessRecoveryAmount = 6;

  /// 대체 운동 1회 체력 증가량
  static const int staminaRecoveryAmount = 4;

  /// 하루 최대 사용 횟수
  static const int maxAlternativeExercisesPerDay = 5;

  AlternativeExercisePetUseCase(this.petRepository);

  /// 대체 운동 보상 적용
  ///
  /// [petId] 대상 펫 ID
  ///
  /// 반환: 업데이트된 Pet 엔티티
  Future<Pet> call(String petId) async {
    var pet = await petRepository.getPet(petId);

    // 날짜가 바뀌었으면 일일 카운트 리셋
    if (pet.needsGoalReset) {
      pet = pet.resetDailyGoals();
    }

    // 일일 사용 횟수 제한
    if (pet.todayAlternativeExerciseCount >= maxAlternativeExercisesPerDay) {
      return pet;
    }

    final currentTime = DateTime.now().millisecondsSinceEpoch;
    final updatedPet = pet.copyWith(
      happiness: (pet.happiness + happinessRecoveryAmount).clamp(0, 100),
      stamina: (pet.stamina + staminaRecoveryAmount).clamp(0, 100),
      todayAlternativeExerciseCount: pet.todayAlternativeExerciseCount + 1,
      lastUpdated: currentTime,
    );

    await petRepository.updatePet(updatedPet);
    return updatedPet;
  }

  /// 대체 운동 가능 여부 확인
  bool canUse(Pet pet) {
    return pet.todayAlternativeExerciseCount < maxAlternativeExercisesPerDay;
  }
}
