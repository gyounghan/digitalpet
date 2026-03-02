import '../entities/pet.dart';
import '../repositories/pet_repository.dart';

/// 반려동물 재우기 유스케이스
/// Sleep 버튼 클릭 시 stamina를 증가시키는 비즈니스 로직
/// 
/// 규칙:
/// - stamina +10
/// - 값은 100을 넘지 않도록 처리
class SleepPetUseCase {
  final PetRepository petRepository;
  
  SleepPetUseCase(this.petRepository);
  
  /// 반려동물 재우기
  /// 
  /// [petId] 재울 반려동물 ID
  /// 
  /// 반환: 업데이트된 Pet 엔티티
  /// 
  /// 동작:
  /// 1. 현재 Pet 조회
  /// 2. stamina +10 (최대 100)
  /// 3. lastUpdated를 현재 시간으로 업데이트
  /// 4. 업데이트된 Pet 저장
  Future<Pet> call(String petId) async {
    // 1. 현재 Pet 조회
    final pet = await petRepository.getPet(petId);
    
    // 2. stamina +10 (최대 100을 넘지 않도록 처리)
    final newStamina = (pet.stamina + 10).clamp(0, 100);
    
    // 3. 현재 시간으로 업데이트
    final currentTime = DateTime.now().millisecondsSinceEpoch;
    
    // 4. 업데이트된 Pet 생성
    final updatedPet = pet.copyWith(
      stamina: newStamina,
      lastUpdated: currentTime,
    );
    
    // 5. 저장
    await petRepository.updatePet(updatedPet);
    
    return updatedPet;
  }
}
