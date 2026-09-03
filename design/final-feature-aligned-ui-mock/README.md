# Final Feature-Aligned UI Mock

이 폴더는 "기능은 현재 코드 그대로, 디자인만 이전 시안 느낌으로" 적용할 때의 최종 디자인안입니다.

## 현재 코드에서 확인한 기능

기준 파일:

- `lib/presentation/screens/main_navigation_screen.dart`
- `lib/presentation/screens/home_screen.dart`
- `lib/presentation/screens/care_screen.dart`
- `lib/presentation/screens/battle_screen.dart`
- `lib/presentation/screens/me_screen.dart`
- `lib/presentation/providers/active_pet_provider.dart`
- `lib/core/constants/feature_flags.dart`

현재 기본 탭:

- 홈
- 케어
- 배틀
- 도감

기본 숨김:

- 랭킹 탭: `FeatureFlags.enableRanking == false`
- 랜덤 온라인 대전 버튼: `FeatureFlags.enableRealtimeBattle == false`

홈 기능:

- 현재 활성 펫 표시
- 펫 이름 수정
- 레벨 표시
- 오늘 이벤트 배너
- 동기화 권한 배너
- 펫 터치 반응 모션
- 먹이 주기
- 포만감, 기분, 체력 표시
- 오늘 목표: 식사, 걸음, 수면
- 긴 잠 상태일 때 무료 깨우기 / 광고 보고 완전 회복

케어 기능:

- 우선 케어 추천
- 물 마시기
- 간편 급식
- 낮잠 모드 15분
- 집중 모드 25분
- 흔들기 보너스 30초
- 포만감, 행복, 기력 상태
- 미션 목록

배틀 기능:

- 내 펫 전투 카드
- 배틀 스타일 선택: 공격형, 균형형, 방어형
- AI 대전
- 친구방 만들기
- 코드로 참가
- 야생 조우가 있을 때 싸운다 / 도망
- 매칭 중 초대 코드 복사
- 오늘 남은 AI/온라인 대전 횟수 표시
- 자동 턴 진행 아레나
- 결과, EXP, 나가기, 한번 더
- 최근 전적
- 한도 소진 시 광고 보고 한 판 더

도감 기능:

- 현재 펫 대표 프로필
- 친밀도, 성장 단계, 레벨
- 성장 경로
- 전투 스탯
- 누적 기록
- 최대 2마리 펫 슬롯
- 활성 펫 전환
- 빈 슬롯에서 새 펫 시작
- 진화 트리
- 진화 가능 시 진화 버튼
- 이메일 로그인/가입
- 카카오 로그인
- 로그아웃
- 새로 키우기

## 디자인 방향

- 이전 시안의 따뜻한 크림/민트 배경과 검정 프레임 느낌 유지
- 홈은 펫을 가장 크게 보여주고, 액션은 실제 수치 변화가 있는 `먹이 주기`를 중심으로 정리
- `놀기`, `휴식`은 현재 코드에서 모션 반응 성격이므로 핵심 케어 기능처럼 크게 강조하지 않음
- 케어는 "지금 필요한 돌봄" 한 장 + 실제 케어 액션 목록으로 정리
- 배틀은 수동 공격 버튼 없이 스타일 선택과 자동 전투 흐름을 강조
- 도감은 수집 앨범 느낌을 살리되, 현재 코드의 2마리 슬롯과 진화 트리를 기준으로 표현

## 열어볼 파일

- `index.html`: 최종 디자인안 HTML/CSS 코드 목업

브라우저 직접 열기:

`file:///Users/hagyeonghan/digitalpet/design/final-feature-aligned-ui-mock/index.html`
