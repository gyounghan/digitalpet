package com.example.pocketfriend

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.widget.RemoteViews
import android.util.Log

/// 펫 홈 화면 위젯 Provider
/// 홈 화면에 펫 정보를 표시하는 위젯
/// 
/// home_widget 패키지에서 전달된 데이터를 읽어서 위젯에 표시
class PetWidgetProvider : AppWidgetProvider() {
    
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        // 각 위젯 인스턴스에 대해 업데이트 수행
        for (appWidgetId in appWidgetIds) {
            updateAppWidget(context, appWidgetManager, appWidgetId)
        }
    }
    
    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        
        // 위젯 업데이트 요청 시 onUpdate 호출
        // home_widget 패키지가 보내는 ACTION_APPWIDGET_UPDATE 브로드캐스트 처리
        if (intent.action == AppWidgetManager.ACTION_APPWIDGET_UPDATE ||
            intent.action == "es.antonborri.home_widget.UPDATE_WIDGET") {
            val appWidgetManager = AppWidgetManager.getInstance(context)
            val appWidgetIds = appWidgetManager.getAppWidgetIds(
                android.content.ComponentName(context, PetWidgetProvider::class.java)
            )
            if (appWidgetIds.isNotEmpty()) {
                onUpdate(context, appWidgetManager, appWidgetIds)
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
            val evolutionStage = prefs.getString("evolutionStage", "0")?.toIntOrNull() ?: 0
            
            // 위젯 레이아웃 생성
            val views = RemoteViews(context.packageName, R.layout.pet_widget)
            
            // 펫 이모지 결정 (행복도에 따라)
            val petEmoji = when {
                happiness >= 70 -> "🌟"
                happiness >= 40 -> "💤"
                else -> "💧"
            }
            
            // 위젯에 데이터 설정
            views.setTextViewText(R.id.pet_emoji, petEmoji)
            views.setTextViewText(R.id.pet_level, "Lv.$level")
            views.setProgressBar(R.id.hunger_bar, 100, hunger, false)
            views.setProgressBar(R.id.happiness_bar, 100, happiness, false)
            views.setProgressBar(R.id.stamina_bar, 100, stamina, false)
            
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
}
