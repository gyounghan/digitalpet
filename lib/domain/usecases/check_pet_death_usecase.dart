import '../entities/pet.dart';
import '../repositories/pet_repository.dart';

/// 펫 사망 조건 체크 유스케이스
/// hunger, happiness, stamina 모두 0인 상태가 3일 이상 지속되면 사망 처리
///
/// 동작:
/// 1. 이미 사망한 펫은 그대로 반환
/// 2. 모든 수치가 0이면 zeroStatStartDate 기록 시작
/// 3. 3일 경과 시 사망 처리
/// 4. 수치가 하나라도 0이 아니면 zeroStatStartDate 초기화
class CheckPetDeathUseCase {
  final PetRepository petRepository;

  /// 사망 판정까지의 일수
  static const int deathThresholdDays = 5;

  CheckPetDeathUseCase(this.petRepository);

  /// 펫의 사망 조건을 체크하고 상태를 업데이트
  ///
  /// [petId] 확인할 반려동물 ID
  ///
  /// 반환: 업데이트된 Pet (사망 처리가 되었을 수 있음)
  Future<Pet> call(String petId) async {
    var pet = await petRepository.getPet(petId);

    if (pet.isDead) return pet;

    if (pet.isAllStatsZero) {
      if (pet.zeroStatStartDate == null) {
        // 처음으로 모든 수치가 0이 됨 - 시작 날짜 기록
        pet = pet.copyWith(zeroStatStartDate: pet.todayDateString);
        await petRepository.updatePet(pet);
      } else if (pet.shouldDie) {
        // 3일 경과 - 사망 처리
        pet = pet.die();
        await petRepository.updatePet(pet);
      }
    } else {
      // 수치가 회복됨 - zeroStatStartDate 초기화
      if (pet.zeroStatStartDate != null) {
        pet = pet.clearZeroStatStartDate();
        await petRepository.updatePet(pet);
      }
    }

    return pet;
  }
}
