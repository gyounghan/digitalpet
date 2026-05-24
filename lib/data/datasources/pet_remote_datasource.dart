import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// 서버 REST API 클라이언트
///
/// NestJS 서버의 /pet 엔드포인트와 HTTP 통신.
/// 모든 호출에 try-catch + 5초 타임아웃 적용.
/// 서버 unreachable 시 null 반환 (오프라인 내성).
class PetRemoteDatasource {
  /// 서버 기본 URL (battle_socket_datasource.dart와 동일)
  static const String defaultBaseUrl = 'http://10.0.2.2:3000';

  final String baseUrl;
  final http.Client _client;

  PetRemoteDatasource({String? baseUrl, http.Client? client})
      : baseUrl = baseUrl ?? defaultBaseUrl,
        _client = client ?? http.Client();

  /// 펫 데이터 동기화 (upsert)
  /// 서버가 최신이면 서버 데이터 반환, 클라이언트가 최신이면 업데이트 후 반환
  Future<Map<String, dynamic>?> syncPet(
    String deviceId,
    Map<String, dynamic> petData,
  ) async {
    try {
      final body = {...petData, 'deviceId': deviceId};
      final response = await _client
          .post(
            Uri.parse('$baseUrl/pet/sync'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return data['pet'] as Map<String, dynamic>?;
      }
      return null;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('PetRemoteDatasource.syncPet failed: $e');
      }
      return null;
    }
  }

  /// 서버에서 펫 데이터 조회
  Future<Map<String, dynamic>?> getPet(String deviceId) async {
    try {
      final response = await _client
          .get(Uri.parse('$baseUrl/pet/$deviceId'))
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return data['pet'] as Map<String, dynamic>?;
      }
      return null;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('PetRemoteDatasource.getPet failed: $e');
      }
      return null;
    }
  }

  /// 이전 코드 생성
  Future<String?> generateTransferCode(String deviceId) async {
    try {
      final response = await _client
          .post(
            Uri.parse('$baseUrl/pet/transfer-code'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'deviceId': deviceId}),
          )
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return data['transferCode'] as String?;
      }
      return null;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('PetRemoteDatasource.generateTransferCode failed: $e');
      }
      return null;
    }
  }

  /// 디바이스 이전 (코드로 복원)
  Future<Map<String, dynamic>?> transferPet(
    String newDeviceId,
    String transferCode,
  ) async {
    try {
      final response = await _client
          .post(
            Uri.parse('$baseUrl/pet/transfer'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'newDeviceId': newDeviceId,
              'transferCode': transferCode,
            }),
          )
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return data['pet'] as Map<String, dynamic>?;
      }
      return null;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('PetRemoteDatasource.transferPet failed: $e');
      }
      return null;
    }
  }

  /// 전적 저장
  Future<void> saveBattleRecord(
    String deviceId,
    Map<String, dynamic> record,
  ) async {
    try {
      await _client
          .post(
            Uri.parse('$baseUrl/pet/battle-record'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'deviceId': deviceId, 'record': record}),
          )
          .timeout(const Duration(seconds: 5));
    } catch (e) {
      if (kDebugMode) {
        debugPrint('PetRemoteDatasource.saveBattleRecord failed: $e');
      }
    }
  }
}
