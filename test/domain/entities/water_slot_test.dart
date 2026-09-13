import 'package:flutter_test/flutter_test.dart';
import 'package:pocketfriend/domain/entities/pet.dart';

String _today() {
  final now = DateTime.now();
  return '${now.year}-${now.month.toString().padLeft(2, '0')}-'
      '${now.day.toString().padLeft(2, '0')}';
}

Pet _pet({int todayWaterCount = 0, int lastWaterDrinkHour = -1}) {
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
    lastWaterDrinkHour: lastWaterDrinkHour,
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

    test('같은 슬롯에서 연속 2잔은 불가 — 다음 슬롯이 열려야 가능', () {
      // 정오(4잔 해금)에 1잔만 마신 상태(밀린 상태)라도,
      // 방금(12시) 마셨다면 같은 슬롯이라 즉시 재음수 불가.
      expect(
        _pet(todayWaterCount: 1, lastWaterDrinkHour: 12).canDrinkWaterAt(12),
        isFalse,
      );
      expect(
        _pet(todayWaterCount: 1, lastWaterDrinkHour: 12).canDrinkWaterAt(13),
        isFalse,
      );
      // 14시가 되면 새 슬롯(5번째)이 열려 다시 가능.
      expect(
        _pet(todayWaterCount: 1, lastWaterDrinkHour: 12).canDrinkWaterAt(14),
        isTrue,
      );
    });

    test('오늘 0잔이면 lastWaterDrinkHour(전날 값)는 무시된다', () {
      expect(
        _pet(todayWaterCount: 0, lastWaterDrinkHour: 22).canDrinkWaterAt(9),
        isTrue,
      );
    });

    test('기록 없음(-1)이면 기존 슬롯 규칙만 적용된다', () {
      expect(_pet(todayWaterCount: 3).canDrinkWaterAt(12), isTrue);
    });
  });
}
