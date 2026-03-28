import '../entities/pet.dart';
import '../repositories/pet_repository.dart';

/// 펫 부활 유스케이스
/// 사망한 펫을 부활시킴 (광고 시청 후 호출)
///
/// 부활 시:
/// - isDead: false
/// - hunger/happiness/stamina: 50/50/50
/// - resurrectCount: +1
/// - deathDate, zeroStatStartDate: null
class ResurrectPetUseCase {
  final PetRepository petRepository;

  ResurrectPetUseCase(this.petRepository);

  /// 펫을 부활시킴
  ///
  /// [petId] 부활시킬 반려동물 ID
  ///
  /// 반환: 부활된 Pet 엔티티
  /// 예외: 펫이 살아있으면 예외 발생
  Future<Pet> call(String petId) async {
    final pet = await petRepository.getPet(petId);

    if (!pet.isDead) {
      throw Exception('살아있는 펫은 부활할 수 없습니다: $petId');
    }

    final resurrectedPet = pet.resurrect();
    await petRepository.updatePet(resurrectedPet);

    return resurrectedPet;
  }
}
