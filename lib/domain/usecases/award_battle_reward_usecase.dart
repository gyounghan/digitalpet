import '../entities/battle_history.dart';
import '../entities/pet.dart';
import '../repositories/battle_history_repository.dart';
import '../repositories/pet_repository.dart';

/// 온라인 배틀 보상 지급 유스케이스
///
/// 온라인 대전은 서버가 로컬 펫 데이터를 갱신하지 않으므로,
/// 확정된 결과(승패/EXP)를 로컬 펫에 반영하고 전적을 남긴다.
/// (예: 상대 접속 끊김 승리 — 기존에는 EXP가 화면 표시만 되고 미지급)
///
/// 레벨업/스탯 보너스 규칙은 AI 대전(BattleWithActivityUseCase)과 동일.
/// todayBattleCount는 AI 대전 일일 제한 전용이므로 증가시키지 않는다.
class AwardBattleRewardUseCase {
  final PetRepository petRepository;
  final BattleHistoryRepository battleHistoryRepository;

  /// 승리 시 행복도 보너스 (AI 대전 일반 승리와 동일)
  static const int victoryHappinessBonus = 5;

  AwardBattleRewardUseCase({
    required this.petRepository,
    required this.battleHistoryRepository,
  });

  /// [petId] 펫에 [exp]를 지급하고 승패([isVictory]) 전적을 기록한다.
  Future<Pet> call(
    String petId, {
    required bool isVictory,
    required int exp,
  }) async {
    var pet = await petRepository.getPet(petId);
    if (pet.isDead) return pet;

    if (pet.needsGoalReset) {
      pet = pet.resetDailyGoals();
    }

    var currentExp = pet.exp + exp;
    var currentLevel = pet.level;
    int levelUps = 0;
    while (true) {
      final required = Pet.getRequiredExpForLevel(currentLevel);
      if (currentExp >= required) {
        currentExp -= required;
        currentLevel++;
        levelUps++;
      } else {
        break;
      }
    }

    final levelUpStatBonus = levelUps * 10;
    final happinessBonus = isVictory ? victoryHappinessBonus : 0;
    final currentTime = DateTime.now().millisecondsSinceEpoch;

    final updatedPet = pet.copyWith(
      exp: currentExp,
      level: currentLevel,
      happiness:
          (pet.happiness + happinessBonus + levelUpStatBonus).clamp(0, 100),
      hunger: (pet.hunger + levelUpStatBonus).clamp(0, 100),
      stamina: (pet.stamina + levelUpStatBonus).clamp(0, 100),
      battleVictoryCount:
          isVictory ? pet.battleVictoryCount + 1 : pet.battleVictoryCount,
      lastUpdated: currentTime,
    );
    await petRepository.updatePet(updatedPet);

    await battleHistoryRepository.saveBattleHistory(BattleHistory(
      id: '${petId}_$currentTime',
      date: currentTime,
      isVictory: isVictory,
      expGained: exp,
      steps: 0,
      exerciseMinutes: 0,
    ));

    return updatedPet;
  }
}
