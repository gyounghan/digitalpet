import '../entities/pet.dart';
import '../repositories/pet_repository.dart';

/// 반려동물에게 먹이 주기 유스케이스
/// Feed 버튼 클릭 시 hunger를 증가시키는 비즈니스 로직
///
/// 규칙:
/// - hunger +20
/// - EXP +5
/// - 식사 시간대: 아침 6:30-10:00, 점심 11:00-14:30, 저녁 17:00-21:00
/// - 각 시간대 1회 제한
class FeedPetUseCase {
  final PetRepository petRepository;

  /// 회복량
  static const int hungerRecoveryAmount = 20;

  /// Feed 시 획득 경험치
  static const int feedExpReward = 5;

  /// 식사 시간대 (시:분 -> 분 단위)
  /// 아침: 6:30-10:00, 점심: 11:00-14:30, 저녁: 17:00-21:00
  static const List<Map<String, int>> mealTimeRanges = [
    {'startHour': 6, 'startMin': 30, 'endHour': 10, 'endMin': 0},
    {'startHour': 11, 'startMin': 0, 'endHour': 14, 'endMin': 30},
    {'startHour': 17, 'startMin': 0, 'endHour': 21, 'endMin': 0},
  ];

  FeedPetUseCase(this.petRepository);

  /// 반려동물에게 먹이 주기
  Future<Pet> call(String petId) async {
    var pet = await petRepository.getPet(petId);

    if (pet.needsGoalReset) {
      pet = pet.resetDailyGoals();
    }

    final currentMealSlot = _getCurrentMealSlot();
    if (currentMealSlot == 0) return pet;
    if (_hasFedInMealSlot(pet, currentMealSlot)) return pet;

    final newHunger = (pet.hunger + hungerRecoveryAmount).clamp(0, 100);
    final newFeedCount = (pet.todayFeedCount + 1).clamp(0, 3);
    final newFedMealSlots = pet.todayFedMealSlots | (1 << (currentMealSlot - 1));
    final newExp = pet.exp + feedExpReward;
    final currentTime = DateTime.now().millisecondsSinceEpoch;

    final updatedPet = pet.copyWith(
      hunger: newHunger,
      todayFeedCount: newFeedCount,
      todayFedMealSlots: newFedMealSlots,
      exp: newExp,
      lastUpdated: currentTime,
    );

    await petRepository.updatePet(updatedPet);
    return updatedPet;
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
