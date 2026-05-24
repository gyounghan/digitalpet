package com.example.pocketfriend

import android.content.Context
import android.content.SharedPreferences
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.os.Handler
import android.os.Looper
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * MainActivity
 *
 * Flutter MethodChannel을 통해 Android 내장 걸음수 센서(TYPE_STEP_COUNTER)를
 * 직접 읽어 Flutter 측에 전달한다.
 *
 * 핵심 개선:
 * - TYPE_STEP_COUNTER는 폰이 움직이지 않으면 onSensorChanged가 호출되지 않을 수
 *   있어 단발성 read는 자주 -1로 끝난다.
 * - 대신 onCreate에서 항상 리스너를 등록해두고 최신값을 캐시(SharedPreferences)
 *   에 유지한다. getStepCount 호출 시 캐시값이 있으면 즉시 반환.
 */
class MainActivity : FlutterActivity(), SensorEventListener {

    companion object {
        private const val CHANNEL = "com.example.pocketfriend/step_counter"
        private const val TAG = "StepCounter"
        private const val PREFS_NAME = "step_sensor_cache"
        private const val KEY_LATEST_STEPS = "latest_cumulative_steps"
        private const val KEY_LATEST_TIME = "latest_step_time"
        private const val READ_TIMEOUT_MS = 4000L
    }

    private var sensorManager: SensorManager? = null
    private var stepSensor: Sensor? = null
    private var latestSteps: Long = -1L

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CHANNEL,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "getStepCount" -> getStepCount(result)
                "isStepSensorAvailable" -> result.success(stepSensor != null)
                else -> result.notImplemented()
            }
        }
    }

    override fun onCreate(savedInstanceState: android.os.Bundle?) {
        super.onCreate(savedInstanceState)
        // 센서 매니저/센서 초기화
        sensorManager =
            getSystemService(Context.SENSOR_SERVICE) as? SensorManager
        stepSensor =
            sensorManager?.getDefaultSensor(Sensor.TYPE_STEP_COUNTER)

        if (stepSensor == null) {
            Log.w(TAG, "TYPE_STEP_COUNTER 센서를 찾을 수 없음")
            return
        }

        // 앱이 살아있는 동안 지속적으로 리스너 등록 → 캐시 유지
        sensorManager?.registerListener(
            this,
            stepSensor,
            SensorManager.SENSOR_DELAY_NORMAL,
        )

        // 마지막 캐시값 복원
        val prefs = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        latestSteps = prefs.getLong(KEY_LATEST_STEPS, -1L)
    }

    override fun onDestroy() {
        sensorManager?.unregisterListener(this)
        super.onDestroy()
    }

    override fun onSensorChanged(event: SensorEvent?) {
        val value = event?.values?.firstOrNull()?.toLong() ?: return
        latestSteps = value
        // 캐시 영속화 — 앱 죽었다가 살아도 마지막 값을 즉시 사용 가능
        getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            .edit()
            .putLong(KEY_LATEST_STEPS, value)
            .putLong(KEY_LATEST_TIME, System.currentTimeMillis())
            .apply()
    }

    override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) {
        // 무시
    }

    /**
     * 현재 누적 걸음수 반환
     *
     * 1) 캐시값(이전 onSensorChanged로 받은 값)이 있으면 즉시 반환
     * 2) 캐시 없으면 4초간 리스너로 첫 이벤트 대기
     * 3) 그래도 못 받으면 영속 캐시(SharedPreferences) 값 반환 (없으면 -1)
     */
    private fun getStepCount(result: MethodChannel.Result) {
        val manager = sensorManager
        val sensor = stepSensor

        if (manager == null || sensor == null) {
            Log.w(TAG, "센서 사용 불가 → 영속 캐시 시도")
            result.success(loadCachedSteps())
            return
        }

        // 1) 이미 받아둔 값이 있으면 즉시 반환
        if (latestSteps >= 0) {
            result.success(latestSteps)
            return
        }

        // 2) 일회성 리스너로 첫 이벤트 대기
        var isResultSent = false
        val oneShotListener = object : SensorEventListener {
            override fun onSensorChanged(event: SensorEvent?) {
                if (isResultSent) return
                isResultSent = true

                val steps = event?.values?.firstOrNull()?.toLong() ?: -1L
                latestSteps = steps
                manager.unregisterListener(this)
                if (steps >= 0) {
                    getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
                        .edit()
                        .putLong(KEY_LATEST_STEPS, steps)
                        .putLong(KEY_LATEST_TIME, System.currentTimeMillis())
                        .apply()
                }
                result.success(steps)
            }

            override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) {
                // 무시
            }
        }

        manager.registerListener(
            oneShotListener,
            sensor,
            SensorManager.SENSOR_DELAY_FASTEST,
        )

        // 3) 4초 타임아웃: 그래도 못 받으면 영속 캐시 사용
        Handler(Looper.getMainLooper()).postDelayed({
            if (!isResultSent) {
                isResultSent = true
                manager.unregisterListener(oneShotListener)
                val cached = loadCachedSteps()
                Log.w(TAG, "센서 응답 타임아웃 → 캐시 사용 (cached=$cached)")
                result.success(cached)
            }
        }, READ_TIMEOUT_MS)
    }

    private fun loadCachedSteps(): Long {
        val prefs: SharedPreferences =
            getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        return prefs.getLong(KEY_LATEST_STEPS, -1L)
    }
}
