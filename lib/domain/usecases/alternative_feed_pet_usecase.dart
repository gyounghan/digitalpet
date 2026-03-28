import '../entities/pet.dart';
import '../repositories/pet_repository.dart';

/// 대체 급식 유스케이스
/// 실제 식사 시간대 Feed가 어려운 사용자를 위한 저효율 보조 액션
class AlternativeFeedPetUseCase {
  final PetRepository petRepository;

  /// 대체 급식 1회 회복량
  static const int hungerRecoveryAmount = 8;

  /// 하루 최대 사용 횟수
  static const int maxAlternativeFeedsPerDay = 3;

  AlternativeFeedPetUseCase(this.petRepository);

  /// 대체 급식 실행
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
    if (pet.todayAlternativeFeedCount >= maxAlternativeFeedsPerDay) {
      return pet;
    }

    final currentTime = DateTime.now().millisecondsSinceEpoch;
    final updatedPet = pet.copyWith(
      hunger: (pet.hunger + hungerRecoveryAmount).clamp(0, 100),
      todayAlternativeFeedCount: pet.todayAlternativeFeedCount + 1,
      lastUpdated: currentTime,
    );

    await petRepository.updatePet(updatedPet);
    return updatedPet;
  }

  /// 대체 급식 가능 여부 확인 (시간대 제한 없음)
  bool canUse(Pet pet) {
    return pet.todayAlternativeFeedCount < maxAlternativeFeedsPerDay;
  }
}
