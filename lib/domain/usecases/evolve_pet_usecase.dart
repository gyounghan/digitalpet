import '../entities/pet.dart';
import '../entities/evolution_type.dart';
import '../repositories/pet_repository.dart';

/// 반려동물 진화 유스케이스
/// 누적 활동 패턴에 따라 Pet의 진화 단계와 방향을 결정하는 비즈니스 로직
/// 
/// 진화 단계:
/// - 1단계: 털뭉치 (evolutionStage = 1, 기본 상태)
/// - 2단계: 활동형/휴식형/균형형 중 하나로 진화 (evolutionStage = 2)
/// - 3단계: 최종 형태 (evolutionStage = 3)
/// 
/// 진화 시점:
/// - 레벨 5 달성 시: 1단계 → 2단계
/// - 레벨 10 달성 시: 2단계 → 3단계
/// 
/// 진화 방향 결정 (2단계 진화 시):
/// - 활동형: totalSteps > 100,000 또는 totalExerciseMinutes > 1,000
/// - 휴식형: totalIdleHours > 200
/// - 균형형: 위 두 조건 모두 미충족 또는 균형잡힌 활동
class EvolvePetUseCase {
  final PetRepository petRepository;
  
  /// 활동형 진화 임계값
  static const int activeEvolutionStepsThreshold = 100000;
  static const int activeEvolutionExerciseMinutesThreshold = 1000;
  
  /// 휴식형 진화 임계값
  static const int restfulEvolutionIdleHoursThreshold = 200;
  
  EvolvePetUseCase(this.petRepository);
  
  /// 반려동물 진화 체크 및 실행
  /// 
  /// [petId] 진화시킬 반려동물 ID
  /// 
  /// 반환: 진화된 Pet 엔티티 (진화 조건 미충족 시 원래 Pet 반환)
  /// 
  /// 동작:
  /// 1. 현재 Pet 조회
  /// 2. 진화 조건 확인 (레벨 기반)
  /// 3. 2단계 진화 시 누적 활동 데이터 기반으로 진화 방향 결정
  /// 4. 조건 만족 시 진화 단계 및 방향 업데이트
  /// 5. 업데이트된 Pet 저장
  Future<Pet> call(String petId) async {
    // 1. 현재 Pet 조회
    final pet = await petRepository.getPet(petId);
    
    // 2. 현재 진화 단계 확인
    int newEvolutionStage = pet.evolutionStage;
    EvolutionType? newEvolutionType = pet.evolutionType;
    
    // 3. 진화 조건 확인
    // 레벨 10 달성 시: 2단계 → 3단계
    if (pet.level >= 10 && newEvolutionStage < 3) {
      newEvolutionStage = 3;
      // 3단계 진화 시에는 진화 방향 유지 (이미 결정됨)
      newEvolutionType ??= EvolutionType.balanced;
    }
    // 레벨 5 달성 시: 1단계 → 2단계
    else if (pet.level >= 5 && newEvolutionStage < 2) {
      newEvolutionStage = 2;
      // 2단계 진화 시 누적 활동 데이터 기반으로 진화 방향 결정
      newEvolutionType = _determineEvolutionType(pet);
    }
    
    // 4. 진화가 발생하지 않았으면 원래 Pet 반환
    if (newEvolutionStage == pet.evolutionStage && newEvolutionType == pet.evolutionType) {
      return pet;
    }
    
    // 5. 현재 시간으로 업데이트
    final currentTime = DateTime.now().millisecondsSinceEpoch;
    
    // 6. 진화된 Pet 생성
    final evolvedPet = pet.copyWith(
      evolutionStage: newEvolutionStage,
      evolutionType: newEvolutionType,
      lastUpdated: currentTime,
    );
    
    // 7. 저장
    await petRepository.updatePet(evolvedPet);
    
    return evolvedPet;
  }
  
  /// 진화 방향 결정
  /// 
  /// [pet] 확인할 Pet 엔티티
  /// 
  /// 반환: 결정된 EvolutionType
  /// 
  /// 우선순위:
  /// 1. 활동형: totalSteps > 100,000 또는 totalExerciseMinutes > 1,000
  /// 2. 휴식형: totalIdleHours > 200
  /// 3. 균형형: 위 두 조건 모두 미충족
  EvolutionType _determineEvolutionType(Pet pet) {
    // 활동형 진화 조건 확인
    final isActive = pet.totalSteps > activeEvolutionStepsThreshold ||
        pet.totalExerciseMinutes > activeEvolutionExerciseMinutesThreshold;
    
    // 휴식형 진화 조건 확인
    final isRestful = pet.totalIdleHours > restfulEvolutionIdleHoursThreshold;
    
    // 진화 방향 결정
    if (isActive) {
      return EvolutionType.active;
    } else if (isRestful) {
      return EvolutionType.restful;
    } else {
      return EvolutionType.balanced;
    }
  }
  
  /// 진화 가능 여부 확인
  /// 
  /// [pet] 확인할 Pet 엔티티
  /// 
  /// 반환: 진화 가능하면 true, 아니면 false
  bool canEvolve(Pet pet) {
    // 레벨 10 달성 시: 2단계 → 3단계
    if (pet.level >= 10 && pet.evolutionStage < 3) {
      return true;
    }
    // 레벨 5 달성 시: 1단계 → 2단계
    if (pet.level >= 5 && pet.evolutionStage < 2) {
      return true;
    }
    return false;
  }
}
