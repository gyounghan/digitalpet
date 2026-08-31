import '../entities/pet.dart';
import '../repositories/pet_repository.dart';

/// 물마시기 유스케이스 — 갓생몬 능동 건강 습관 (수분 섭취 기록)
///
/// 하루 수분 목표(Pet.waterGoalCount = 8잔)를 채우는 능동 케어.
/// 한 잔당 소량 기력 회복(+2). 목표 달성 시 완료 보너스 EXP를 1회 지급.
/// 실제 음용은 검증 불가라 급식처럼 사용자 탭 기반 — 남용은 하루 캡으로 방지.
class DrinkWaterUseCase {
  final PetRepository petRepository;

  /// 한 잔당 기력 회복량 (수분 → 컨디션)
  static const int staminaPerCup = 2;

  /// 목표 달성 완료 보너스 EXP (하루 1회)
  static const int completionExp = 12;

  DrinkWaterUseCase(this.petRepository);

  /// 물 한 잔 마시기 — 적용되면 갱신된 Pet, 조건 미충족이면 원본 그대로
  Future<Pet> call(String petId) async {
    var pet = await petRepository.getPet(petId);

    if (pet.needsGoalReset) {
      pet = pet.resetDailyGoals();
    }
    if (pet.isDead || !pet.canDrinkWater) return pet;

    final newCount = pet.todayWaterCount + 1;
    final reachedGoal = newCount == Pet.waterGoalCount;

    final updated = pet.copyWith(
      todayWaterCount: newCount,
      stamina: (pet.stamina + staminaPerCup).clamp(0, 100),
      // 목표(8잔) 달성 순간에만 완료 보너스 EXP 1회
      exp: reachedGoal ? pet.exp + completionExp : null,
      lastUpdated: DateTime.now().millisecondsSinceEpoch,
    );

    await petRepository.updatePet(updated);
    return updated;
  }

  bool canUse(Pet pet) => !pet.isDead && pet.canDrinkWater;
}
