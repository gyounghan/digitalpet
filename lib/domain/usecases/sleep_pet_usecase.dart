import '../entities/pet.dart';
import '../repositories/pet_repository.dart';
import '../constants/species_growth_config.dart';

/// 반려동물 재우기 유스케이스
/// Sleep 버튼 클릭 시 stamina를 증가시키는 비즈니스 로직
///
/// 규칙:
/// - stamina +10 (최대 100)
/// - 하루 최대 3회 (Feed의 일일 3회와 대칭 — 무제한 연타로 수면 관리가
///   무의미해지는 것을 방지)
class SleepPetUseCase {
  final PetRepository petRepository;

  /// 1회 stamina 회복량
  static const int staminaRecoveryAmount = 10;

  /// 하루 최대 사용 횟수
  static const int maxSleepsPerDay = 3;

  SleepPetUseCase(this.petRepository);

  /// 반려동물 재우기
  ///
  /// [petId] 재울 반려동물 ID
  ///
  /// 반환: 업데이트된 Pet 엔티티 (일일 제한 도달 시 변경 없이 원래 Pet 반환)
  Future<Pet> call(String petId) async {
    // 1. 현재 Pet 조회
    var pet = await petRepository.getPet(petId);

    // 2. 날짜가 바뀌었으면 일일 카운트 리셋
    if (pet.needsGoalReset) {
      pet = pet.resetDailyGoals();
    }

    // 3. 일일 사용 횟수 제한
    if (pet.todaySleepCount >= maxSleepsPerDay) {
      return pet;
    }

    // 4. stamina +10 (최대 100을 넘지 않도록 처리)
    final m = SpeciesGrowthConfig.getGainMultipliers(pet.evolutionType);
    final newStamina =
        (pet.stamina + (staminaRecoveryAmount * m.stamina).round())
            .clamp(0, 100);

    // 5. 업데이트된 Pet 생성
    final updatedPet = pet.copyWith(
      stamina: newStamina,
      todaySleepCount: pet.todaySleepCount + 1,
      lastUpdated: DateTime.now().millisecondsSinceEpoch,
    );

    // 6. 저장
    await petRepository.updatePet(updatedPet);

    return updatedPet;
  }

  /// 오늘 더 사용할 수 있는지 확인 (UI 비활성화 판단용)
  bool canUse(Pet pet) {
    if (pet.needsGoalReset) return true;
    return pet.todaySleepCount < maxSleepsPerDay;
  }
}
