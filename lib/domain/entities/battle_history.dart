/// 대결 전적 엔티티
/// 대결 결과를 기록하는 순수 Dart 클래스
class BattleHistory {
  /// 전적 고유 ID
  final String id;
  
  /// 대결 날짜 (타임스탬프)
  final int date;
  
  /// 승리 여부
  final bool isVictory;
  
  /// 획득한 경험치
  final int expGained;
  
  /// 오늘의 걸음 수
  final int steps;
  
  /// 오늘의 운동 시간 (분)
  final int exerciseMinutes;
  
  BattleHistory({
    required this.id,
    required this.date,
    required this.isVictory,
    required this.expGained,
    required this.steps,
    required this.exerciseMinutes,
  });
  
  /// 날짜 문자열 반환 (YYYY-MM-DD)
  String get dateString {
    final dateTime = DateTime.fromMillisecondsSinceEpoch(date);
    return '${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')}';
  }
  
  /// 시간 문자열 반환 (HH:MM)
  String get timeString {
    final dateTime = DateTime.fromMillisecondsSinceEpoch(date);
    return '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
}
