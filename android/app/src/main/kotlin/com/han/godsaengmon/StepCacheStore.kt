package com.han.godsaengmon

import android.content.Context

/**
 * 걸음 센서 누적값 캐시 저장소
 *
 * 두 SharedPreferences 파일에 동시에 기록한다:
 * 1. 네이티브 캐시([NATIVE_PREFS_NAME]) — MainActivity가 즉시 응답용으로 사용
 * 2. Flutter 캐시([FLUTTER_PREFS_NAME]) — shared_preferences 플러그인이 읽는
 *    파일. MethodChannel이 없는 WorkManager 백그라운드 isolate에서
 *    StepSensorDatasource가 폴백으로 읽는다.
 *
 * TYPE_STEP_COUNTER 누적값은 단조 증가하므로 오래된 캐시를 읽어도
 * 걸음수가 과대 계산되지 않는다 (미달분은 다음 동기화에서 따라잡음).
 */
object StepCacheStore {

    private const val NATIVE_PREFS_NAME = "step_sensor_cache"
    private const val KEY_LATEST_STEPS = "latest_cumulative_steps"
    private const val KEY_LATEST_TIME = "latest_step_time"

    // shared_preferences 플러그인 규약: 파일명 고정 + 키에 "flutter." 접두어
    private const val FLUTTER_PREFS_NAME = "FlutterSharedPreferences"
    private const val FLUTTER_KEY_STEPS = "flutter.step_sensor_cumulative"
    private const val FLUTTER_KEY_TIME = "flutter.step_sensor_time"

    /** 누적 걸음수를 네이티브·Flutter 캐시에 모두 기록 */
    fun write(context: Context, cumulativeSteps: Long) {
        val now = System.currentTimeMillis()
        context.getSharedPreferences(NATIVE_PREFS_NAME, Context.MODE_PRIVATE)
            .edit()
            .putLong(KEY_LATEST_STEPS, cumulativeSteps)
            .putLong(KEY_LATEST_TIME, now)
            .apply()
        context.getSharedPreferences(FLUTTER_PREFS_NAME, Context.MODE_PRIVATE)
            .edit()
            .putLong(FLUTTER_KEY_STEPS, cumulativeSteps)
            .putLong(FLUTTER_KEY_TIME, now)
            .apply()
    }

    /** 네이티브 캐시에서 마지막 누적 걸음수 읽기 (없으면 -1) */
    fun loadLatestSteps(context: Context): Long =
        context.getSharedPreferences(NATIVE_PREFS_NAME, Context.MODE_PRIVATE)
            .getLong(KEY_LATEST_STEPS, -1L)
}
