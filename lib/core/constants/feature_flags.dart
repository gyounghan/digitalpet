/// MVP 출시 범위 조절용 feature flag (PM_REVIEW.md 참조)
///
/// 코드는 유지하고 진입점만 숨긴다. 다시 켤 때는 빌드 시
/// `--dart-define=ENABLE_RANKING=true` 처럼 지정하면 되고,
/// 코드 수정 없이 환경별로 온오프할 수 있다.
class FeatureFlags {
  FeatureFlags._();

  /// 랭킹 탭 노출 여부.
  /// 초기엔 유저풀이 없어 빈 랭킹판이 "죽은 앱" 인상을 주므로 기본 숨김.
  static const bool enableRanking =
      bool.fromEnvironment('ENABLE_RANKING', defaultValue: false);

  /// 실시간 온라인 대련 진입점 노출 여부.
  /// 동시 접속자가 없으면 매칭 대기 화면이 최악의 첫인상이 되므로 기본 숨김.
  /// (비동기 PvP가 자리 잡은 후 이벤트성으로 재오픈 예정)
  static const bool enableRealtimeBattle =
      bool.fromEnvironment('ENABLE_REALTIME_BATTLE', defaultValue: false);
}
