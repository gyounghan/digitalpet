import 'package:hive/hive.dart';
import '../../domain/entities/battle_history.dart';

/// 대결 전적 데이터 모델
/// Domain의 BattleHistory 엔티티를 확장하여 Hive 저장 및 JSON 직렬화 지원
/// 
/// Hive TypeId: 1
/// Hive Box 이름: 'battle_history'
@HiveType(typeId: 1)
class BattleHistoryModel extends BattleHistory {
  @HiveField(0)
  @override
  final String id;
  
  @HiveField(1)
  @override
  final int date;
  
  @HiveField(2)
  @override
  final bool isVictory;
  
  @HiveField(3)
  @override
  final int expGained;
  
  @HiveField(4)
  @override
  final int steps;
  
  @HiveField(5)
  @override
  final int exerciseMinutes;
  
  BattleHistoryModel({
    required this.id,
    required this.date,
    required this.isVictory,
    required this.expGained,
    required this.steps,
    required this.exerciseMinutes,
  }) : super(
          id: id,
          date: date,
          isVictory: isVictory,
          expGained: expGained,
          steps: steps,
          exerciseMinutes: exerciseMinutes,
        );
  
  /// Domain Entity (BattleHistory)에서 BattleHistoryModel 생성
  factory BattleHistoryModel.fromEntity(BattleHistory history) {
    return BattleHistoryModel(
      id: history.id,
      date: history.date,
      isVictory: history.isVictory,
      expGained: history.expGained,
      steps: history.steps,
      exerciseMinutes: history.exerciseMinutes,
    );
  }
  
  /// BattleHistoryModel을 Domain Entity로 변환
  BattleHistory toEntity() {
    return BattleHistory(
      id: id,
      date: date,
      isVictory: isVictory,
      expGained: expGained,
      steps: steps,
      exerciseMinutes: exerciseMinutes,
    );
  }
}
