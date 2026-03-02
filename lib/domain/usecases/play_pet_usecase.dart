import '../entities/pet.dart';
import '../repositories/pet_repository.dart';

/// 반려동물과 놀아주기 유스케이스
/// Play 버튼 클릭 시 happiness를 증가시키는 비즈니스 로직
/// 
/// 규칙:
/// - happiness +10
/// - 값은 100을 넘지 않도록 처리
class PlayPetUseCase {
  final PetRepository petRepository;
  
  PlayPetUseCase(this.petRepository);
  
  /// 반려동물과 놀아주기
  /// 
  /// [petId] 놀아줄 반려동물 ID
  /// 
  /// 반환: 업데이트된 Pet 엔티티
  /// 
  /// 동작:
  /// 1. 현재 Pet 조회
  /// 2. happiness +10 (최대 100)
  /// 3. lastUpdated를 현재 시간으로 업데이트
  /// 4. 업데이트된 Pet 저장
  Future<Pet> call(String petId) async {
    // 1. 현재 Pet 조회
    final pet = await petRepository.getPet(petId);
    
    // 2. happiness +10 (최대 100을 넘지 않도록 처리)
    final newHappiness = (pet.happiness + 10).clamp(0, 100);
    
    // 3. 현재 시간으로 업데이트
    final currentTime = DateTime.now().millisecondsSinceEpoch;
    
    // 4. 업데이트된 Pet 생성
    final updatedPet = pet.copyWith(
      happiness: newHappiness,
      lastUpdated: currentTime,
    );
    
    // 5. 저장
    await petRepository.updatePet(updatedPet);
    
    return updatedPet;
  }
}
