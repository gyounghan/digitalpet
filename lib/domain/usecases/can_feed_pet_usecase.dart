import '../entities/pet.dart';
import '../repositories/pet_repository.dart';

/// Feed 가능 여부 체크 유스케이스
/// 배고픔 상태와 식사 시간대를 확인하여 Feed 버튼을 표시할지 결정하는 비즈니스 로직
///
/// Feed 가능 조건:
/// - 현재 시간이 식사 시간대 (아침 7-9시, 점심 12-14시, 저녁 18-20시)
/// - 해당 식사 슬롯에서 아직 Feed를 하지 않았을 때
class CanFeedPetUseCase {
  final PetRepository petRepository;

  /// 식사 시간대 (시간)
  /// 아침: 7-9시, 점심: 12-14시, 저녁: 18-20시
  static const List<Map<String, int>> mealTimeRanges = [
    {'start': 7, 'end': 9}, // 아침
    {'start': 12, 'end': 14}, // 점심
    {'start': 18, 'end': 20}, // 저녁
  ];

  CanFeedPetUseCase(this.petRepository);

  /// Feed 가능 여부 확인
  ///
  /// [petId] 확인할 반려동물 ID
  ///
  /// 반환: Feed 가능하면 true, 아니면 false
  ///
  /// 동작:
  /// 1. 현재 Pet 조회
  /// 2. 현재 시간이 식사 시간대인지 확인
  /// 3. 해당 식사 슬롯에서 이미 Feed했는지 확인
  Future<bool> call(String petId) async {
    // 1. 현재 Pet 조회
    final pet = await petRepository.getPet(petId);

    // 2. 현재 시간이 식사 시간대인지 확인
    final currentMealSlot = _getCurrentMealSlot();
    if (currentMealSlot > 0) {
      // 식사 시간대에는 해당 슬롯에서 이미 Feed 했는지 확인
      return !_hasFedInMealSlot(pet, currentMealSlot);
    }

    // 3. 식사 시간대가 아니면 Feed 버튼을 표시하지 않음
    return false;
  }

  /// Feed 가능 여부 확인 (Pet 엔티티 직접 전달)
  ///
  /// [pet] 확인할 Pet 엔티티
  ///
  /// 반환: Feed 가능하면 true, 아니면 false
  bool canFeed(Pet pet) {
    // 현재 시간이 식사 시간대인지 확인
    final currentMealSlot = _getCurrentMealSlot();
    if (currentMealSlot > 0) {
      // 식사 시간대에는 해당 슬롯에서 이미 Feed 했는지 확인
      return !_hasFedInMealSlot(pet, currentMealSlot);
    }

    // 식사 시간대가 아니면 Feed 버튼을 표시하지 않음
    return false;
  }

  /// 현재 식사 시간대 슬롯 반환
  /// 0: 식사 시간대 아님, 1: 아침, 2: 점심, 3: 저녁
  int _getCurrentMealSlot() {
    final now = DateTime.now();
    final currentHour = now.hour;

    for (int i = 0; i < mealTimeRanges.length; i++) {
      final range = mealTimeRanges[i];
      if (currentHour >= range['start']! && currentHour < range['end']!) {
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












