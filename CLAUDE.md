# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

```bash
# Install dependencies
flutter pub get

# Run the app
flutter run

# Analyze code (run after every change)
flutter analyze

# Build debug APK
flutter build apk --debug

# Run tests
flutter test
```

**Always run `flutter analyze` after making code changes.** If modifying entities/models, also verify `flutter build apk --debug` succeeds.

## Git Workflow & Commits

See **[GIT_WORKFLOW.md](./GIT_WORKFLOW.md)** for:
- **Branch strategy**: main (production) ← develop ← feature/bugfix/hotfix
- **Commit message format**: `<type>(<scope>): <subject>` (Conventional Commits)
- **Type**: feat, fix, docs, style, refactor, test, chore, ci, perf
- **Branch naming**: `feature/기능명`, `bugfix/버그명`, `hotfix/긴급-사항`

**Before committing:**
1. Switch to correct branch (develop for features, or create feature/xxx)
2. Run `flutter analyze` and `flutter test`
3. Write clear commit message following Conventional Commits format
4. Example: `feat(pet): mood 8단계 우선순위 로직 추가`

## Architecture

PocketFriend is a Flutter Tamagotchi-style pet app using **Clean Architecture** with Riverpod state management. The app tracks user health activity (steps, exercise, phone idle time) and uses it to affect a virtual pet's state.

### Layer Structure

```
lib/
├── core/           # Constants, theme, utilities (shared across layers)
├── domain/         # Pure Dart — no Flutter/external dependencies
│   ├── entities/   # Pet, ActivityData, BattleHistory, DailyGoals, EvolutionType, PhoneUsage
│   ├── repositories/ # Abstract interfaces only
│   └── usecases/   # ~20 use cases encapsulating all business logic
├── data/           # Implementation layer
│   ├── models/     # Hive models extending domain entities (PetModel: @HiveType(typeId: 0))
│   ├── datasources/ # Hive, HealthKit/Google Fit, PhoneUsage access
│   ├── repositories/ # Repository implementations
│   └── services/   # NotificationService, WidgetService, BackgroundService
└── presentation/
    ├── providers/  # Riverpod providers (ViewModel role)
    ├── screens/    # HomeScreen, BattleScreen, EvolutionScreen, ShareScreen
    └── widgets/    # Reusable UI components
```

**Dependency direction**: `Presentation → Domain ← Data`. Presentation must not directly import Data models.

### Pet State System

The core `Pet` entity tracks:
- **Stats**: `hunger` (0–100), `happiness` (0–100), `stamina` (0–100)
- **Mood**: auto-calculated from stats — 10 types: `happy`, `sleepy`, `hungry`, `bored`, `normal`, `energetic`, `tired`, `full`, `anxious`, `satisfied`
- **Evolution**: 3 types (`active`, `restful`, `balanced`) determined by activity patterns
- **Daily goals**: feed count, sleep hours, alternative action limits

### Key Patterns

**UseCase invocation** — all business logic goes through UseCases, never directly in providers or UI:
```dart
class FeedPetUseCase {
  final PetRepository repository;
  FeedPetUseCase(this.repository);
  Future<Pet> call(String petId) async { ... }
}
```

**Hive initialization** — always check box is open before accessing:
```dart
Future<void> _ensureInitialized() async {
  if (_box == null) _box = await Hive.openBox<PetModel>('pets');
}
```
All Hive adapter registrations happen in `main.dart` before `runApp`.

**Widget sync** — all pet state changes must go through `_updateAndEvolve()` in `pet_provider.dart`, which handles the home screen widget update exactly once. Never call `widgetService.updatePetWidget()` separately after `_updateAndEvolve()`. Widget update failures must be silently caught (widget may not be installed).

**Background processing** — WorkManager (`background_service.dart`) handles scheduled tasks. Changes to pet state from background must also sync the widget.

### Checklist for Common Changes

**Adding a field to Pet entity:**
- [ ] Update `Pet` in `domain/entities/`
- [ ] Update `PetModel` with `@HiveField(N)` (new unique field number)
- [ ] Update `copyWith`, `fromJson`/`toJson`, `fromHive` in `PetModel`
- [ ] Run `flutter analyze`

**Adding an Enum value:**
- [ ] Add cases to all `switch` statements (check for `non_exhaustive_switch_statement`)
- [ ] Add Korean string to `AppStrings`

**Adding a UseCase:**
- [ ] Create UseCase in `domain/usecases/`
- [ ] Add Provider in `presentation/providers/`
- [ ] Wire dependency injection through Riverpod

### Naming Conventions

| Type | Convention | Example |
|------|-----------|---------|
| Files | `snake_case` | `pet_repository.dart` |
| Entities | `PascalCase` noun | `Pet` |
| Models | `{Entity}Model` | `PetModel` |
| Repositories | `{Entity}Repository` / `{Entity}RepositoryImpl` | `PetRepositoryImpl` |
| DataSources | `{Entity}LocalDataSource` | `PetLocalDataSource` |
| Providers | `{entity}Provider` / `{Entity}Notifier` | `petNotifierProvider` |
| Screens | `{Name}Screen` | `HomeScreen` |

### Note on Duplicate Directories

There are both `lib/data/datasource/` (singular, legacy) and `lib/data/datasources/` (plural, current) directories. New datasource code goes in `datasources/` (plural).


한국어로 응답해줘.
모든 작업이 끝나고 유닛 테스트 가능한 부분은 작성해줘

---

## Kotlin (Android Native) 가이드라인

이 프로젝트의 Android 네이티브 코드(`android/` 폴더)는 Kotlin으로 작성된다.
실무 수준의 아래 규칙을 반드시 준수한다.

### 명명 규칙 (Naming Conventions)

| 종류 | 규칙 | 예시 |
|------|------|------|
| 클래스 / 인터페이스 | `PascalCase` | `PetWidgetProvider`, `WidgetRepository` |
| 함수 / 변수 | `camelCase` | `updateAppWidget()`, `animationHandler` |
| 상수 (`const val`) | `SCREAMING_SNAKE_CASE` | `ANIMATION_UPDATE_INTERVAL` |
| 패키지 | `lowercase.dot.separated` | `com.example.pocketfriend` |
| 파일 | 클래스명과 동일 | `PetWidgetProvider.kt` |
| Boolean 변수 | `is` / `has` / `can` 접두어 | `isAnimating`, `hasPermission` |
| 람다 파라미터 | 의미 있는 단어 (it 남용 금지) | `ids.forEach { id -> ... }` |

### 아키텍처 패턴

**Android 네이티브 레이어 책임 분리:**
- `AppWidgetProvider` — UI 갱신 전용, 비즈니스 로직 없음
- `Repository` — 데이터 소스 추상화 (SharedPreferences, DB, Network)
- `UseCase` / `Helper` — 단일 책임 비즈니스 로직
- `ViewModel` (Compose/Fragment 사용 시) — UI 상태 보유, LiveData/StateFlow 노출

**의존 방향:** UI → ViewModel → UseCase → Repository → DataSource

### Kotlin 관용 표현 (Idioms)

**null 처리 — Elvis 연산자와 let 활용:**
```kotlin
// Bad
if (value != null) doSomething(value) else doDefault()

// Good
value?.let { doSomething(it) } ?: doDefault()
val result = nullable?.toIntOrNull() ?: defaultValue
```

**when 표현식 — 모든 분기를 명시적으로:**
```kotlin
// sealed class / enum은 반드시 else 없이 전체 케이스 나열
val text = when (mood) {
    "hungry"   -> "배고픔"
    "sleepy"   -> "졸림"
    "happy"    -> "기쁨"
    else       -> "보통"  // String처럼 소진 불가 타입만 else 허용
}
```

**data class — 불변 모델에 사용:**
```kotlin
data class PetWidgetState(
    val level: Int = 1,
    val mood: String = "normal",
    val hunger: Int = 100,
    val happiness: Int = 100,
    val stamina: Int = 100,
)
```

**sealed class — 상태/결과 표현:**
```kotlin
sealed class WidgetResult {
    data class Success(val state: PetWidgetState) : WidgetResult()
    data class Error(val message: String) : WidgetResult()
    object Loading : WidgetResult()
}
```

**확장 함수 — 유틸 로직 분리:**
```kotlin
// Bad: 클래스 내부에 Helper 로직 혼재
// Good: 확장 함수로 분리
fun String?.toMoodOrDefault(default: String = "normal"): String =
    if (this != null && isKnownMood(this)) this else default

fun SharedPreferences.getIntOrDefault(key: String, default: Int): Int =
    getString(key, null)?.toIntOrNull() ?: default
```

**object / companion object — 싱글톤 상수·팩토리:**
```kotlin
companion object {
    private const val PREFS_NAME = "HomeWidgetPreferences"
    private const val TAG = "PetWidgetProvider"

    fun newIntent(context: Context): Intent =
        Intent(context, PetWidgetProvider::class.java)
}
```

### 코루틴 (Coroutines) — 비동기 처리 표준

```kotlin
// ViewModel에서
viewModelScope.launch {
    val result = withContext(Dispatchers.IO) { repository.loadState() }
    _uiState.value = result
}

// suspend 함수는 반드시 Dispatcher 명시
suspend fun loadWidgetData(context: Context): PetWidgetState =
    withContext(Dispatchers.IO) {
        // IO 작업
    }

// 예외는 runCatching 또는 try/catch (GlobalScope 절대 사용 금지)
val result = runCatching { repository.fetch() }
    .getOrElse { PetWidgetState() }
```

### 에러 처리

```kotlin
// 외부 경계(IO, 시스템 API)에서만 try/catch
// 내부 로직은 sealed Result로 전파
fun updateWidget(context: Context, id: Int) {
    try {
        val state = readState(context)
        applyToViews(state, id)
    } catch (e: Exception) {
        Log.e(TAG, "위젯 업데이트 실패", e)
        // 위젯은 설치 안 됐을 수 있으므로 silently fail
    }
}
```

### 불변성 (Immutability)

```kotlin
// val 우선, var는 꼭 필요한 경우만
val level: Int           // Good
var isAnimating: Boolean // 상태 변경이 필요한 경우만 var

// 컬렉션: List/Map (읽기 전용) 기본, MutableList는 내부 구현에서만
private val _items = mutableListOf<String>()
val items: List<String> get() = _items
```

### 로깅 규칙

```kotlin
// 태그는 companion object 상수로 통일
private const val TAG = "PetWidgetProvider"

Log.d(TAG, "상세 정보: $value")   // 디버그
Log.w(TAG, "예상치 못한 상태")     // 경고
Log.e(TAG, "오류 발생", exception) // 에러 (예외 객체 반드시 포함)

// 민감 정보(사용자 데이터)는 절대 로깅 금지
```

### Android 위젯 특화 패턴

**RemoteViews 업데이트 — 원자적으로:**
```kotlin
// 전체 뷰를 한 번에 구성 후 단일 updateAppWidget 호출
val views = RemoteViews(context.packageName, R.layout.pet_widget).apply {
    setImageViewResource(R.id.pet_image, imageResId)
    setTextViewText(R.id.pet_level, "Lv.$level")
    setTextViewText(R.id.pet_mood, moodText)
    setOnClickPendingIntent(R.id.widget_container, pendingIntent)
}
appWidgetManager.updateAppWidget(appWidgetId, views)
```

**Handler 메모리 누수 방지:**
```kotlin
// ApplicationContext 사용 (Activity Context 절대 사용 금지)
val appContext = context.applicationContext
animationHandler = Handler(Looper.getMainLooper())

// onDisabled/onDeleted에서 반드시 정리
override fun onDisabled(context: Context) {
    stopAnimationUpdates()
    super.onDisabled(context)
}
```

**PendingIntent — 항상 FLAG_IMMUTABLE 포함 (Android 12+):**
```kotlin
PendingIntent.getActivity(
    context, requestCode, intent,
    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
)
```

### Kotlin 안티패턴 (절대 사용 금지)

```kotlin
// ❌ !! 연산자 — NPE 위험
val value = nullable!!.doSomething()

// ❌ GlobalScope — 수명주기 관리 불가
GlobalScope.launch { ... }

// ❌ Thread.sleep — 코루틴에서는 delay() 사용
Thread.sleep(1000)

// ❌ runBlocking on main thread — ANR 위험
runBlocking { heavyWork() }

// ❌ 과도한 it 중첩
list.filter { it.isNotEmpty() }.map { it.trim() }.forEach { println(it) }
// ✅ 명시적 파라미터명
list.filter { item -> item.isNotEmpty() }
    .map { item -> item.trim() }
    .forEach { item -> println(item) }
```

### Kotlin 유닛 테스트 패턴

```kotlin
// 테스트 파일: src/test/kotlin/.../{ClassName}Test.kt
class PetMoodResolverTest {
    private lateinit var resolver: PetMoodResolver

    @BeforeEach
    fun setUp() {
        resolver = PetMoodResolver()
    }

    @Test
    fun `hunger 20 이하면 hungry 반환`() {
        val result = resolver.calculate(hunger = 20, happiness = 80, stamina = 80)
        assertEquals("hungry", result)
    }

    @Test
    fun `모든 수치 90 이상이면 energetic 반환`() {
        val result = resolver.calculate(hunger = 90, happiness = 90, stamina = 90)
        assertEquals("energetic", result)
    }
}
```

**테스트 대상 우선순위:**
1. 순수 비즈니스 로직 함수 (mood 계산, imageType 결정, 한국어 변환)
2. Repository 단위 (SharedPreferences mock)
3. UI 레이어는 통합 테스트로 대체

### Kotlin 코드 작성 후 체크리스트

- [ ] `var` 대신 `val` 사용 가능한지 검토
- [ ] `!!` 연산자 없는지 확인
- [ ] `when` 표현식에서 누락된 분기 없는지 확인
- [ ] ApplicationContext vs ActivityContext 올바르게 사용했는지 확인
- [ ] 리소스(Handler, Coroutine) 해제 코드 존재하는지 확인
- [ ] Log 태그가 companion object 상수인지 확인
- [ ] PendingIntent에 FLAG_IMMUTABLE 포함했는지 확인 (Android 12+)
