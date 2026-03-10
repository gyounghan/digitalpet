import '../entities/pet.dart';
import '../repositories/pet_repository.dart';

/// 반려동물 이름 변경 유스케이스
/// 펫의 이름을 변경하는 비즈니스 로직
/// 
/// 규칙:
/// - 이름은 1자 이상 20자 이하
/// - 빈 문자열이면 기본값 '펫'으로 설정
class UpdatePetNameUseCase {
  final PetRepository petRepository;
  
  UpdatePetNameUseCase(this.petRepository);
  
  /// 반려동물 이름 변경
  /// 
  /// [petId] 이름을 변경할 반려동물 ID
  /// [newName] 새로운 이름 (1~20자)
  /// 
  /// 반환: 업데이트된 Pet 엔티티
  /// 
  /// 동작:
  /// 1. 현재 Pet 조회
  /// 2. 이름 유효성 검사 (1~20자)
  /// 3. 빈 문자열이면 기본값 '펫'으로 설정
  /// 4. 업데이트된 Pet 저장
  Future<Pet> call(String petId, String newName) async {
    // 1. 현재 Pet 조회
    final pet = await petRepository.getPet(petId);
    
    // 2. 이름 유효성 검사 및 정규화
    String normalizedName = newName.trim();
    if (normalizedName.isEmpty) {
      normalizedName = '펫';
    }
    
    // 3. 이름 길이 제한 (최대 20자)
    if (normalizedName.length > 20) {
      normalizedName = normalizedName.substring(0, 20);
    }
    
    // 4. 현재 시간으로 업데이트
    final currentTime = DateTime.now().millisecondsSinceEpoch;
    
    // 5. 업데이트된 Pet 생성
    final updatedPet = pet.copyWith(
      name: normalizedName,
      lastUpdated: currentTime,
    );
    
    // 6. 저장
    await petRepository.updatePet(updatedPet);
    
    return updatedPet;
  }
}
