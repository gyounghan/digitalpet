import '../entities/pet.dart';
import '../repositories/pet_repository.dart';

/// 집중(뽀모도로) 세션 유스케이스 — 갓생몬 핵심 능동 습관
///
/// 25분간 폰을 내려놓고 집중하면 펫이 "함께 성장"한다. 낮잠(기력 회복)과
/// 달리 집중은 성장 축 — 완료 시 EXP + 행복을 준다(생산성·디지털 웰빙).
/// 세션 완료(타이머 소진)는 UI가 판정하고, 이 유스케이스는 보상만 적용한다.
/// 하루 [Pet.focusGoalCount]회 캡으로 남용을 막는다.
class FocusSessionUseCase {
  final PetRepository petRepository;

  /// 세션 길이 (분) — 표준 뽀모도로
  static const int sessionMinutes = 25;

  /// 세션 완료 보상 EXP (25분 몰입이라 급식/물보다 크게)
  static const int sessionExp = 20;

  /// 세션 완료 행복 보상
  static const int happinessReward = 6;

  FocusSessionUseCase(this.petRepository);

  /// 집중 세션 완료 보상 적용 — 적용되면 갱신된 Pet, 미충족이면 원본 그대로.
  /// (EXP는 raw로 더하고 레벨업은 _updateAndEvolve가 처리)
  Future<Pet> call(String petId) async {
    var pet = await petRepository.getPet(petId);

    if (pet.needsGoalReset) {
      pet = pet.resetDailyGoals();
    }
    if (pet.isDead || !pet.canFocus) return pet;

    final newFocusCount = pet.todayFocusCount + 1;
    // 일일 집중 목표(focusGoalCount)를 채운 순간 누적 달성 +1 (부엉이 각성 축)
    final reachedGoal = newFocusCount == Pet.focusGoalCount;

    final updated = pet.copyWith(
      todayFocusCount: newFocusCount,
      exp: pet.exp + sessionExp,
      happiness: (pet.happiness + happinessReward).clamp(0, 100),
      focusAchievedCount:
          reachedGoal ? pet.focusAchievedCount + 1 : null,
      lastUpdated: DateTime.now().millisecondsSinceEpoch,
    );

    await petRepository.updatePet(updated);
    return updated;
  }

  bool canUse(Pet pet) => !pet.isDead && pet.canFocus;
}
