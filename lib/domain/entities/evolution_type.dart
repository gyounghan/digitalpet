/// 진화 종 타입 (사신수 기반)
/// 사용자의 활동 패턴(활동량 × 규칙성)에 따라 결정
enum EvolutionType {
  /// 새 계열 (주작) - 활발하고 자유로운 패턴
  bird,

  /// 뱀 계열 (청룡) - 차분하고 자유로운 패턴
  snake,

  /// 호랑이 계열 (백호) - 활발하고 규칙적인 패턴
  tiger,

  /// 거북이 계열 (현무) - 차분하고 규칙적인 패턴
  turtle,

  // ── 설화 영물(히든 종) — 한 지표가 극단일 때 사신수 대신 각성 ──
  // 각성 조건은 EvolutionAxisScores.hiddenTypeFor 참조

  /// 삼족오 계열 - 걸음 극단 (태양의 세발 까마귀)
  samjoko,

  /// 구미호 계열 - 급식 극단 (아홉 꼬리 여우)
  gumiho,

  /// 달토끼 계열 - 수면 극단 (달의 토끼)
  moonrabbit,

  /// 해태 계열 - 연속 접속 극단 (정의의 수호수)
  haetae,

  /// 도깨비 계열 - 배틀 승수 극단 (장난꾸러기 싸움꾼)
  dokkaebi,

  /// 황룡 계열 - 네 지표 균형 (오방의 중앙, 완벽 육성)
  hwangryong,
}

/// 종 분류 편의 확장
extension EvolutionTypeX on EvolutionType {
  /// 설화 영물(히든 종) 여부 — 사신수(bird/snake/tiger/turtle)가 아닌 종
  bool get isHiddenSpecies =>
      this == EvolutionType.samjoko ||
      this == EvolutionType.gumiho ||
      this == EvolutionType.moonrabbit ||
      this == EvolutionType.haetae ||
      this == EvolutionType.dokkaebi ||
      this == EvolutionType.hwangryong;
}
