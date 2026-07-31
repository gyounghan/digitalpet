/// 식사 시간대 공통 정의 — Feed/CanFeed/AlternativeFeed 유스케이스 단일 소스.
///
/// 아침 6:30-10:00, 점심 11:00-14:30, 저녁 17:00-21:00.
/// 각 시간대(슬롯)는 정식 급식이든 간편 급식이든 합쳐서 1회만 사용 가능하며,
/// 사용 여부는 Pet.todayFedMealSlots 비트마스크(1=아침, 2=점심, 4=저녁)로 기록한다.
class MealTimes {
  MealTimes._();

  /// 식사 시간대 (시:분 범위)
  static const List<Map<String, int>> ranges = [
    {'startHour': 6, 'startMin': 30, 'endHour': 10, 'endMin': 0},
    {'startHour': 11, 'startMin': 0, 'endHour': 14, 'endMin': 30},
    {'startHour': 17, 'startMin': 0, 'endHour': 21, 'endMin': 0},
  ];

  /// [now] 시각의 식사 슬롯 반환 — 0: 식사 시간대 아님, 1: 아침, 2: 점심, 3: 저녁
  static int slotAt(DateTime now) {
    final currentMinutes = now.hour * 60 + now.minute;
    for (int i = 0; i < ranges.length; i++) {
      final range = ranges[i];
      final startMinutes = range['startHour']! * 60 + range['startMin']!;
      final endMinutes = range['endHour']! * 60 + range['endMin']!;
      if (currentMinutes >= startMinutes && currentMinutes < endMinutes) {
        return i + 1;
      }
    }
    return 0;
  }

  /// [fedMealSlots] 비트마스크에서 [slot]이 이미 사용됐는지
  static bool hasFedInSlot(int fedMealSlots, int slot) {
    return (fedMealSlots & (1 << (slot - 1))) != 0;
  }

  /// [slot]을 사용 처리한 새 비트마스크 반환
  static int markFed(int fedMealSlots, int slot) {
    return fedMealSlots | (1 << (slot - 1));
  }
}
