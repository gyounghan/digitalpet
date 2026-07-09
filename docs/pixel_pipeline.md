# 픽셀 도트 파이프라인 가이드

PocketFriend의 펫 렌더링은 이미지 파일을 런타임에 디코딩하지 않는다.
오프라인 파이썬 스크립트가 PNG를 **도트 좌표 데이터(Dart const)**로 구워 두고,
런타임은 `CustomPainter`로 좌표에 사각 도트만 찍는다 (다마고치 LCD 스타일).

이 문서는 다른 세션/모델이 동일한 작업(모션 추가, 성장기 확장, 아트 수정)을
이어서 할 수 있도록 전체 구조와 절차를 기록한 것이다.

---

## 1. 데이터 모델 — 3계조 PixelSprite

`lib/core/pixel/pet_pixel_data.dart` (생성 파일)에 정의:

```dart
class PixelSprite {
  final int size;            // 그리드 한 변 (정적 64, 모션 24·32·36)
  final List<int> dark;      // 아웃라인/눈 — 행(y)별 비트마스크
  final List<int> body;      // 몸통(테마색) — 행별 비트마스크
  final List<int> accent;    // 보조색(배/부리/등딱지) — 행별 비트마스크
}
```

- 비트마스크: `bit x`가 1이면 `(x, y)`에 도트. `(row >> x) & 1`로 판독.
- **주의**: 64그리드는 행 마스크가 64비트 전체를 쓰므로 최상위 비트가 켜진
  행은 Dart에서 음수 리터럴이다. 비트 연산만 쓰므로 무해하지만,
  **웹(dart2js) 빌드에서는 비트 연산이 32비트로 잘려 깨진다** — 모바일 전용.
- 세 레이어는 서로 겹치지 않는다 (테스트로 보장).

색은 런타임에 주입한다:
- `dark` → `darkColor` (기본 `0xFF33383F`)
- `body` → `dotColor` (종별 테마색 `SpeciesTheme.primary`)
- `accent` → `accentColor` (종별 보조색 `SpeciesTheme.spriteAccent`,
  미지정 시 `dotColor`와 동일 → 하위 호환)

종별 보조색 (`lib/core/theme/species_theme.dart`):

| 종 | primary | spriteAccent |
|---|---|---|
| tiger (백호) | 청회색 | `0xFFF0F3F8` 설백 |
| bird (주작) | 주홍 | `0xFFFFC94D` 노랑 |
| turtle (현무) | 초록 | `0xFF9C7A4C` 갈색 |
| snake (청룡, dragon 에셋) | 파랑 | `0xFFF2E3C2` 크림 |

---

## 2. 정적 스프라이트 파이프라인 (146장, 64×64)

**스크립트**: `tool/generate_pixel_data.py` → `lib/core/pixel/pet_pixel_data.dart`

```
python tool/generate_pixel_data.py
```

처리: `assets/*.png` 전부 → 알파 bbox 크롭 → 정사각 패딩(중앙) →
64×64 BOX 다운샘플 → 셀 분류:

| 조건 | 레이어 |
|---|---|
| 평균 알파 ≤ 0.5 | 없음 (빈칸) |
| luminance < 0.45 | dark |
| luminance > 0.78 | accent |
| 그 외 | body |

키는 파일명 stem (`'dragon2'`, `'tiger_smile1'`, `'기본이미지'` 등).
런타임 조회: `pixelSpriteForAsset('assets/dragon2.png')`.

**위젯용 JSON도 동시 출력**: 이 스크립트는 Dart와 함께
`android/app/src/main/assets/pet_pixel_data.json`(행 마스크를 16자리 부호없는
hex 문자열로)을 굽는다. 안드로이드 홈 위젯이 이 JSON을 파싱해 앱과 동일한
도트를 **네이티브에서 직접 렌더**한다 (§4.1). 도트를 수정하면 스크립트
한 번으로 앱·위젯이 함께 갱신되므로 좌표 테이블을 Kotlin에 복제하지 않는다.

---

## 3. 모션 파이프라인 (9스프라이트×9모션×3프레임 — 털뭉치 40 / 유아기 32 / 성장기 36)

**스크립트**: `tool/generate_motion_data.py` → `lib/core/pixel/pet_motion_data.dart`
(출력: `motionFrames` — `Map<String 스프라이트키, Map<String모션, List<PixelSprite>>>`,
키는 `'{종}{스테이지}'` — `'dragon1'`(유아기 32), `'dragon2'`(성장기 36))

핵심 아이디어: 원본 `assets/{종}{1|2}.png` 픽셀아트를 **도트 아트 문자열**로
옮긴 뒤(수작업 정리), 부위별 변형으로 모션을 합성한다. 프레임을 손으로 243장
그리는 게 아니라, 스프라이트당 몸체 아트 1장 + 조립 규칙으로 만든다.

아트 소스는 유아기 24·성장기 28이지만 `TARGET_SIZE`대로 32·36으로
**업스케일**한다(`upscale_art` — 최근접 이웃, 디자인 유지). 눈은 `scale_eye`로
위치만 옮기고 크기는 ~0.7배로 줄이며(커져서 무섭지 않게), 입은 `scale_point`로
스케일. 모든 연산 함수는 `len(g)`에서 크기를 얻고, 이펙트 글리프 좌표는 24
기준값에 `r = 크기 - 24`를 더해 우측/하단 앵커로 보정한다.

### 3.1 아트 문법

```
'.' 빈칸  /  '#' 진한 도트(아웃라인·눈)  /  'o' 몸통(테마색)  /  '+' 보조색
```

`SPECIES_ART[스프라이트키]` 구조:
- `body`: N행×N칸 정사각 문자열 리스트 (다리 포함 원본 실루엣, 왼쪽을 봄)
- `eyes`: 눈 rect 목록 `[(x, y, w, h)]` — tiger는 정면 얼굴이라 2개,
  turtle2(현무)는 거북 눈 + 뱀 머리 눈 2개
- `mouth`: 입 좌표 `(x, y)`

### 3.2 아트를 처음 만드는 절차 (성장기 등 새 스프라이트 추가 시)

1. **원본 확인**: PNG를 직접 열어 보고 특징(볏/귀/등딱지/꼬리) 파악.
2. **덤프**: PIL로 bbox 크롭 → (필요시 비율 크롭으로 물방울/동전/그림자 제외)
   → `(w, h)` BOX 리사이즈 → 알파/휘도 임계로 `.#o` 문자열 출력.
   덤프 코드는 `SPECIES_SRC`의 파라미터와 반드시 일치시킬 것 (아래 3.3).
3. **수작업 정리**: 떠 있는 배경 요소 제거, 바닥 그림자 행 제거/정리,
   바닥 아웃라인 정돈. 각 행은 정확히 그리드 폭 문자 수여야 한다
   (`validate()`가 검사).
4. **눈/입 좌표 지정**: ASCII에서 어두운 눈 덩어리를 찾아 rect로 기록.
   눈 rect는 원본에 박힌 눈 도트를 **전부 덮어야** 표정 교체가 깨끗하다.
5. **미리보기 반복**: `python tool/preview_motion.py <종> <모션> [프레임]`
   으로 확인하며 다듬는다. (`@`=dark, `+`=accent, `.`=body)

### 3.3 보조색 자동 태깅 — `SPECIES_SRC`

아트의 'o'/'#' 셀에 대해 **원본 PNG 색을 재샘플링**해 '+'로 승격한다.
`SPECIES_SRC[스프라이트키] = dict(path, crop or None, size=(w,h), off=(x,y), light or None, darkmid)`

- 크롭비율/리사이즈/오프셋은 **아트를 덤프할 때 쓴 값과 동일해야** 한다
  (셀 ↔ 원본 픽셀이 1:1 대응돼야 하므로).
- `off` = 덤프 (sx, sy)가 아트의 어느 칸에 배치됐는지
  (`아트칸 = 덤프칸 + off` — bird2처럼 세로가 긴 원본은 x 오프셋도 사용).
- 규칙: `'o'` + luminance > light → `'+'` /
  `'#'` + 0.18 ≤ luminance < 0.45 **AND r > g** (붉은 계열) → `'+'`
  (turtle 등딱지용 — r>g 조건이 없으면 어두운 초록 아웃라인까지 갈색이 됨)
- 아트에 직접 쓴 `'+'`는 그대로 유지된다 — 알파 평균이 낮아 자동 태깅이
  놓치는 부분(dragon2 노란 뿔 등)은 손으로 '+'를 박으면 된다.
- 키별 임계가 다르다: dragon 0.75, tiger 0.80(흰 몸), bird 0.68(노랑),
  turtle은 밝음 규칙 없이 갈색 규칙만 (스테이지 1·2 동일).

### 3.4 포즈 엔진

`pose(종, eye, mouth, step, dx, dy, lean)` 이 몸체+표정+다리를 조립:

- **eye**: `open`(채움) / `closed`(아래 가로선) / `happy`(^) /
  `pain`(X자 — 2×2처럼 작은 눈은 최소 3×3로 키워 그림) /
  `angry`(채움+눈썹). rect 영역을 'o'로 지운 뒤 스타일을 그린다.
- **mouth**: `open`이면 입 좌표에 2도트.
- **step**: 하단 3행(bbox 기준)을 좌/우 절반으로 나눠 이동 —
  `front`(앞다리 들어 전진) / `back`(뒷다리) / `both_up`(점프 웅크림).
- **lean**: 상단 절반만 가로 이동 (±1~2) — 숙임/젖힘.
- **dx/dy**: 전체 이동 (그리드 밖 클리핑 — 오른쪽 잘림은 의도적으로 허용).

보조 함수:
- `lying_pose(종, factor)`: 바닥 고정 세로 눌림(역매핑) + 감은 눈 재배치 —
  수면 자세. factor 0.62(들숨)/0.55(날숨)로 호흡 표현.
- `head_bow(g, depth)`: 상단 절반을 앞·아래로 — 밥먹기.
- `lift_art(g, n)`: 위로 이동하되 머리 잘림 방지(상단 빈 행만큼만).
- `draw_breath_puff/ball(g, 종)`: 공격 브레스. **기준점은 입 좌표가 아니라
  입 높이에서 몸의 왼쪽 가장자리**(`_breath_origin`) — tiger처럼 입이 정면
  얼굴 안쪽인 종도 몸 밖으로 분사된다. ball은 그리드 왼쪽 끝(절대 좌표)에
  찍혀 몸에서 분리된 투사체로 보인다.

### 3.5 모션 정의 (9종 — 모두 3프레임)

| 모션 | 구성 |
|---|---|
| walk | front 스텝 → 양발 → back 스텝 |
| eat | 몸 dx+2(그릇 자리) · 밥그릇(김+보조색 밥+진한 그릇) 수북→반→빈, 머리 숙여 냠(눈 감음)→^^ |
| sleep | lying 들숨/날숨 교차 + Z 글리프 누적 |
| attack | dx+4~5 뒤로 물러남(오른쪽 잘림 허용) → 분리된 puff → 왼쪽 끝 파이어볼+궤적 |
| dodge | 움찔 → back 스텝+dx+3+lean+2+속도선 → 복귀 |
| hurt | ><눈+땀(머리 위 상단 0~3행 — 몸과 안 겹침) → 크게 휘청(땀 2방울) → 복귀 |
| angry | 부릅눈+💢 + 발 구르기(front/back 스텝 교차) |
| joy | ^^눈 숙임 → 다리 웅크려 점프+반짝이 → 착지 |
| hungry | 힘없이 처짐(눈 감음)+생각 점 → 머리 위 밥공기 말풍선(FOOD_THOUGHT) 피어오름+침 → 밥 보며 눈 뜨고 군침(반짝). eat은 바닥 밥그릇, hungry는 머리 위 상상 아이콘 |

이펙트 글리프(Z, 반짝이, 💢, 땀, 속도선, 침)는 dark 도트 좌표 목록,
밥그릇·밥 상상 아이콘(FOOD_THOUGHT)·브레스는 `(dx, dy, 문자)` 목록(다색)이다.

### 3.6 재생성·검증

```
python tool/generate_motion_data.py      # 데이터 재생성
python tool/preview_motion.py dragon walk    # ASCII 미리보기 (3프레임)
flutter analyze                          # 항상 0 error/warning 유지
TMP='C:\pf_tmp' TEMP='C:\pf_tmp' flutter test   # 전체 테스트
flutter build apk --debug
```

**중요**: 이 PC에서 `flutter test`는 TEMP 경로에 한글 사용자명이 있으면
전 스위트가 "Connection closed" 로 실패한다. 반드시 위처럼 ASCII 경로로
TMP/TEMP를 지정할 것.

테스트 파일:
- `test/core/pixel/pet_pixel_data_test.dart` — 정적 146장 무결성
  (64그리드, 3레이어 비겹침, 핵심 에셋 키 존재)
- `test/core/pixel/pet_motion_data_test.dart` — 모션 243프레임 무결성
  (size-행수 일치, 털뭉치 40/유아기 32/성장기 36, 3레이어 비겹침, 프레임 간 차이,
  mood 매핑, 에셋 경로→스프라이트 키 추출)

---

## 4. 런타임 위젯 계층

```
lib/presentation/widgets/
├── pixel_pet_image.dart
│   ├── pixelKeyFromAssetPath()   'assets/dragon2.png' → 'dragon2'
│   ├── PixelPetImage             에셋 경로로 정적 도트 렌더 (fallback 지원)
│   ├── PixelSpriteView           PixelSprite 객체 직접 렌더 (모션 프레임용)
│   └── _PixelSpritePainter       3색 Path 일괄 드로잉, gapRatio 0(도트 밀착)
├── pixel_motion_animation.dart
│   ├── PixelMotion enum          walk/eat/sleep/attack/dodge/hurt/angry/joy/hungry
│   ├── motionForMood()           happy→joy, normal→walk, hungry→hungry,
│   │                             sleepy·tired→sleep, sad·dead→hurt
│   ├── motionSpriteKeyFromAssetPath  모션 데이터가 있는 에셋이면
│   │                             '기본이미지'→'fluff', '{종}{1|2}' 키 반환 (stage 1·2·3)
│   └── PixelMotionAnimation      spriteKey 기반 3프레임 루프 (기본 900ms/
│                                 사이클, 인덱스 변경 시에만 setState)
└── pet_image_animation.dart      stage 4(사신수) mood 정적 프레임 렌더
```

### 화면 연결

- **홈** (`home_screen.dart` `_buildPetSprite`): `_motionSpriteKey(pet)`가
  키를 주면(stage 1 'fluff' / stage 2·3 '{종}{stage-1}')
  `PixelMotionAnimation(mood 기반 모션)`. 급식 버튼 →
  `_playTransientMotion(PixelMotion.eat)` 2.7초.
  사신수(stage 4)만 `PetImageAnimation`(정적 mood 도트).
- **배틀** (`battle_screen.dart` `_myTurnMotion`): 턴 중 내 펫이
  회피(상대 피해 0)→dodge / 우세→attack / 열세→hurt, 600ms 사이클.
- **색 주입**: 밝은 배경에서는 `theme.primary`+`theme.spriteAccent`,
  어두운 그라데이션 카드 위에서는 흰색 도트(accent 미지정).
  털뭉치(stage 1)는 `SpeciesTheme.fluffBody`(밝은 베이지) 단색.

### 4.1 안드로이드 홈 위젯 (네이티브 도트 렌더)

위젯은 앱과 **동일한 도트를 네이티브 Kotlin에서 직접 그린다** (이전엔 drawable
PNG였음). Flutter 엔진이 없어도(백그라운드) 항상 최신 도트를 표시한다.

- **Flutter → 위젯** (`widget_service.dart`): 현재 mood/stage로 고른 스프라이트
  키를 `pixelKey`로, 종·단계를 `evolutionType`/`evolutionStage`로 저장
  (`saveWidgetData`). 이미지 파일/PNG는 넘기지 않는다.
- **네이티브 렌더** (`WidgetPixelRenderer.kt`): `PetWidgetProvider.tryApplyDotImage`가
  진입점. 앱 홈과 **동일한 스프라이트**를 고른다:
  - **모션 스테이지(털뭉치·유아기·성장기)**: `WidgetMotionData`가
    `assets/pet_motion_data.json`(§3의 generate_motion_data.py가 함께 생성 —
    스프라이트키→모션→대표 프레임 1장)을 파싱. `evolutionType`+`evolutionStage`로
    모션 스프라이트 키를(`motionSpriteKey`, 앱 `_motionSpriteKey`와 동일),
    `mood`로 모션을(`motionForMood`, 앱과 동일) 골라 프레임을 찾는다.
  - **사신수(stage 4) 등 모션 없는 단계**: `WidgetPixelData`가
    `assets/pet_pixel_data.json`(§2)을 `pixelKey`로 조회(정적 mood 도트).
  - 색은 `resolveDotColors`(종별 색, 앱 `SpeciesTheme`와 동일 — 털뭉치는
    `fluffBody`+`fluffAccent` 분홍 볼터치)로 주입해 Bitmap을 `setImageViewBitmap`.
- **폴백**: 모션/정적 도트 모두 없으면 기존 drawable 리소스(`evolutionImage`)로.
- **좌표 자동 동기화**: 도트 데이터는 JSON으로만 공유 — Kotlin에 복제 없음.
  단, **색(5종)은 `SpeciesTheme`와 `resolveDotColors`에 이중 유지**(거의 불변).

---

## 5. 픽셀 갤러리 (디버그 화면)

`lib/presentation/screens/debug_pixel_gallery_screen.dart` — **릴리스 전 삭제 대상**.

- 진입: 도감(Me) 탭 맨 아래 "픽셀 갤러리 (디버그)" 버튼
  (`me_screen.dart`의 `_buildDebugGalleryButton` — 삭제 시 이 버튼과 화면
  파일, import 한 줄만 지우면 됨)
- 탭 1 "스프라이트": `petPixelSprites` 146장 그리드 (키 접두어로 종 테마색 적용)
- 탭 2 "도트 모션": `motionFrames` 9스프라이트×9모션 애니메이션
- 우상단 🌙: 어두운 배경 토글 (흰 도트 대비 확인)

---

## 6. 확장 레시피: 새 스테이지 모션 추가하기 (성장기는 완료됨)

**성장기(stage 3, `'{종}2'` 28×28)는 이 레시피대로 구현 완료.**
신수(stage 4, `'{종}3'`) 등 추가 스테이지를 붙일 때의 절차:

1. `assets/{종}N.png`를 열어 특징 파악.
2. 그리드 크기 결정 (몸집 표현 — 성장기 28 사용, 신수는 32 권장).
   생성기는 이미 크기 무관 구조라 정사각 아트만 넣으면 된다.
3. 덤프 스크립트(§3.2 절차, `SPECIES_SRC`와 동일 파라미터)로 초안을 뽑고
   수작업 정리 → `SPECIES_ART`/`SPECIES_SRC`에 `'{종}N'` 키로 추가.
4. Dart 쪽은 대부분 자동 적용:
   - `motionSpriteKeyFromAssetPath`가 맵 키 존재로 판단 → 배틀/갤러리 자동
   - 홈 `_hasMotionStage`의 스테이지 게이트에 새 스테이지 추가
   - 테스트의 그리드 크기 기대값(`유아기 24, 성장기 28`)에 새 스테이지 추가
5. 검증 루틴은 3.6과 동일. 커밋 단위: 아트/데이터 → 화면 연결.

---

## 7. 주의사항 모음

- 모든 스프라이트는 **왼쪽을 본다** — 공격/브레스 -x, 음식 왼쪽 아래.
- 몸을 오른쪽(+x)으로 밀어 이펙트 공간을 만드는 건 허용된 관례
  (꼬리 잘림 OK — 사용자 승인됨).
- 생성 파일(`pet_pixel_data.dart`, `pet_motion_data.dart`)은 절대 손으로
  수정하지 말 것 — 스크립트 수정 후 재생성.
- 아트 수정 후에는 반드시 `preview_motion.py`로 눈 확인 → 재생성 →
  analyze/test/build 순서.
- Android 홈 위젯은 네이티브에서 도트를 직접 렌더한다 (§4.1). 도트 수정 후엔
  두 스크립트가 각각 위젯 JSON을 함께 굽는다:
  `generate_pixel_data.py` → `pet_pixel_data.json`(정적),
  `generate_motion_data.py` → `pet_motion_data.json`(모션). 둘 다 재생성할 것.
- AdMob은 테스트 유닛 ID 상태 — 릴리스 전 교체 필요.
