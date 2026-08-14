import 'package:shared_preferences/shared_preferences.dart';

/// 로그인 세션 홀더 — JWT 토큰의 단일 소스
///
/// 원격 데이터소스들이 매 호출마다 SharedPreferences를 읽지 않도록
/// 메모리에 올려두고, 로그인/로그아웃 시 영속화까지 함께 처리한다.
/// 앱 시작 시 [load]를 한 번 호출할 것 (main.dart).
class AuthSession {
  AuthSession._();

  static const String _keyToken = 'auth_token';
  static const String _keyNickname = 'auth_nickname';
  static const String _keyEmail = 'auth_email';

  static String? token;
  static String? nickname;
  static String? email;

  static bool get isLoggedIn => token != null;

  /// HTTP 헤더 (로그인 상태면 Authorization 포함)
  static Map<String, String> headers({bool json = true}) => {
        if (json) 'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      };

  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    token = prefs.getString(_keyToken);
    nickname = prefs.getString(_keyNickname);
    email = prefs.getString(_keyEmail);
  }

  static Future<void> save({
    required String newToken,
    required String newNickname,
    String? newEmail,
  }) async {
    token = newToken;
    nickname = newNickname;
    email = newEmail;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyToken, newToken);
    await prefs.setString(_keyNickname, newNickname);
    if (newEmail != null) {
      await prefs.setString(_keyEmail, newEmail);
    } else {
      await prefs.remove(_keyEmail);
    }
  }

  static Future<void> clear() async {
    token = null;
    nickname = null;
    email = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyToken);
    await prefs.remove(_keyNickname);
    await prefs.remove(_keyEmail);
  }
}
