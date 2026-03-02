import '../entities/pet.dart';
import '../repositories/pet_repository.dart';

/// 반려동물 상태 업데이트 유스케이스
/// 시간 경과에 따라 펫의 상태(hunger, happiness)를 감소시키는 비즈니스 로직
/// 
/// 감소 규칙:
/// - 1시간당 hunger -2
/// - 1시간당 happiness -1
/// - stamina는 감소하지 않음
/// - 값은 0 이하로 내려가지 않음
class UpdatePetStateUseCase {
  final PetRepository petRepository;
  
  UpdatePetStateUseCase(this.petRepository);
  
  /// 반려동물 상태를 시간 경과에 따라 업데이트
  /// 
  /// [petId] 업데이트할 반려동물 ID
  /// 
  /// 반환: 업데이트된 Pet 엔티티
  /// 
  /// 동작:
  /// 1. 현재 시간과 lastUpdated 비교하여 경과 시간(시간 단위) 계산
  /// 2. 경과 시간에 따라 hunger, happiness 감소
  /// 3. 값이 0 이하로 내려가지 않도록 처리
  /// 4. 업데이트된 Pet을 저장하고 반환
  Future<Pet> call(String petId) async {
    // 1. 현재 Pet 조회
    final pet = await petRepository.getPet(petId);
    
    // 2. 현재 시간과 lastUpdated 비교하여 경과 시간 계산
    final currentTime = DateTime.now().millisecondsSinceEpoch;
    final elapsedMilliseconds = currentTime - pet.lastUpdated;
    final elapsedHours = elapsedMilliseconds ~/ (1000 * 60 * 60); // 시간 단위로 변환
    
    // 경과 시간이 없으면 업데이트 불필요
    if (elapsedHours <= 0) {
      return pet;
    }
    
    // 3. 감소 규칙 적용
    // 1시간당 hunger -2, happiness -1
    final hungerDecrease = elapsedHours * 2;
    final happinessDecrease = elapsedHours * 1;
    
    // 4. 값이 0 이하로 내려가지 않도록 처리
    final newHunger = (pet.hunger - hungerDecrease).clamp(0, 100);
    final newHappiness = (pet.happiness - happinessDecrease).clamp(0, 100);
    // stamina는 감소하지 않음
    
    // 5. 업데이트된 Pet 생성
    final updatedPet = pet.copyWith(
      hunger: newHunger,
      happiness: newHappiness,
      lastUpdated: currentTime, // 현재 시간으로 업데이트
    );
    
    // 6. Hive에 저장
    await petRepository.updatePet(updatedPet);
    
    return updatedPet;
  }
}
