import 'dart:math';
import '../entities/pet.dart';
import '../entities/evolution_type.dart';
import '../repositories/pet_repository.dart';

/// 반려동물 진화 유스케이스 (사신수 진화 트리)
///
/// 진화 단계 (4단계):
/// - 1단계: 털뭉치 (evolutionStage = 1, 기본 상태)
/// - 2단계: 아기 종 (evolutionStage = 2, Lv5 → 활동량×규칙성으로 종 결정)
/// - 3단계: normal / superior (evolutionStage = 3, Lv10 → 종별 추가 조건)
/// - 4단계: mythical (evolutionStage = 4, Lv15 → superior만 승격 가능)
///
/// 진화 종 (EvolutionType):
/// - bird (주작): 활발+자유 패턴
/// - snake (청룡): 차분+자유 패턴
/// - tiger (백호): 활발+규칙 패턴
/// - turtle (현무): 차분+규칙 패턴
///
/// 진화 등급 (evolutionGrade):
/// - '': 미결정 (1단계)
/// - 'normal': 일반 (3단계 기본)
/// - 'superior': 상위 (3단계 우수)
/// - 'mythical': 신수 (4단계, superior에서만 승격)
class EvolvePetUseCase {
  final PetRepository petRepository;

  EvolvePetUseCase(this.petRepository);

  /// 진화 체크 및 실행
  Future<Pet> call(String petId) async {
    final pet = await petRepository.getPet(petId);
    if (pet.isDead) return pet;

    int newStage = pet.evolutionStage;
    EvolutionType? newType = pet.evolutionType;
    String newGrade = pet.evolutionGrade;

    // 4단계: Lv15 + superior만 mythical 가능
    if (pet.level >= 15 && newStage < 4 && newStage >= 3) {
      if (pet.evolutionGrade == 'superior' && _meetsStage4Condition(pet)) {
        newStage = 4;
        newGrade = 'mythical';
      }
    }
    // 3단계: Lv10 + 종별 조건 → normal / superior
    else if (pet.level >= 10 && newStage < 3 && newStage >= 2) {
      final grade = _determineStage3Grade(pet);
      if (grade.isNotEmpty) {
        newStage = 3;
        newGrade = grade;
      }
    }
    // 2단계: Lv5 + 활동 패턴으로 종 결정
    else if (pet.level >= 5 && newStage < 2) {
      newStage = 2;
      newType = _determineEvolutionType(pet);
      newGrade = '';
    }

    if (newStage == pet.evolutionStage &&
        newType == pet.evolutionType &&
        newGrade == pet.evolutionGrade) {
      return pet;
    }

    final currentTime = DateTime.now().millisecondsSinceEpoch;
    final evolvedPet = pet.copyWith(
      evolutionStage: newStage,
      evolutionType: newType,
      evolutionGrade: newGrade,
      lastUpdated: currentTime,
    );

    await petRepository.updatePet(evolvedPet);
    return evolvedPet;
  }

  /// 2단계 진화 종 결정 (활동량 × 규칙성 매트릭스)
  ///
  /// 활동 점수 = min(totalSteps/35000, 2.0) + min(totalExerciseMinutes/100, 1.0)
  /// 규칙 점수 = min(goalStreakCount/3, 1.0) + min(consecutiveLoginDays/7, 1.0)
  ///
  /// 활동>=1.0 && 규칙>=1.0 → tiger (활발+규칙)
  /// 활동>=1.0 && 규칙<1.0  → bird  (활발+자유)
  /// 활동<1.0  && 규칙>=1.0 → turtle (차분+규칙)
  /// 활동<1.0  && 규칙<1.0  → snake  (차분+자유)
  EvolutionType _determineEvolutionType(Pet pet) {
    final activityScore =
        min(pet.totalSteps / 35000.0, 2.0) +
        min(pet.totalExerciseMinutes / 100.0, 1.0);
    final regularityScore =
        min(pet.goalStreakCount / 3.0, 1.0) +
        min(pet.consecutiveLoginDays / 7.0, 1.0);

    final isActive = activityScore >= 1.0;
    final isRegular = regularityScore >= 1.0;

    if (isActive && isRegular) return EvolutionType.tiger;
    if (isActive && !isRegular) return EvolutionType.bird;
    if (!isActive && isRegular) return EvolutionType.turtle;
    return EvolutionType.snake;
  }

  /// 3단계 등급 결정 (종별 조건)
  ///
  /// bird:   battleVictoryCount>=15 AND happiness>=70 → superior, else normal
  /// snake:  goalStreakCount>=5 AND consecutiveLoginDays>=30 → superior, else normal
  /// tiger:  battleVictoryCount>=15 AND (hunger+happiness+stamina)>=180 → superior, else normal
  /// turtle: consecutiveLoginDays>=14 AND totalIdleHours>=100 → superior, else normal
  String _determineStage3Grade(Pet pet) {
    switch (pet.evolutionType) {
      case EvolutionType.bird:
        if (pet.battleVictoryCount >= 15 && pet.happiness >= 70) {
          return 'superior';
        }
        return 'normal';
      case EvolutionType.snake:
        if (pet.goalStreakCount >= 5 && pet.consecutiveLoginDays >= 30) {
          return 'superior';
        }
        return 'normal';
      case EvolutionType.tiger:
        final totalStats = pet.hunger + pet.happiness + pet.stamina;
        if (pet.battleVictoryCount >= 15 && totalStats >= 180) {
          return 'superior';
        }
        return 'normal';
      case EvolutionType.turtle:
        if (pet.consecutiveLoginDays >= 14 && pet.totalIdleHours >= 100) {
          return 'superior';
        }
        return 'normal';
      default:
        return 'normal';
    }
  }

  /// 4단계 mythical 조건 충족 여부 (superior에서만 승격 가능)
  ///
  /// bird(봉황→주작):   totalSteps>=300000 AND battleVictoryCount>=30
  /// snake(이무기→청룡): consecutiveLoginDays>=60 AND goalStreakCount>=15 AND resurrectCount==0
  /// tiger(맹호→백호):   battleVictoryCount>=50 AND (hunger+happiness+stamina)>=210
  /// turtle(영귀→현무):  consecutiveLoginDays>=30 AND totalIdleHours>=300 AND resurrectCount==0
  bool _meetsStage4Condition(Pet pet) {
    switch (pet.evolutionType) {
      case EvolutionType.bird:
        return pet.totalSteps >= 300000 && pet.battleVictoryCount >= 30;
      case EvolutionType.snake:
        return pet.consecutiveLoginDays >= 60 &&
            pet.goalStreakCount >= 15 &&
            pet.resurrectCount == 0;
      case EvolutionType.tiger:
        final totalStats = pet.hunger + pet.happiness + pet.stamina;
        return pet.battleVictoryCount >= 50 && totalStats >= 210;
      case EvolutionType.turtle:
        return pet.consecutiveLoginDays >= 30 &&
            pet.totalIdleHours >= 300 &&
            pet.resurrectCount == 0;
      default:
        return false;
    }
  }

  /// 진화 가능 여부 확인
  bool canEvolve(Pet pet) {
    if (pet.isDead) return false;

    // 4단계 승격 가능?
    if (pet.level >= 15 && pet.evolutionStage < 4 && pet.evolutionStage >= 3) {
      return pet.evolutionGrade == 'superior' && _meetsStage4Condition(pet);
    }
    // 3단계 진화 가능?
    if (pet.level >= 10 && pet.evolutionStage < 3 && pet.evolutionStage >= 2) {
      return true; // 3단계는 항상 normal 이상으로 진화 가능
    }
    // 2단계 종 결정 가능?
    if (pet.level >= 5 && pet.evolutionStage < 2) {
      return true;
    }
    return false;
  }
}
