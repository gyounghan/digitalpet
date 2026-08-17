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
  /// 3. 로컬이 막 만든 펫이고 서버에 키우던 펫이 있으면 서버 펫 채택 (기기 이전)
  /// 4. 그 외에는 타임스탬프 비교하여 최신 데이터 선택
  /// 5. 로컬과 서버 모두 업데이트
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

    // 5. 기기 이전 보호 — 새 폰 첫 실행 시 생성된 빈 펫은 lastUpdated가
    //    서버의 키우던 펫보다 항상 최신이라, 시간 비교만으로는 빈 펫이
    //    서버 펫을 덮어써 버린다. 로컬에 육성 진척이 전혀 없고 서버에
    //    키우던 펫이 있으면 타임스탬프와 무관하게 서버 펫을 채택한다.
    //    의도적 '새로 키우기'는 초기화 시점에 서버에도 즉시 push되므로
    //    (PetNotifier.restart → _syncToServer) 이 규칙과 충돌하지 않는다.
    if (!hasDurableProgress(currentLocal) && hasDurableProgress(remotePet)) {
      await localRepository.updatePet(remotePet);
      return remotePet;
    }

    // 6. 최신 데이터 선택 (타임스탬프 비교 — 동률이면 로컬 우선)
    final latestPet = currentLocal.lastUpdated >= remotePet.lastUpdated
        ? currentLocal
        : remotePet;

    // 7. 로컬과 서버 모두 최신 데이터로 업데이트
    await localRepository.updatePet(latestPet);
    await remoteRepository!.savePet(latestPet);

    return latestPet;
  }

  /// 육성 진척 여부 — 시간이 흘러도 줄지 않는 지표만 본다.
  ///
  /// 걸음 수(totalSteps)·exp는 첫날 헬스 자동 동기화만으로 생길 수 있어
  /// 제외한다 — 새 폰에서 하루 걷고 나서 로그인해도 기기 이전이 동작해야
  /// 하기 때문. 레벨은 exp가 충분히 쌓여야 오르므로 durable로 취급한다.
  static bool hasDurableProgress(Pet pet) =>
      pet.evolutionStage > 1 ||
      pet.level > 1 ||
      pet.feedAchievedCount > 0 ||
      pet.sleepAchievedCount > 0 ||
      pet.exerciseAchievedCount > 0 ||
      pet.totalSetsRewarded > 0 ||
      pet.battleVictoryCount > 0 ||
      pet.resurrectCount > 0;
}
