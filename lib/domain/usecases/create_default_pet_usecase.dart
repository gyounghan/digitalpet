import '../entities/pet.dart';
import '../repositories/pet_repository.dart';

/// 기본 반려동물 생성 유스케이스
/// Pet 데이터가 없을 때 기본값으로 초기화하는 비즈니스 로직
/// 
/// 기본값:
/// - hunger: 100
/// - happiness: 100
/// - stamina: 100
/// - level: 1
/// - exp: 0
/// - evolutionStage: 0
/// - lastUpdated: 현재 시간
class CreateDefaultPetUseCase {
  final PetRepository petRepository;
  
  CreateDefaultPetUseCase(this.petRepository);
  
  /// 기본 반려동물 생성
  /// 
  /// [petId] 생성할 반려동물 ID
  /// 
  /// 반환: 생성된 Pet 엔티티
  /// 
  /// 동작:
  /// 1. 기본값으로 Pet 생성
  /// 2. Hive에 저장
  /// 3. 생성된 Pet 반환
  Future<Pet> call(String petId) async {
    final currentTime = DateTime.now().millisecondsSinceEpoch;
    
    // 기본값으로 Pet 생성
    // evolutionStage: 1 (1단계 털뭉치 상태)
    final today = DateTime.now();
    final todayDate = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
    
    final defaultPet = Pet(
      id: petId,
      name: '펫', // 기본 이름
      hunger: 100,
      happiness: 100,
      stamina: 100,
      level: 1,
      exp: 0,
      evolutionStage: 1, // 1단계 털뭉치
      lastUpdated: currentTime,
      lastStatusDecayUpdated: currentTime,
      totalSteps: 0,
      totalExerciseMinutes: 0,
      todaySyncedSteps: 0,
      todaySyncedExerciseMinutes: 0,
      totalIdleHours: 0,
      evolutionType: null, // 아직 결정되지 않음
      todayFeedCount: 0,
      todayFedMealSlots: 0,
      todaySleepHours: 0,
      todayAlternativeFeedCount: 0,
      todayAlternativeSleepCount: 0,
      todayAlternativeExerciseCount: 0,
      lastGoalResetDate: todayDate,
      isDead: false,
      resurrectCount: 0,
      goalStartDate: todayDate,
      goalStreakCount: 0,
      goalStartTotalSteps: 0,
      goalStartTotalExerciseMinutes: 0,
      battleVictoryCount: 0,
      todayEvent: '',
      lastEventDate: '',
      consecutiveLoginDays: 0,
      lastLoginDate: todayDate,
      todayBattleCount: 0,
      todayLoginCount: 0,
      lastLoginTime: 0,
    );
    
    // Hive에 저장
    await petRepository.savePet(defaultPet);
    
    return defaultPet;
  }
}
