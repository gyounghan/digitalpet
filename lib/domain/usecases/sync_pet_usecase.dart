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
    
    // 3. 서버 Pet 조회 (HTTP 타임아웃 최대 5초 소요 가능)
    final remotePet = await remoteRepository!.getPet(petId);

    // 4. 원격 조회가 걸린 시간 동안 로컬이 변했을 수 있다(급식 등) —
    //    낡은 스냅샷으로 비교·저장하면 그 사이 기록이 되돌아가므로 재조회
    final currentLocal = await localRepository.getPet(petId);

    if (remotePet == null) {
      // 서버에 없으면 로컬 데이터를 서버에 업로드
      await remoteRepository!.savePet(currentLocal);
      return currentLocal;
    }

    // 5. 최신 데이터 선택 (타임스탬프 비교 — 동률이면 로컬 우선)
    final latestPet = currentLocal.lastUpdated >= remotePet.lastUpdated
        ? currentLocal
        : remotePet;
    
    // 6. 로컬과 서버 모두 최신 데이터로 업데이트
    await localRepository.updatePet(latestPet);
    await remoteRepository!.savePet(latestPet);
    
    return latestPet;
  }
}
