import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../../core/constants/server_config.dart';
import '../../domain/entities/evolution_type.dart';

/// 랭킹 엔트리 도메인 모델
/// 서버 응답을 그대로 받지만, evolutionType은 enum으로 변환.
class RankingEntryDto {
  final int rank;
  final String deviceId;
  final String name;
  final int level;
  final int rp;
  final EvolutionType? evolutionType;
  final int evolutionStage;
  final int battleVictoryCount;
  final int battleDefeatCount;
  final bool isMine;

  const RankingEntryDto({
    required this.rank,
    required this.deviceId,
    required this.name,
    required this.level,
    required this.rp,
    required this.evolutionType,
    required this.evolutionStage,
    required this.battleVictoryCount,
    required this.battleDefeatCount,
    this.isMine = false,
  });

  factory RankingEntryDto.fromJson(Map<String, dynamic> json) {
    final typeStr = json['evolutionType'] as String?;
    final evType = typeStr == null
        ? null
        : EvolutionType.values
            .firstWhere((e) => e.name == typeStr, orElse: () => EvolutionType.tiger);
    return RankingEntryDto(
      rank: json['rank'] as int? ?? 0,
      deviceId: json['deviceId'] as String? ?? '',
      name: json['name'] as String? ?? '???',
      level: json['level'] as int? ?? 1,
      rp: json['rp'] as int? ?? 0,
      evolutionType: evType,
      evolutionStage: json['evolutionStage'] as int? ?? 1,
      battleVictoryCount: json['battleVictoryCount'] as int? ?? 0,
      battleDefeatCount: json['battleDefeatCount'] as int? ?? 0,
      isMine: json['isMine'] as bool? ?? false,
    );
  }
}

/// 서버에서 받는 종합 응답
class RankingResponseDto {
  final List<RankingEntryDto> top3;
  final List<RankingEntryDto> surrounding;
  final RankingEntryDto? me;
  final int totalCount;

  const RankingResponseDto({
    required this.top3,
    required this.surrounding,
    required this.me,
    required this.totalCount,
  });

  factory RankingResponseDto.fromJson(Map<String, dynamic> json) {
    return RankingResponseDto(
      top3: (json['top3'] as List<dynamic>? ?? [])
          .map((e) => RankingEntryDto.fromJson(e as Map<String, dynamic>))
          .toList(),
      surrounding: (json['surrounding'] as List<dynamic>? ?? [])
          .map((e) => RankingEntryDto.fromJson(e as Map<String, dynamic>))
          .toList(),
      me: json['me'] == null
          ? null
          : RankingEntryDto.fromJson(json['me'] as Map<String, dynamic>),
      totalCount: json['totalCount'] as int? ?? 0,
    );
  }
}

/// 랭킹 서버 REST API 클라이언트
///
/// NestJS 서버의 /ranking 엔드포인트와 통신.
/// 모든 호출에 5초 타임아웃 + 오프라인 내성 (실패 시 null 반환).
class RankingRemoteDatasource {
  /// 서버 기본 URL — ServerConfig 단일 소스 (--dart-define=SERVER_URL로 교체)
  static const String defaultBaseUrl = ServerConfig.baseUrl;

  final String baseUrl;
  final http.Client _client;

  RankingRemoteDatasource({String? baseUrl, http.Client? client})
      : baseUrl = baseUrl ?? defaultBaseUrl,
        _client = client ?? http.Client();

  /// 전체 TOP3 조회
  Future<List<RankingEntryDto>?> getTop3() async {
    try {
      final response = await _client
          .get(Uri.parse('$baseUrl/ranking/top'))
          .timeout(const Duration(seconds: 5));
      if (response.statusCode != 200) return null;
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final list = data['top3'] as List<dynamic>? ?? [];
      return list
          .map((e) => RankingEntryDto.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('RankingRemoteDatasource.getTop3 failed: $e');
      }
      return null;
    }
  }

  /// 내 주변 5명 + TOP3 조회
  Future<RankingResponseDto?> getAroundMe(String deviceId) async {
    try {
      final response = await _client
          .get(Uri.parse('$baseUrl/ranking/me/$deviceId'))
          .timeout(const Duration(seconds: 5));
      if (response.statusCode != 200) return null;
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return RankingResponseDto.fromJson(data);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('RankingRemoteDatasource.getAroundMe failed: $e');
      }
      return null;
    }
  }
}
