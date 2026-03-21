# PocketFriend — 프로젝트 분석 및 현황

**최종 업데이트**: 2026-03-21
**앱 상태**: 핵심 기능 구현 완료, 실무 안정화 단계

---

## 📋 목차

1. [프로젝트 개요](#프로젝트-개요)
2. [핵심 시나리오](#핵심-시나리오)
3. [주요 기능](#주요-기능)
4. [기술 스택](#기술-스택)
5. [현재 상태 평가](#현재-상태-평가)
6. [남은 작업](#남은-작업)
7. [수정이 필요한 사항](#수정이-필요한-사항)

---

## 프로젝트 개요

**앱 이름**: PocketFriend
**플랫폼**: Flutter (iOS/Android) + Kotlin (Android 위젯)
**장르**: 건강 관리 × 디지털 펫 시뮬레이션
**아키텍처**: Clean Architecture + Riverpod

### 목표
사용자의 **실제 건강 활동**(걸음 수, 운동 시간, 휴식)을 추적하고,
이를 **가상의 펫**에 반영해서 **자연스럽게 건강한 습관을 만들도록** 동기부여하는 앱.

---

## 핵심 시나리오

### 사용자 여정

```
1. 앱 설치 & 펫 생성
   ↓
2. 일상 활동 추적 (자동)
   • HealthKit/Health Connect 연동: 걸음, 운동
   • 폰 미사용 감지: 휴식/수면 유추
   ↓
3. 펫이 활동에 반응 (자동 갱신)
   • 활동 많음 → "행복", "활기참"
   • 밤 시간대 + 체력 낮음 → "졸림"
   • 운동 직후 → "만족함"
   ↓
4. 펫 진화 (레벨 기반 + 활동 패턴)
   • Lv.5: 1단계 → 2단계 진화 (활동형/휴식형/균형형 결정)
   • Lv.10: 2단계 → 3단계 진화 (최종 형태)
   ↓
5. 홈 화면 위젯에서 펫 상태 한눈에 확인
   • 위젯 자동 갱신 (앱 백그라운드)
```

### 한 가지 예시 경험

```
월요일 아침 → 휴대폰 잠금 → 펫이 수면 중
점심 → 8,000걸음 기록 → 펫이 "운동" 중 (이미지 애니메이션)
밤 10시 → stamina 55 → 시간대 반영으로 "졸림" 상태 (기존보다 빠름)
밤 → 홈 화면 위젯에 펫 상태 표시 → "졸림 💤 Lv.8"

누적 활동 → 어느날 갑자기 "진화 가능!" 알림 → 진화 화면 진입
```

---

## 주요 기능

### 1. 펫 상태 추적 (Pet Entity)

| 속성 | 범위 | 설명 |
|------|------|------|
| **hunger** (배고픔) | 0–100 | 0=배고픔, 100=배부름 |
| **happiness** (행복도) | 0–100 | 0=불행, 100=행복 |
| **stamina** (체력) | 0–100 | 0=피곤, 100=최상 |
| **level** (레벨) | 1–∞ | 활동량에 따라 증가 |
| **exp** (경험치) | 0–∞ | 누적 활동의 수치화 |
| **mood** (기분) | 10가지 열거형 | hunger/happiness/stamina + 시간대로 자동 계산 |

### 2. 기분 상태 (Mood) — 자동 계산 엔진 ✅ 업데이트됨

펫의 기분은 **3가지 수치 + 현재 시간대** 기반으로 8단계 우선순위로 결정된다.
Flutter (`pet.dart`) ↔ Kotlin (`PetWidgetProvider.kt`) 동일 로직 유지.

```
우선순위별 기분 결정 로직 (v2):

1단계: 위기 상태 (≤ 10 — 즉각 개입)
   hunger ≤ 10    → "배고픔"
   stamina ≤ 10   → "피곤함"

2단계: 경고 상태 (≤ 25)
   hunger ≤ 25    → "배고픔"
   stamina ≤ 25   → "피곤함"

3단계: 수면 신호 (시간대 반영)
   밤 22:00~06:00 && stamina ≤ 60  → "졸림"  ← 시간대 컨텍스트 신규
   stamina ≤ 35   → "졸림"

4단계: 감정 위기
   happiness ≤ 20  → "불안함"
   happiness ≤ 35  → "지루함"

5단계: 최상 긍정 상태
   hunger≥90 && happiness≥90 && stamina≥90  → "활기참"
   hunger≥80 && happiness≥85 && stamina≥80  → "기쁨"  ← happiness 기준 85로 상향

6단계: 부분 긍정 상태
   hunger≥85 && happiness≥60 && stamina≥55  → "배부름"  ← 기준 완화
   happiness≥75 && stamina≥45 && hunger≥55  → "만족함"  ← 운동 직후 패턴 신규
   (hunger≥70 && happiness≥70) || (stamina 조건)  → "만족함"

7단계: 불균형 감지
   max_차이 > 35   → "불안함"  ← 40→35로 더 민감하게

8단계: 기본값  → "보통"
```

**이전 v1 대비 개선 포인트**:
- 임계값이 단순 20/30 이분법 → 10/25/35 3단계로 세분화
- 밤 시간대(22~6시)에 stamina 60 이하면 졸림 — 실생활 수면 패턴 반영
- 운동 직후 상태 반영 (stamina 소모됐지만 happiness 높으면 "만족함")
- 불균형 감지 임계값 40 → 35 (더 빠른 반응)

### 3. 진화 시스템 (3단계)

```
Stage 1: 알/초기 상태
└─ 사용자가 앱 시작한 상태

Stage 2: 1차 진화 (Lv.5 도달)
├─ 활동형 (active)     : 100,000+ 걸음 또는 1,000+ 운동 분
├─ 휴식형 (restful)    : 200+ 미사용 시간
└─ 균형형 (balanced)   : 위 조건 미충족

Stage 3: 최종 진화 (Lv.10 도달)
└─ 진화 방향 유지 (이미 2단계에서 결정됨)
```

### 4. 일일 목표 (Daily Goals)

자동 리셋: 매일 00:00 (로컬 시간 기준)에 초기화

```
추적 항목:
- todayFeedCount      : Feed 횟수 (최대 3회, 식사 시간대별)
- todaySleepHours     : 수면 시간 (목표 4~6시간, 레벨 기반)
- todayAlternativeFeedCount      : 간편 급식 사용 횟수 (1회 제한)
- todayAlternativeSleepCount     : 짧은 휴식 사용 횟수 (1회 제한)
- todayAlternativeExerciseCount  : 실내 운동 사용 횟수 (1회 제한)
```

### 5. 활동 데이터 연동 (Health Integration)

```
데이터 소스:

[iOS]
├─ HealthKit: 걸음, 운동, 수면 (권한 필요)
└─ 폰 미사용: 화면 꺼짐 감지

[Android]
├─ Health Connect (health 패키지 13.x)
│   ├─ 권한: READ_STEPS, READ_EXERCISE
│   └─ AndroidManifest: SHOW_PERMISSIONS_RATIONALE intent-filter 필요 (적용 완료)
├─ 폰 미사용: 화면 꺼짐 감지
└─ WorkManager: 백그라운드 동기화 (30분 주기)

동기화 시점:
- 앱 포그라운드: 1분마다 (onMinuteTick)
- 앱 전환: 포그라운드 복귀 시 즉시
- 앱 백그라운드: WorkManager 30분마다
```

### 6. 자동 액션 (Automation)

```
auto_feed_pet_usecase
├─ 조건: 식사 시간대 (7-9, 12-14, 18-20시) + 해당 슬롯 미급식
├─ 효과: hunger +10
└─ 빈도: 슬롯당 1회 (비트마스크로 추적)

auto_sleep_pet_usecase
├─ 조건: 폰 미사용 30분+
├─ 효과: stamina 회복
└─ 빈도: 배치 작업 (30분마다)

update_pet_from_activity_usecase
├─ 데이터: 오늘 0시 이후 걸음/운동 delta 계산
├─ 효과: 1,000보당 happiness+5·stamina+3, 10분당 happiness+10·stamina+5
└─ 빈도: 실시간 (포그라운드) + 배치 (백그라운드)
```

### 7. 홈 화면 위젯 (Android)

```
Kotlin PetWidgetProvider 담당

표시 정보:
- 펫 이미지 (애니메이션) → mood에 따라 3–4프레임 순환
- Level: "Lv.8"
- Mood: "졸림" 등 한국어

동작:
- 800ms 주기로 이미지 변경
- home_widget 패키지로 SharedPreferences 동기화
- 위젯 클릭 → 앱 실행
- 기분 판정 로직은 Flutter pet.dart와 동일 (calculateMoodFromStats)
```

---

## 기술 스택

### Frontend (Flutter/Dart)

```
lib/
├── domain/              # 순수 비즈니스 로직 (20개 UseCase)
│   ├── entities/        # Pet, EvolutionType, ActivityData, ...
│   ├── repositories/    # 추상 인터페이스
│   └── usecases/        # 비즈니스 규칙
├── data/                # 구현층
│   ├── models/          # Hive 모델 (@HiveType)
│   ├── datasources/     # Health Connect, HealthKit, PhoneUsage, Hive
│   ├── repositories/    # Repository 구현
│   └── services/        # NotificationService, WidgetService, BackgroundService
└── presentation/        # UI (Riverpod 상태 관리)
    ├── providers/       # Riverpod StateNotifier
    ├── screens/         # 5개 화면 (Home, Evolution, Battle, Share, Navigation)
    └── widgets/         # 재사용 컴포넌트
```

### 주요 패키지 버전

| 패키지 | 버전 | 용도 |
|--------|------|------|
| `flutter_riverpod` | 2.5.1 | 상태 관리 |
| `hive` | 2.2.3 | 로컬 저장소 |
| `health` | 13.1.4 | HealthKit/Health Connect |
| `home_widget` | 0.9.0 | Android 홈 위젯 |
| `workmanager` | 0.9.0 | 백그라운드 작업 |
| `flutter_local_notifications` | 17.0.0 | 알림 |

### Hive 박스 구성

```
4개 Box:
- pets          : PetModel (typeId: 0)
- battles       : BattleHistoryModel (typeId: 1)
- notifications : NotificationData
- phone_usage   : PhoneUsageData

주의: @HiveField(N) 번호는 절대 변경 불가, 새 필드는 끝에 추가
```

---

## 현재 상태 평가

### ✅ 잘 구현된 부분

| 항목 | 평가 | 사유 |
|------|------|------|
| **아키텍처** | ⭐⭐⭐⭐⭐ | Clean Architecture 완벽히 준수, 레이어 간 의존성 명확 |
| **비즈니스 로직** | ⭐⭐⭐⭐⭐ | 20개 UseCase로 단일 책임 원칙 준수 |
| **Mood 엔진** | ⭐⭐⭐⭐⭐ | 8단계 우선순위, 시간대 반영, Flutter↔Kotlin 동기화 |
| **진화 시스템** | ⭐⭐⭐⭐⭐ | 3단계 진화, 활동 패턴 기반 방향 결정 |
| **활동 동기화** | ⭐⭐⭐⭐ | Health Connect/HealthKit 연동, delta 계산 |
| **UI 상태 관리** | ⭐⭐⭐⭐ | Riverpod StateNotifier, 리빌드 최적화 |
| **위젯 구현** | ⭐⭐⭐⭐ | Kotlin 원자적 갱신, 애니메이션, mood 동기화 |
| **일일 목표** | ⭐⭐⭐⭐ | 레벨별 목표값, 식사 시간대 비트마스크 추적 |

### ⚠️ 주의 대상

| 항목 | 평가 | 사유 |
|------|------|------|
| **Hive 마이그레이션** | ⚠️ | 필드 추가 시 이전 데이터 손상 위험 (전략 문서화 필요) |
| **Health Connect 권한 UX** | ⚠️ | 권한 거부 시 사용자에게 안내 화면 없음 |
| **진화/배틀/공유 UI** | ⚠️ | 화면 구조는 있으나 UI 구현 미완성 |

### 🔍 미확인 사항

- iOS HealthKit 권한 거부 후 복구 경로
- 연속 30일 사용 시 Hive 성능 (배틀 기록 누적)
- 진화 단계별 이미지 에셋 완비 여부

---

## 남은 작업

### 🟡 High (1–2주 내)

#### 1. 진화 화면 UI 구현
**파일**: `lib/presentation/screens/evolution_screen.dart`
**상태**: 구조 있음, UI 미완성
**작업**:
- 진화 애니메이션 (단계별 이미지 전환)
- Stage 1/2/3 시각화
- EvolutionType별 테마 적용

#### 2. 일일 목표 진행률 UI
**파일**: `lib/presentation/screens/home_screen.dart`
**작업**:
- Feed 진행 바 (오늘 n/3)
- 수면 시간 진행 바 (목표 시간 기준)
- 대체 액션 제한 표시 (1회 사용 후 비활성화)

#### 3. Hive 마이그레이션 전략 문서화
**위험**: Pet 엔티티에 필드 추가 시 기존 유저 데이터 손상 가능
**대응 원칙**:
- `@HiveField(N)` 번호는 절대 변경 불가
- 새 필드는 항상 마지막 번호 다음에 추가
- 새 필드는 반드시 기본값 지정 (`= 0`, `= ''` 등)
- CLAUDE.md의 "Adding a field to Pet entity" 체크리스트 엄수

---

### 🟢 Medium (2–4주)

#### 4. 전투 시스템 (Battle) UI 완성
**파일**: `lib/presentation/screens/battle_screen.dart`
**현황**: `BattleWithActivityUseCase` 로직 완성됨, UI 미완성
**작업**:
- 배틀 화면 UI (활동 목표 달성 → 승리 연출)
- 배틀 기록 목록 표시
- 경험치 획득 애니메이션

#### 5. 공유 기능 (Share)
**파일**: `lib/presentation/screens/share_screen.dart`
**현황**: 빈 화면
**작업**:
- 펫 이미지 + 통계 스크린샷 생성
- SNS 공유 (카카오톡, Instagram)

#### 6. Health Connect 권한 거부 UX
**현황**: 권한 없으면 activity 데이터 0으로 처리 (silently)
**작업**:
- 권한 거부 시 사용자에게 설명 화면 표시
- 설정 앱으로 이동하는 버튼 제공

---

### 🔵 Low (다음 버전 또는 선택사항)

#### 7. 멀티 펫 지원
**현황**: `defaultPetId = 'default-pet'` 하드코딩
**작업**: 펫 추가, 전환, 별도 프로필

#### 8. 소셜 기능
**작업**: 친구 목록, 리더보드, 협력 퀘스트

#### 9. 상점 시스템
**작업**: 펫 옷, 배경, 아이템 구매 (인앱 결제)

---

## 수정이 필요한 사항

### 🔧 버그 & 논리 오류

#### 1. `update_pet_from_activity_usecase.dart` — 보상 단위 재검토
**현상**: 1,000보당 happiness+5·stamina+3인데 하루 10,000보면 최대 +50 happiness. 이미 70 이상이면 효과 없음
**검토 필요**: 수치 감소 속도(30분당 -1)와 보상 속도의 균형 재조정

#### 2. `battle_with_activity_usecase.dart` — 상대방 펫 개념 없음
**현상**: 현재는 "일일 목표 달성 여부"로만 승패 결정 (실제 배틀 아님)
**작업**: 배틀 화면 구현 시 상대방 가상 펫 생성 로직 추가

---

### 📝 코드 정리

#### 3. 삭제된 파일 git commit 완료 필요
**현상**: git status에 `D` (deleted) 표시된 파일 100+ 개
```
D lib/core/constants/hive_constants.dart  (리팩토링으로 삭제됨)
D design/src/...                           (design 폴더 정리됨)
... 등
```
**수정**: `git add -A` → commit

#### 4. 중복 디렉토리 정리
**현상**: `lib/data/datasource/` (singular, 레거시) + `lib/data/datasources/` (plural, 현재)
**수정**: 레거시 폴더 삭제, 모든 import를 `datasources/`로 통일

---

### 🎨 UI/UX 개선

#### 5. 로딩 상태 피드백
**현상**: 활동 동기화 중 사용자가 진행 상황 모름
**수정**: 마지막 동기화 시간 표시 ("마지막 동기화: 5분 전")

#### 6. 펫 기분 수치 시각화
**현상**: 기분 텍스트만으로 상태 이해 어려움
**수정**: 원형/막대 게이지 (Hunger / Happiness / Stamina)

---

### 📊 성능 최적화

#### 7. Riverpod 리빌드 최소화
```dart
// Bad: 전체 Pet 감시 → mood 외 변경에도 리빌드
ref.watch(petNotifierProvider(petId))

// Good: 필요한 속성만 감시
ref.watch(petNotifierProvider(petId).select((s) => s.valueOrNull?.mood))
```

#### 8. 오래된 배틀 기록 정리
**현황**: BattleHistory가 무한 누적됨
**수정**: 최근 30개만 보관, 오래된 것은 삭제

---

## 완료된 수정 이력

| 날짜 | 항목 | 파일 |
|------|------|------|
| 2026-03-21 | Mood 엔진 v2: 시간대 반영, 임계값 세분화 | `pet.dart`, `PetWidgetProvider.kt` |
| 2026-03-21 | AndroidManifest Health Connect rationale filter 추가 | `AndroidManifest.xml` |
| 2026-03-21 | HealthDataSource._initialized static으로 변경 (인스턴스 공유) | `health_datasource.dart` |
| 2026-03-21 | WorkManager 주기 15분 → 30분으로 변경 (배터리 최적화) | `background_service.dart` |

---

## 작업 우선순위 요약

```
이번 주 (High)
├─ 진화 화면 UI 완성
├─ 일일 목표 진행률 표시
└─ Hive 마이그레이션 전략 문서화

2~4주 (Medium)
├─ 배틀 화면 UI
├─ 공유 기능 구현
└─ Health Connect 권한 거부 UX

다음 버전 (Low)
├─ 멀티 펫
├─ 소셜 기능
└─ 상점 시스템
```

---

## 결론

**현재 PocketFriend는**:
- ✅ **아키텍처**: 프로덕션 수준
- ✅ **핵심 기능**: 95% 완성 (Mood, 진화, 활동 연동, 위젯)
- ✅ **걷기 데이터**: Health Connect 연동 수정 완료
- ✅ **배터리**: WorkManager 30분 주기로 최적화
- ⚠️ **UI 미완성**: 진화 화면, 배틀 UI, 공유 기능
- 🎯 **목표**: 2주 내 진화/배틀 UI 완성 → 베타 릴리스 가능
