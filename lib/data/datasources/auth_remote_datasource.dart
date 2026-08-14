import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../../core/constants/server_config.dart';

/// 로그인된 계정 정보 (서버 /auth 응답)
class AuthUser {
  final String id;
  final String provider; // 'email' | 'kakao' | 'naver'
  final String? email;
  final String nickname;

  const AuthUser({
    required this.id,
    required this.provider,
    required this.email,
    required this.nickname,
  });

  factory AuthUser.fromJson(Map<String, dynamic> json) => AuthUser(
        id: json['id'] as String? ?? '',
        provider: json['provider'] as String? ?? 'email',
        email: json['email'] as String?,
        nickname: json['nickname'] as String? ?? '',
      );
}

/// 인증 결과 — 성공 시 token/user, 실패 시 서버의 한국어 error 메시지
class AuthResult {
  final String? token;
  final AuthUser? user;
  final String? error;

  const AuthResult({this.token, this.user, this.error});

  bool get isSuccess => token != null && user != null;
}

/// 계정 서버 REST 클라이언트 (server/src/auth.js 계약)
///
/// - POST /auth/register {email, password, nickname}
/// - POST /auth/login    {email, password}
/// - POST /auth/kakao    {accessToken}   — 카카오 SDK 토큰을 서버가 검증
/// - POST /auth/naver    {accessToken}
/// - GET  /auth/me       (Bearer)
class AuthRemoteDatasource {
  final String baseUrl;
  final http.Client _client;

  AuthRemoteDatasource({String? baseUrl, http.Client? client})
      : baseUrl = baseUrl ?? ServerConfig.baseUrl,
        _client = client ?? http.Client();

  Future<AuthResult> _post(String path, Map<String, dynamic> body) async {
    try {
      final response = await _client
          .post(
            Uri.parse('$baseUrl$path'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 5));
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode == 200 && data['token'] != null) {
        return AuthResult(
          token: data['token'] as String,
          user: AuthUser.fromJson(data['user'] as Map<String, dynamic>),
        );
      }
      return AuthResult(
          error: data['error'] as String? ?? '요청에 실패했어요 (${response.statusCode})');
    } catch (e) {
      if (kDebugMode) debugPrint('AuthRemoteDatasource$path failed: $e');
      return const AuthResult(error: '서버에 연결할 수 없어요. 잠시 후 다시 시도해주세요.');
    }
  }

  Future<AuthResult> register({
    required String email,
    required String password,
    String? nickname,
  }) =>
      _post('/auth/register',
          {'email': email, 'password': password, 'nickname': nickname});

  Future<AuthResult> login({
    required String email,
    required String password,
  }) =>
      _post('/auth/login', {'email': email, 'password': password});

  /// 카카오 SDK로 얻은 access token으로 로그인 (서버가 kapi로 검증)
  Future<AuthResult> loginWithKakao(String accessToken) =>
      _post('/auth/kakao', {'accessToken': accessToken});

  /// 네이버 SDK로 얻은 access token으로 로그인
  Future<AuthResult> loginWithNaver(String accessToken) =>
      _post('/auth/naver', {'accessToken': accessToken});

  /// 저장된 토큰이 아직 유효한지 확인 + 계정 정보 조회
  Future<AuthUser?> me(String token) async {
    try {
      final response = await _client.get(
        Uri.parse('$baseUrl/auth/me'),
        headers: {'Authorization': 'Bearer $token'},
      ).timeout(const Duration(seconds: 5));
      if (response.statusCode != 200) return null;
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return AuthUser.fromJson(data['user'] as Map<String, dynamic>);
    } catch (e) {
      if (kDebugMode) debugPrint('AuthRemoteDatasource.me failed: $e');
      return null;
    }
  }
}
