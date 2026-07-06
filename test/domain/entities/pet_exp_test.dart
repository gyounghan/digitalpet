import 'package:flutter_test/flutter_test.dart';
import 'package:pocketfriend/domain/entities/pet.dart';

void main() {
  group('Pet.getRequiredExpForLevel — 레벨별 필요 EXP 곡선 (RPG 후반 가파름)', () {
    test('레벨 1~3: 50', () {
      expect(Pet.getRequiredExpForLevel(1), 50);
      expect(Pet.getRequiredExpForLevel(3), 50);
    });

    test('레벨 4~7: 100', () {
      expect(Pet.getRequiredExpForLevel(4), 100);
      expect(Pet.getRequiredExpForLevel(7), 100);
    });

    test('레벨 8~12: 200', () {
      expect(Pet.getRequiredExpForLevel(8), 200);
      expect(Pet.getRequiredExpForLevel(12), 200);
    });

    test('레벨 13~17: 350', () {
      expect(Pet.getRequiredExpForLevel(13), 350);
      expect(Pet.getRequiredExpForLevel(17), 350);
    });

    test('레벨 18~22: 550', () {
      expect(Pet.getRequiredExpForLevel(18), 550);
      expect(Pet.getRequiredExpForLevel(22), 550);
    });

    test('레벨 23~27: 800', () {
      expect(Pet.getRequiredExpForLevel(23), 800);
      expect(Pet.getRequiredExpForLevel(27), 800);
    });

    test('레벨 28+: 1100', () {
      expect(Pet.getRequiredExpForLevel(28), 1100);
      expect(Pet.getRequiredExpForLevel(50), 1100);
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
