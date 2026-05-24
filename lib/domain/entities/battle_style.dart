/// 배틀 스타일 — 플레이어가 전투 전에 선택하는 전략
///
/// 공격형: ATK +20%, DEF -10%
/// 균형형: 변화 없음
/// 방어형: DEF +20%, ATK -10%
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
        return 'ATK +20% · DEF -10%';
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
        return 1.2;
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
        return 0.9;
      case BattleStyle.balanced:
        return 1.0;
      case BattleStyle.defender:
        return 1.2;
    }
  }
}
