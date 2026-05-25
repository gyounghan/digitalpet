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
            val moodText = getWidgetString(context, "moodText", null)

            // 진화 이미지 (Flutter에서 저장한 진화 drawable 리소스명)
            val evolutionImage = getWidgetString(context, "evolutionImage", null)

            Log.d(
                "PetWidgetProvider",
                "Widget update - syncTraceId: $syncTraceId, level: $level, rawMood: $rawMood, resolvedMood: $resolvedMood, imageType: $imageType, evolutionImage: $evolutionImage"
            )

            val views = RemoteViews(context.packageName, R.layout.pet_widget)

            // 이미지 결정: 진화 이미지 우선, 없으면 mood 기반 애니메이션
            val imageResourceId = resolveWidgetImageResourceId(context, evolutionImage, imageType)

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

            views.setTextViewText(R.id.pet_level, "Lv.$level")

            val displayMoodText = resolveMoodText(moodText, resolvedMood)
            views.setTextViewText(R.id.pet_mood, displayMoodText)

            Log.d("PetWidgetProvider", "Displaying - syncTraceId: $syncTraceId, level: $level, moodText: $displayMoodText")

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
            Log.e("PetWidgetProvider", "Error updating widget", e)
        }
    }
    
    /// 애니메이션을 위한 위젯 업데이트
    ///
    /// 진화 이미지가 있으면 정적 표시 (애니메이션 없음)
    /// 없으면 mood 기반 이미지 순환 애니메이션
    private fun updateAppWidgetForAnimation(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int
    ) {
        try {
            val level = getWidgetString(context, "level", "1")?.toIntOrNull() ?: 1
            val hunger = getWidgetString(context, "hunger", "100")?.toIntOrNull() ?: 100
            val happiness = getWidgetString(context, "happiness", "100")?.toIntOrNull() ?: 100
            val stamina = getWidgetString(context, "stamina", "100")?.toIntOrNull() ?: 100
            val rawMood = getWidgetString(context, "mood", "normal") ?: "normal"
            val resolvedMood = resolveMood(rawMood, hunger, happiness, stamina)
            val imageType = resolveImageType(
                getWidgetString(context, "imageType", null),
                resolvedMood
            )
            val moodText = getWidgetString(context, "moodText", null)
            val evolutionImage = getWidgetString(context, "evolutionImage", null)

            val views = RemoteViews(context.packageName, R.layout.pet_widget)

            // 이미지 결정: 진화 이미지 우선
            val imageResourceId = resolveWidgetImageResourceId(context, evolutionImage, imageType)

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

            views.setTextViewText(R.id.pet_level, "Lv.$level")

            val displayMoodText = resolveMoodText(moodText, resolvedMood)
            views.setTextViewText(R.id.pet_mood, displayMoodText)

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
            "sad" -> "sad"
            "happy" -> "happy"
            "normal" -> "exercise"
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
            mood == "normal" ||
            mood == "hungry" ||
            mood == "sleepy" ||
            mood == "tired" ||
            mood == "sad"
    }

    /// Flutter Pet.mood 로직과 동일한 상태 판정
    /// pet.dart의 mood getter와 동일한 우선순위·임계값 유지
    private fun calculateMoodFromStats(hunger: Int, happiness: Int, stamina: Int): String {
        val hour = java.util.Calendar.getInstance().get(java.util.Calendar.HOUR_OF_DAY)
        val isNightTime = hour >= 22 || hour < 6

        // pet.dart의 mood getter와 동일한 우선순위·임계값 (6종)
        // 1) 배고픔
        if (hunger <= 25) return "hungry"
        // 2) 지침
        if (stamina <= 25) return "tired"
        // 3) 졸림 (밤에는 더 민감)
        if (isNightTime && stamina <= 60) return "sleepy"
        if (stamina <= 40) return "sleepy"
        // 4) 시무룩
        if (happiness <= 35) return "sad"
        // 5) 행복
        if (hunger >= 75 && happiness >= 70 && stamina >= 60) return "happy"
        // 6) 보통
        return "normal"
    }

    /// 위젯에 표시할 이미지 리소스 ID 결정
    /// 진화 이미지가 있으면 우선 사용, 없으면 mood 기반 애니메이션 이미지 사용
    /// 홈 화면과 동일한 이미지를 보장하기 위해 Flutter에서 전달한 evolutionImage를 우선 참조
    private fun resolveWidgetImageResourceId(
        context: Context,
        evolutionImage: String?,
        imageType: String
    ): Int {
        // 1. 진화 이미지가 있으면 우선 사용 (정적 이미지, 애니메이션 없음)
        if (!evolutionImage.isNullOrBlank()) {
            val evoResourceId = context.resources.getIdentifier(
                evolutionImage, "drawable", context.packageName
            )
            if (evoResourceId != 0) {
                return evoResourceId
            }
            Log.w("PetWidgetProvider", "Evolution image not found: $evolutionImage, falling back to mood")
        }

        // 2. 진화 이미지가 없으면 mood 기반 애니메이션 이미지
        val currentTime = System.currentTimeMillis()
        val imageCount = getImageCountForImageType(imageType)
        val cycleDuration = imageCount * ANIMATION_UPDATE_INTERVAL
        val imageIndex = ((currentTime % cycleDuration) / ANIMATION_UPDATE_INTERVAL).toInt() % imageCount
        val imageResourceName = resolveImageResourceName(imageType, imageIndex)
        return context.resources.getIdentifier(imageResourceName, "drawable", context.packageName)
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
            "happy" -> "행복"
            "normal" -> "보통"
            "hungry" -> "배고픔"
            "sleepy" -> "졸림"
            "tired" -> "지침"
            "sad" -> "시무룩"
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
