import '../constants/daily_events.dart';
import '../entities/pet.dart';

/// 배틀 보상 적용 결과
class BattleRewardOutcome {
  final Pet updatedPet;

  /// 배수(횟수별 감쇠·이벤트) 적용 후 실제 획득 EXP
  final int expGained;

  const BattleRewardOutcome({
    required this.updatedPet,
    required this.expGained,
  });
}

/// 배틀 보상 상수 + 적용 로직 (AI 대전·온라인 대전 공통 단일 소스)
///
/// 서버(pocket-friend-server)의 배틀 엔진은 "기본 경험치"(승 50 / 압승 70 /
/// 패 15)까지만 계산해 내려주고, 하루 배틀 횟수별 감쇠·모험 이벤트 배수·
/// 레벨업·스탯 보너스·배틀 카운트는 항상 이 로직 한 곳에서 적용한다.
/// AI 대전과 온라인 대전의 보상이 어긋나면 반드시 여기부터 의심할 것.
class BattleReward {
  static const int victoryExp = 50;
  static const int defeatExp = 15;
  static const int dominantVictoryExp = 70;

  /// 하루 1·2·3번째 배틀 보상 배수
  static const List<double> rewardMultipliers = [1.0, 0.7, 0.5];

  /// 승패 → 기본 경험치 (서버 미제공 시 폴백)
  static int baseExpFor({
    required bool isVictory,
    required bool isDominantVictory,
  }) {
    if (isDominantVictory) return dominantVictoryExp;
    return isVictory ? victoryExp : defeatExp;
  }

  /// 배틀 결과 보상을 [pet]에 적용한 새 Pet과 실제 획득 EXP를 반환한다.
  ///
  /// [baseExp]는 서버가 내려준 기본 경험치 — null이면 승패로부터 계산.
  /// [isOnline]이면 온라인 대전 카운트([Pet.todayOnlineBattleCount])를,
  /// 아니면 AI 대전 카운트([Pet.todayBattleCount])를 증가·감쇠 기준으로 쓴다
  /// (하루 한도가 모드별로 따로 걸리므로 감쇠도 모드별로 따로 적용).
  /// 배수 인덱스는 적용 전 카운트 기준이므로, 호출 전에 자정 리셋
  /// ([Pet.needsGoalReset])을 먼저 처리해야 한다.
  static BattleRewardOutcome apply(
    Pet pet, {
    required bool isVictory,
    required bool isDominantVictory,
    int? baseExp,
    required int nowMs,
    bool isOnline = false,
  }) {
    final modeBattleCount =
        isOnline ? pet.todayOnlineBattleCount : pet.todayBattleCount;
    final multiplierIndex =
        modeBattleCount.clamp(0, rewardMultipliers.length - 1);
    final multiplier = rewardMultipliers[multiplierIndex];
    final resolvedBase = baseExp ??
        baseExpFor(isVictory: isVictory, isDominantVictory: isDominantVictory);
    // adventure 이벤트: 배틀 EXP 2배 (호출 전 자정 리셋이 어제 이벤트를 지움)
    final eventMultiplier = pet.todayEvent == DailyEvents.adventure
        ? DailyEvents.adventureBattleExpMultiplier.toDouble()
        : 1.0;
    final expGain = (resolvedBase * multiplier * eventMultiplier).round();

    var currentExp = pet.exp + expGain;
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
    final happinessBonus = isDominantVictory ? 8 : (isVictory ? 5 : 0);

    final updatedPet = pet.copyWith(
      exp: currentExp,
      level: currentLevel,
      happiness:
          (pet.happiness + happinessBonus + levelUpStatBonus).clamp(0, 100),
      hunger: (pet.hunger + levelUpStatBonus).clamp(0, 100),
      stamina: (pet.stamina + levelUpStatBonus).clamp(0, 100),
      todayBattleCount: isOnline ? null : pet.todayBattleCount + 1,
      todayOnlineBattleCount:
          isOnline ? pet.todayOnlineBattleCount + 1 : null,
      battleVictoryCount:
          isVictory ? pet.battleVictoryCount + 1 : pet.battleVictoryCount,
      lastUpdated: nowMs,
    );

    return BattleRewardOutcome(updatedPet: updatedPet, expGained: expGain);
  }
}
