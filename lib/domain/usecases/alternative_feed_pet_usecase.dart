import '../entities/pet.dart';
import '../repositories/pet_repository.dart';
import '../constants/meal_times.dart';
import '../constants/species_growth_config.dart';

/// 대체 급식 유스케이스
/// 정식 Feed(+20)가 부담스러울 때 쓰는 저효율 보조 액션 (+8, EXP 없음)
///
/// 규칙:
/// - 정식 급식과 동일한 식사 시간대에만 사용 가능
/// - 식사 슬롯을 공유: 한 시간대에 정식/간편 합쳐 1회만 (다회 급식 방지)
/// - 식사 목표(todayFeedCount)에는 정식 급식과 동일하게 1회로 인정
/// - 하루 최대 3회 (슬롯 3개와 자연 일치)
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
  /// [now] 테스트용 현재 시각 주입 (기본: DateTime.now())
  ///
  /// 반환: 업데이트된 Pet 엔티티 (조건 미충족 시 원본 그대로)
  Future<Pet> call(String petId, {DateTime? now}) async {
    var pet = await petRepository.getPet(petId);

    // 날짜가 바뀌었으면 일일 카운트 리셋
    if (pet.needsGoalReset) {
      pet = pet.resetDailyGoals();
    }

    final clock = now ?? DateTime.now();

    // 식사 시간대 + 슬롯 미사용일 때만 가능 (정식 급식과 슬롯 공유)
    final currentMealSlot = MealTimes.slotAt(clock);
    if (currentMealSlot == 0) return pet;
    if (MealTimes.hasFedInSlot(pet.todayFedMealSlots, currentMealSlot)) {
      return pet;
    }

    // 일일 사용 횟수 제한
    if (pet.todayAlternativeFeedCount >= maxAlternativeFeedsPerDay) {
      return pet;
    }

    final currentTime = clock.millisecondsSinceEpoch;
    final updatedPet = pet.copyWith(
      hunger: (pet.hunger + (hungerRecoveryAmount * SpeciesGrowthConfig.getGainMultipliers(pet.evolutionType).hunger).round()).clamp(0, 100),
      todayFeedCount: (pet.todayFeedCount + 1).clamp(0, 3),
      todayFedMealSlots:
          MealTimes.markFed(pet.todayFedMealSlots, currentMealSlot),
      todayAlternativeFeedCount: pet.todayAlternativeFeedCount + 1,
      lastUpdated: currentTime,
    );

    await petRepository.updatePet(updatedPet);
    return updatedPet;
  }

  /// 대체 급식 가능 여부 확인 (일일 횟수 기준 — 시간대/슬롯은 CanFeedPetUseCase로 판정)
  bool canUse(Pet pet) {
    return pet.todayAlternativeFeedCount < maxAlternativeFeedsPerDay;
  }
}
