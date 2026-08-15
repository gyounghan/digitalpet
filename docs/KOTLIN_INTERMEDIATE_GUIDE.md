# Kotlin 중급 개발자 가이드 (PocketFriend 프로젝트 기반)

> 이 문서는 PocketFriend 프로젝트의 실제 Android 네이티브 코드(`PetWidgetProvider.kt`)에서 사용된
> Kotlin 문법, Android API, 설계 패턴을 중심으로 정리한 중급 개발자 필수 지식입니다.

---

## 목차

1. [companion object와 상수 관리](#1-companion-object와-상수-관리)
2. [Nullable 안전 처리](#2-nullable-안전-처리)
3. [when 표현식](#3-when-표현식)
4. [문자열 템플릿과 로깅](#4-문자열-템플릿과-로깅)
5. [AppWidgetProvider 생명주기](#5-appwidgetprovider-생명주기)
6. [RemoteViews 위젯 렌더링](#6-remoteviews-위젯-렌더링)
7. [SharedPreferences와 다중 저장소](#7-sharedpreferences와-다중-저장소)
8. [PendingIntent와 FLAG_IMMUTABLE](#8-pendingintent와-flag_immutable)
9. [Handler 기반 애니메이션](#9-handler-기반-애니메이션)
10. [타입 안전 변환](#10-타입-안전-변환)
11. [Collection 안전 접근](#11-collection-안전-접근)
12. [Context 사용 원칙](#12-context-사용-원칙)
13. [try-catch와 실무 예외 처리](#13-try-catch와-실무-예외-처리)
14. [Gradle 설정과 desugaring](#14-gradle-설정과-desugaring)
15. [중급에서 고급으로 가기 위해 알아야 할 것](#15-중급에서-고급으로-가기-위해-알아야-할-것)

---

## 1. companion object와 상수 관리

### 개념
`companion object`는 Java의 `static`에 해당. 클래스 인스턴스 없이 접근 가능한 멤버를 정의.

### 프로젝트 사용 예시

```kotlin
class PetWidgetProvider : AppWidgetProvider() {
    companion object {
        private const val TAG = "PetWidgetProvider"
        private const val HOME_WIDGET_PREFS = "HomeWidgetPreferences"
        private const val LEGACY_WIDGET_PREFS = "HomeWidget"
        private const val ANIMATION_UPDATE_INTERVAL = 800L

        // 애니메이션 상태 (인스턴스 간 공유)
        private var animationHandler: Handler? = null
        private var animationRunnable: Runnable? = null
        private var isAnimating = false
    }
}
```

### 왜 중요한가

| 용도 | 설명 | 예시 |
|------|------|------|
| **상수 정의** | `const val`로 컴파일 타임 상수 | `TAG`, `PREFS_NAME` |
| **상태 공유** | 여러 위젯 인스턴스가 같은 상태 참조 | `animationHandler` |
| **팩토리 메서드** | 인스턴스 생성 로직 분리 | `fun newInstance()` |

### 실무 규칙

```kotlin
// ✅ Good: 상수는 SCREAMING_SNAKE_CASE
private const val MAX_RETRY_COUNT = 3

// ✅ Good: 변경 가능한 공유 상태는 var + nullable
private var handler: Handler? = null

// ❌ Bad: 상수에 val 사용 (const가 아니면 런타임 초기화)
private val TAG = "SomeClass"  // const val이어야 함
```

---

## 2. Nullable 안전 처리

### Kotlin의 가장 중요한 특징

Kotlin은 **null 안전 타입 시스템**을 가짐. `?`가 없으면 null 불가.

### 프로젝트 사용 예시

```kotlin
// Safe call operator (?.)
// SharedPreferences에서 값이 없을 수 있으므로 nullable
val hunger = prefs.getString("hunger", null)?.toIntOrNull() ?: 50

// Elvis 연산자 (?:)
// null이면 기본값 사용
val level = prefs.getString("level", null)?.toIntOrNull() ?: 1

// let을 활용한 null 체크
animationHandler?.let { handler ->
    animationRunnable?.let { runnable ->
        handler.removeCallbacks(runnable)
    }
}
```

### 핵심 패턴 비교

```kotlin
// ❌ Bad: Java 스타일 null 체크
if (value != null) {
    if (value.subValue != null) {
        doSomething(value.subValue)
    }
}

// ✅ Good: Kotlin 체이닝
value?.subValue?.let { doSomething(it) }

// ❌ Bad: !! 연산자 (NPE 위험)
val name = user!!.name

// ✅ Good: Elvis 연산자로 기본값
val name = user?.name ?: "Unknown"
```

### 실무에서 자주 쓰는 Nullable 패턴

```kotlin
// 1. toIntOrNull() - 안전한 타입 변환
val number: Int? = "abc".toIntOrNull()  // null (크래시 안 남)

// 2. orEmpty() - null이면 빈 컬렉션
val list = nullableList.orEmpty()

// 3. takeIf / takeUnless - 조건부 null 반환
val validAge = age.takeIf { it in 0..150 }  // 범위 밖이면 null
```

---

## 3. when 표현식

### 개념
Java의 `switch`보다 훨씬 강력. **표현식**이므로 값을 반환 가능.

### 프로젝트 사용 예시

```kotlin
// 1. 값 매핑 (문자열 → 문자열)
fun mapMoodToKoreanText(mood: String): String {
    return when (mood) {
        "happy"     -> "기쁨"
        "hungry"    -> "배고픔"
        "sleepy"    -> "졸림"
        "tired"     -> "피곤함"
        "bored"     -> "심심함"
        "energetic" -> "활기참"
        "full"      -> "배부름"
        "anxious"   -> "불안함"
        "satisfied" -> "만족함"
        "dead"      -> "사망"
        else        -> "보통"
    }
}

// 2. 브로드캐스트 액션 분기
override fun onReceive(context: Context, intent: Intent) {
    when (intent.action) {
        "es.antonborri.home_widget.UPDATE_WIDGET",
        "es.antonborri.home_widget.action.UPDATE" -> {
            // 위젯 업데이트 처리
        }
        "com.godsaengmon.app.ACTION_ANIMATION_UPDATE" -> {
            // 애니메이션 업데이트
        }
        else -> super.onReceive(context, intent)
    }
}

// 3. 이미지 프레임 수 결정
fun getImageCountForImageType(imageType: String): Int {
    return when (imageType) {
        "feed" -> 4
        else   -> 3
    }
}
```

### when의 고급 사용법 (중급 필수)

```kotlin
// 범위 체크
when (score) {
    in 90..100 -> "A"
    in 80..89  -> "B"
    in 70..79  -> "C"
    else       -> "F"
}

// 타입 체크 (is)
when (response) {
    is Success -> handleSuccess(response.data)
    is Error   -> handleError(response.message)
    is Loading -> showLoading()
}

// 조건식 (인자 없는 when)
when {
    hunger <= 10              -> "hungry"
    stamina <= 10             -> "tired"
    happiness >= 90           -> "happy"
    hunger >= 90              -> "full"
    else                      -> "normal"
}
```

### 주의사항

```kotlin
// ❌ Bad: enum/sealed class에서 else 사용 (새 값 추가 시 버그)
when (type) {
    Type.A -> "a"
    Type.B -> "b"
    else -> "unknown"  // Type.C 추가해도 컴파일 경고 없음
}

// ✅ Good: 모든 케이스 명시 (컴파일러가 누락 감지)
when (type) {
    Type.A -> "a"
    Type.B -> "b"
    Type.C -> "c"
}
```

---

## 4. 문자열 템플릿과 로깅

### 프로젝트 사용 예시

```kotlin
// 변수 삽입
Log.d(TAG, "위젯 업데이트: hunger=$hunger, happiness=$happiness")

// 표현식 삽입
Log.d(TAG, "이미지 리소스: ${resolveImageResourceName(imageType, frameIndex)}")

// 복잡한 표현식
Log.d(TAG, "상태: Lv.${level}, mood=${mood ?: "unknown"}")
```

### 로깅 실무 규칙

```kotlin
companion object {
    // ✅ TAG는 항상 companion object 상수
    private const val TAG = "PetWidgetProvider"
}

// ✅ 레벨별 사용 구분
Log.d(TAG, "디버그 정보: $value")         // 개발 중 상세 정보
Log.w(TAG, "예상치 못한 상태: $state")    // 경고 (앱은 계속 동작)
Log.e(TAG, "오류 발생", exception)        // 에러 (예외 객체 반드시 포함)

// ❌ 절대 금지: 민감 정보 로깅
Log.d(TAG, "사용자 토큰: $token")         // 보안 위험
```

---

## 5. AppWidgetProvider 생명주기

### 개념
Android 홈 화면 위젯의 기본 클래스. **BroadcastReceiver**를 상속.

### 프로젝트 사용 예시

```kotlin
class PetWidgetProvider : AppWidgetProvider() {

    // 위젯이 업데이트될 때 (주기적 + 수동)
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        for (appWidgetId in appWidgetIds) {
            updateAppWidget(context, appWidgetManager, appWidgetId)
        }
        startAnimationUpdates(context)
    }

    // 첫 번째 위젯이 추가될 때
    override fun onEnabled(context: Context) {
        super.onEnabled(context)
        startAnimationUpdates(context)
    }

    // 마지막 위젯이 제거될 때
    override fun onDisabled(context: Context) {
        stopAnimationUpdates()  // 리소스 정리 필수!
        super.onDisabled(context)
    }

    // 특정 위젯 삭제 시
    override fun onDeleted(context: Context, appWidgetIds: IntArray) {
        super.onDeleted(context, appWidgetIds)
    }
}
```

### 생명주기 다이어그램

```
위젯 추가  → onEnabled() → onUpdate() → [반복: onUpdate()]
위젯 삭제  → onDeleted()
마지막 삭제 → onDeleted() → onDisabled()
브로드캐스트 → onReceive() → (적절한 핸들러)
```

### 실무 주의사항

```kotlin
// ✅ onDisabled에서 반드시 리소스 정리
override fun onDisabled(context: Context) {
    stopAnimationUpdates()    // Handler 콜백 제거
    super.onDisabled(context)
}

// ✅ appWidgetIds는 배열 - 여러 위젯이 있을 수 있음
for (appWidgetId in appWidgetIds) {
    updateAppWidget(context, appWidgetManager, appWidgetId)
}
```

---

## 6. RemoteViews 위젯 렌더링

### 개념
위젯은 다른 프로세스에서 실행되므로 **직접 View 접근이 불가능**.
`RemoteViews`를 통해 원격으로 UI를 설정.

### 프로젝트 사용 예시

```kotlin
private fun updateAppWidget(
    context: Context,
    appWidgetManager: AppWidgetManager,
    appWidgetId: Int
) {
    // RemoteViews 생성 (레이아웃 지정)
    val views = RemoteViews(context.packageName, R.layout.pet_widget)

    // 텍스트 설정
    views.setTextViewText(R.id.pet_level, "Lv.$level")
    views.setTextViewText(R.id.pet_mood, moodText)

    // 이미지 설정
    val imageResId = context.resources.getIdentifier(
        resourceName, "drawable", context.packageName
    )
    if (imageResId != 0) {
        views.setImageViewResource(R.id.pet_image, imageResId)
    }

    // 클릭 리스너 (PendingIntent)
    val pendingIntent = PendingIntent.getActivity(
        context, 0, intent,
        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
    )
    views.setOnClickPendingIntent(R.id.widget_container, pendingIntent)

    // ⚡ 한 번에 업데이트 (원자적)
    appWidgetManager.updateAppWidget(appWidgetId, views)
}
```

### 핵심 원칙

```kotlin
// ✅ RemoteViews는 한 번에 구성 후 단일 updateAppWidget 호출
val views = RemoteViews(packageName, layout).apply {
    setTextViewText(R.id.title, "제목")
    setTextViewText(R.id.subtitle, "부제")
    setImageViewResource(R.id.icon, R.drawable.ic_pet)
}
appWidgetManager.updateAppWidget(widgetId, views)  // 한 번만 호출

// ❌ Bad: 여러 번 호출 (깜빡임 발생)
appWidgetManager.updateAppWidget(widgetId, views1)
appWidgetManager.updateAppWidget(widgetId, views2)  // 불필요한 이중 업데이트
```

### RemoteViews 제한사항

| 가능 | 불가능 |
|------|--------|
| `setTextViewText()` | 커스텀 View 사용 |
| `setImageViewResource()` | RecyclerView |
| `setOnClickPendingIntent()` | 직접 클릭 리스너 |
| `setViewVisibility()` | 애니메이션 API |

---

## 7. SharedPreferences와 다중 저장소

### 프로젝트 사용 예시 (레거시 호환)

```kotlin
// 최신 저장소 우선 → 레거시 fallback
private fun getWidgetString(context: Context, key: String): String? {
    // 1차: 최신 home_widget 저장소
    val newPrefs = context.getSharedPreferences(HOME_WIDGET_PREFS, Context.MODE_PRIVATE)
    val newValue = newPrefs.getString(key, null)
    if (newValue != null) return newValue

    // 2차: 레거시 저장소 (이전 버전 호환)
    val legacyPrefs = context.getSharedPreferences(LEGACY_WIDGET_PREFS, Context.MODE_PRIVATE)
    return legacyPrefs.getString(key, null)
}
```

### 왜 다중 저장소인가

```
앱 버전 1.0: "HomeWidget" 저장소 사용
앱 버전 2.0: "HomeWidgetPreferences" 저장소로 변경

→ 업데이트한 사용자는 새 저장소에 데이터 없음
→ 레거시 저장소를 fallback으로 읽어야 데이터 유실 방지
```

### SharedPreferences 실무 패턴

```kotlin
// ✅ 읽기: 타입 안전 변환
val hunger = prefs.getString("hunger", null)?.toIntOrNull() ?: 50

// ✅ 쓰기: apply() 비동기 (UI 스레드 안전)
prefs.edit().apply {
    putString("mood", "happy")
    putInt("level", 5)
    apply()  // 비동기 저장
}

// ❌ Bad: commit() 동기 (UI 스레드 블로킹)
prefs.edit().putString("mood", "happy").commit()
```

---

## 8. PendingIntent와 FLAG_IMMUTABLE

### 개념
`PendingIntent`는 다른 앱/시스템에게 "나중에 이 작업을 실행해줘"라고 위임하는 토큰.

### 프로젝트 사용 예시

```kotlin
// 위젯 클릭 시 앱 열기
val intent = context.packageManager.getLaunchIntentForPackage(context.packageName)
val pendingIntent = PendingIntent.getActivity(
    context,
    0,
    intent,
    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE  // ⚠️ 필수
)
views.setOnClickPendingIntent(R.id.widget_container, pendingIntent)
```

### FLAG_IMMUTABLE이 필수인 이유

```kotlin
// Android 12 (API 31) 이상에서 FLAG_IMMUTABLE 또는 FLAG_MUTABLE 필수
// 없으면 SecurityException 발생

// ✅ 위젯 클릭처럼 변경 불필요한 경우
PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE

// ✅ 알림의 direct reply처럼 변경이 필요한 경우
PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_MUTABLE
```

### PendingIntent 플래그 정리

| 플래그 | 용도 |
|--------|------|
| `FLAG_IMMUTABLE` | Intent 내용 수정 불가 (Android 12+ 기본) |
| `FLAG_UPDATE_CURRENT` | 이미 존재하면 extras만 업데이트 |
| `FLAG_CANCEL_CURRENT` | 이미 존재하면 취소 후 새로 생성 |
| `FLAG_ONE_SHOT` | 한 번만 사용 가능 |

---

## 9. Handler 기반 애니메이션

### 프로젝트 사용 예시

```kotlin
companion object {
    private var animationHandler: Handler? = null
    private var animationRunnable: Runnable? = null
    private var isAnimating = false
    private const val ANIMATION_UPDATE_INTERVAL = 800L  // 800ms
}

// 애니메이션 시작
private fun startAnimationUpdates(context: Context) {
    if (isAnimating) return

    // ✅ ApplicationContext 사용 (Activity 누수 방지)
    val appContext = context.applicationContext
    animationHandler = Handler(Looper.getMainLooper())

    animationRunnable = Runnable {
        // 위젯 업데이트 로직
        updateAppWidgetForAnimation(appContext)
        // 다음 프레임 예약
        scheduleNextAnimationUpdate()
    }

    isAnimating = true
    animationHandler?.post(animationRunnable!!)
}

// 다음 프레임 예약
private fun scheduleNextAnimationUpdate() {
    animationHandler?.postDelayed(animationRunnable!!, ANIMATION_UPDATE_INTERVAL)
}

// ✅ 반드시 정리 (메모리 누수 방지)
private fun stopAnimationUpdates() {
    animationRunnable?.let { runnable ->
        animationHandler?.removeCallbacks(runnable)
    }
    animationHandler = null
    animationRunnable = null
    isAnimating = false
}
```

### Handler vs 코루틴

| | Handler | 코루틴 |
|---|---|---|
| **용도** | UI 스레드 반복 작업 | 비동기 작업 전반 |
| **위젯에서** | ✅ 적합 (BroadcastReceiver 환경) | ⚠️ 수명주기 관리 어려움 |
| **취소** | `removeCallbacks()` | `cancel()` |
| **스레드** | 메인 스레드 고정 | Dispatcher 선택 가능 |

### 실무 주의사항

```kotlin
// ✅ 반드시 메인 루퍼 사용
Handler(Looper.getMainLooper())

// ❌ 절대 금지: 기본 생성자 (deprecated)
Handler()  // Android 11+에서 deprecated

// ✅ 반드시 정리 코드 존재
override fun onDisabled(context: Context) {
    stopAnimationUpdates()  // Handler 콜백 제거
}
```

---

## 10. 타입 안전 변환

### 프로젝트 사용 예시

```kotlin
// ❌ 위험: Integer.parseInt (예외 발생 가능)
val hunger = Integer.parseInt(hungerStr)  // "abc" → NumberFormatException

// ✅ 안전: toIntOrNull + Elvis
val hunger = hungerStr?.toIntOrNull() ?: 50  // "abc" → null → 50

// ✅ 안전: 리소스 ID 확인
val imageResId = context.resources.getIdentifier(
    resourceName, "drawable", context.packageName
)
if (imageResId != 0) {
    views.setImageViewResource(R.id.pet_image, imageResId)
} else {
    // 폴백 처리
    views.setTextViewText(R.id.pet_image_fallback, fallbackEmoji)
}
```

### Kotlin 타입 변환 메서드 정리

| 메서드 | 안전성 | 실패 시 |
|--------|--------|---------|
| `toInt()` | ❌ 위험 | NumberFormatException |
| `toIntOrNull()` | ✅ 안전 | null 반환 |
| `as Type` | ❌ 위험 | ClassCastException |
| `as? Type` | ✅ 안전 | null 반환 |
| `toString()` | ✅ 안전 | "null" 문자열 |

---

## 11. Collection 안전 접근

### 프로젝트 사용 예시

```kotlin
// 이미지 타입 목록에서 안전 접근
val imageTypes = listOf("normal", "happy", "sad", "feed")
val imageType = imageTypes.getOrElse(index) { "normal" }

// when으로 이미지 프레임 수 결정
val frameCount = when (imageType) {
    "feed" -> 4
    else   -> 3
}

// 프레임 인덱스 계산 (시간 기반)
val frameIndex = ((System.currentTimeMillis() / ANIMATION_UPDATE_INTERVAL) % frameCount).toInt()
```

### Collection 안전 접근 패턴

```kotlin
// ✅ getOrElse - 인덱스 범위 초과 시 기본값
list.getOrElse(99) { "default" }

// ✅ getOrNull - 인덱스 범위 초과 시 null
list.getOrNull(99) ?: "default"

// ✅ firstOrNull - 조건에 맞는 첫 요소 (없으면 null)
list.firstOrNull { it.startsWith("a") }

// ❌ Bad: 직접 인덱스 접근 (IndexOutOfBoundsException)
list[99]

// ❌ Bad: first (빈 리스트에서 예외)
emptyList<String>().first()
```

---

## 12. Context 사용 원칙

### 프로젝트 사용 예시

```kotlin
// ✅ ApplicationContext 사용 (Handler에 저장할 때)
val appContext = context.applicationContext
animationHandler = Handler(Looper.getMainLooper())

// ✅ 일반 Context 사용 (일회성 작업)
val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
```

### Context 종류와 사용 원칙

| 상황 | ApplicationContext | Activity Context |
|------|-------------------|-----------------|
| **Handler에 저장** | ✅ | ❌ 메모리 누수 |
| **SharedPreferences** | ✅ | ✅ |
| **위젯 업데이트** | ✅ | ✅ |
| **Dialog 생성** | ❌ | ✅ |
| **Theme 접근** | ❌ | ✅ |
| **Toast** | ✅ | ✅ |

### 핵심 규칙

```kotlin
// ✅ 오래 살아있는 객체에는 반드시 ApplicationContext
class MyService {
    private lateinit var appContext: Context

    fun init(context: Context) {
        appContext = context.applicationContext  // ✅
    }
}

// ❌ Activity를 오래 살아있는 객체에 저장하면 메모리 누수
class BadService {
    private lateinit var context: Context  // Activity가 들어오면 누수!
}
```

---

## 13. try-catch와 실무 예외 처리

### 프로젝트 사용 예시

```kotlin
private fun updateAppWidget(
    context: Context,
    appWidgetManager: AppWidgetManager,
    appWidgetId: Int
) {
    try {
        val views = RemoteViews(context.packageName, R.layout.pet_widget)
        // ... 위젯 구성 로직
        appWidgetManager.updateAppWidget(appWidgetId, views)
    } catch (e: Exception) {
        Log.e(TAG, "위젯 업데이트 실패", e)
        // 위젯은 설치 안 됐을 수 있으므로 silently fail
    }
}
```

### 실무 예외 처리 원칙

```kotlin
// 1. 외부 경계(IO, 시스템 API)에서만 try-catch
try {
    val data = readFromSharedPreferences(context)
    updateWidget(data)
} catch (e: Exception) {
    Log.e(TAG, "위젯 업데이트 실패", e)
}

// 2. 예외 객체는 반드시 로그에 포함
Log.e(TAG, "실패", e)      // ✅ 스택트레이스 포함
Log.e(TAG, "실패: ${e.message}")  // ⚠️ 스택트레이스 없음

// 3. 빈 catch 블록 금지
try { ... } catch (e: Exception) { }  // ❌ 무시하지 말 것

// 4. 너무 넓은 Exception 대신 구체적 예외
try { ... } catch (e: NumberFormatException) { ... }  // ✅ 구체적
try { ... } catch (e: Exception) { ... }               // ⚠️ 마지막 수단
```

---

## 14. Gradle 설정과 desugaring

### 프로젝트 build.gradle.kts

```kotlin
android {
    compileSdk = 36

    defaultConfig {
        minSdk = 26      // Android 8.0+
    }

    compileOptions {
        // Java 11 API를 이전 Android 버전에서도 사용 가능하게
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = "11"
    }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
```

### desugaring이 뭔가

```
문제: Java 11의 java.time, Stream API 등은 Android 8 이하에서 사용 불가
해결: desugaring이 컴파일 시점에 하위 호환 코드로 변환

사용 가능해지는 API:
- java.time.* (LocalDate, Instant 등)
- java.util.stream.*
- java.util.Optional
- CompletableFuture
```

---

## 15. 중급에서 고급으로 가기 위해 알아야 할 것

### 현재 프로젝트에서 아직 사용하지 않지만 알아야 하는 것들

| 주제 | 이유 | 우선순위 |
|------|------|---------|
| **코루틴 (Coroutines)** | Handler 대신 현대적 비동기 처리 | ⭐⭐⭐ |
| **Flow** | 반응형 데이터 스트림 | ⭐⭐⭐ |
| **sealed class** | 상태/결과 표현 (Result, UiState) | ⭐⭐⭐ |
| **data class** | 불변 데이터 모델 | ⭐⭐ |
| **Hilt/Koin DI** | 의존성 주입 | ⭐⭐ |
| **확장 함수** | 유틸 로직 분리 | ⭐⭐ |
| **Jetpack Compose** | 선언형 UI (위젯 Glance) | ⭐ |
| **Unit Test (JUnit5)** | 테스트 코드 작성 | ⭐⭐⭐ |

### 코루틴 예시 (Handler 대체)

```kotlin
// 현재: Handler 기반
animationHandler?.postDelayed(runnable, 800L)

// 고급: 코루틴 기반
private val scope = CoroutineScope(Dispatchers.Main + SupervisorJob())

fun startAnimation() {
    scope.launch {
        while (isActive) {
            updateWidget()
            delay(800L)
        }
    }
}

fun stopAnimation() {
    scope.cancel()
}
```

### sealed class 예시 (위젯 상태 관리)

```kotlin
// 현재: 문자열 비교
if (mood == "happy") { ... }
else if (mood == "hungry") { ... }

// 고급: sealed class
sealed class WidgetState {
    data class Loaded(val mood: String, val level: Int) : WidgetState()
    data class Error(val message: String) : WidgetState()
    object Loading : WidgetState()
}

// 컴파일러가 모든 케이스 처리를 보장
when (state) {
    is WidgetState.Loaded  -> renderPet(state.mood, state.level)
    is WidgetState.Error   -> renderError(state.message)
    is WidgetState.Loading -> renderLoading()
    // 새 상태 추가 시 컴파일 에러 → 누락 방지
}
```

### data class 예시

```kotlin
// 현재: 필드를 개별 변수로 관리
val hunger = prefs.getString("hunger", null)?.toIntOrNull() ?: 50
val happiness = prefs.getString("happiness", null)?.toIntOrNull() ?: 50

// 고급: data class로 구조화
data class PetWidgetState(
    val level: Int = 1,
    val mood: String = "normal",
    val hunger: Int = 50,
    val happiness: Int = 50,
    val stamina: Int = 50,
)

// 자동 생성: equals(), hashCode(), toString(), copy(), componentN()
val state = PetWidgetState(level = 5, mood = "happy")
val updated = state.copy(mood = "hungry")  // 불변 복사
```

---

## 요약 체크리스트

중급 Kotlin 개발자로서 아래 항목을 모두 이해하고 있어야 합니다:

- [ ] `companion object`로 상수와 싱글톤 상태 관리
- [ ] `?.`, `?:`, `.let{}`, `toIntOrNull()` 등 nullable 안전 처리
- [ ] `when` 표현식으로 분기 처리 (범위, 타입, 조건)
- [ ] `AppWidgetProvider` 생명주기 (onUpdate → onDisabled)
- [ ] `RemoteViews`로 위젯 UI 원격 설정
- [ ] `SharedPreferences` 읽기/쓰기 + 다중 저장소 전략
- [ ] `PendingIntent` + `FLAG_IMMUTABLE` (Android 12+)
- [ ] `Handler` + `Looper.getMainLooper()` 주기적 작업
- [ ] `ApplicationContext` vs `Activity Context` 사용 원칙
- [ ] `try-catch` 외부 경계에서만 + 예외 객체 로그 포함
- [ ] Gradle `desugaring` + `compileSdk`/`minSdk` 이해
- [ ] `getOrElse`, `firstOrNull` 등 Collection 안전 접근
