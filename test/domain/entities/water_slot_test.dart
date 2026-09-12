import 'package:flutter_test/flutter_test.dart';
import 'package:pocketfriend/domain/entities/pet.dart';

String _today() {
  final now = DateTime.now();
  return '${now.year}-${now.month.toString().padLeft(2, '0')}-'
      '${now.day.toString().padLeft(2, '0')}';
}

Pet _pet({int todayWaterCount = 0}) {
  final now = DateTime.now().millisecondsSinceEpoch;
  return Pet(
    id: 'p',
    hunger: 80,
    happiness: 80,
    stamina: 50,
    level: 1,
    exp: 0,
    evolutionStage: 1,
    lastUpdated: now,
    lastStatusDecayUpdated: now,
    lastGoalResetDate: _today(),
    todayWaterCount: todayWaterCount,
  );
}

void main() {
  group('물잔 시간 슬롯 해금', () {
    test('06시 이전 새벽에는 1잔만 열린다', () {
      expect(Pet.unlockedWaterSlots(0), 1);
      expect(Pet.unlockedWaterSlots(5), 1);
    });

    test('06시부터 2시간마다 1잔씩 열린다', () {
      expect(Pet.unlockedWaterSlots(6), 1);
      expect(Pet.unlockedWaterSlots(7), 1);
      expect(Pet.unlockedWaterSlots(8), 2);
      expect(Pet.unlockedWaterSlots(12), 4);
      expect(Pet.unlockedWaterSlots(18), 7);
      expect(Pet.unlockedWaterSlots(20), 8);
      expect(Pet.unlockedWaterSlots(23), 8);
    });

    test('canDrinkWaterAt — 해금 잔수보다 덜 마셨을 때만 가능', () {
      // 정오(4잔 해금): 3잔 마심 → 가능, 4잔 마심 → 불가
      expect(_pet(todayWaterCount: 3).canDrinkWaterAt(12), isTrue);
      expect(_pet(todayWaterCount: 4).canDrinkWaterAt(12), isFalse);
      // 밤(8잔 해금): 7잔 마심 → 가능, 8잔(총량 소진) → 불가
      expect(_pet(todayWaterCount: 7).canDrinkWaterAt(21), isTrue);
      expect(_pet(todayWaterCount: 8).canDrinkWaterAt(21), isFalse);
    });

    test('canDrinkWater(총량)는 시간과 무관하게 8잔 미만이면 true', () {
      expect(_pet(todayWaterCount: 7).canDrinkWater, isTrue);
      expect(_pet(todayWaterCount: 8).canDrinkWater, isFalse);
    });
  });
}
