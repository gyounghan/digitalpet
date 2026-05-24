import 'package:flutter_test/flutter_test.dart';
import 'package:pocketfriend/domain/entities/pet.dart';

void main() {
  group('Pet.getRequiredExpForLevel — 레벨별 필요 EXP 곡선', () {
    test('레벨 1~5: 80', () {
      expect(Pet.getRequiredExpForLevel(1), 80);
      expect(Pet.getRequiredExpForLevel(3), 80);
      expect(Pet.getRequiredExpForLevel(5), 80);
    });

    test('레벨 6~10: 120', () {
      expect(Pet.getRequiredExpForLevel(6), 120);
      expect(Pet.getRequiredExpForLevel(10), 120);
    });

    test('레벨 11~15: 160', () {
      expect(Pet.getRequiredExpForLevel(11), 160);
      expect(Pet.getRequiredExpForLevel(15), 160);
    });

    test('레벨 16~20: 200', () {
      expect(Pet.getRequiredExpForLevel(16), 200);
      expect(Pet.getRequiredExpForLevel(20), 200);
    });

    test('레벨 21~25: 250', () {
      expect(Pet.getRequiredExpForLevel(21), 250);
      expect(Pet.getRequiredExpForLevel(25), 250);
    });

    test('레벨 26+: 300', () {
      expect(Pet.getRequiredExpForLevel(26), 300);
      expect(Pet.getRequiredExpForLevel(50), 300);
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
