import '../entities/pet.dart';
import '../repositories/pet_repository.dart';
import '../constants/daily_events.dart';
import '../constants/meal_times.dart';
import '../constants/species_growth_config.dart';

/// 반려동물에게 먹이 주기 유스케이스
/// Feed 버튼 클릭 시 hunger를 증가시키는 비즈니스 로직
///
/// 규칙:
/// - hunger +20
/// - EXP +5
/// - 식사 시간대: 아침 6:30-10:00, 점심 11:00-14:30, 저녁 17:00-21:00
/// - 각 시간대 1회 제한 (간편 급식과 슬롯 공유 — MealTimes 참고)
class FeedPetUseCase {
  final PetRepository petRepository;

  /// 회복량
  static const int hungerRecoveryAmount = 20;

  /// Feed 시 획득 경험치
  static const int feedExpReward = 5;

  FeedPetUseCase(this.petRepository);

  /// 반려동물에게 먹이 주기
  Future<Pet> call(String petId) async {
    var pet = await petRepository.getPet(petId);

    if (pet.needsGoalReset) {
      pet = pet.resetDailyGoals();
    }

    final currentMealSlot = MealTimes.slotAt(DateTime.now());
    if (currentMealSlot == 0) return pet;
    if (MealTimes.hasFedInSlot(pet.todayFedMealSlots, currentMealSlot)) {
      return pet;
    }

    final m = SpeciesGrowthConfig.getGainMultipliers(pet.evolutionType);
    // tasty 이벤트: 식사 회복 +5 (resetDailyGoals가 어제 이벤트를 지우므로
    // 이 시점의 todayEvent는 항상 오늘 것)
    final eventBonus =
        pet.todayEvent == DailyEvents.tasty ? DailyEvents.tastyFeedBonus : 0;
    final newHunger =
        (pet.hunger + (hungerRecoveryAmount * m.hunger).round() + eventBonus)
            .clamp(0, 100);
    final newFeedCount = (pet.todayFeedCount + 1).clamp(0, 3);
    final newFedMealSlots =
        MealTimes.markFed(pet.todayFedMealSlots, currentMealSlot);
    final newExp = pet.exp + (feedExpReward * m.exp).round();
    final currentTime = DateTime.now().millisecondsSinceEpoch;

    final updatedPet = pet.copyWith(
      hunger: newHunger,
      todayFeedCount: newFeedCount,
      todayFedMealSlots: newFedMealSlots,
      exp: newExp,
      lastUpdated: currentTime,
    );

    await petRepository.updatePet(updatedPet);
    return updatedPet;
  }
}
