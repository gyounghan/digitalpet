import '../entities/pet.dart';
import 'calculate_daily_goals_score_usecase.dart';

/// 목표 카테고리 (홈 목표 카드의 세 줄)
enum GoalCategory { feed, exercise, sleep }

/// 펫 상태 전이(prev → next)에서 UI가 축하해야 할 이벤트를 뽑아낸다.
///
/// 목표 카드가 누적식 표시(달성하면 곧바로 다음 목표치로 확장)라서
/// 달성 순간이 "너무 자연스러워" 티가 나지 않는 문제의 단일 판정 소스.
/// todayXxxAchievedCount는 자정에 리셋(감소)되므로 **증가만** 이벤트로 본다.
class PetTransitionEvents {
  /// 이번 전이에서 새로 목표를 달성한 카테고리들
  final Set<GoalCategory> achievedNow;

  /// 이번 전이에서 새로 완성된 세트 수 (0이면 없음)
  final int setsCompleted;

  /// 새로 완성된 첫 세트의 보상 EXP (표시용 — 반감 규칙 반영)
  final int setRewardExp;

  const PetTransitionEvents({
    required this.achievedNow,
    required this.setsCompleted,
    required this.setRewardExp,
  });

  bool get hasAny => achievedNow.isNotEmpty || setsCompleted > 0;

  static PetTransitionEvents diff(Pet prev, Pet next) {
    final achieved = <GoalCategory>{};
    if (next.todayFeedAchievedCount > prev.todayFeedAchievedCount) {
      achieved.add(GoalCategory.feed);
    }
    if (next.todayExerciseAchievedCount > prev.todayExerciseAchievedCount) {
      achieved.add(GoalCategory.exercise);
    }
    if (next.todaySleepAchievedCount > prev.todaySleepAchievedCount) {
      achieved.add(GoalCategory.sleep);
    }

    final setsDelta = next.todaySetExpClaimed - prev.todaySetExpClaimed;
    final setsCompleted = setsDelta > 0 ? setsDelta : 0;
    // 세트 보상은 오늘 몇 번째 세트인지에 따라 반감(base >> N) —
    // 새로 완성된 첫 세트는 prev 시점의 클레임 수가 N이다.
    final setRewardExp = setsCompleted > 0
        ? CalculateDailyGoalsScoreUseCase.setExpBase >>
            prev.todaySetExpClaimed.clamp(0, 31)
        : 0;

    return PetTransitionEvents(
      achievedNow: achieved,
      setsCompleted: setsCompleted,
      setRewardExp: setRewardExp,
    );
  }

  /// 진화 연출을 보여줘야 하는가 — "기기에서 마지막으로 본 단계"보다
  /// 높은 3단계 이상 도달 시. (2단계는 종 결정 연출이 전담)
  ///
  /// [seenStage]가 null이면 기준이 없는 최초 실행 — 뒤늦은 연출을 막기 위해
  /// 보여주지 않는다(호출부는 현재 단계를 기록만 한다).
  static bool shouldRevealEvolution({
    required int? seenStage,
    required Pet pet,
  }) {
    if (seenStage == null) return false;
    if (pet.isDead) return false;
    return pet.evolutionStage >= 3 && pet.evolutionStage > seenStage;
  }
}
