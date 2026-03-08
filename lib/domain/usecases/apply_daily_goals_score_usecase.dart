import '../entities/pet.dart';
import '../repositories/pet_repository.dart';
import 'calculate_daily_goals_score_usecase.dart';

/// 일일 목표 점수 적용 유스케이스
/// 일일 목표 달성 점수를 계산하고 경험치를 적용
/// 
/// 동작:
/// 1. 일일 목표 점수 계산
/// 2. 점수에 따른 경험치 획득
/// 3. 레벨 업 계산
/// 4. 업데이트된 Pet 저장
class ApplyDailyGoalsScoreUseCase {
  final PetRepository petRepository;
  final CalculateDailyGoalsScoreUseCase calculateScoreUseCase;
  
  ApplyDailyGoalsScoreUseCase({
    required this.petRepository,
    required this.calculateScoreUseCase,
  });
  
  /// 일일 목표 점수 적용
  /// 
  /// [petId] 적용할 반려동물 ID
  /// 
  /// 반환: 업데이트된 Pet 엔티티
  Future<Pet> call(String petId) async {
    // 1. 현재 Pet 조회
    var pet = await petRepository.getPet(petId);
    
    // 2. 일일 목표 리셋 확인
    if (pet.needsGoalReset) {
      pet = pet.resetDailyGoals();
      await petRepository.updatePet(pet);
    }
    
    // 3. 일일 목표 점수 계산
    final scoreResult = await calculateScoreUseCase(petId);
    
    // 4. 경험치 적용
    final newExp = pet.exp + scoreResult.expGain;
    
    // 5. 레벨 업 계산 (100 경험치당 1 레벨)
    final oldLevel = pet.exp ~/ 100;
    final newLevel = newExp ~/ 100;
    final levelIncrease = newLevel - oldLevel;
    
    // 6. 현재 시간으로 업데이트
    final currentTime = DateTime.now().millisecondsSinceEpoch;
    
    // 7. 업데이트된 Pet 생성
    final updatedPet = pet.copyWith(
      exp: newExp,
      level: pet.level + levelIncrease,
      lastUpdated: currentTime,
    );
    
    // 8. 저장
    await petRepository.updatePet(updatedPet);
    
    return updatedPet;
  }
}
