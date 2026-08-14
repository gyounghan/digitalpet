/// 서버 설정 — 환경변수 단일 소스
///
/// JWT_SECRET은 프로덕션에서 반드시 환경변수로 주입할 것.
/// (기본값은 로컬 개발 편의용 — 노출되어도 로컬 데이터만 위험)

export const config = {
  port: Number(process.env.PORT ?? 3000),
  jwtSecret: process.env.JWT_SECRET ?? 'pocketfriend-dev-secret',
  /// JWT 만료 (기기 보관용이라 길게 — 90일)
  jwtExpiresIn: '90d',
  dataFile: process.env.DATA_FILE ?? 'data/db.json',
};
