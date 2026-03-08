import 'package:hive_flutter/hive_flutter.dart';
import '../../domain/entities/battle_history.dart';
import '../models/battle_history_model.dart';
import '../models/battle_history_model_adapter.dart';

/// 대결 전적 로컬 데이터소스
/// Hive를 사용한 로컬 저장소 접근
class BattleHistoryDataSource {
  static const String _boxName = 'battle_history';
  Box<BattleHistoryModel>? _box;
  
  /// Hive Box 초기화
  Future<void> init() async {
    if (!Hive.isAdapterRegistered(1)) {
      Hive.registerAdapter(BattleHistoryModelAdapter());
    }
    _box = await Hive.openBox<BattleHistoryModel>(_boxName);
  }
  
  /// 대결 전적 저장
  Future<void> saveBattleHistory(BattleHistory history) async {
    if (_box == null) await init();
    final model = BattleHistoryModel.fromEntity(history);
    await _box!.put(history.id, model);
  }
  
  /// 모든 대결 전적 조회 (최신순)
  Future<List<BattleHistory>> getAllBattleHistory() async {
    if (_box == null) await init();
    final models = _box!.values.toList();
    // 날짜 기준 내림차순 정렬 (최신순)
    models.sort((a, b) => b.date.compareTo(a.date));
    return models.map((model) => model.toEntity()).toList();
  }
  
  /// 최근 N개 대결 전적 조회
  Future<List<BattleHistory>> getRecentBattleHistory(int limit) async {
    final allHistory = await getAllBattleHistory();
    return allHistory.take(limit).toList();
  }
  
  /// 승리 횟수 조회
  Future<int> getVictoryCount() async {
    if (_box == null) await init();
    return _box!.values.where((model) => model.isVictory).length;
  }
  
  /// 패배 횟수 조회
  Future<int> getDefeatCount() async {
    if (_box == null) await init();
    return _box!.values.where((model) => !model.isVictory).length;
  }
  
  /// 총 대결 횟수 조회
  Future<int> getTotalBattleCount() async {
    if (_box == null) await init();
    return _box!.values.length;
  }
}
