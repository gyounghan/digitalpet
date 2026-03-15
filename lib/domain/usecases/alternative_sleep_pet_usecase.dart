import '../entities/pet.dart';
import '../repositories/pet_repository.dart';

/// 대체 수면 유스케이스
/// 실제 수면/미사용 연동이 어려운 사용자를 위한 저효율 보조 액션
class AlternativeSleepPetUseCase {
  final PetRepository petRepository;

  /// 대체 수면 1회 회복량 (실제 Sleep보다 낮음)
  static const int staminaRecoveryAmount = 5;

  /// 하루 최대 사용 횟수
  static const int maxAlternativeSleepsPerDay = 3;

  AlternativeSleepPetUseCase(this.petRepository);

  /// 대체 수면 실행
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
    if (pet.todayAlternativeSleepCount >= maxAlternativeSleepsPerDay) {
      return pet;
    }

    final currentTime = DateTime.now().millisecondsSinceEpoch;
    final updatedPet = pet.copyWith(
      stamina: (pet.stamina + staminaRecoveryAmount).clamp(0, 100),
      todayAlternativeSleepCount: pet.todayAlternativeSleepCount + 1,
      lastUpdated: currentTime,
    );

    await petRepository.updatePet(updatedPet);
    return updatedPet;
  }

  /// 대체 수면 가능 여부 확인
  bool canUse(Pet pet) {
    return pet.todayAlternativeSleepCount < maxAlternativeSleepsPerDay;
  }
}
