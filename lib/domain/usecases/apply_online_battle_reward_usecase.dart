import '../entities/battle_history.dart';
import '../repositories/activity_repository.dart';
import '../repositories/battle_history_repository.dart';
import '../repositories/pet_repository.dart';
import 'apply_battle_reward.dart';

/// 온라인 PvP 배틀 결과 보상 적용 유스케이스
///
/// 서버는 배틀 시뮬레이션과 기본 경험치(50/70/15) 산정까지만 담당한다.
/// 실제 보상 — 하루 배틀 횟수별 감쇠, 모험 이벤트 배수, 레벨업/스탯 보너스,
/// 배틀 카운트 증가, 전적 저장 — 은 AI 대전과 완전히 동일하게
/// [BattleReward.apply]로 클라이언트에서 적용한다.
class ApplyOnlineBattleRewardUseCase {
  final PetRepository petRepository;
  final ActivityRepository activityRepository;
  final BattleHistoryRepository battleHistoryRepository;

  ApplyOnlineBattleRewardUseCase({
    required this.petRepository,
    required this.activityRepository,
    required this.battleHistoryRepository,
  });

  /// [baseExp]는 서버 battle:result의 expGained(기본 경험치).
  /// null이면 승패로부터 로컬 상수로 계산한다 (상대 이탈 승리 등).
  Future<BattleRewardOutcome> call(
    String petId, {
    required bool isVictory,
    required bool isDominantVictory,
    int? baseExp,
  }) async {
    var pet = await petRepository.getPet(petId);

    if (pet.isDead) {
      return BattleRewardOutcome(updatedPet: pet, expGained: 0);
    }

    // 자정이 지났으면 오늘 카운트 리셋 후 보상 배수를 계산 (AI 대전과 동일)
    if (pet.needsGoalReset) {
      pet = pet.resetDailyGoals();
    }

    final now = DateTime.now().millisecondsSinceEpoch;
    final reward = BattleReward.apply(
      pet,
      isVictory: isVictory,
      isDominantVictory: isDominantVictory,
      baseExp: baseExp,
      nowMs: now,
    );
    await petRepository.updatePet(reward.updatedPet);

    final todayActivity = await activityRepository.getTodayActivityData();
    await battleHistoryRepository.saveBattleHistory(BattleHistory(
      id: '${petId}_$now',
      date: now,
      isVictory: isVictory,
      expGained: reward.expGained,
      steps: todayActivity.steps,
      exerciseMinutes: todayActivity.exerciseMinutes,
    ));

    return reward;
  }
}
