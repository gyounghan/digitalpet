import '../entities/pet.dart';
import '../repositories/pet_repository.dart';

/// 기본 반려동물 생성 유스케이스
/// Pet 데이터가 없을 때 기본값으로 초기화하는 비즈니스 로직
/// 
/// 기본값:
/// - hunger: 100
/// - happiness: 100
/// - stamina: 100
/// - level: 1
/// - exp: 0
/// - evolutionStage: 0
/// - lastUpdated: 현재 시간
class CreateDefaultPetUseCase {
  final PetRepository petRepository;
  
  CreateDefaultPetUseCase(this.petRepository);
  
  /// 기본 반려동물 생성
  /// 
  /// [petId] 생성할 반려동물 ID
  /// 
  /// 반환: 생성된 Pet 엔티티
  /// 
  /// 동작:
  /// 1. 기본값으로 Pet 생성
  /// 2. Hive에 저장
  /// 3. 생성된 Pet 반환
  Future<Pet> call(String petId) async {
    final currentTime = DateTime.now().millisecondsSinceEpoch;
    
    // 기본값으로 Pet 생성
    final defaultPet = Pet(
      id: petId,
      hunger: 100,
      happiness: 100,
      stamina: 100,
      level: 1,
      exp: 0,
      evolutionStage: 0,
      lastUpdated: currentTime,
    );
    
    // Hive에 저장
    await petRepository.savePet(defaultPet);
    
    return defaultPet;
  }
}
