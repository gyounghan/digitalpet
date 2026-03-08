import '../entities/battle_history.dart';

/// 대결 전적 저장소 인터페이스
/// Domain 레이어에서 정의하며, Data 레이어에서 구현
abstract class BattleHistoryRepository {
  /// 대결 전적 저장
  /// 
  /// [history] 저장할 BattleHistory 엔티티
  Future<void> saveBattleHistory(BattleHistory history);
  
  /// 모든 대결 전적 조회
  /// 
  /// 반환: BattleHistory 엔티티 리스트 (최신순)
  Future<List<BattleHistory>> getAllBattleHistory();
  
  /// 최근 N개 대결 전적 조회
  /// 
  /// [limit] 조회할 개수
  /// 
  /// 반환: BattleHistory 엔티티 리스트 (최신순)
  Future<List<BattleHistory>> getRecentBattleHistory(int limit);
  
  /// 승리 횟수 조회
  /// 
  /// 반환: 승리한 대결 횟수
  Future<int> getVictoryCount();
  
  /// 패배 횟수 조회
  /// 
  /// 반환: 패배한 대결 횟수
  Future<int> getDefeatCount();
  
  /// 총 대결 횟수 조회
  /// 
  /// 반환: 전체 대결 횟수
  Future<int> getTotalBattleCount();
}
