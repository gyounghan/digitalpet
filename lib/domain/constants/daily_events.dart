/// 일일 이벤트 ID와 효과 수치의 단일 소스
///
/// LoginBonusUseCase가 매일 첫 접속 시 추첨해 `pet.todayEvent`에 저장하고,
/// 각 유스케이스가 아래 상수로 효과를 적용한다.
/// 홈 배너 문구는 AppStrings.eventNames — 효과 수치를 바꾸면 문구도 함께 갱신할 것.
///
/// 효과 적용 위치:
/// - sunny     → UpdatePetFromActivityUseCase (걸음 happiness 보상 1.5배)
/// - cozy      → AutoSleepPetUseCase (수면 stamina 회복 1.5배)
/// - tasty     → FeedPetUseCase (식사 hunger 회복 +5)
/// - happy_day → UpdatePetStateUseCase (스탯 감쇠 절반)
/// - adventure → BattleReward (배틀 EXP 2배)
class DailyEvents {
  DailyEvents._();

  static const String sunny = 'sunny';
  static const String cozy = 'cozy';
  static const String tasty = 'tasty';
  static const String happyDay = 'happy_day';
  static const String adventure = 'adventure';
  static const String normal = 'normal';

  /// sunny: 걸음 기반 happiness 보상 배율
  static const double sunnyStepRewardMultiplier = 1.5;

  /// cozy: 수면(폰 미사용) stamina 회복 배율
  static const double cozySleepRecoveryMultiplier = 1.5;

  /// tasty: 식사 시 hunger 추가 회복량
  static const int tastyFeedBonus = 5;

  /// happy_day: 스탯 감쇠 배율 (절반)
  static const double happyDayDecayMultiplier = 0.5;

  /// adventure: 배틀 기본 EXP 배율
  static const int adventureBattleExpMultiplier = 2;
}
