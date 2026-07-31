import 'package:flutter_test/flutter_test.dart';
import 'package:pocketfriend/domain/entities/pet.dart';

void main() {
  group('Pet.getRequiredExpForLevel — 레벨별 필요 EXP 곡선 (RPG 후반 가파름)', () {
    test('레벨 1~3: 50', () {
      expect(Pet.getRequiredExpForLevel(1), 50);
      expect(Pet.getRequiredExpForLevel(3), 50);
    });

    test('레벨 4~7: 120', () {
      expect(Pet.getRequiredExpForLevel(4), 120);
      expect(Pet.getRequiredExpForLevel(7), 120);
    });

    test('레벨 8~12: 250', () {
      expect(Pet.getRequiredExpForLevel(8), 250);
      expect(Pet.getRequiredExpForLevel(12), 250);
    });

    test('레벨 13~17: 450', () {
      expect(Pet.getRequiredExpForLevel(13), 450);
      expect(Pet.getRequiredExpForLevel(17), 450);
    });

    test('레벨 18~22: 700', () {
      expect(Pet.getRequiredExpForLevel(18), 700);
      expect(Pet.getRequiredExpForLevel(22), 700);
    });

    test('레벨 23~27: 1050', () {
      expect(Pet.getRequiredExpForLevel(23), 1050);
      expect(Pet.getRequiredExpForLevel(27), 1050);
    });

    test('레벨 28+: 1500', () {
      expect(Pet.getRequiredExpForLevel(28), 1500);
      expect(Pet.getRequiredExpForLevel(50), 1500);
    });

    test('레벨이 올라갈수록 필요 EXP 증가 (감소 없음)', () {
      var prev = Pet.getRequiredExpForLevel(1);
      for (var lv = 2; lv <= 30; lv++) {
        final cur = Pet.getRequiredExpForLevel(lv);
        expect(cur, greaterThanOrEqualTo(prev),
            reason: 'lv=$lv (cur=$cur) < lv-1 (prev=$prev)');
        prev = cur;
      }
    });
  });
}
