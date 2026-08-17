/// 서버 접속 설정 — 단일 소스
///
/// 빌드/실행 시 `--dart-define=SERVER_URL=https://api.example.com` 으로
/// 환경별 서버를 주입한다 (PM_REVIEW.md 참조).
/// 기본값은 Fly.io 프로덕션 서버 — 로컬 개발 서버로 붙으려면
/// `--dart-define=SERVER_URL=http://10.0.2.2:3000` (에뮬레이터) 또는
/// `--dart-define=SERVER_URL=http://PC아이피:3000` (실기기)로 교체.
class ServerConfig {
  ServerConfig._();

  static const String baseUrl = String.fromEnvironment(
    'SERVER_URL',
    defaultValue: 'https://godsaengmon-server.fly.dev',
  );
}
