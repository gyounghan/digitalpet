import '../entities/pet.dart';
import '../repositories/pet_repository.dart';

/// Feed 가능 여부 체크 유스케이스
/// 식사 시간대를 확인하여 Feed 버튼을 표시할지 결정하는 비즈니스 로직
///
/// Feed 가능 조건:
/// - 현재 시간이 식사 시간대 (아침 6:30-10:00, 점심 11:00-14:30, 저녁 17:00-21:00)
/// - 해당 식사 슬롯에서 아직 Feed를 하지 않았을 때
class CanFeedPetUseCase {
  final PetRepository petRepository;

  /// 식사 시간대 (분 단위)
  static const List<Map<String, int>> mealTimeRanges = [
    {'startHour': 6, 'startMin': 30, 'endHour': 10, 'endMin': 0},
    {'startHour': 11, 'startMin': 0, 'endHour': 14, 'endMin': 30},
    {'startHour': 17, 'startMin': 0, 'endHour': 21, 'endMin': 0},
  ];

  CanFeedPetUseCase(this.petRepository);

  /// Feed 가능 여부 확인 (Repository 조회)
  Future<bool> call(String petId) async {
    final pet = await petRepository.getPet(petId);
    return canFeed(pet);
  }

  /// Feed 가능 여부 확인 (Pet 엔티티 직접 전달)
  bool canFeed(Pet pet) {
    if (pet.isDead) return false;
    final currentMealSlot = _getCurrentMealSlot();
    if (currentMealSlot > 0) {
      return !_hasFedInMealSlot(pet, currentMealSlot);
    }
    return false;
  }

  /// 현재 식사 시간대 슬롯 반환
  /// 0: 식사 시간대 아님, 1: 아침, 2: 점심, 3: 저녁
  int _getCurrentMealSlot() {
    final now = DateTime.now();
    final currentMinutes = now.hour * 60 + now.minute;

    for (int i = 0; i < mealTimeRanges.length; i++) {
      final range = mealTimeRanges[i];
      final startMinutes = range['startHour']! * 60 + range['startMin']!;
      final endMinutes = range['endHour']! * 60 + range['endMin']!;
      if (currentMinutes >= startMinutes && currentMinutes < endMinutes) {
        return i + 1;
      }
    }

    return 0;
  }

  /// 특정 식사 슬롯에서 이미 Feed 했는지 확인
  bool _hasFedInMealSlot(Pet pet, int mealSlot) {
    final slotBit = 1 << (mealSlot - 1);
    return (pet.todayFedMealSlots & slotBit) != 0;
  }
}
