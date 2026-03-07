# PocketFriend 펫 시나리오 개발 계획서

## 1. 프로젝트 개요

### 1.1 목표

- 디지털 디톡스 효과를 주는 반려동물 키우기 앱
- 사용자의 실제 활동(걷기, 운동, 폰 사용 패턴)을 반영한 펫 관리 시스템
- 누적 활동 결과에 따른 진화 시스템
- 강아지 컨셉의 귀여운 UI/UX

### 1.2 핵심 가치

- **디지털 디톡스**: 폰 미사용 시간이 펫의 휴식으로 연결
- **건강 증진**: 걷기/운동량이 펫의 성장으로 직결
- **자동화**: 사용자가 직접 버튼을 누르지 않고도 자연스러운 상호작용
- **진화 다양성**: 활동 패턴에 따라 다른 진화 방향

---

## 2. 현재 앱 상태 분석

### 2.1 구현된 기능

- ✅ 기본 Pet 엔티티 및 상태 관리 (hunger, happiness, stamina)
- ✅ 시간 경과에 따른 자동 상태 감소
- ✅ Feed/Play/Sleep 버튼 기반 액션 (수동) → **제거됨 (자동화로 대체)**
- ✅ 진화 시스템 (레벨 기반, 5단계) → **누적 활동 기반으로 개선됨**
- ✅ 알림 시스템
- ✅ 홈 화면 위젯
- ✅ 배틀 시스템 (기본 턴제) → **활동 기반으로 개선됨**
- ✅ Hive 기반 로컬 저장소
- ✅ Riverpod 상태 관리

### 2.2 새로 구현된 기능

- ✅ 헬스케어 데이터 접근 (걷기 수, 운동 시간)
- ✅ 폰 사용 감지 (앱 생명주기 기반)
- ✅ 자동화된 Feed/Play/Sleep 트리거
- ✅ 누적 활동 기반 진화 시스템
- ✅ 한국어 현지화
- ✅ 강아지 컨셉 색상 테마
- ✅ 활동 기반 대결 시스템
- ⏸️ 서버 동기화 (기본 구조만 구현, 실제 연동은 선택 사항)

---

## 3. 요구사항별 상세 분석 및 구현 방안

### 3.1 폰 미사용 감지 → 펫 잠자기 (디지털 디톡스)

#### 구현 완료

**구현 방법:**
- 앱 생명주기(`AppLifecycleState`) 기반으로 미사용 시간 추적
- `PhoneUsage` 엔티티로 마지막 포그라운드/백그라운드 시간 관리
- 30분 이상 미사용 시 자동으로 `stamina` 증가 (30분당 +5)

**구현된 파일:**
- `lib/domain/entities/phone_usage.dart` ✅
- `lib/domain/repositories/phone_usage_repository.dart` ✅
- `lib/domain/usecases/detect_phone_idle_usecase.dart` ✅
- `lib/domain/usecases/auto_sleep_pet_usecase.dart` ✅
- `lib/data/datasources/phone_usage_datasource.dart` ✅
- `lib/data/repositories/phone_usage_repository_impl.dart` ✅
- `lib/presentation/providers/pet_provider.dart` (자동 Sleep 트리거 통합) ✅
- `lib/presentation/screens/main_navigation_screen.dart` (앱 생명주기 감지) ✅

---

### 3.2 걷기/운동량 추적 → 펫 활동 (건강 증진)

#### 구현 완료

**구현 방법:**
- `health` 패키지를 사용하여 Google Fit / HealthKit 통합
- 걸음 수와 운동 시간을 추적하여 펫 상태 자동 업데이트
- 1000보당 `happiness +5`, `stamina +3`
- 10분 운동당 `happiness +10`, `stamina +5`

**구현된 파일:**
- `lib/domain/entities/activity_data.dart` ✅
- `lib/domain/repositories/activity_repository.dart` ✅
- `lib/domain/usecases/update_pet_from_activity_usecase.dart` ✅
- `lib/data/datasources/health_datasource.dart` ✅
- `lib/data/repositories/activity_repository_impl.dart` ✅
- `android/app/src/main/AndroidManifest.xml` (헬스케어 권한 추가) ✅

---

### 3.3 식사 시점 결정

#### 구현 완료 (옵션 A: 시간 기반 자동 식사)

**구현 방법:**
- 펫이 배고픈 상태(hunger < 30)에서 2시간 이상 지속 시 자동 식사
- 식사 시간대(아침 7-9시, 점심 12-14시, 저녁 18-20시)에 우선 적용
- 배고픔이 심하면(hunger < 10) 시간대 무관하게 자동 식사
- 식사 후 `hunger +30` 회복

**구현된 파일:**
- `lib/domain/usecases/auto_feed_pet_usecase.dart` ✅
- `lib/presentation/providers/pet_provider.dart` (자동 Feed 트리거 통합) ✅

---

### 3.4 상태별 애니메이션 표시

#### 구현 완료

**구현 방법:**
- `PetMood` → `PetImageType` 자동 매핑 헬퍼 함수 생성
- `PetNotifier`에서 상태 변경 시 자동으로 이미지 타입 업데이트
- 위젯도 동일하게 반영

**구현된 파일:**
- `lib/core/utils/pet_image_helper.dart` ✅
- `lib/presentation/providers/pet_provider.dart` (자동 애니메이션 전환) ✅
- `lib/presentation/widgets/pet_image_animation.dart` (상태 기반 이미지 타입) ✅
- `lib/data/services/widget_service.dart` (상태 기반 위젯 업데이트) ✅
- `lib/presentation/screens/home_screen.dart` (pet.mood 기반 이미지 표시) ✅

---

### 3.5 누적 활동 기반 진화 시스템

#### 구현 완료

**구현 방법:**
- `Pet` 엔티티에 누적 활동 필드 추가:
  - `totalSteps`: 누적 걸음 수
  - `totalExerciseMinutes`: 누적 운동 시간 (분)
  - `totalIdleHours`: 누적 미사용 시간 (시간)
- `EvolutionType` enum 추가: `active`, `restful`, `balanced`
- 진화 방향 결정:
  - 활동형: `totalSteps > 100,000` 또는 `totalExerciseMinutes > 1,000`
  - 휴식형: `totalIdleHours > 200`
  - 균형형: 위 두 조건 모두 미충족

**구현된 파일:**
- `lib/domain/entities/evolution_type.dart` ✅
- `lib/domain/entities/pet.dart` (누적 활동 필드 추가) ✅
- `lib/data/models/pet_model.dart` (누적 활동 필드 추가) ✅
- `lib/data/models/pet_model_adapter.dart` (Hive 어댑터 업데이트) ✅
- `lib/domain/usecases/evolve_pet_usecase.dart` (누적 활동 기반 진화 로직) ✅
- `lib/domain/usecases/update_pet_from_activity_usecase.dart` (누적 활동 업데이트) ✅
- `lib/domain/usecases/auto_sleep_pet_usecase.dart` (누적 미사용 시간 업데이트) ✅

---

### 3.6 진화 시점 결정

#### 구현 완료

**구현 방법:**
- 레벨 5 달성 시: 1단계 → 2단계 (진화 방향 결정)
- 레벨 10 달성 시: 2단계 → 3단계 (최종 형태)
- 진화 시점에 누적 활동 데이터를 확인하여 방향 결정

**구현된 파일:**
- `lib/domain/usecases/evolve_pet_usecase.dart` ✅

---

### 3.7 한국어 현지화

#### 구현 완료

**구현 방법:**
- `AppStrings` 상수 클래스 생성
- 모든 하드코딩된 텍스트를 상수로 이동
- UI 텍스트를 한국어로 변환

**구현된 파일:**
- `lib/core/constants/app_strings.dart` ✅
- `lib/presentation/screens/home_screen.dart` (리소스 사용) ✅
- `lib/presentation/widgets/status_bar.dart` (리소스 사용) ✅
- `lib/presentation/screens/battle_screen.dart` (리소스 사용) ✅
- `lib/domain/usecases/check_notification_usecase.dart` (리소스 사용) ✅
- `lib/presentation/providers/pet_provider.dart` (리소스 사용) ✅

---

### 3.8 Feed/Play/Sleep 버튼 제거 및 자동화

#### 구현 완료

**구현 방법:**
- `home_screen.dart`에서 버튼 UI 제거
- 자동화 트리거:
  - Sleep: 폰 미사용 감지 시 자동
  - Feed: 시간 기반 자동
  - Play: 걷기/운동량 기반 자동

**구현된 파일:**
- `lib/presentation/screens/home_screen.dart` (버튼 제거) ✅

---

### 3.9 강아지 컨셉 색상 테마 개선

#### 구현 완료 (이미지 참고로 최종 조정)

**구현 방법:**
- **배경색**: 밝은 라벤더/핑크 그라디언트 (`#F3E8F5` → `#FFF5F8`)
- **Primary 색상**: 중간 보라색 (`#A08CDB`) - 이미지 참고
- **Accent 색상**: 보라색 (`#A08CDB`)
- **버튼 스타일**: 
  - 활성 버튼: 보라색 배경 + 흰색 텍스트
  - 비활성 버튼: 흰색 배경 + 보라색 텍스트
- **카드 배경**: 흰색 (`#FFFFFF`)
- **텍스트 색상**: 어두운 회색 (`#333333`)
- **프로그레스 바 색상**:
  - 배고픔: 오렌지-레드 (`#F2786B`)
  - 행복도: 노란색-오렌지 (`#F6C769`)
  - 체력: 그린 (`#78C97B`)
- **헤더 버튼**: 밝은 라일락 배경 (`#E0D6F5`) + 보라색 아이콘

**구현된 파일:**
- `lib/core/theme/app_colors.dart` ✅
- `lib/core/theme/app_theme.dart` ✅ (밝은 테마로 변경)
- `lib/presentation/widgets/pet_button.dart` ✅

---

### 3.10 대결 시스템 개선

#### 구현 완료 (옵션 A: 활동 기반 대결)

**구현 방법:**
- 일일 목표 달성 여부로 승부 결정
- 목표: 10,000보 또는 30분 운동
- 목표 달성 시 승리 → 보너스 경험치 100
- 목표 미달성 시 패배 → 경험치 20

**구현된 파일:**
- `lib/domain/usecases/battle_with_activity_usecase.dart` ✅
- `lib/presentation/screens/battle_screen.dart` (활동 기반 대결 UI) ✅

---

### 3.11 서버 동기화

#### 기본 구조만 구현 (선택 사항)

**구현 방법:**
- Domain 레이어에 인터페이스만 정의
- 실제 구현은 필요 시 추가

**구현된 파일:**
- `lib/domain/repositories/pet_remote_repository.dart` (인터페이스만) ✅
- `lib/domain/usecases/sync_pet_usecase.dart` (기본 로직만) ✅

---

## 4. 개발 우선순위 및 완료 상태

### Phase 1: 핵심 자동화 기능 ✅ 완료

1. ✅ 폰 미사용 감지 → 자동 Sleep
2. ✅ 걷기/운동량 추적 → 자동 Play
3. ✅ 시간 기반 자동 Feed
4. ✅ 상태별 자동 애니메이션 전환
5. ✅ Feed/Play/Sleep 버튼 제거

### Phase 2: 진화 시스템 개선 ✅ 완료

1. ✅ 누적 활동 필드 추가
2. ✅ 누적 활동 기반 진화 로직
3. ✅ 진화 시점 및 방향 결정

### Phase 3: UI/UX 개선 ✅ 완료

1. ✅ 한국어 현지화
2. ✅ 강아지 컨셉 색상 테마

### Phase 4: 고급 기능 ✅ 완료

1. ✅ 활동 기반 대결 시스템
2. ✅ 서버 동기화 기본 구조 (선택적 구현 준비)

---

## 5. 기술 스택 추가 사항

### 추가된 패키지

```yaml
dependencies:
  # 백그라운드 작업
  workmanager: ^0.5.2
  
  # 헬스케어 데이터
  health: ^10.1.0
  
  # 현지화
  flutter_localizations:
    sdk: flutter
```

---

## 6. 데이터 모델 변경 사항

### Pet 엔티티 확장 ✅ 완료

```dart
class Pet {
  // 기존 필드
  final String id;
  final int hunger;
  final int happiness;
  final int stamina;
  final int level;
  final int exp;
  final int evolutionStage;
  final int lastUpdated;
  
  // 추가 필드 (누적 활동)
  final int totalSteps;           // 누적 걸음 수
  final int totalExerciseMinutes; // 누적 운동 시간 (분)
  final int totalIdleHours;       // 누적 미사용 시간 (시간)
  
  // 추가 필드 (진화 방향)
  final EvolutionType? evolutionType; // 활동형, 휴식형, 균형형
}
```

---

## 7. 주요 파일 변경 목록

### 신규 파일

- `lib/domain/entities/phone_usage.dart` ✅
- `lib/domain/entities/activity_data.dart` ✅
- `lib/domain/entities/evolution_type.dart` ✅
- `lib/domain/repositories/phone_usage_repository.dart` ✅
- `lib/domain/repositories/activity_repository.dart` ✅
- `lib/domain/repositories/pet_remote_repository.dart` ✅
- `lib/domain/usecases/detect_phone_idle_usecase.dart` ✅
- `lib/domain/usecases/update_pet_from_activity_usecase.dart` ✅
- `lib/domain/usecases/auto_feed_pet_usecase.dart` ✅
- `lib/domain/usecases/auto_sleep_pet_usecase.dart` ✅
- `lib/domain/usecases/battle_with_activity_usecase.dart` ✅
- `lib/domain/usecases/sync_pet_usecase.dart` ✅
- `lib/data/datasources/phone_usage_datasource.dart` ✅
- `lib/data/datasources/health_datasource.dart` ✅
- `lib/data/repositories/phone_usage_repository_impl.dart` ✅
- `lib/data/repositories/activity_repository_impl.dart` ✅
- `lib/core/constants/app_strings.dart` ✅
- `lib/core/utils/pet_image_helper.dart` ✅

### 수정 파일

- `lib/domain/entities/pet.dart` (누적 활동 필드 추가) ✅
- `lib/data/models/pet_model.dart` (누적 활동 필드 추가) ✅
- `lib/data/models/pet_model_adapter.dart` (Hive 어댑터 업데이트) ✅
- `lib/domain/usecases/evolve_pet_usecase.dart` (누적 활동 기반 진화) ✅
- `lib/domain/usecases/create_default_pet_usecase.dart` (기본값 업데이트) ✅
- `lib/presentation/providers/pet_provider.dart` (자동화 로직 통합) ✅
- `lib/presentation/screens/home_screen.dart` (버튼 제거, 자동화) ✅
- `lib/presentation/screens/main_navigation_screen.dart` (앱 생명주기 감지) ✅
- `lib/presentation/screens/battle_screen.dart` (활동 기반 대결) ✅
- `lib/core/theme/app_colors.dart` (강아지 컨셉 색상) ✅
- `lib/core/constants/hive_constants.dart` (phone_usage Box 추가) ✅
- `lib/data/services/widget_service.dart` (상태 기반 위젯 업데이트) ✅
- `lib/domain/usecases/check_notification_usecase.dart` (한국어 리소스 사용) ✅
- `pubspec.yaml` (필수 패키지 추가) ✅
- `android/app/src/main/AndroidManifest.xml` (헬스케어 권한 추가) ✅
- `lib/main.dart` (초기화 로직 추가) ✅

---

## 8. 리스크 및 고려사항

### 8.1 권한 요청

- **헬스케어 권한**: 사용자가 거부할 수 있음 → 에러 처리로 무시하고 계속 진행
- **앱 생명주기**: 모든 플랫폼에서 지원되므로 권한 문제 없음

### 8.2 배터리 최적화

- 앱 생명주기 기반으로 구현하여 배터리 소모 최소화
- 백그라운드 작업은 필요 시 `WorkManager` 사용 가능

### 8.3 플랫폼 차이

- iOS와 Android의 헬스케어 API 차이 → `health` 패키지가 자동 처리
- 앱 생명주기는 모든 플랫폼에서 동일하게 작동

### 8.4 사용자 경험

- 자동화가 자연스럽게 작동하도록 구현
- 설정 화면 추가 시 자동화 옵션 on/off 제공 가능

---

## 9. 구현 완료 요약

### 완료된 기능

1. ✅ 폰 미사용 감지 및 자동 Sleep
2. ✅ 걷기/운동량 추적 및 자동 Play
3. ✅ 시간 기반 자동 Feed
4. ✅ 상태별 자동 애니메이션 전환
5. ✅ Feed/Play/Sleep 버튼 제거
6. ✅ 누적 활동 필드 추가
7. ✅ 누적 활동 기반 진화 로직
8. ✅ 진화 시점 결정 (레벨 5/10)
9. ✅ 한국어 현지화
10. ✅ 강아지 컨셉 색상 테마
11. ✅ 활동 기반 대결 시스템
12. ✅ 서버 동기화 기본 구조

---

## 10. 다음 단계

1. **테스트**: 구현된 기능들을 실제 기기에서 테스트
2. **이미지 준비**: 진화 단계별 이미지 (현재 이미지로 대체 중)
3. **버그 수정**: 테스트 중 발견된 문제 해결
4. **서버 동기화**: 필요 시 실제 서버 연동 구현

---

**모든 계획된 기능이 구현 완료되었습니다.**
