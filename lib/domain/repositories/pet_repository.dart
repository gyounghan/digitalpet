import '../entities/pet.dart';

/// 반려동물 저장소 인터페이스
/// Domain 레이어에서 정의하며, Data 레이어에서 구현
/// 
/// Pet 데이터의 CRUD 작업을 추상화
abstract class PetRepository {
  /// Pet 존재 여부 확인
  /// 
  /// [id] 확인할 반려동물 ID
  /// 
  /// 반환: Pet가 존재하면 true, 없으면 false
  Future<bool> hasPet(String id);
  
  /// ID로 반려동물 조회
  /// 
  /// [id] 반려동물 고유 ID
  /// 
  /// 반환: Pet 엔티티
  /// 예외: Pet를 찾을 수 없으면 예외 발생
  Future<Pet> getPet(String id);
  
  /// 반려동물 저장
  /// 
  /// [pet] 저장할 Pet 엔티티
  Future<void> savePet(Pet pet);
  
  /// 반려동물 업데이트
  /// 
  /// [pet] 업데이트할 Pet 엔티티
  Future<void> updatePet(Pet pet);
  
  /// 모든 반려동물 조회
  /// 
  /// 반환: Pet 엔티티 리스트
  Future<List<Pet>> getAllPets();
}
