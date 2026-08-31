import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../domain/entities/wild_encounter.dart';

/// 야생 조우 저장소 (SharedPreferences)
///
/// 조우는 기기 로컬의 1회성 이벤트라 펫 데이터(Hive)와 분리해 보관한다.
/// 백그라운드 isolate에서도 동일하게 접근 가능.
class WildEncounterDatasource {
  static const String _keyPending = 'wild_encounter_pending';
  static const String _keyLastRollDate = 'wild_encounter_last_roll_date';

  /// 대기 중인 조우 조회 — 날짜가 지난 조우는 자동 정리 후 null
  Future<WildEncounter?> getPending({DateTime? now}) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_keyPending);
    if (raw == null) return null;
    try {
      final encounter =
          WildEncounter.fromJson(jsonDecode(raw) as Map<String, dynamic>);
      final clock = now ?? DateTime.now();
      final today = '${clock.year}-${clock.month.toString().padLeft(2, '0')}-'
          '${clock.day.toString().padLeft(2, '0')}';
      if (encounter.dateString != today) {
        await prefs.remove(_keyPending);
        return null; // 어제의 야생 펫은 떠났다
      }
      return encounter;
    } catch (_) {
      await prefs.remove(_keyPending);
      return null;
    }
  }

  Future<void> savePending(WildEncounter encounter) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyPending, jsonEncode(encounter.toJson()));
  }

  /// 조우 소비 (배틀 완료/도망)
  Future<void> clearPending() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyPending);
  }

  /// 오늘 이미 굴렸는지 (등장 여부와 무관하게 하루 1회)
  Future<String?> getLastRollDate() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyLastRollDate);
  }

  Future<void> setLastRollDate(String dateString) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyLastRollDate, dateString);
  }
}
