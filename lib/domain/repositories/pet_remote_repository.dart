import '../entities/pet.dart';

/// 펫 원격 저장소 인터페이스
/// 서버와의 동기화를 위한 인터페이스
/// 
/// 주의: 현재는 인터페이스만 정의하며, 실제 구현은 선택 사항
/// 서버 동기화가 필요할 때 구현
abstract class PetRemoteRepository {
  /// 서버에서 펫 데이터 조회
  /// 
  /// [petId] 조회할 반려동물 ID
  /// 
  /// 반환: Pet 엔티티 (없으면 null)
  Future<Pet?> getPet(String petId);
  
  /// 서버에 펫 데이터 저장
  /// 
  /// [pet] 저장할 Pet 엔티티
  Future<void> savePet(Pet pet);
  
  /// 서버와 로컬 데이터 동기화
  /// 
  /// [petId] 동기화할 반려동물 ID
  /// 
  /// 반환: 동기화된 Pet 엔티티
  Future<Pet> syncPet(String petId);
}
