# PocketFriend 서버

펫 클라우드 저장/기기 이전, 계정(이메일·카카오·네이버), 실시간 배틀, 랭킹.
외부 DB 없이 JSON 파일로 영속화하므로 어느 PC에서든 아래 두 줄로 구동된다.

```bash
cd server
npm install
npm start          # http://localhost:3000
```

- 개발 중 자동 재시작: `npm run dev`
- 테스트: `npm test`
- 환경변수: `PORT`(기본 3000), `JWT_SECRET`(**프로덕션 필수**), `DATA_FILE`(기본 data/db.json)

앱 연결: 에뮬레이터는 기본값(`10.0.2.2:3000`)으로 바로 연결된다.
실기기는 같은 Wi-Fi에서 PC IP로 지정:

```bash
flutter run --dart-define=SERVER_URL=http://192.168.x.x:3000
```

## 구성

| 파일 | 역할 |
|---|---|
| `src/index.js` | Express + Socket.IO 부트스트랩 |
| `src/store.js` | JSON 파일 저장소 (유저/펫/랭킹/이전코드/전적) |
| `src/auth.js` | 이메일 가입·로그인(bcrypt+JWT), 카카오/네이버 토큰 검증 |
| `src/pet_routes.js` | 펫 동기화/조회/이전 코드/전적 (클라이언트 계약 준수) |
| `src/ranking.js` | RP 랭킹 (승 +25 · 압승 +35 · 패 +5) |
| `src/battle_gateway.js` | `/battle` 소켓 — 랜덤 매칭 + 친구 대전 방 |
| `src/battle_sim.js` | PvP 시뮬 — 클라이언트 배틀 규칙과 동일 |

프로토콜 명세: [docs/battle_server_protocol.md](../docs/battle_server_protocol.md)

## 계정과 저장 키

- 로그인 없이도 모든 기능 동작 (기기 ID 기반 게스트).
- 로그인하면 기기가 계정에 연결되고 게스트 데이터(펫·랭킹·전적)가 계정으로 이관된다.
- **기기 변경**: 새 기기에서 로그인만 하면 서버 펫을 그대로 이어받는다.
  계정 없이도 `이전 코드`(24시간 유효, 6자리)로 이전 가능.

## 카카오/네이버 로그인 활성화 절차

서버는 이미 준비돼 있다 — 앱이 SDK로 access token을 얻어
`POST /auth/kakao` / `POST /auth/naver`에 전달하면 서버가 프로바이더 API로
검증해 자체 JWT를 발급한다 (서버에는 앱 키가 필요 없다).

앱 쪽에 필요한 작업:

1. **카카오**: [developers.kakao.com](https://developers.kakao.com) 앱 등록 →
   네이티브 앱 키 발급 → `kakao_flutter_sdk_user` 패키지 추가 →
   AndroidManifest에 키 스킴 등록 → 로그인 성공 시
   `AuthRemoteDatasource.loginWithKakao(token.accessToken)` 호출.
2. **네이버**: [developers.naver.com](https://developers.naver.com) 앱 등록 →
   클라이언트 ID/시크릿 발급 → `flutter_naver_login` 패키지 추가 →
   `AuthRemoteDatasource.loginWithNaver(accessToken)` 호출.
3. 도감 화면 계정 카드의 "준비 중" 문구를 버튼으로 교체.

## API 요약

```
GET  /health
POST /auth/register        { email, password, nickname? }      → { token, user }
POST /auth/login           { email, password }                 → { token, user }
POST /auth/kakao           { accessToken }                     → { token, user }
POST /auth/naver           { accessToken }                     → { token, user }
GET  /auth/me              (Bearer)                            → { user }
POST /pet/sync             { deviceId, ...pet } (Bearer 선택)  → { pet }
GET  /pet/:deviceId                                            → { pet }
POST /pet/transfer-code    { deviceId }                        → { transferCode }
POST /pet/transfer         { newDeviceId, transferCode }       → { pet }
POST /pet/battle-record    { deviceId, record }                → { ok }
GET  /ranking/top                                              → { top3 }
GET  /ranking/me/:deviceId                                     → { top3, surrounding, me, totalCount }
WS   /battle (Socket.IO)   — battle:join/create_room/join_room ...
```
