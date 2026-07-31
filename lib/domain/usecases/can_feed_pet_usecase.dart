import '../entities/pet.dart';
import '../repositories/pet_repository.dart';
import '../constants/meal_times.dart';

/// Feed 가능 여부 체크 유스케이스
/// 식사 시간대를 확인하여 Feed 버튼을 표시할지 결정하는 비즈니스 로직
///
/// Feed 가능 조건:
/// - 현재 시간이 식사 시간대 (아침 6:30-10:00, 점심 11:00-14:30, 저녁 17:00-21:00)
/// - 해당 식사 슬롯에서 아직 Feed(정식/간편)를 하지 않았을 때
class CanFeedPetUseCase {
  final PetRepository petRepository;

  CanFeedPetUseCase(this.petRepository);

  /// Feed 가능 여부 확인 (Repository 조회)
  Future<bool> call(String petId) async {
    final pet = await petRepository.getPet(petId);
    return canFeed(pet);
  }

  /// Feed 가능 여부 확인 (Pet 엔티티 직접 전달)
  bool canFeed(Pet pet) {
    if (pet.isDead) return false;
    final currentMealSlot = MealTimes.slotAt(DateTime.now());
    if (currentMealSlot > 0) {
      return !MealTimes.hasFedInSlot(pet.todayFedMealSlots, currentMealSlot);
    }
    return false;
  }
}
