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
        
        when (intent.action) {
            AppWidgetManager.ACTION_APPWIDGET_UPDATE,
            "es.antonborri.home_widget.UPDATE_WIDGET" -> {
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
            // SharedPreferences에서 펫 데이터 읽기
            // home_widget 패키지는 "HomeWidget" 이름의 SharedPreferences에 데이터를 저장
            val prefs = context.getSharedPreferences("HomeWidget", Context.MODE_PRIVATE)
            
            // 문자열로 저장된 데이터를 읽어서 정수로 변환
            val hunger = prefs.getString("hunger", "100")?.toIntOrNull() ?: 100
            val happiness = prefs.getString("happiness", "100")?.toIntOrNull() ?: 100
            val stamina = prefs.getString("stamina", "100")?.toIntOrNull() ?: 100
            val level = prefs.getString("level", "1")?.toIntOrNull() ?: 1
            val imageType = prefs.getString("imageType", "sleeping") ?: "sleeping"
            val mood = prefs.getString("mood", "normal") ?: "normal"
            // Flutter에서 저장한 상태 텍스트 읽기 (앱 내 상태와 동기화)
            val moodText = prefs.getString("moodText", null)
            
            // 디버깅: moodText가 제대로 읽히는지 확인
            Log.d("PetWidgetProvider", "Widget update - level: $level, moodText: $moodText, mood: $mood, hunger: $hunger, happiness: $happiness, stamina: $stamina")
            
            // 현재 시간 기반으로 이미지 인덱스 계산 (애니메이션 효과)
            // 이미지 타입에 따라 다른 개수 사용: hungry는 4장, sleeping은 3장
            val currentTime = System.currentTimeMillis()
            val imageCount = if (imageType == "hungry") 4 else 3
            val cycleDuration = imageCount * ANIMATION_UPDATE_INTERVAL // 이미지 개수 * 800ms
            val imageIndex = ((currentTime % cycleDuration) / ANIMATION_UPDATE_INTERVAL).toInt() % imageCount
            
            // 위젯 레이아웃 생성
            val views = RemoteViews(context.packageName, R.layout.pet_widget)
            
            // 펫 이미지 결정 (앱 홈 화면과 동일한 로직)
            // 이미지 타입에 따라 다른 이미지 표시
            // 주의: 이미지는 android/app/src/main/res/drawable/ 폴더에 있어야 함
            val imageResourceName = when (imageType) {
                "hungry" -> {
                    // 배고픈 이미지 (hungry_1, hungry_2, hungry_3, hungry_4)
                    when (imageIndex) {
                        0 -> "hungry_1"
                        1 -> "hungry_2"
                        2 -> "hungry_3"
                        3 -> "hungry_4"
                        else -> "hungry_1"
                    }
                }
                "sleeping", "normal" -> {
                    // 잠자는 이미지 (sleeping_1, sleeping_2, sleeping_3)
                    when (imageIndex) {
                        0 -> "sleeping_1"
                        1 -> "sleeping_2"
                        2 -> "sleeping_3"
                        else -> "sleeping_1"
                    }
                }
                else -> "sleeping_1" // 기본값
            }
            
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
                val petEmoji = when {
                    imageType == "hungry" -> "🍽️"
                    happiness >= 70 -> "🌟"
                    happiness >= 40 -> "💤"
                    else -> "💧"
                }
                views.setTextViewText(R.id.pet_image_text, petEmoji)
                views.setViewVisibility(R.id.pet_image, android.view.View.GONE)
                views.setViewVisibility(R.id.pet_image_text, android.view.View.VISIBLE)
            }
            
            views.setTextViewText(R.id.pet_level, "Lv.$level")
            
            // 상태 텍스트 설정 (한국어)
            // Flutter에서 저장한 moodText를 우선 사용 (앱 내 상태와 동기화)
            // moodText가 없으면 Pet.mood 로직과 동일하게 계산 (하위 호환성)
            val displayMoodText = moodText ?: run {
                // Pet.mood 로직과 동일하게 계산
                when {
                    // 모든 수치가 90 이상이면 활기참 상태
                    hunger >= 90 && happiness >= 90 && stamina >= 90 -> "활기참"
                    // 모든 수치가 80 이상이면 기쁨 상태
                    hunger >= 80 && happiness >= 80 && stamina >= 80 -> "기쁨"
                    // 포만감이 90 이상이고 다른 수치도 60 이상이면 배부름 상태
                    hunger >= 90 && happiness >= 60 && stamina >= 60 -> "배부름"
                    // 대부분의 수치가 70 이상이면 만족함 상태
                    (hunger >= 70 && happiness >= 70) || 
                    (hunger >= 70 && stamina >= 70) || 
                    (happiness >= 70 && stamina >= 70) -> "만족함"
                    // 배고픔이 20 이하이면 배고픔 상태
                    hunger <= 20 -> "배고픔"
                    // 체력이 20 이하이면 피곤함 상태
                    stamina <= 20 -> "피곤함"
                    // 체력이 30 이하이면 졸림 상태
                    stamina <= 30 -> "졸림"
                    // 행복도가 20 이하이면 불안함 상태
                    happiness <= 20 -> "불안함"
                    // 행복도가 30 이하이면 지루함 상태
                    happiness <= 30 -> "지루함"
                    // 수치가 불균형할 때 불안함 상태
                    else -> {
                        val avg = (hunger + happiness + stamina) / 3.0
                        val maxDiff = maxOf(
                            kotlin.math.abs(hunger - avg),
                            kotlin.math.abs(happiness - avg),
                            kotlin.math.abs(stamina - avg)
                        )
                        if (maxDiff > 40) "불안함" else "보통"
                    }
                }
            }
            views.setTextViewText(R.id.pet_mood, displayMoodText)
            
            // 디버깅: 실제로 표시되는 값 확인
            Log.d("PetWidgetProvider", "Displaying - level: $level, moodText: $displayMoodText (from moodText: $moodText)")
            
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
            val prefs = context.getSharedPreferences("HomeWidget", Context.MODE_PRIVATE)
            
            // 기존 데이터 읽기
            val hunger = prefs.getString("hunger", "100")?.toIntOrNull() ?: 100
            val happiness = prefs.getString("happiness", "100")?.toIntOrNull() ?: 100
            val stamina = prefs.getString("stamina", "100")?.toIntOrNull() ?: 100
            val level = prefs.getString("level", "1")?.toIntOrNull() ?: 1
            val imageType = prefs.getString("imageType", "sleeping") ?: "sleeping"
            // Flutter에서 저장한 상태 텍스트 읽기 (앱 내 상태와 동기화)
            val moodText = prefs.getString("moodText", null)
            
            // 디버깅: 애니메이션 업데이트 시에도 moodText 확인
            Log.d("PetWidgetProvider", "Animation update - level: $level, moodText: $moodText")
            
            // 현재 시간 기반으로 이미지 인덱스 계산 (애니메이션 효과)
            // 시간 기반으로 순환하여 위젯이 업데이트될 때마다 다른 이미지 표시
            val currentTime = System.currentTimeMillis()
            // 이미지 타입에 따라 다른 개수 사용: hungry는 4장, sleeping은 3장
            val imageCount = if (imageType == "hungry") 4 else 3
            val cycleDuration = imageCount * ANIMATION_UPDATE_INTERVAL // 이미지 개수 * 800ms
            val imageIndex = ((currentTime % cycleDuration) / ANIMATION_UPDATE_INTERVAL).toInt() % imageCount
            
            Log.d("PetWidgetProvider", "Animation update: imageType=$imageType, imageIndex=$imageIndex")
            
            val views = RemoteViews(context.packageName, R.layout.pet_widget)
            
            // 펫 이미지 결정
            val imageResourceName = when (imageType) {
                "hungry" -> {
                    when (imageIndex) {
                        0 -> "hungry_1"
                        1 -> "hungry_2"
                        2 -> "hungry_3"
                        3 -> "hungry_4"
                        else -> "hungry_1"
                    }
                }
                "sleeping", "normal" -> {
                    when (imageIndex) {
                        0 -> "sleeping_1"
                        1 -> "sleeping_2"
                        2 -> "sleeping_3"
                        else -> "sleeping_1"
                    }
                }
                else -> "sleeping_1"
            }
            
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
                val petEmoji = when {
                    imageType == "hungry" -> "🍽️"
                    happiness >= 70 -> "🌟"
                    happiness >= 40 -> "💤"
                    else -> "💧"
                }
                views.setTextViewText(R.id.pet_image_text, petEmoji)
                views.setViewVisibility(R.id.pet_image, android.view.View.GONE)
                views.setViewVisibility(R.id.pet_image_text, android.view.View.VISIBLE)
            }
            
            // 기존 데이터 유지
            views.setTextViewText(R.id.pet_level, "Lv.$level")
            
            // 상태 텍스트 설정 (한국어)
            // Flutter에서 저장한 moodText를 우선 사용 (앱 내 상태와 동기화)
            // moodText가 없으면 Pet.mood 로직과 동일하게 계산 (하위 호환성)
            val displayMoodText = moodText ?: run {
                // Pet.mood 로직과 동일하게 계산
                when {
                    // 모든 수치가 90 이상이면 활기참 상태
                    hunger >= 90 && happiness >= 90 && stamina >= 90 -> "활기참"
                    // 모든 수치가 80 이상이면 기쁨 상태
                    hunger >= 80 && happiness >= 80 && stamina >= 80 -> "기쁨"
                    // 포만감이 90 이상이고 다른 수치도 60 이상이면 배부름 상태
                    hunger >= 90 && happiness >= 60 && stamina >= 60 -> "배부름"
                    // 대부분의 수치가 70 이상이면 만족함 상태
                    (hunger >= 70 && happiness >= 70) || 
                    (hunger >= 70 && stamina >= 70) || 
                    (happiness >= 70 && stamina >= 70) -> "만족함"
                    // 배고픔이 20 이하이면 배고픔 상태
                    hunger <= 20 -> "배고픔"
                    // 체력이 20 이하이면 피곤함 상태
                    stamina <= 20 -> "피곤함"
                    // 체력이 30 이하이면 졸림 상태
                    stamina <= 30 -> "졸림"
                    // 행복도가 20 이하이면 불안함 상태
                    happiness <= 20 -> "불안함"
                    // 행복도가 30 이하이면 지루함 상태
                    happiness <= 30 -> "지루함"
                    // 수치가 불균형할 때 불안함 상태
                    else -> {
                        val avg = (hunger + happiness + stamina) / 3.0
                        val maxDiff = maxOf(
                            kotlin.math.abs(hunger - avg),
                            kotlin.math.abs(happiness - avg),
                            kotlin.math.abs(stamina - avg)
                        )
                        if (maxDiff > 40) "불안함" else "보통"
                    }
                }
            }
            views.setTextViewText(R.id.pet_mood, displayMoodText)
            
            // 디버깅: 애니메이션 업데이트 시에도 실제로 표시되는 값 확인
            Log.d("PetWidgetProvider", "Animation displaying - level: $level, moodText: $displayMoodText (from moodText: $moodText)")
            
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
