import '../entities/pet.dart';
import '../repositories/pet_repository.dart';

/// Feed 가능 여부 체크 유스케이스
/// 배고픔 상태와 식사 시간대를 확인하여 Feed 버튼을 표시할지 결정하는 비즈니스 로직
/// 
/// Feed 가능 조건:
/// - 펫이 배고픈 상태 (hunger < 30)
/// - 현재 시간이 식사 시간대 (아침 7-9시, 점심 12-14시, 저녁 18-20시)
/// - 또는 배고픔이 매우 심한 경우 (hunger < 10) - 식사 시간대 무관
class CanFeedPetUseCase {
  final PetRepository petRepository;
  
  /// 배고픔으로 간주할 hunger 임계값
  static const int hungerThreshold = 30;
  
  /// 매우 심한 배고픔 임계값 (식사 시간대 무관하게 Feed 가능)
  static const int severeHungerThreshold = 10;
  
  /// 식사 시간대 (시간)
  /// 아침: 7-9시, 점심: 12-14시, 저녁: 18-20시
  static const List<Map<String, int>> mealTimeRanges = [
    {'start': 7, 'end': 9},   // 아침
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
  /// 2. 배고픔 상태 확인 (hunger < 30)
  /// 3. 현재 시간이 식사 시간대인지 확인
  /// 4. 또는 매우 심한 배고픔인지 확인 (hunger < 10)
  Future<bool> call(String petId) async {
    // 1. 현재 Pet 조회
    final pet = await petRepository.getPet(petId);
    
    // 2. 배고픔 상태 확인
    if (pet.hunger >= hungerThreshold) {
      return false; // 배고프지 않으면 Feed 불가
    }
    
    // 3. 매우 심한 배고픔인 경우 (hunger < 10) - 식사 시간대 무관하게 Feed 가능
    if (pet.hunger < severeHungerThreshold) {
      return true;
    }
    
    // 4. 현재 시간이 식사 시간대인지 확인
    final now = DateTime.now();
    final currentHour = now.hour;
    
    for (final range in mealTimeRanges) {
      if (currentHour >= range['start']! && currentHour < range['end']!) {
        return true; // 식사 시간대이고 배고픔 상태면 Feed 가능
      }
    }
    
    return false; // 식사 시간대가 아니면 Feed 불가
  }
  
  /// Feed 가능 여부 확인 (Pet 엔티티 직접 전달)
  /// 
  /// [pet] 확인할 Pet 엔티티
  /// 
  /// 반환: Feed 가능하면 true, 아니면 false
  bool canFeed(Pet pet) {
    // 배고픔 상태 확인
    if (pet.hunger >= hungerThreshold) {
      return false;
    }
    
    // 매우 심한 배고픔인 경우 (hunger < 10) - 식사 시간대 무관하게 Feed 가능
    if (pet.hunger < severeHungerThreshold) {
      return true;
    }
    
    // 현재 시간이 식사 시간대인지 확인
    final now = DateTime.now();
    final currentHour = now.hour;
    
    for (final range in mealTimeRanges) {
      if (currentHour >= range['start']! && currentHour < range['end']!) {
        return true;
      }
    }
    
    return false;
  }
}
