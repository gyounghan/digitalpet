import 'package:flutter_test/flutter_test.dart';
import 'package:pocketfriend/domain/entities/battle_style.dart';

void main() {
  group('BattleStyle 보정 배수', () {
    // EV 중립 설계: 데미지 공식(atk - def/2)상 DEF는 절반 반영 →
    // ATK ±10% / DEF ∓20% 가 기대값 동일 (기존 +20%/-10%는 공격형 상위호환)
    test('공격형: ATK 1.1 / DEF 0.8', () {
      expect(BattleStyle.attacker.attackMultiplier, 1.1);
      expect(BattleStyle.attacker.defenseMultiplier, 0.8);
    });

    test('균형형: ATK 1.0 / DEF 1.0', () {
      expect(BattleStyle.balanced.attackMultiplier, 1.0);
      expect(BattleStyle.balanced.defenseMultiplier, 1.0);
    });

    test('방어형: ATK 0.9 / DEF 1.2', () {
      expect(BattleStyle.defender.attackMultiplier, 0.9);
      expect(BattleStyle.defender.defenseMultiplier, 1.2);
    });

    test('한국어 라벨', () {
      expect(BattleStyle.attacker.label, '공격형');
      expect(BattleStyle.balanced.label, '균형형');
      expect(BattleStyle.defender.label, '방어형');
    });

    test('설명 문자열 - 공격형/방어형은 보정 정보 포함', () {
      expect(BattleStyle.attacker.description, contains('ATK'));
      expect(BattleStyle.attacker.description, contains('DEF'));
      expect(BattleStyle.defender.description, contains('ATK'));
      expect(BattleStyle.defender.description, contains('DEF'));
    });
  });

  group('BattleStyle 적용 시뮬레이션', () {
    test('공격형 적용 시 base ATK 50 → 55', () {
      const baseAtk = 50.0;
      final styled = (baseAtk * BattleStyle.attacker.attackMultiplier).round();
      expect(styled, 55);
    });

    test('공격형 적용 시 base DEF 50 → 40', () {
      const baseDef = 50.0;
      final styled =
          (baseDef * BattleStyle.attacker.defenseMultiplier).round();
      expect(styled, 40);
    });

    test('방어형 적용 시 base DEF 50 → 60', () {
      const baseDef = 50.0;
      final styled =
          (baseDef * BattleStyle.defender.defenseMultiplier).round();
      expect(styled, 60);
    });

    test('균형형 적용 시 변화 없음', () {
      const baseAtk = 50.0;
      const baseDef = 50.0;
      expect((baseAtk * BattleStyle.balanced.attackMultiplier).round(), 50);
      expect((baseDef * BattleStyle.balanced.defenseMultiplier).round(), 50);
    });
  });
}
