import '../../domain/entities/battle_history.dart';
import '../../domain/repositories/battle_history_repository.dart';
import '../datasources/battle_history_datasource.dart';

/// BattleHistoryRepository 인터페이스 구현
/// Domain의 추상화된 인터페이스를 실제 구현
class BattleHistoryRepositoryImpl implements BattleHistoryRepository {
  final BattleHistoryDataSource dataSource;
  
  BattleHistoryRepositoryImpl(this.dataSource);
  
  @override
  Future<void> saveBattleHistory(BattleHistory history) async {
    await dataSource.saveBattleHistory(history);
  }
  
  @override
  Future<List<BattleHistory>> getAllBattleHistory() async {
    return await dataSource.getAllBattleHistory();
  }
  
  @override
  Future<List<BattleHistory>> getRecentBattleHistory(int limit) async {
    return await dataSource.getRecentBattleHistory(limit);
  }
  
  @override
  Future<int> getVictoryCount() async {
    return await dataSource.getVictoryCount();
  }
  
  @override
  Future<int> getDefeatCount() async {
    return await dataSource.getDefeatCount();
  }
  
  @override
  Future<int> getTotalBattleCount() async {
    return await dataSource.getTotalBattleCount();
  }
}
