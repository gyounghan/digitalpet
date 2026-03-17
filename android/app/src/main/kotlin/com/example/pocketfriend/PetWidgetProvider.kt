package com.example.pocketfriend

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.widget.RemoteViews
import android.util.Log
import android.os.Handler
import android.os.Looper

/// 펫 홈 화면 위젯 Provider
/// 홈 화면에 펫 정보를 표시하는 위젯
/// 
/// home_widget 패키지에서 전달된 데이터를 읽어서 위젯에 표시
/// 애니메이션 효과를 위해 주기적으로 위젯을 업데이트
class PetWidgetProvider : AppWidgetProvider() {
    
    companion object {
        /// home_widget Android 플러그인의 실제 SharedPreferences 이름
        private const val HOME_WIDGET_PREFS = "HomeWidgetPreferences"
        /// 과거 구현과의 호환을 위한 레거시 이름
        private const val LEGACY_WIDGET_PREFS = "HomeWidget"

        /// 애니메이션 업데이트 간격 (밀리초)
        /// 800ms마다 이미지를 변경하여 애니메이션 효과 생성
        private const val ANIMATION_UPDATE_INTERVAL = 800L
        
        /// 애니메이션 업데이트를 위한 Intent Action
        private const val ACTION_ANIMATION_UPDATE = "com.example.pocketfriend.ACTION_ANIMATION_UPDATE"
        
        /// 애니메이션 핸들러 (싱글톤)
        private var animationHandler: Handler? = null
        private var animationRunnable: Runnable? = null
        private var isAnimating = false
    }
    
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        Log.d("PetWidgetProvider", "onUpdate called with ${appWidgetIds.size} widget(s)")
        
        // 각 위젯 인스턴스에 대해 업데이트 수행
        for (appWidgetId in appWidgetIds) {
            updateAppWidget(context, appWidgetManager, appWidgetId)
        }
        
        // 애니메이션을 위한 주기적 업데이트 시작
        startAnimationUpdates(context, appWidgetManager, appWidgetIds)
    }
    
    override fun onEnabled(context: Context) {
        Log.d("PetWidgetProvider", "onEnabled: Widget added")
        super.onEnabled(context)
    }
    
    override fun onDisabled(context: Context) {
        Log.d("PetWidgetProvider", "onDisabled: All widgets removed")
        // 애니메이션 중지
        stopAnimationUpdates()
        super.onDisabled(context)
    }
    
    override fun onDeleted(context: Context, appWidgetIds: IntArray) {
        Log.d("PetWidgetProvider", "onDeleted: ${appWidgetIds.size} widget(s) deleted")
        super.onDeleted(context, appWidgetIds)
        
        // 모든 위젯이 삭제되었는지 확인
        val appWidgetManager = AppWidgetManager.getInstance(context)
        val remainingWidgetIds = appWidgetManager.getAppWidgetIds(
            android.content.ComponentName(context, PetWidgetProvider::class.java)
        )
        
        if (remainingWidgetIds.isEmpty()) {
            stopAnimationUpdates()
        }
    }
    
    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        Log.d("PetWidgetProvider", "onReceive action=${intent.action}")
        
        when (intent.action) {
            AppWidgetManager.ACTION_APPWIDGET_UPDATE,
            "es.antonborri.home_widget.UPDATE_WIDGET",
            "es.antonborri.home_widget.action.UPDATE" -> {
                // 위젯 업데이트 요청 시 onUpdate 호출
                // home_widget 패키지가 보내는 ACTION_APPWIDGET_UPDATE 브로드캐스트 처리
                val appWidgetManager = AppWidgetManager.getInstance(context)
                val appWidgetIds = appWidgetManager.getAppWidgetIds(
                    android.content.ComponentName(context, PetWidgetProvider::class.java)
                )
                if (appWidgetIds.isNotEmpty()) {
                    onUpdate(context, appWidgetManager, appWidgetIds)
                }
            }
            ACTION_ANIMATION_UPDATE -> {
                // 애니메이션 업데이트: 이미지 인덱스만 변경하여 애니메이션 효과 생성
                val appWidgetManager = AppWidgetManager.getInstance(context)
                val appWidgetIds = appWidgetManager.getAppWidgetIds(
                    android.content.ComponentName(context, PetWidgetProvider::class.java)
                )
                if (appWidgetIds.isNotEmpty()) {
                    // 애니메이션 업데이트: 이미지 인덱스만 변경
                    for (appWidgetId in appWidgetIds) {
                        updateAppWidgetForAnimation(context, appWidgetManager, appWidgetId)
                    }
                    // 다음 업데이트 예약
                    scheduleNextAnimationUpdate(context, appWidgetManager, appWidgetIds)
                } else {
                    // 위젯이 없으면 업데이트 중지
                    stopAnimationUpdates()
                }
            }
            else -> {
                Log.d("PetWidgetProvider", "onReceive ignored action=${intent.action}")
            }
        }
    }
    
    /// 위젯 업데이트
    /// 
    /// home_widget 패키지에서 저장한 데이터를 읽어서 위젯에 표시
    private fun updateAppWidget(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int
    ) {
        try {
            val level = getWidgetString(context, "level", "1")?.toIntOrNull() ?: 1
            val hunger = getWidgetString(context, "hunger", "100")?.toIntOrNull() ?: 100
            val happiness = getWidgetString(context, "happiness", "100")?.toIntOrNull() ?: 100
            val stamina = getWidgetString(context, "stamina", "100")?.toIntOrNull() ?: 100
            val syncTraceId = getWidgetString(context, "syncTraceId", "unknown") ?: "unknown"
            val rawMood = getWidgetString(context, "mood", "normal") ?: "normal"
            val resolvedMood = resolveMood(rawMood, hunger, happiness, stamina)
            val imageType = resolveImageType(
                getWidgetString(context, "imageType", null),
                resolvedMood
            )
            // Flutter에서 저장한 상태 텍스트 읽기 (앱 내 상태와 동기화)
            val moodText = getWidgetString(context, "moodText", null)
            
            // 디버깅: moodText가 제대로 읽히는지 확인
            Log.d(
                "PetWidgetProvider",
                "Widget update - syncTraceId: $syncTraceId, level: $level, rawMood: $rawMood, resolvedMood: $resolvedMood, moodText: $moodText, imageType: $imageType, hunger: $hunger, happiness: $happiness, stamina: $stamina"
            )
            
            // 현재 시간 기반으로 이미지 인덱스 계산 (애니메이션 효과)
            // 이미지 타입에 따라 다른 개수 사용: feed는 4장, 그 외는 3장
            val currentTime = System.currentTimeMillis()
            val imageCount = getImageCountForImageType(imageType)
            val cycleDuration = imageCount * ANIMATION_UPDATE_INTERVAL // 이미지 개수 * 800ms
            val imageIndex = ((currentTime % cycleDuration) / ANIMATION_UPDATE_INTERVAL).toInt() % imageCount
            
            // 위젯 레이아웃 생성
            val views = RemoteViews(context.packageName, R.layout.pet_widget)
            
            // 펫 이미지 결정 (앱 홈 화면과 동일한 로직)
            // 이미지 타입에 따라 다른 이미지 표시
            // 주의: 이미지는 android/app/src/main/res/drawable/ 폴더에 있어야 함
            val imageResourceName = resolveImageResourceName(imageType, imageIndex)
            
            // 리소스 ID 가져오기 (없으면 기본 아이콘 사용)
            val imageResourceId = context.resources.getIdentifier(
                imageResourceName,
                "drawable",
                context.packageName
            )
            
            // 위젯에 데이터 설정
            if (imageResourceId != 0) {
                // 이미지 리소스가 있으면 ImageView 표시
                views.setImageViewResource(R.id.pet_image, imageResourceId)
                views.setViewVisibility(R.id.pet_image, android.view.View.VISIBLE)
                views.setViewVisibility(R.id.pet_image_text, android.view.View.GONE)
            } else {
                // 이미지가 없으면 이모지로 대체 (앱 홈 화면과 유사하게)
                val petEmoji = resolveImageFallbackEmoji(imageType)
                views.setTextViewText(R.id.pet_image_text, petEmoji)
                views.setViewVisibility(R.id.pet_image, android.view.View.GONE)
                views.setViewVisibility(R.id.pet_image_text, android.view.View.VISIBLE)
            }
            
            views.setTextViewText(R.id.pet_level, "Lv.$level")
            
            // 상태 텍스트는 Flutter가 저장한 moodText를 최우선 사용한다.
            // 없을 경우에는 mood 문자열만으로 하위 호환 처리한다.
            val displayMoodText = resolveMoodText(moodText, resolvedMood)
            views.setTextViewText(R.id.pet_mood, displayMoodText)
            
            // 디버깅: 실제로 표시되는 값 확인
            Log.d("PetWidgetProvider", "Displaying - syncTraceId: $syncTraceId, level: $level, moodText: $displayMoodText (from moodText: $moodText)")
            
            // 위젯 클릭 시 앱 열기
            val intent = android.content.Intent(context, MainActivity::class.java)
            val pendingIntent = android.app.PendingIntent.getActivity(
                context,
                0,
                intent,
                android.app.PendingIntent.FLAG_UPDATE_CURRENT or android.app.PendingIntent.FLAG_IMMUTABLE
            )
            views.setOnClickPendingIntent(R.id.widget_container, pendingIntent)
            
            // 위젯 업데이트
            appWidgetManager.updateAppWidget(appWidgetId, views)
        } catch (e: Exception) {
            Log.e("PetWidgetProvider", "Error updating widget", e)
        }
    }
    
    /// 애니메이션을 위한 위젯 업데이트
    /// 
    /// 이미지 인덱스만 변경하여 애니메이션 효과 생성
    /// 다른 데이터는 변경하지 않고 이미지만 순환
    private fun updateAppWidgetForAnimation(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int
    ) {
        try {
            // 기존 데이터 읽기
            val level = getWidgetString(context, "level", "1")?.toIntOrNull() ?: 1
            val hunger = getWidgetString(context, "hunger", "100")?.toIntOrNull() ?: 100
            val happiness = getWidgetString(context, "happiness", "100")?.toIntOrNull() ?: 100
            val stamina = getWidgetString(context, "stamina", "100")?.toIntOrNull() ?: 100
            val syncTraceId = getWidgetString(context, "syncTraceId", "unknown") ?: "unknown"
            val rawMood = getWidgetString(context, "mood", "normal") ?: "normal"
            val resolvedMood = resolveMood(rawMood, hunger, happiness, stamina)
            val imageType = resolveImageType(
                getWidgetString(context, "imageType", null),
                resolvedMood
            )
            // Flutter에서 저장한 상태 텍스트 읽기 (앱 내 상태와 동기화)
            val moodText = getWidgetString(context, "moodText", null)
            
            // 디버깅: 애니메이션 업데이트 시에도 moodText 확인
            Log.d(
                "PetWidgetProvider",
                "Animation update - syncTraceId: $syncTraceId, level: $level, rawMood: $rawMood, resolvedMood: $resolvedMood, moodText: $moodText, imageType: $imageType"
            )
            
            // 현재 시간 기반으로 이미지 인덱스 계산 (애니메이션 효과)
            // 시간 기반으로 순환하여 위젯이 업데이트될 때마다 다른 이미지 표시
            val currentTime = System.currentTimeMillis()
            // 이미지 타입에 따라 다른 개수 사용: feed는 4장, 그 외는 3장
            val imageCount = getImageCountForImageType(imageType)
            val cycleDuration = imageCount * ANIMATION_UPDATE_INTERVAL // 이미지 개수 * 800ms
            val imageIndex = ((currentTime % cycleDuration) / ANIMATION_UPDATE_INTERVAL).toInt() % imageCount
            
            Log.d("PetWidgetProvider", "Animation update: imageType=$imageType, imageIndex=$imageIndex")
            
            val views = RemoteViews(context.packageName, R.layout.pet_widget)
            
            // 펫 이미지 결정
            val imageResourceName = resolveImageResourceName(imageType, imageIndex)
            
            val imageResourceId = context.resources.getIdentifier(
                imageResourceName,
                "drawable",
                context.packageName
            )
            
            // 이미지만 업데이트
            if (imageResourceId != 0) {
                views.setImageViewResource(R.id.pet_image, imageResourceId)
                views.setViewVisibility(R.id.pet_image, android.view.View.VISIBLE)
                views.setViewVisibility(R.id.pet_image_text, android.view.View.GONE)
            } else {
                val petEmoji = resolveImageFallbackEmoji(imageType)
                views.setTextViewText(R.id.pet_image_text, petEmoji)
                views.setViewVisibility(R.id.pet_image, android.view.View.GONE)
                views.setViewVisibility(R.id.pet_image_text, android.view.View.VISIBLE)
            }
            
            // 기존 데이터 유지
            views.setTextViewText(R.id.pet_level, "Lv.$level")
            
            // 상태 텍스트는 Flutter가 저장한 moodText를 최우선 사용한다.
            // 없을 경우에는 mood 문자열만으로 하위 호환 처리한다.
            val displayMoodText = resolveMoodText(moodText, resolvedMood)
            views.setTextViewText(R.id.pet_mood, displayMoodText)
            
            // 디버깅: 애니메이션 업데이트 시에도 실제로 표시되는 값 확인
            Log.d("PetWidgetProvider", "Animation displaying - syncTraceId: $syncTraceId, level: $level, moodText: $displayMoodText (from moodText: $moodText)")
            
            // 위젯 클릭 시 앱 열기
            val intent = android.content.Intent(context, MainActivity::class.java)
            val pendingIntent = android.app.PendingIntent.getActivity(
                context,
                0,
                intent,
                android.app.PendingIntent.FLAG_UPDATE_CURRENT or android.app.PendingIntent.FLAG_IMMUTABLE
            )
            views.setOnClickPendingIntent(R.id.widget_container, pendingIntent)
            
            appWidgetManager.updateAppWidget(appWidgetId, views)
        } catch (e: Exception) {
            Log.e("PetWidgetProvider", "Error updating widget for animation", e)
        }
    }

    /// 위젯 데이터 문자열 조회
    /// home_widget 최신 저장소(HomeWidgetPreferences)를 우선 사용하고,
    /// 값이 없으면 레거시 저장소(HomeWidget)를 fallback으로 조회한다.
    private fun getWidgetString(context: Context, key: String, defaultValue: String?): String? {
        val currentPrefs = context.getSharedPreferences(HOME_WIDGET_PREFS, Context.MODE_PRIVATE)
        val currentValue = currentPrefs.getString(key, null)
        if (currentValue != null) {
            return currentValue
        }

        val legacyPrefs = context.getSharedPreferences(LEGACY_WIDGET_PREFS, Context.MODE_PRIVATE)
        return legacyPrefs.getString(key, defaultValue)
    }

    /// imageType을 최종 결정
    /// 동기화 일관성을 위해 mood를 단일 기준으로 사용한다.
    /// (mood가 없거나 알 수 없는 경우에만 imageType으로 보정)
    private fun resolveImageType(imageType: String?, mood: String): String {
        val mappedFromMood = mapMoodToImageType(mood)
        if (mappedFromMood != null) {
            return mappedFromMood
        }

        // mood가 비어 있거나 알 수 없는 경우에만 imageType 하위 호환 처리
        val legacyType = imageType?.trim()
        return when (legacyType) {
            "feed", "sleep", "exercise", "happy", "bored", "anxious", "full", "sad" -> legacyType
            "hungry" -> "feed"
            "sleeping" -> "sleep"
            "normal" -> "exercise"
            else -> "sleep"
        }
    }

    /// mood를 imageType으로 변환
    private fun mapMoodToImageType(mood: String): String? {
        return when (mood.trim()) {
            "hungry" -> "feed"
            "sleepy", "tired" -> "sleep"
            "bored" -> "bored"
            "anxious" -> "anxious"
            "happy" -> "happy"
            "full", "satisfied" -> "full"
            "energetic", "normal" -> "exercise"
            else -> null
        }
    }

    /// mood 최종 결정
    /// - 유효한 mood면 그대로 사용
    /// - 유효하지 않거나 비어있으면 수치(hunger/happiness/stamina)로 재계산
    private fun resolveMood(mood: String?, hunger: Int, happiness: Int, stamina: Int): String {
        val normalizedMood = mood?.trim()?.lowercase() ?: ""
        if (isKnownMood(normalizedMood)) {
            return normalizedMood
        }
        return calculateMoodFromStats(hunger, happiness, stamina)
    }

    /// 유효한 mood 문자열인지 확인
    private fun isKnownMood(mood: String): Boolean {
        return mood == "happy" ||
            mood == "sleepy" ||
            mood == "hungry" ||
            mood == "bored" ||
            mood == "normal" ||
            mood == "energetic" ||
            mood == "tired" ||
            mood == "full" ||
            mood == "anxious" ||
            mood == "satisfied"
    }

    /// Flutter Pet.mood 로직과 동일한 상태 판정
    private fun calculateMoodFromStats(hunger: Int, happiness: Int, stamina: Int): String {
        if (hunger <= 20) return "hungry"
        if (stamina <= 20) return "tired"
        if (stamina <= 30) return "sleepy"
        if (happiness <= 20) return "anxious"
        if (happiness <= 30) return "bored"

        if (hunger >= 90 && happiness >= 90 && stamina >= 90) return "energetic"
        if (hunger >= 80 && happiness >= 80 && stamina >= 80) return "happy"

        if (hunger >= 90 && happiness >= 60 && stamina >= 60) return "full"
        if ((hunger >= 70 && happiness >= 70) ||
            (hunger >= 70 && stamina >= 70) ||
            (happiness >= 70 && stamina >= 70)
        ) return "satisfied"

        val avg = (hunger + happiness + stamina) / 3.0
        val maxDiff = maxOf(
            kotlin.math.abs(hunger - avg),
            kotlin.math.abs(happiness - avg),
            kotlin.math.abs(stamina - avg)
        )
        if (maxDiff > 40) return "anxious"

        return "normal"
    }

    /// 이미지 타입별 프레임 수 반환
    private fun getImageCountForImageType(imageType: String): Int {
        return if (imageType == "feed") 4 else 3
    }

    /// 이미지 타입/인덱스로 drawable 리소스명 반환
    private fun resolveImageResourceName(imageType: String, imageIndex: Int): String {
        return when (imageType) {
            "feed" -> listOf("feed_1", "feed_2", "feed_3", "feed_4").getOrElse(imageIndex) { "feed_1" }
            "sleep" -> listOf("sleep_1", "sleep_2", "sleep_3").getOrElse(imageIndex) { "sleep_1" }
            "exercise" -> listOf("exercise_1", "exercise_2", "exercise_3").getOrElse(imageIndex) { "exercise_1" }
            "happy" -> listOf("happy_1", "happy_2", "happy_3").getOrElse(imageIndex) { "happy_1" }
            "bored" -> listOf("bored_1", "bored_2", "bored_3").getOrElse(imageIndex) { "bored_1" }
            "anxious" -> listOf("anxious_1", "anxious_2", "anxious_3").getOrElse(imageIndex) { "anxious_1" }
            "full" -> listOf("full_1", "full_2", "full_3").getOrElse(imageIndex) { "full_1" }
            "sad" -> listOf("sad_1", "sad_2", "sad_3").getOrElse(imageIndex) { "sad_1" }
            else -> "sleep_1"
        }
    }

    /// 이미지 로드 실패 시 이모지 폴백
    private fun resolveImageFallbackEmoji(imageType: String): String {
        return when (imageType) {
            "feed" -> "🍽️"
            "sleep" -> "💤"
            "sad" -> "😢"
            "happy" -> "😊"
            "bored" -> "😐"
            "anxious" -> "😟"
            "full" -> "😋"
            else -> "🏃"
        }
    }

    /// 표시용 상태 텍스트 결정 (한국어)
    /// 동기화 일관성을 위해 mood를 기준으로 텍스트를 결정한다.
    /// mood를 알 수 없을 때만 moodText를 사용한다.
    private fun resolveMoodText(moodText: String?, mood: String): String {
        val mappedFromMood = mapMoodToKoreanText(mood)
        if (mappedFromMood != null) {
            return mappedFromMood
        }

        return if (!moodText.isNullOrBlank()) moodText else "보통"
    }

    /// mood를 한국어 상태 텍스트로 변환
    private fun mapMoodToKoreanText(mood: String): String? {
        return when (mood.trim()) {
            "hungry" -> "배고픔"
            "tired" -> "피곤함"
            "sleepy" -> "졸림"
            "anxious" -> "불안함"
            "bored" -> "지루함"
            "energetic" -> "활기참"
            "happy" -> "기쁨"
            "full" -> "배부름"
            "satisfied" -> "만족함"
            "normal" -> "보통"
            else -> null
        }
    }
    
    /// 애니메이션 업데이트 시작
    /// 
    /// Handler를 사용하여 주기적으로 위젯을 업데이트하여 애니메이션 효과 생성
    /// 위젯이 활성화되어 있는 동안만 작동
    /// 
    /// 주의: 위젯 프로세스가 종료되면 애니메이션이 중지됩니다.
    /// 위젯이 다시 업데이트되면 자동으로 재시작됩니다.
    private fun startAnimationUpdates(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        // 이미 애니메이션이 실행 중이면 중복 시작 방지
        if (isAnimating) {
            Log.d("PetWidgetProvider", "Animation already running, skipping start")
            return
        }
        
        isAnimating = true
        Log.d("PetWidgetProvider", "Starting animation updates for ${appWidgetIds.size} widget(s)")
        
        // Handler 초기화 (메인 스레드)
        if (animationHandler == null) {
            animationHandler = Handler(Looper.getMainLooper())
        }
        
        // 애니메이션 Runnable 생성
        val contextRef = context.applicationContext // ApplicationContext 사용 (메모리 누수 방지)
        val managerRef = appWidgetManager
        
        animationRunnable = object : Runnable {
            override fun run() {
                if (!isAnimating) {
                    return
                }
                
                // 위젯이 여전히 존재하는지 확인
                val currentWidgetIds = managerRef.getAppWidgetIds(
                    android.content.ComponentName(contextRef, PetWidgetProvider::class.java)
                )
                
                if (currentWidgetIds.isEmpty()) {
                    // 위젯이 없으면 애니메이션 중지
                    Log.d("PetWidgetProvider", "No widgets found, stopping animation")
                    stopAnimationUpdates()
                    return
                }
                
                // 애니메이션 업데이트 실행
                for (appWidgetId in currentWidgetIds) {
                    updateAppWidgetForAnimation(contextRef, managerRef, appWidgetId)
                }
                
                // 다음 업데이트 예약
                if (isAnimating && animationHandler != null) {
                    animationHandler?.postDelayed(this, ANIMATION_UPDATE_INTERVAL)
                }
            }
        }
        
        // 첫 번째 업데이트 시작 (즉시 실행)
        animationHandler?.post(animationRunnable!!)
    }
    
    /// 다음 애니메이션 업데이트 예약
    /// 
    /// 현재 업데이트 후 다음 업데이트를 예약
    private fun scheduleNextAnimationUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        // Handler를 사용한 방식에서는 이미 Runnable이 다음 업데이트를 예약하므로
        // 여기서는 추가 작업이 필요 없음
        // 하지만 위젯이 없으면 중지
        if (appWidgetIds.isEmpty()) {
            stopAnimationUpdates()
        }
    }
    
    /// 애니메이션 업데이트 중지
    /// 
    /// 위젯이 제거되거나 더 이상 필요하지 않을 때 호출
    private fun stopAnimationUpdates() {
        if (!isAnimating) {
            return
        }
        
        Log.d("PetWidgetProvider", "Stopping animation updates")
        isAnimating = false
        
        // Runnable 제거
        animationRunnable?.let {
            animationHandler?.removeCallbacks(it)
        }
        animationRunnable = null
        
        // Handler는 유지 (재사용 가능)
    }
}
