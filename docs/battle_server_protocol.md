# 배틀 서버 Socket.IO 프로토콜

클라이언트(`lib/data/datasources/battle_socket_datasource.dart`)가 사용하는
소켓 이벤트 명세. **타 PC에서 NestJS 서버 구현 시 이 문서를 기준으로 맞출 것.**

- 네임스페이스: `/battle`
- 전송: websocket 전용
- 서버 주소: 클라이언트는 `ServerConfig.baseUrl`
  (`--dart-define=SERVER_URL=...`, 기본 `http://10.0.2.2:3000`)로 접속

## 공통 페이로드: petPayload

클라이언트가 큐 입장/방 생성/방 참가 시 보내는 펫 정보. `atk/def/hp`는
클라이언트가 계산한 실전 스탯(도감 스탯 × 배틀 스타일 배수)이며 서버는
그대로 사용한다.

```jsonc
{
  "deviceId": "uuid",        // RP(랭킹)·전적 저장 키. null 가능
  "petName": "펫이름",
  "level": 10,
  "evolutionStage": 3,       // 1~4
  "evolutionType": "bird",   // bird|snake|tiger|turtle|null
  "atk": 25,
  "def": 20,
  "hp": 90,
  "stamina": 80                 // 기력 — 회피율 계산용 (아래 배틀 규칙 참조)
}
```

## 클라이언트 → 서버

| 이벤트 | 페이로드 | 설명 |
|---|---|---|
| `battle:join` | petPayload | 랜덤 매칭 큐 입장 |
| `battle:cancel` | — | 매칭 큐 이탈 |
| `battle:create_room` | petPayload | **친구 대전 방 생성** — 초대 코드 발급 요청 |
| `battle:join_room` | `{ roomCode, ...petPayload }` | **초대 코드로 방 참가** |
| `battle:leave_room` | — | 방 대기 취소 (방장이 나가면 방 해체) |

## 서버 → 클라이언트

| 이벤트 | 페이로드 | 설명 |
|---|---|---|
| `battle:queued` | — | 큐 등록 확인 |
| `battle:room_created` | `{ "roomCode": "ABC123" }` | 방 생성 완료 — 코드는 대문자 영숫자 4~6자 권장 |
| `battle:room_error` | `{ "message": "존재하지 않는 코드입니다" }` | 방 없음/가득참/자기 방 참가 등 (한국어 메시지 그대로 노출됨) |
| `battle:matched` | `{ "roomId": "...", "opponent": { "petName", "level", "evolutionType", "maxHp" } }` | 매칭 성사 — **친구 대전도 참가 완료 시 양쪽에 동일하게 전송** (이후 흐름은 랜덤 매칭과 완전히 동일) |
| `battle:turn` | 아래 참조 | 턴 결과 (서버가 시뮬레이션 후 순차 push) |
| `battle:result` | `{ "isVictory": bool, "isDominantVictory": bool, "expGained": int }` | 최종 결과 — expGained는 기본 경험치(감쇠/이벤트 배수는 클라이언트가 적용) |
| `battle:timeout` | — | 매칭 시간 초과 |
| `battle:opponent_disconnected` | — | 상대 이탈 → 클라이언트가 몰수승 보상 로컬 지급 |

### battle:turn 페이로드

각 필드는 **수신자 관점** (player = 그 소켓의 유저):

```jsonc
{
  "turnNumber": 1,
  "playerSkillName": "쪼기",
  "playerDamage": 12,          // 0이면 클라이언트가 "빗나감!" + 회피 모션 표시
  "opponentSkillName": "물기",
  "opponentDamage": 9,
  "playerHpRemaining": 81,
  "opponentHpRemaining": 78
}
```

## 친구 대전 흐름 요약

```
방장                          서버                         친구
battle:create_room  ──────▶
                    ◀────── battle:room_created {roomCode}
        (코드를 친구에게 공유 — 클라이언트 UI에 복사 버튼 있음)
                                          ◀────── battle:join_room {roomCode,...}
                    ◀────── battle:matched ──────▶ battle:matched
                    ◀────── battle:turn × N ─────▶ (관점 반전해 각각 전송)
                    ◀────── battle:result  ─────▶
```

## 서버 구현 시 주의

- 배틀 시뮬레이션 규칙은 `BattleWithActivityUseCase`와 동일해야 체감 일관성이
  유지된다: 데미지 `atk×배수 − def÷2 + rand(5)−2` (최소 1), 상성 유리 +20%
  단방향, **회피 = 기본 5% + 기력/100 × 10% (최대 15%)**
  (회피 시 데미지 0·디버프 미적용 — PvP는 양측 각자의 `stamina` 페이로드로 계산),
  KO까지 진행(안전 상한 30턴 — 도달 시 남은 HP 판정).
- 클라이언트는 연결 후 6초 내 연결 실패 시 자동 취소하므로, 서버 다운 상태를
  별도로 처리할 필요 없음.
- `deviceId`가 null이면 랭킹/전적 갱신은 생략.
