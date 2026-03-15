import '../entities/pet.dart';
import '../repositories/pet_repository.dart';

/// 자동 펫 먹이주기 유스케이스
/// 시간 기반으로 자동으로 hunger를 회복시키는 비즈니스 로직
///
/// 규칙:
/// - 펫이 배고픈 상태(hunger < 30)일 때 자동 식사 대상
/// - 식사 후 hunger +30 회복
/// - 하루 최대 3회 자동 식사 (아침/점심/저녁 시간대)
/// - 동일 식사 시간대 중복 자동 식사 방지
class AutoFeedPetUseCase {
  final PetRepository petRepository;

  /// 배고픔으로 간주할 hunger 임계값
  static const int hungerThreshold = 30;

  /// 자동 식사 시 hunger 회복량
  static const int hungerRecoveryAmount = 30;

  /// 하루 최대 자동 식사 횟수
  static const int maxAutoFeedsPerDay = 3;

  /// 자동 식사 시간대 (시간)
  /// 아침: 7-9시, 점심: 12-14시, 저녁: 18-20시
  static const List<Map<String, int>> mealTimeRanges = [
    {'start': 7, 'end': 9}, // 아침
    {'start': 12, 'end': 14}, // 점심
    {'start': 18, 'end': 20}, // 저녁
  ];

  AutoFeedPetUseCase(this.petRepository);

  /// 자동으로 펫에게 먹이 주기
  ///
  /// [petId] 먹이를 줄 반려동물 ID
  /// 반환: 업데이트된 Pet 엔티티 (조건 미충족 시 원래 Pet 반환)
  ///
  /// 동작:
  /// 1. 현재 Pet 조회
  /// 2. 배고픔 상태 확인 (hunger < 30)
  /// 3. 현재 시간이 식사 시간대인지 확인
  /// 4. 해당 시간대에 이미 자동 식사했는지 확인
  /// 5. 조건 만족 시 hunger +30 회복
  Future<Pet> call(String petId) async {
    // 1. 현재 Pet 조회
    final pet = await petRepository.getPet(petId);

    // 2. 배고픔 상태 확인
    if (pet.hunger >= hungerThreshold) {
      return pet; // 배고프지 않으면 업데이트하지 않음
    }

    // 3. 현재 시간이 식사 시간대인지 확인
    final now = DateTime.now();
    final currentHour = now.hour;
    int currentMealSlot = 0; // 1: 아침, 2: 점심, 3: 저녁
    for (int i = 0; i < mealTimeRanges.length; i++) {
      final range = mealTimeRanges[i];
      if (currentHour >= range['start']! && currentHour < range['end']!) {
        currentMealSlot = i + 1;
        break;
      }
    }

    // 식사 시간대가 아니어도 배고픔이 너무 심하면 (hunger < 10) 자동 식사
    final isSevereHungry = pet.hunger < 10;
    if (currentMealSlot == 0 && !isSevereHungry) {
      return pet; // 식사 시간대가 아니고 배고픔이 심하지 않으면 대기
    }

    // 4. 오늘 자동 식사 횟수 제한 및 동일 시간대 중복 방지
    if (!isSevereHungry) {
      if (pet.todayFeedCount >= maxAutoFeedsPerDay) {
        return pet;
      }
      if (_hasFedInMealSlot(pet, currentMealSlot)) {
        return pet;
      }
    }

    // 5. hunger 회복
    final newHunger = (pet.hunger + hungerRecoveryAmount).clamp(0, 100);

    // 6. 오늘의 Feed 횟수 및 식사 슬롯 기록 업데이트
    final newFeedCount = (pet.todayFeedCount + 1).clamp(0, maxAutoFeedsPerDay);
    final newFedMealSlots = currentMealSlot > 0
        ? (pet.todayFedMealSlots | (1 << (currentMealSlot - 1)))
        : pet.todayFedMealSlots;

    // 7. 현재 시간으로 업데이트
    final currentTime = DateTime.now().millisecondsSinceEpoch;
    final updatedPet = pet.copyWith(
      hunger: newHunger,
      todayFeedCount: newFeedCount,
      todayFedMealSlots: newFedMealSlots,
      lastUpdated: currentTime,
    );

    // 8. 저장
    await petRepository.updatePet(updatedPet);

    return updatedPet;
  }

  /// 자동 식사 가능 여부 확인
  ///
  /// [pet] 확인할 Pet 엔티티
  ///
  /// 반환: 자동 식사 가능하면 true, 아니면 false
  bool canAutoFeed(Pet pet) {
    // 배고픔 상태 확인
    if (pet.hunger >= hungerThreshold) {
      return false;
    }

    // 식사 시간대 확인
    final now = DateTime.now();
    final currentHour = now.hour;
    bool isMealTime = false;
    for (final range in mealTimeRanges) {
      if (currentHour >= range['start']! && currentHour < range['end']!) {
        isMealTime = true;
        break;
      }
    }

    // 식사 시간대가 아니어도 배고픔이 너무 심하면 (hunger < 10) 자동 식사 가능
    return isMealTime || pet.hunger < 10;
  }

  /// 특정 식사 슬롯에서 이미 Feed 했는지 확인
  bool _hasFedInMealSlot(Pet pet, int mealSlot) {
    final slotBit = 1 << (mealSlot - 1);
    return (pet.todayFedMealSlots & slotBit) != 0;
  }
}
