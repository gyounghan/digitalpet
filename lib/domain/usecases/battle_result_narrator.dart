/// 대련 결과 해설 생성기 (순수 함수)
///
/// 승패보다 "성장 확인"에 초점을 맞춘다 (PM_REVIEW.md 참조).
/// 전투 스탯이 전부 건강 지표에서 파생되므로(HP=누적 걸음, ATK=행복,
/// DEF=기력, 컨디션 보정=오늘의 돌봄), 그 인과를 문장으로 되돌려준다.
///
/// 톤 규칙:
/// - "약하다", "졌습니다" 단독 표기 금지
/// - 패배 시엔 반드시 원인 + 내일의 처방 세트로 말한다
/// - 오늘의 활동("오늘 N보 걸어서 버텼다")을 근거로 제시한다
class BattleNarration {
  /// 한 줄 헤드라인 (승패 배너 아래 표시)
  final String headline;

  /// 해설 문구 목록 (최대 3줄)
  final List<String> lines;

  const BattleNarration({required this.headline, required this.lines});
}

class BattleResultNarrator {
  BattleResultNarrator._();

  /// 좋은 컨디션으로 칭찬하는 임계값
  static const int goodStatThreshold = 70;

  /// 걸음 서사에 실제 걸음 수를 언급하는 최소치
  static const int stepMentionThreshold = 1000;

  /// 해설 최대 줄 수
  static const int maxLines = 3;

  static BattleNarration narrate({
    required bool isVictory,
    required bool isDominantVictory,
    required int playerHpRemaining,
    required int playerMaxHp,
    required int hunger,
    required int happiness,
    required int stamina,
    required int todaySteps,
    bool affinityAdvantage = false,
  }) {
    final lines = <String>[];
    final hpRatio =
        playerMaxHp > 0 ? playerHpRemaining / playerMaxHp : 0.0;

    if (isVictory) {
      // 1) HP·걸음 서사 — 오늘의 활동이 버팀목이었음을 근거로
      if (hpRatio >= 0.5) {
        lines.add(todaySteps >= stepMentionThreshold
            ? '오늘 $todaySteps보를 걸어둔 덕에 HP가 끝까지 버텨줬어!'
            : '몸이 튼튼해서 HP가 끝까지 버텨줬어!');
      } else {
        lines.add('아슬아슬했지만 끝까지 버텨냈어!');
      }
      // 2) 컨디션 칭찬 (가장 잘 채워둔 축 하나)
      final praise = _praiseLine(
          hunger: hunger, happiness: happiness, stamina: stamina);
      if (praise != null) lines.add(praise);
      // 3) 상성 — 승리에 한 몫 했을 때만 가볍게
      if (affinityAdvantage) {
        lines.add('사신수 상성도 우리 편이었어!');
      }
    } else {
      // 패배 — 원인(가장 낮은 스탯) + 내일의 처방을 반드시 세트로
      lines.add(_defeatCauseAndRemedy(
          hunger: hunger, happiness: happiness, stamina: stamina));
      // 잘한 점도 하나는 짚어준다 (죄책감 방지)
      final praise = _praiseLine(
          hunger: hunger, happiness: happiness, stamina: stamina);
      if (praise != null) lines.add(praise);
    }

    return BattleNarration(
      headline: _headline(isVictory, isDominantVictory),
      lines: lines.take(maxLines).toList(),
    );
  }

  static String _headline(bool isVictory, bool isDominantVictory) {
    if (isDominantVictory) return '완벽한 컨디션이었어!';
    if (isVictory) return '오늘의 노력이 빛났어!';
    return '아쉽지만, 한 뼘 성장했어!';
  }

  /// 70 이상인 축 중 우선순위(행복→기력→포만감)로 칭찬 한 줄
  static String? _praiseLine({
    required int hunger,
    required int happiness,
    required int stamina,
  }) {
    if (happiness >= goodStatThreshold) {
      return '행복이 가득해서 공격이 잘 먹혔어.';
    }
    if (stamina >= goodStatThreshold) {
      return '기력이 좋아서 방어를 잘했어.';
    }
    if (hunger >= goodStatThreshold) {
      return '든든하게 먹어둔 덕에 지치지 않았어.';
    }
    return null;
  }

  /// 패배 원인(최저 스탯) + 처방. 컨디션이 다 좋았다면 상대 탓으로 돌려준다.
  static String _defeatCauseAndRemedy({
    required int hunger,
    required int happiness,
    required int stamina,
  }) {
    final lowest = [hunger, happiness, stamina]
        .reduce((a, b) => a < b ? a : b);
    if (lowest >= goodStatThreshold) {
      return '컨디션은 최고였는데 상대가 한 수 위였어. 내일 다시 해보자!';
    }
    // 동률이면 포만감 → 행복 → 기력 순으로 처방 (식사가 가장 쉬운 행동)
    if (hunger == lowest) {
      return '포만감이 낮아서 중간에 지쳤어. 내일은 밥을 챙기면 더 오래 버틸 거야!';
    }
    if (happiness == lowest) {
      return '기운이 조금 없었어. 내일 같이 산책하면 공격이 강해질 거야!';
    }
    return '몸이 무거웠나 봐. 폰을 내려놓고 쉬면 방어가 단단해질 거야!';
  }
}
