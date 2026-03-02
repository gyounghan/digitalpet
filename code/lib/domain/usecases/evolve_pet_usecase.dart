import '../entities/pet.dart';
import '../repositories/pet_repository.dart';

/// 반려동물 진화 유스케이스
/// 조건을 만족하면 Pet의 진화 단계를 업데이트하는 비즈니스 로직
/// 
/// 진화 조건:
/// - level >= 3 && happiness > 70 → evolutionStage = 2
/// - level >= 5 && hunger < 30 → evolutionStage = 3
/// - level >= 8 → evolutionStage = 4
/// 
/// 주의: 진화는 한 단계씩만 진행되며, 이미 더 높은 단계에 있으면 진화하지 않음
class EvolvePetUseCase {
  final PetRepository petRepository;
  
  EvolvePetUseCase(this.petRepository);
  
  /// 반려동물 진화 체크 및 실행
  /// 
  /// [petId] 진화시킬 반려동물 ID
  /// 
  /// 반환: 진화된 Pet 엔티티 (진화 조건 미충족 시 원래 Pet 반환)
  /// 
  /// 동작:
  /// 1. 현재 Pet 조회
  /// 2. 진화 조건 확인
  /// 3. 조건 만족 시 진화 단계 업데이트
  /// 4. 업데이트된 Pet 저장
  Future<Pet> call(String petId) async {
    // 1. 현재 Pet 조회
    final pet = await petRepository.getPet(petId);
    
    // 2. 현재 진화 단계 확인
    int newEvolutionStage = pet.evolutionStage;
    
    // 3. 진화 조건 확인 (높은 단계부터 확인하여 최대 진화 단계 결정)
    // level >= 8 → evolutionStage = 4
    if (pet.level >= 8 && newEvolutionStage < 4) {
      newEvolutionStage = 4;
    }
    // level >= 5 && hunger < 30 → evolutionStage = 3
    else if (pet.level >= 5 && pet.hunger < 30 && newEvolutionStage < 3) {
      newEvolutionStage = 3;
    }
    // level >= 3 && happiness > 70 → evolutionStage = 2
    else if (pet.level >= 3 && pet.happiness > 70 && newEvolutionStage < 2) {
      newEvolutionStage = 2;
    }
    
    // 4. 진화가 발생하지 않았으면 원래 Pet 반환
    if (newEvolutionStage == pet.evolutionStage) {
      return pet;
    }
    
    // 5. 현재 시간으로 업데이트
    final currentTime = DateTime.now().millisecondsSinceEpoch;
    
    // 6. 진화된 Pet 생성
    final evolvedPet = pet.copyWith(
      evolutionStage: newEvolutionStage,
      lastUpdated: currentTime,
    );
    
    // 7. 저장
    await petRepository.updatePet(evolvedPet);
    
    return evolvedPet;
  }
  
  /// 진화 가능 여부 확인
  /// 
  /// [pet] 확인할 Pet 엔티티
  /// 
  /// 반환: 진화 가능하면 true, 아니면 false
  bool canEvolve(Pet pet) {
    // level >= 8 → evolutionStage = 4
    if (pet.level >= 8 && pet.evolutionStage < 4) {
      return true;
    }
    // level >= 5 && hunger < 30 → evolutionStage = 3
    if (pet.level >= 5 && pet.hunger < 30 && pet.evolutionStage < 3) {
      return true;
    }
    // level >= 3 && happiness > 70 → evolutionStage = 2
    if (pet.level >= 3 && pet.happiness > 70 && pet.evolutionStage < 2) {
      return true;
    }
    return false;
  }
}
