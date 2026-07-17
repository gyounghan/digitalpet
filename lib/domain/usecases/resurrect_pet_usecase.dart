import '../entities/pet.dart';
import '../repositories/pet_repository.dart';

/// 펫 깨우기 유스케이스
/// 긴 잠(isDead)에 빠진 펫을 깨움
///
/// - 무료 깨우기: 수치 30/30/30으로 낮게 재시작
/// - [fullRecovery] = true (광고 시청 후): 100/100/100 완전 회복
/// - 레벨 패널티 없음, resurrectCount(깨어난 횟수) +1
class ResurrectPetUseCase {
  final PetRepository petRepository;

  ResurrectPetUseCase(this.petRepository);

  /// 펫을 긴 잠에서 깨움
  ///
  /// [petId] 깨울 반려동물 ID
  /// [fullRecovery] 광고 시청 보상 여부 (true면 완전 회복)
  ///
  /// 반환: 깨어난 Pet 엔티티
  /// 예외: 펫이 잠들어 있지 않으면 예외 발생
  Future<Pet> call(String petId, {bool fullRecovery = false}) async {
    final pet = await petRepository.getPet(petId);

    if (!pet.isDead) {
      throw Exception('잠들어 있지 않은 펫은 깨울 수 없습니다: $petId');
    }

    final awakenedPet = pet.wakeUp(fullRecovery: fullRecovery);
    await petRepository.updatePet(awakenedPet);

    return awakenedPet;
  }
}
