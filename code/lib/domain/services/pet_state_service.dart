import '../entities/pet.dart';
import '../usecases/update_pet_state_usecase.dart';

/// 반려동물 상태 서비스
/// 시간 경과에 따라 펫 상태를 업데이트하는 서비스 클래스
/// 
/// 앱 실행 시 호출하여 펫의 상태를 시간 경과에 맞게 업데이트
/// 
/// 사용 예시:
/// ```dart
/// final service = PetStateService(updatePetStateUseCase);
/// final updatedPet = await service.updatePetState('pet-id');
/// ```
class PetStateService {
  final UpdatePetStateUseCase updatePetStateUseCase;
  
  PetStateService(this.updatePetStateUseCase);
  
  /// 반려동물 상태 업데이트
  /// 
  /// 앱 실행 시 호출하여 시간 경과에 따라 펫 상태를 업데이트
  /// 
  /// [petId] 업데이트할 반려동물 ID
  /// 
  /// 반환: 업데이트된 Pet 엔티티
  /// 
  /// 동작:
  /// 1. 현재 시간과 lastUpdated 비교하여 경과 시간 계산
  /// 2. 경과 시간에 따라 hunger, happiness 감소
  /// 3. 값이 0 이하로 내려가지 않도록 처리
  /// 4. 업데이트된 Pet을 Hive에 저장
  Future<Pet> updatePetState(String petId) async {
    return await updatePetStateUseCase(petId);
  }
}
