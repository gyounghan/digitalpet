import '../entities/pet.dart';
import '../repositories/pet_repository.dart';
import '../repositories/pet_remote_repository.dart';

/// 펫 동기화 유스케이스
/// 로컬과 서버 간의 펫 데이터를 동기화하는 비즈니스 로직
/// 
/// 주의: 현재는 기본 구조만 정의하며, 실제 구현은 선택 사항
/// 서버 동기화가 필요할 때 구현
class SyncPetUseCase {
  final PetRepository localRepository;
  final PetRemoteRepository? remoteRepository;
  
  SyncPetUseCase({
    required this.localRepository,
    this.remoteRepository,
  });
  
  /// 펫 데이터 동기화
  /// 
  /// [petId] 동기화할 반려동물 ID
  /// 
  /// 반환: 동기화된 Pet 엔티티
  /// 
  /// 동작:
  /// 1. 로컬 Pet 조회
  /// 2. 서버 Pet 조회 (remoteRepository가 있는 경우)
  /// 3. 타임스탬프 비교하여 최신 데이터 선택
  /// 4. 로컬과 서버 모두 업데이트
  Future<Pet> call(String petId) async {
    // 1. 로컬 Pet 조회
    final localPet = await localRepository.getPet(petId);
    
    // 2. 서버 동기화가 없으면 로컬 데이터만 반환
    if (remoteRepository == null) {
      return localPet;
    }
    
    // 3. 서버 Pet 조회
    final remotePet = await remoteRepository!.getPet(petId);
    
    // 4. 타임스탬프 비교하여 최신 데이터 선택
    if (remotePet == null) {
      // 서버에 없으면 로컬 데이터를 서버에 업로드
      await remoteRepository!.savePet(localPet);
      return localPet;
    }
    
    // 5. 최신 데이터 선택 (타임스탬프 비교)
    final latestPet = localPet.lastUpdated > remotePet.lastUpdated
        ? localPet
        : remotePet;
    
    // 6. 로컬과 서버 모두 최신 데이터로 업데이트
    await localRepository.updatePet(latestPet);
    await remoteRepository!.savePet(latestPet);
    
    return latestPet;
  }
}
