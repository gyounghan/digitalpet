/// 서버 접속 설정 — 단일 소스
///
/// 빌드/실행 시 `--dart-define=SERVER_URL=https://api.example.com` 으로
/// 환경별 서버를 주입한다 (PM_REVIEW.md 참조).
/// 기본값은 Android 에뮬레이터에서 로컬 NestJS 개발 서버(localhost:3000)를
/// 가리키는 10.0.2.2 — 실기기/프로덕션 배포 시 반드시 dart-define으로 교체.
class ServerConfig {
  ServerConfig._();

  static const String baseUrl = String.fromEnvironment(
    'SERVER_URL',
    defaultValue: 'http://10.0.2.2:3000',
  );
}
