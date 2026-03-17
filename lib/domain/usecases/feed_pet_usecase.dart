import '../entities/pet.dart';
import '../repositories/pet_repository.dart';

/// 반려동물에게 먹이 주기 유스케이스
/// Feed 버튼 클릭 시 hunger를 증가시키는 비즈니스 로직
///
/// 규칙:
/// - hunger +10
/// - 값은 100을 넘지 않도록 처리
class FeedPetUseCase {
  final PetRepository petRepository;

  /// 식사 시간대 (시간)
  /// 아침: 7-9시, 점심: 12-14시, 저녁: 18-20시
  static const List<Map<String, int>> mealTimeRanges = [
    {'start': 7, 'end': 9},
    {'start': 12, 'end': 14},
    {'start': 18, 'end': 20},
  ];

  FeedPetUseCase(this.petRepository);

  /// 반려동물에게 먹이 주기
  ///
  /// [petId] 먹이를 줄 반려동물 ID
  ///
  /// 반환: 업데이트된 Pet 엔티티
  ///
  /// 동작:
  /// 1. 현재 Pet 조회
  /// 2. 일일 목표 리셋 확인 (날짜 변경 시)
  /// 3. hunger +10 (최대 100)
  /// 4. 오늘의 Feed 횟수 증가 (최대 3회)
  /// 5. lastUpdated를 현재 시간으로 업데이트
  /// 6. 업데이트된 Pet 저장
  Future<Pet> call(String petId) async {
    // 1. 현재 Pet 조회
    var pet = await petRepository.getPet(petId);

    // 2. 일일 목표 리셋 확인
    if (pet.needsGoalReset) {
      pet = pet.resetDailyGoals();
    }

    // 3. 현재 식사 시간대 슬롯 확인
    final currentMealSlot = _getCurrentMealSlot();
    if (currentMealSlot == 0) {
      // 식사 시간대 외에는 기본 Feed 불가 (대체 급식 사용)
      return pet;
    }

    if (currentMealSlot > 0 && _hasFedInMealSlot(pet, currentMealSlot)) {
      // 이미 해당 식사 시간대에 Feed를 완료했으면 중복 Feed 방지
      return pet;
    }

    // 4. hunger +10 (최대 100을 넘지 않도록 처리)
    final newHunger = (pet.hunger + 10).clamp(0, 100);

    // 5. 오늘의 Feed 횟수 증가 (최대 3회)
    final newFeedCount = (pet.todayFeedCount + 1).clamp(0, 3);

    // 6. 식사 시간대 Feed 기록 비트마스크 업데이트
    final newFedMealSlots = currentMealSlot > 0
        ? (pet.todayFedMealSlots | (1 << (currentMealSlot - 1)))
        : pet.todayFedMealSlots;

    // 7. 현재 시간으로 업데이트
    final currentTime = DateTime.now().millisecondsSinceEpoch;

    // 8. 업데이트된 Pet 생성
    final updatedPet = pet.copyWith(
      hunger: newHunger,
      todayFeedCount: newFeedCount,
      todayFedMealSlots: newFedMealSlots,
      lastUpdated: currentTime,
    );

    // 9. 저장
    await petRepository.updatePet(updatedPet);

    return updatedPet;
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
