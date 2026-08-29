import '../entities/pet.dart';
import '../repositories/pet_repository.dart';

/// 광고 시청 보상 — 오늘 배틀 가능 횟수 +1
///
/// 하루 기본 한도([Pet.maxBattlesPerDay])를 다 쓴 뒤 리워드 광고를 보면
/// 해당 모드([online])의 가능 횟수가 1회 늘어난다.
/// 광고 추가분(todayBattleAdBonus/todayOnlineBattleAdBonus)은 자정에
/// resetDailyGoals로 함께 리셋된다 — 다음 날로 이월되지 않는다.
///
/// 반드시 리워드 광고 시청 완료 콜백(onRewarded)에서만 호출할 것.
class GrantExtraBattleUseCase {
  final PetRepository petRepository;

  GrantExtraBattleUseCase(this.petRepository);

  /// [petId] 대상 펫 ID
  /// [online] true면 온라인(친구 포함) 대전, false면 AI 대전 횟수 추가
  ///
  /// 반환: 갱신된 Pet
  Future<Pet> call(String petId, {required bool online}) async {
    var pet = await petRepository.getPet(petId);

    // 자정이 지났으면 먼저 리셋 — 어제 광고 추가분 위에 얹지 않는다
    if (pet.needsGoalReset) {
      pet = pet.resetDailyGoals();
    }

    final updated = pet.copyWith(
      todayBattleAdBonus: online ? null : pet.todayBattleAdBonus + 1,
      todayOnlineBattleAdBonus:
          online ? pet.todayOnlineBattleAdBonus + 1 : null,
      lastUpdated: DateTime.now().millisecondsSinceEpoch,
    );
    await petRepository.updatePet(updated);
    return updated;
  }
}
