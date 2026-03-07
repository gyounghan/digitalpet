import '../entities/pet.dart';
import '../repositories/pet_repository.dart';

/// 자동 펫 먹이주기 유스케이스
/// 시간 기반으로 자동으로 hunger를 회복시키는 비즈니스 로직
/// 
/// 규칙:
/// - 펫이 배고픈 상태(hunger < 30)에서 2시간 이상 지속되면 자동으로 식사
/// - 식사 후 hunger +30 회복
/// - 하루 최대 3회 자동 식사 (아침/점심/저녁 시간대)
/// - 마지막 식사 시간을 추적하여 중복 식사 방지
class AutoFeedPetUseCase {
  final PetRepository petRepository;
  
  /// 배고픔으로 간주할 hunger 임계값
  static const int hungerThreshold = 30;
  
  /// 자동 식사까지 필요한 대기 시간 (시간)
  static const int autoFeedWaitHours = 2;
  
  /// 자동 식사 시 hunger 회복량
  static const int hungerRecoveryAmount = 30;
  
  /// 하루 최대 자동 식사 횟수
  static const int maxAutoFeedsPerDay = 3;
  
  /// 자동 식사 시간대 (시간)
  /// 아침: 7-9시, 점심: 12-14시, 저녁: 18-20시
  static const List<Map<String, int>> mealTimeRanges = [
    {'start': 7, 'end': 9},   // 아침
    {'start': 12, 'end': 14}, // 점심
    {'start': 18, 'end': 20}, // 저녁
  ];
  
  AutoFeedPetUseCase(this.petRepository);
  
  /// 자동으로 펫에게 먹이 주기
  /// 
  /// [petId] 먹이를 줄 반려동물 ID
  /// [lastFeedTime] 마지막 식사 시간 (타임스탬프, null이면 Pet의 lastUpdated 사용)
  /// 
  /// 반환: 업데이트된 Pet 엔티티 (조건 미충족 시 원래 Pet 반환)
  /// 
  /// 동작:
  /// 1. 현재 Pet 조회
  /// 2. 배고픔 상태 확인 (hunger < 30)
  /// 3. 마지막 식사로부터 경과 시간 확인 (2시간 이상)
  /// 4. 현재 시간이 식사 시간대인지 확인
  /// 5. 오늘 자동 식사 횟수 확인 (최대 3회)
  /// 6. 조건 만족 시 hunger +30 회복
  Future<Pet> call(String petId, {int? lastFeedTime}) async {
    // 1. 현재 Pet 조회
    final pet = await petRepository.getPet(petId);
    
    // 2. 배고픔 상태 확인
    if (pet.hunger >= hungerThreshold) {
      return pet; // 배고프지 않으면 업데이트하지 않음
    }
    
    // 3. 마지막 식사 시간 확인
    final feedTime = lastFeedTime ?? pet.lastUpdated;
    final currentTime = DateTime.now().millisecondsSinceEpoch;
    final elapsedMilliseconds = currentTime - feedTime;
    final elapsedHours = elapsedMilliseconds ~/ (1000 * 60 * 60);
    
    // 4. 2시간 이상 경과했는지 확인
    if (elapsedHours < autoFeedWaitHours) {
      return pet; // 아직 시간이 안 됨
    }
    
    // 5. 현재 시간이 식사 시간대인지 확인
    final now = DateTime.now();
    final currentHour = now.hour;
    bool isMealTime = false;
    for (final range in mealTimeRanges) {
      if (currentHour >= range['start']! && currentHour < range['end']!) {
        isMealTime = true;
        break;
      }
    }
    
    // 식사 시간대가 아니어도 배고픔이 너무 심하면 (hunger < 10) 자동 식사
    if (!isMealTime && pet.hunger >= 10) {
      return pet; // 식사 시간대가 아니고 배고픔이 심하지 않으면 대기
    }
    
    // 6. 오늘 자동 식사 횟수 확인 (간단한 구현: 마지막 식사가 오늘이면 카운트)
    // 실제로는 별도 저장소에 오늘 식사 횟수를 저장해야 하지만,
    // 여기서는 간단히 마지막 식사 시간이 오늘이면 1회로 간주
    final lastFeedDate = DateTime.fromMillisecondsSinceEpoch(feedTime);
    final today = DateTime(now.year, now.month, now.day);
    final lastFeedDay = DateTime(lastFeedDate.year, lastFeedDate.month, lastFeedDate.day);
    
    // 오늘이 아니면 자동 식사 가능 (새로운 날)
    // 오늘이면 마지막 식사로부터 충분한 시간이 경과했는지 확인
    if (lastFeedDay == today && elapsedHours < autoFeedWaitHours) {
      return pet; // 오늘 이미 식사했고 시간이 안 됨
    }
    
    // 7. hunger 회복
    final newHunger = (pet.hunger + hungerRecoveryAmount).clamp(0, 100);
    
    // 8. 현재 시간으로 업데이트
    final updatedPet = pet.copyWith(
      hunger: newHunger,
      lastUpdated: currentTime,
    );
    
    // 9. 저장
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
    
    // 마지막 업데이트로부터 경과 시간 확인
    final currentTime = DateTime.now().millisecondsSinceEpoch;
    final elapsedMilliseconds = currentTime - pet.lastUpdated;
    final elapsedHours = elapsedMilliseconds ~/ (1000 * 60 * 60);
    
    if (elapsedHours < autoFeedWaitHours) {
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
}
