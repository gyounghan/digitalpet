import '../entities/pet.dart';
import '../repositories/pet_repository.dart';

/// 반려동물 상태 업데이트 유스케이스
/// 시간 경과에 따라 펫의 상태(hunger, happiness, stamina)를 감소시키는 비즈니스 로직
/// 
/// 감소 규칙:
/// - 포만감(hunger): 30분마다 -1
/// - 운동(happiness): 30분마다 -1
/// - 수면(stamina): 30분마다 -1
/// - 값은 0 이하로 내려가지 않음
class UpdatePetStateUseCase {
  final PetRepository petRepository;
  static const int decreasePerInterval = 1;
  static const int decreaseIntervalMinutes = 30;
  
  UpdatePetStateUseCase(this.petRepository);
  
  /// 반려동물 상태를 시간 경과에 따라 업데이트
  /// 
  /// [petId] 업데이트할 반려동물 ID
  /// 
  /// 반환: 업데이트된 Pet 엔티티
  /// 
  /// 동작:
  /// 1. 현재 시간과 lastStatusDecayUpdated 비교하여 경과 시간(분 단위) 계산
  /// 2. 경과 시간에 따라 30분 단위 감소 횟수 계산
  /// 3. 감소 횟수에 따라 hunger, happiness, stamina 감소
  /// 3. 값이 0 이하로 내려가지 않도록 처리
  /// 4. 업데이트된 Pet을 저장하고 반환
  Future<Pet> call(String petId) async {
    // 1. 현재 Pet 조회
    final pet = await petRepository.getPet(petId);

    // 사망한 펫은 상태 업데이트 불필요
    if (pet.isDead) return pet;

    // 2. 현재 시간과 lastStatusDecayUpdated 비교하여 경과 시간 계산 (분 단위)
    final currentTime = DateTime.now().millisecondsSinceEpoch;
    final elapsedMilliseconds = currentTime - pet.lastStatusDecayUpdated;
    final elapsedMinutes = elapsedMilliseconds ~/ (1000 * 60); // 분 단위로 변환
    
    // 경과 시간이 30분 미만이면 업데이트 불필요
    final elapsedIntervals = elapsedMinutes ~/ decreaseIntervalMinutes;
    if (elapsedIntervals < 1) {
      return pet;
    }
    
    // 3. 감소 규칙 적용 (30분 단위)
    final hungerDecrease = elapsedIntervals * decreasePerInterval;
    final happinessDecrease = elapsedIntervals * decreasePerInterval;
    final staminaDecrease = elapsedIntervals * decreasePerInterval;
    
    // 4. 값이 0 이하로 내려가지 않도록 처리
    final newHunger = (pet.hunger - hungerDecrease).clamp(0, 100);
    final newHappiness = (pet.happiness - happinessDecrease).clamp(0, 100);
    final newStamina = (pet.stamina - staminaDecrease).clamp(0, 100);
    
    // 5. 업데이트된 Pet 생성
    final updatedPet = pet.copyWith(
      hunger: newHunger,
      happiness: newHappiness,
      stamina: newStamina,
      lastStatusDecayUpdated: currentTime,
      lastUpdated: currentTime, // 현재 시간으로 업데이트
    );
    
    // 6. Hive에 저장
    await petRepository.updatePet(updatedPet);
    
    return updatedPet;
  }
}
