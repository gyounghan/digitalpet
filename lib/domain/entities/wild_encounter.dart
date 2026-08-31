import 'evolution_type.dart';

/// 야생 조우 — 산책하다 우연히 만난 야생 펫 (다마고치식 랜덤 인카운터)
///
/// 하루 걸음이 임계를 넘으면 확률적으로 등장한다("걷다가 만난다").
/// 당일에만 유효하며, 싸우거나 도망가면(또는 자정이 지나면) 사라진다.
class WildEncounter {
  /// 상대 종 이름 (EvolutionType.name, null이면 털뭉치 — 내 펫이 종 미결정일 때)
  final String? speciesName;

  final int level;

  /// 등장 시각 (밀리초)
  final int spawnedAtMs;

  /// 등장 날짜 (yyyy-MM-dd) — 당일 유효성 판정
  final String dateString;

  const WildEncounter({
    required this.speciesName,
    required this.level,
    required this.spawnedAtMs,
    required this.dateString,
  });

  EvolutionType? get species {
    if (speciesName == null) return null;
    for (final t in EvolutionType.values) {
      if (t.name == speciesName) return t;
    }
    return null;
  }

  Map<String, dynamic> toJson() => {
        'speciesName': speciesName,
        'level': level,
        'spawnedAtMs': spawnedAtMs,
        'dateString': dateString,
      };

  factory WildEncounter.fromJson(Map<String, dynamic> json) => WildEncounter(
        speciesName: json['speciesName'] as String?,
        level: json['level'] as int? ?? 1,
        spawnedAtMs: json['spawnedAtMs'] as int? ?? 0,
        dateString: json['dateString'] as String? ?? '',
      );
}
