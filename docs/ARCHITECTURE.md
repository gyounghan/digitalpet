# PocketFriend 아키텍처 문서

## 목차
1. [프로젝트 개요](#프로젝트-개요)
2. [아키텍처 개요](#아키텍처-개요)
3. [프로젝트 구조](#프로젝트-구조)
4. [레이어별 상세 분석](#레이어별-상세-분석)
5. [데이터 흐름](#데이터-흐름)
6. [상태 관리](#상태-관리)
7. [주요 기능](#주요-기능)
8. [의존성 주입](#의존성-주입)
9. [비즈니스 로직](#비즈니스-로직)
10. [앱 생명주기](#앱-생명주기)

---

## 프로젝트 개요

**PocketFriend**는 반려동물 키우기 모바일 앱으로, 사용자가 가상의 펫을 키우고 관리할 수 있는 기능을 제공합니다.

### 주요 기능
- 펫 상태 관리 (배고픔, 행복도, 체력)
- 시간 경과에 따른 자동 상태 감소
- Feed/Play/Sleep 액션을 통한 상태 회복
- 진화 시스템 (5단계 진화)
- 알림 시스템 (상태 기반 알림)
- 홈 화면 위젯 (Android/iOS)
- 배틀 시스템 (간단한 턴제 전투)

### 기술 스택
- **프레임워크**: Flutter (Dart)
- **상태 관리**: Riverpod
- **로컬 저장소**: Hive
- **알림**: flutter_local_notifications
- **홈 화면 위젯**: home_widget
- **아키텍처 패턴**: Clean Architecture

---

## 아키텍처 개요

PocketFriend는 **Clean Architecture** 패턴을 엄격히 따르고 있습니다.

### 아키텍처 원칙

1. **의존성 역전 원칙 (DIP)**
   - 고수준 모듈이 저수준 모듈에 의존하지 않음
   - 추상화(인터페이스)에 의존

2. **단일 책임 원칙 (SRP)**
   - 각 클래스는 하나의 책임만 가짐
   - UseCase는 단일 비즈니스 로직만 처리

3. **레이어 분리**
   - Domain 레이어는 순수 Dart (Flutter 의존성 없음)
   - Data 레이어는 Domain에만 의존
   - Presentation 레이어는 Domain과 Data에 의존

### 의존성 방향

```
Presentation → Domain ← Data
     ↓            ↑
     └────────────┘
```

- **Domain**: 가장 안쪽 레이어, 순수 Dart 클래스
- **Data**: Domain의 인터페이스를 구현
- **Presentation**: Domain과 Data를 사용하여 UI 구성

---

## 프로젝트 구조

### 전체 디렉토리 구조

```
lib/
├── core/                          # 공통 유틸리티 및 상수
│   ├── constants/                 # 상수 정의
│   │   ├── hive_constants.dart    # Hive Box 이름, TypeId
│   │   └── notification_constants.dart  # 알림 관련 상수
│   ├── theme/                     # 테마 및 색상
│   │   ├── app_theme.dart         # Material 테마 정의
│   │   └── app_colors.dart        # 색상 팔레트
│   └── utils/                     # 유틸리티 함수
│       ├── evolution_helper.dart  # 진화 단계 헬퍼
│       └── validators.dart        # 값 유효성 검사
│
├── domain/                        # 비즈니스 로직 레이어 (Pure Dart)
│   ├── entities/                  # 엔티티 (비즈니스 모델)
│   │   └── pet.dart               # Pet 엔티티
│   ├── repositories/              # 리포지토리 인터페이스
│   │   ├── pet_repository.dart    # Pet 저장소 인터페이스
│   │   └── notification_repository.dart  # 알림 저장소 인터페이스
│   ├── usecases/                  # 유스케이스 (비즈니스 로직)
│   │   ├── update_pet_state_usecase.dart      # 상태 업데이트
│   │   ├── feed_pet_usecase.dart              # 먹이 주기
│   │   ├── play_pet_usecase.dart              # 놀아주기
│   │   ├── sleep_pet_usecase.dart             # 재우기
│   │   ├── create_default_pet_usecase.dart    # 기본 Pet 생성
│   │   ├── evolve_pet_usecase.dart            # 진화 처리
│   │   └── check_notification_usecase.dart    # 알림 체크
│   └── services/                  # 도메인 서비스
│       └── pet_state_service.dart # Pet 상태 서비스
│
├── data/                          # 데이터 레이어
│   ├── models/                    # 데이터 모델 (Hive)
│   │   ├── pet_model.dart         # Pet 데이터 모델
│   │   └── pet_model_adapter.dart # Hive TypeAdapter
│   ├── datasource/                # 데이터소스
│   │   ├── pet_local_datasource.dart          # Pet 로컬 저장소
│   │   └── notification_local_datasource.dart # 알림 로컬 저장소
│   ├── repository/                # 리포지토리 구현
│   │   ├── pet_repository_impl.dart           # Pet 저장소 구현
│   │   └── notification_repository_impl.dart # 알림 저장소 구현
│   └── services/                  # 데이터 서비스
│       ├── notification_service.dart  # 알림 서비스
│       └── widget_service.dart        # 위젯 서비스
│
├── presentation/                  # UI 레이어 (Flutter)
│   ├── providers/                 # Riverpod 상태 관리
│   │   └── pet_provider.dart     # Pet 관련 Provider
│   ├── screens/                   # 화면
│   │   ├── main_navigation_screen.dart  # 메인 네비게이션
│   │   ├── home_screen.dart             # 홈 화면
│   │   ├── evolution_screen.dart       # 진화 화면
│   │   ├── battle_screen.dart          # 배틀 화면
│   │   └── share_screen.dart          # 공유 화면
│   └── widgets/                   # 재사용 가능한 위젯
│       ├── status_bar.dart        # 상태바 위젯
│       ├── pet_button.dart        # 버튼 위젯
│       ├── glass_card.dart        # 글래스모피즘 카드
│       ├── pet_image_animation.dart    # 펫 이미지 애니메이션
│       ├── sleeping_pet_animation.dart # 잠자는 애니메이션
│       └── pet_card.dart          # 펫 카드
│
└── main.dart                      # 앱 진입점
```

---

## 레이어별 상세 분석

### 1. Domain 레이어 (비즈니스 로직)

Domain 레이어는 **순수 Dart**로 작성되어 있으며, Flutter나 외부 패키지에 의존하지 않습니다.

#### 엔티티 (Entities)

**Pet** (`domain/entities/pet.dart`)
```dart
class Pet {
  final String id;              // 고유 ID
  final int hunger;             // 배고픔 (0~100)
  final int happiness;          // 행복도 (0~100)
  final int stamina;            // 체력 (0~100)
  final int level;              // 레벨
  final int exp;                // 경험치
  final int evolutionStage;    // 진화 단계 (0~4)
  final int lastUpdated;        // 마지막 업데이트 시간 (타임스탬프)
}
```

**특징:**
- 불변 객체 (immutable)
- `copyWith()` 메서드로 상태 변경
- 비즈니스 로직의 핵심 모델

#### 리포지토리 인터페이스 (Repositories)

**PetRepository** (`domain/repositories/pet_repository.dart`)
```dart
abstract class PetRepository {
  Future<bool> hasPet(String id);
  Future<Pet> getPet(String id);
  Future<void> savePet(Pet pet);
  Future<void> updatePet(Pet pet);
  Future<List<Pet>> getAllPets();
}
```

**특징:**
- Domain 레이어에서 인터페이스만 정의
- 구현은 Data 레이어에서 담당
- 의존성 역전 원칙 준수

#### 유스케이스 (UseCases)

각 유스케이스는 단일 비즈니스 로직을 캡슐화합니다.

**UpdatePetStateUseCase**
- 시간 경과에 따른 상태 감소
- 규칙: 1시간당 hunger -2, happiness -1

**FeedPetUseCase**
- 먹이 주기 액션
- 규칙: hunger +10 (최대 100)

**PlayPetUseCase**
- 놀아주기 액션
- 규칙: happiness +10 (최대 100)

**SleepPetUseCase**
- 재우기 액션
- 규칙: stamina +10 (최대 100)

**CreateDefaultPetUseCase**
- 기본 Pet 생성
- 초기값: 모든 수치 100, level 1, evolutionStage 0

**EvolvePetUseCase**
- 진화 조건 확인 및 실행
- 진화 조건:
  - Stage 2: level >= 3 && happiness > 70
  - Stage 3: level >= 5 && hunger < 30
  - Stage 4: level >= 8

**CheckNotificationUseCase**
- 알림 발송 조건 확인
- 알림 조건:
  - hunger < 30 → "나 너무 배고파..."
  - happiness < 30 → "나 심심해..."
  - 6시간 미접속 → "오늘 나 안 볼거야?"
- 제한: 하루 최대 3회

### 2. Data 레이어 (데이터 구현)

Data 레이어는 Domain의 인터페이스를 구현하고, 실제 데이터 저장/조회를 담당합니다.

#### 모델 (Models)

**PetModel** (`data/models/pet_model.dart`)
```dart
@HiveType(typeId: 0)
class PetModel extends Pet {
  // Hive 필드 어노테이션
  @HiveField(0) final String id;
  @HiveField(1) final int hunger;
  // ...
}
```

**특징:**
- Domain의 `Pet` 엔티티를 확장
- Hive 저장을 위한 어노테이션
- `fromEntity()`, `toEntity()` 메서드로 변환

#### 데이터소스 (DataSources)

**PetLocalDataSource** (`data/datasource/pet_local_datasource.dart`)
- Hive Box를 사용한 로컬 저장소 접근
- Box 이름: `'pets'` (HiveConstants.petBoxName)
- 메서드: `init()`, `getPet()`, `savePet()`, `updatePet()`, `getAllPets()`

**NotificationLocalDataSource**
- 알림 기록 및 접속 시간 저장
- 일일 알림 횟수 자동 초기화 로직 포함

#### 리포지토리 구현 (Repository Implementations)

**PetRepositoryImpl** (`data/repository/pet_repository_impl.dart`)
- `PetRepository` 인터페이스 구현
- `PetLocalDataSource` 사용
- Domain Entity ↔ Data Model 변환 처리

**특징:**
- Domain의 추상화된 인터페이스를 실제 구현
- 데이터 변환 로직 포함
- 에러 처리 (Pet 없을 때 예외 발생)

#### 데이터 서비스 (Services)

**NotificationService**
- `flutter_local_notifications`를 사용한 알림 발송
- Android/iOS 알림 권한 요청 및 처리

**WidgetService**
- `home_widget`을 사용한 홈 화면 위젯 업데이트
- Pet 데이터를 위젯에 전달

### 3. Presentation 레이어 (UI)

Presentation 레이어는 Flutter 위젯으로 구성되며, Riverpod을 사용한 상태 관리가 핵심입니다.

#### 프로바이더 (Providers)

**pet_provider.dart** (`presentation/providers/pet_provider.dart`)

의존성 주입을 위한 Provider들:
```dart
// DataSource Provider
petLocalDataSourceProvider

// Repository Provider
petRepositoryProvider

// UseCase Providers
updatePetStateUseCaseProvider
feedPetUseCaseProvider
playPetUseCaseProvider
sleepPetUseCaseProvider
createDefaultPetUseCaseProvider
evolvePetUseCaseProvider
checkNotificationUseCaseProvider

// Service Providers
notificationServiceProvider
widgetServiceProvider

// StateNotifier Provider
petNotifierProvider (Family Provider)
```

**PetNotifier** (StateNotifier)
- Pet 상태를 관리하는 핵심 클래스
- `AsyncValue<Pet>` 상태 관리
- 앱 실행 시 자동 상태 업데이트
- Feed/Play/Sleep 액션 처리
- 자동 진화 체크 및 알림 체크

#### 화면 (Screens)

**MainNavigationScreen**
- 하단 네비게이션 바를 통한 화면 전환
- `IndexedStack`으로 화면 상태 유지
- 4개 화면: Home, Evolution, Battle, Share

**HomeScreen**
- 메인 화면
- Pet 상태 표시 (StatusBar)
- Feed/Play/Sleep 액션 버튼
- Pet 이미지 애니메이션
- 실시간 상태 업데이트

**EvolutionScreen**
- 진화 상태 및 조건 표시

**BattleScreen**
- 간단한 턴제 전투 시스템

**ShareScreen**
- Pet 정보 공유

#### 위젯 (Widgets)

**StatusBar**
- Pet 상태(hunger, happiness, stamina) 시각화
- 애니메이션 효과 포함

**PetButton**
- 액션 버튼 (primary/secondary 변형)
- 탭 애니메이션 효과

**GlassCard**
- 글래스모피즘 효과 카드
- 반투명 배경 및 블러 효과

**PetImageAnimation**
- Pet 상태에 따른 이미지 애니메이션
- 타입: sleeping, hungry, normal

### 4. Core 레이어 (공통 유틸리티)

**상수 (Constants)**
- `HiveConstants`: Hive Box 이름 및 TypeId
- `NotificationConstants`: 알림 관련 상수

**테마 (Theme)**
- `AppTheme`: Material 테마 정의
- `AppColors`: 색상 팔레트 및 그라디언트

**유틸리티 (Utils)**
- `EvolutionHelper`: 진화 단계별 이름, 아이콘, 색상 반환
- `Validators`: 값 유효성 검사

---

## 데이터 흐름

### 앱 시작 시 데이터 흐름

```
1. main() 함수 실행
   ↓
2. Hive 초기화
   - Hive.initFlutter()
   - PetModelAdapter 등록
   - PetLocalDataSource.init() (Box 열기)
   ↓
3. 알림 서비스 초기화
   - NotificationService.init()
   - 권한 요청
   ↓
4. 위젯 서비스 초기화
   - WidgetService.initialize()
   ↓
5. ProviderScope로 앱 래핑
   ↓
6. MainNavigationScreen 표시
   ↓
7. HomeScreen 로드
   ↓
8. PetNotifier 초기화
   - _loadPet() 호출
   ↓
9. Pet 로드 프로세스
   a. Pet 존재 여부 확인
   b. 없으면 기본 Pet 생성
   c. 마지막 접속 시간 업데이트
   d. 시간 경과에 따른 상태 업데이트
   e. 진화 체크 및 실행
   f. 위젯 업데이트
   g. 알림 체크
   ↓
10. UI에 Pet 상태 표시
```

### 사용자 액션 시 데이터 흐름 (예: Feed)

```
1. 사용자가 Feed 버튼 클릭
   ↓
2. HomeScreen._handleFeed() 호출
   ↓
3. PetNotifier.feed() 호출
   ↓
4. FeedPetUseCase 실행
   - 현재 Pet 조회
   - hunger +10 (최대 100)
   - lastUpdated 업데이트
   - Pet 저장
   ↓
5. PetNotifier._updateAndEvolve() 호출
   - EvolvePetUseCase 실행 (진화 체크)
   - WidgetService.updatePetWidget() 호출
   - 알림 체크
   ↓
6. PetNotifier 상태 업데이트
   - state = AsyncValue.data(updatedPet)
   ↓
7. UI 자동 리빌드 (Riverpod watch)
   ↓
8. 상태바 및 이미지 업데이트
```

---

## 상태 관리

### Riverpod 아키텍처

PocketFriend는 **Riverpod**을 사용한 상태 관리 시스템을 구축했습니다.

#### Provider 계층 구조

```
DataSource Providers
    ↓
Repository Providers
    ↓
UseCase Providers
    ↓
Service Providers
    ↓
StateNotifier Provider (PetNotifier)
    ↓
UI (ConsumerWidget/ConsumerStatefulWidget)
```

#### PetNotifier의 역할

**PetNotifier**는 앱의 핵심 상태 관리자입니다:

1. **상태 관리**
   - `AsyncValue<Pet>` 타입으로 Pet 상태 관리
   - 로딩, 데이터, 에러 상태 처리

2. **자동 업데이트**
   - 앱 실행 시 자동으로 상태 업데이트
   - 시간 경과에 따른 상태 감소 반영

3. **액션 처리**
   - `feed()`, `play()`, `sleep()` 메서드
   - 각 액션 후 자동 진화 체크 및 알림 체크

4. **위젯 동기화**
   - 상태 변경 시 홈 화면 위젯 자동 업데이트

#### 상태 업데이트 흐름

```dart
// 1. 상태 초기화
state = AsyncValue.loading()

// 2. 데이터 로드
final pet = await repository.getPet(petId)
state = AsyncValue.data(pet)

// 3. 액션 후 상태 업데이트
final updatedPet = await feedPetUseCase(petId)
state = AsyncValue.data(updatedPet)

// 4. 에러 처리
catch (e, stackTrace) {
  state = AsyncValue.error(e, stackTrace)
}
```

---

## 주요 기능

### 1. Pet 상태 관리

#### 상태 속성
- **hunger** (배고픔): 0~100
- **happiness** (행복도): 0~100
- **stamina** (체력): 0~100
- **level** (레벨): 경험치 기반
- **exp** (경험치): 액션 수행 시 증가
- **evolutionStage** (진화 단계): 0~4

#### 시간 경과에 따른 자동 감소
- **규칙**: 1시간당 hunger -2, happiness -1
- **구현**: `UpdatePetStateUseCase`
- **트리거**: 앱 실행 시, 상태 조회 시

#### 액션을 통한 상태 회복
- **Feed**: hunger +10
- **Play**: happiness +10
- **Sleep**: stamina +10

### 2. 진화 시스템

#### 진화 단계
- **Stage 0**: 알
- **Stage 1**: 유년기
- **Stage 2**: 성장기 (level >= 3 && happiness > 70)
- **Stage 3**: 성체 (level >= 5 && hunger < 30)
- **Stage 4**: 완전체 (level >= 8)

#### 진화 조건 확인
- `EvolvePetUseCase`에서 자동 체크
- 액션 수행 후, 앱 실행 시 자동 실행
- 한 단계씩만 진화 (점진적 진화)

### 3. 알림 시스템

#### 알림 조건
1. **미접속 알림** (우선순위 1)
   - 조건: 6시간 이상 미접속
   - 메시지: "오늘 나 안 볼거야?"

2. **배고픔 알림** (우선순위 2)
   - 조건: hunger < 30
   - 메시지: "나 너무 배고파..."

3. **행복도 알림** (우선순위 3)
   - 조건: happiness < 30
   - 메시지: "나 심심해..."

#### 알림 제한
- 하루 최대 3회 알림 발송
- 일일 알림 횟수 자동 초기화 (자정)

### 4. 홈 화면 위젯

#### 기능
- Pet 상태를 홈 화면에 표시
- 앱을 열지 않아도 상태 확인 가능
- 상태 변경 시 자동 업데이트

#### 구현
- Android: App Widget (Kotlin)
- iOS: Widget Extension (Swift)
- Flutter: `home_widget` 패키지 사용

### 5. 배틀 시스템

#### 기능
- 간단한 턴제 전투
- Attack/Defend 액션
- 승리 시 경험치 획득

---

## 의존성 주입

### Riverpod Provider 구조

의존성 주입은 Riverpod Provider를 통해 이루어집니다.

#### Provider 정의 위치
- `presentation/providers/pet_provider.dart`

#### Provider 계층

```dart
// 1단계: DataSource
final petLocalDataSourceProvider = Provider<PetLocalDataSource>((ref) {
  return PetLocalDataSource();
});

// 2단계: Repository
final petRepositoryProvider = Provider<PetRepository>((ref) {
  final dataSource = ref.watch(petLocalDataSourceProvider);
  return PetRepositoryImpl(dataSource);
});

// 3단계: UseCase
final feedPetUseCaseProvider = Provider<FeedPetUseCase>((ref) {
  final repository = ref.watch(petRepositoryProvider);
  return FeedPetUseCase(repository);
});

// 4단계: StateNotifier
final petNotifierProvider = StateNotifierProvider.family<...>((ref, petId) {
  return PetNotifier(
    repository: ref.watch(petRepositoryProvider),
    feedPetUseCase: ref.watch(feedPetUseCaseProvider),
    // ...
  );
});
```

#### 의존성 해결 순서

1. **DataSource 생성**: 가장 저수준 의존성
2. **Repository 생성**: DataSource 주입
3. **UseCase 생성**: Repository 주입
4. **StateNotifier 생성**: 모든 UseCase 주입
5. **UI에서 사용**: StateNotifier 구독

---

## 비즈니스 로직

### 상태 업데이트 규칙

#### 시간 경과에 따른 감소
```dart
// 1시간당 감소량
hunger -= elapsedHours * 2
happiness -= elapsedHours * 1
stamina -= 0  // 체력은 감소하지 않음

// 값 범위 제한
hunger = hunger.clamp(0, 100)
happiness = happiness.clamp(0, 100)
```

#### 액션에 따른 증가
```dart
// Feed 액션
hunger = (hunger + 10).clamp(0, 100)

// Play 액션
happiness = (happiness + 10).clamp(0, 100)

// Sleep 액션
stamina = (stamina + 10).clamp(0, 100)
```

### 진화 규칙

```dart
// 진화 조건 확인 순서 (높은 단계부터)
if (level >= 8 && evolutionStage < 4) {
  evolutionStage = 4;  // 완전체
} else if (level >= 5 && hunger < 30 && evolutionStage < 3) {
  evolutionStage = 3;  // 성체
} else if (level >= 3 && happiness > 70 && evolutionStage < 2) {
  evolutionStage = 2;  // 성장기
}
```

### 알림 규칙

```dart
// 우선순위 기반 알림 체크
if (elapsedHours >= 6) {
  message = "오늘 나 안 볼거야?";
} else if (hunger < 30) {
  message = "나 너무 배고파...";
} else if (happiness < 30) {
  message = "나 심심해...";
}

// 일일 제한 확인
if (todayNotificationCount >= 3) {
  return null;  // 알림 발송 안 함
}
```

---

## 앱 생명주기

### 앱 시작 시 (main.dart)

```dart
void main() async {
  // 1. Flutter 바인딩 초기화
  WidgetsFlutterBinding.ensureInitialized();
  
  // 2. Hive 초기화
  await _initHive();
  
  // 3. 알림 서비스 초기화
  await _initNotifications();
  
  // 4. 위젯 서비스 초기화
  await _initWidget();
  
  // 5. 앱 실행
  runApp(ProviderScope(child: MyApp()));
}
```

### 화면 로드 시 (HomeScreen)

```dart
// 1. PetNotifier 초기화
final petNotifier = ref.watch(petNotifierProvider('default-pet'));

// 2. PetNotifier._loadPet() 자동 실행
//    - Pet 존재 여부 확인
//    - 기본 Pet 생성 (없으면)
//    - 상태 업데이트
//    - 진화 체크
//    - 위젯 업데이트
//    - 알림 체크

// 3. UI에 상태 표시
petNotifier.when(
  loading: () => CircularProgressIndicator(),
  error: (err, stack) => ErrorWidget(err),
  data: (pet) => PetContent(pet),
)
```

### 액션 수행 시

```dart
// 1. 사용자 액션 (예: Feed 버튼 클릭)
onPressed: () {
  ref.read(petNotifierProvider('default-pet').notifier).feed();
}

// 2. PetNotifier.feed() 실행
//    - FeedPetUseCase 호출
//    - 상태 업데이트
//    - _updateAndEvolve() 호출
//      - 진화 체크
//      - 위젯 업데이트
//      - 알림 체크
//    - 상태 업데이트

// 3. UI 자동 리빌드 (Riverpod watch)
```

---

## 데이터 저장 구조

### Hive Box 구조

#### Pet Box (`'pets'`)
- **키**: Pet ID (String)
- **값**: PetModel (HiveObject)
- **TypeId**: 0

#### Notification Box (`'notifications'`)
- 알림 기록 및 접속 시간 저장
- 일일 알림 횟수 관리

### 데이터 모델 변환

```
Domain Entity (Pet)
    ↕ (fromEntity/toEntity)
Data Model (PetModel)
    ↕ (Hive)
로컬 저장소 (Hive Box)
```

---

## 에러 처리

### 현재 구현
- 기본 `Exception` 사용
- Domain 레이어에 커스텀 에러 클래스 없음

### 에러 처리 위치
- **Repository**: Pet 없을 때 `Exception` 발생
- **Notifier**: try-catch로 에러 처리, `AsyncValue.error()`로 상태 업데이트
- **UI**: `AsyncValue.when()`으로 에러 상태 처리

---

## 확장성 고려사항

### 현재 구조의 장점
1. **Clean Architecture**: 레이어 분리로 유지보수 용이
2. **UseCase 패턴**: 비즈니스 로직 재사용 가능
3. **의존성 주입**: 테스트 및 교체 용이
4. **Family Provider**: 여러 Pet 지원 가능

### 개선 가능한 부분
1. **커스텀 에러 클래스**: Domain 레이어에 에러 정의
2. **Pet 이름 필드**: 현재 하드코딩된 "Luna"
3. **테스트 코드**: 단위 테스트 및 통합 테스트 부재
4. **레벨업 시스템**: 경험치 기반 레벨업 로직 명확화 필요

---

## 참고 자료

- **디자인 원본**: `design/` 폴더의 React 컴포넌트
- **아키텍처 규칙**: `.cursor/rules/flutter-clean-architecture.mdc`
- **UI 가이드**: `docs/UI.md`

---

## 결론

PocketFriend는 Clean Architecture 패턴을 엄격히 따르는 잘 구조화된 Flutter 앱입니다. 

**핵심 특징:**
- ✅ 레이어 분리 및 의존성 역전 원칙 준수
- ✅ Domain 레이어 순수성 유지
- ✅ UseCase 패턴으로 비즈니스 로직 캡슐화
- ✅ Riverpod을 통한 효율적인 상태 관리
- ✅ 확장 가능한 아키텍처 구조

**주요 기능:**
- Pet 상태 관리 및 자동 업데이트
- 진화 시스템
- 알림 시스템
- 홈 화면 위젯
- 배틀 시스템

이 문서는 앱의 구조와 작동 방식을 이해하는 데 도움이 되도록 작성되었습니다.
