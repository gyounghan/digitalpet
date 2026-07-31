/// 배틀 스타일 — 플레이어가 전투 전에 선택하는 전략
///
/// 데미지 공식(atk - def/2)상 DEF는 절반만 반영되므로, 기대값이 같으려면
/// DEF 증감폭이 ATK의 2배여야 한다. 그래서 ±10% / ∓20% 대칭으로 설계:
/// 공격형: ATK +10%, DEF -20% — 빨리 이기고 빨리 진다 (하이리스크 템포)
/// 균형형: 변화 없음
/// 방어형: ATK -10%, DEF +20% — 느리지만 안전하다
enum BattleStyle {
  attacker,
  balanced,
  defender,
}

extension BattleStyleX on BattleStyle {
  /// 한국어 라벨
  String get label {
    switch (this) {
      case BattleStyle.attacker:
        return '공격형';
      case BattleStyle.balanced:
        return '균형형';
      case BattleStyle.defender:
        return '방어형';
    }
  }

  /// 한 줄 설명
  String get description {
    switch (this) {
      case BattleStyle.attacker:
        return 'ATK +10% · DEF -20%';
      case BattleStyle.balanced:
        return '균형 잡힌 전투';
      case BattleStyle.defender:
        return 'DEF +20% · ATK -10%';
    }
  }

  /// ATK 보정 배수
  double get attackMultiplier {
    switch (this) {
      case BattleStyle.attacker:
        return 1.1;
      case BattleStyle.balanced:
        return 1.0;
      case BattleStyle.defender:
        return 0.9;
    }
  }

  /// DEF 보정 배수
  double get defenseMultiplier {
    switch (this) {
      case BattleStyle.attacker:
        return 0.8;
      case BattleStyle.balanced:
        return 1.0;
      case BattleStyle.defender:
        return 1.2;
    }
  }
}
