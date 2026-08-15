package com.godsaengmon.app

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.os.Build
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
 * - Android 10(Q)+에서는 ACTIVITY_RECOGNITION 런타임 권한이 없으면 등록된
 *   리스너에 이벤트가 오지 않는다. 권한 요청은 Flutter 쪽에서 onCreate 이후에
 *   일어나므로, onResume마다 권한을 재확인해 아직 미등록이면 등록한다
 *   (권한을 나중에 허용한 세션에서도 재시작 없이 걸음이 잡히도록).
 */
class MainActivity : FlutterActivity(), SensorEventListener {

    companion object {
        private const val CHANNEL = "com.godsaengmon.app/step_counter"
        private const val TAG = "StepCounter"
        private const val READ_TIMEOUT_MS = 4000L
    }

    private var sensorManager: SensorManager? = null
    private var stepSensor: Sensor? = null
    private var latestSteps: Long = -1L
    private var isListenerRegistered = false

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

        // 마지막 캐시값 복원
        latestSteps = StepCacheStore.loadLatestSteps(this)

        // 권한이 이미 있으면 즉시 등록, 없으면 onResume에서 재시도
        registerStepListenerIfPossible()
    }

    override fun onResume() {
        super.onResume()
        // Flutter 쪽 권한 요청 다이얼로그가 닫히면 onResume이 호출되므로
        // 권한 허용 직후 같은 세션에서 리스너가 살아난다
        registerStepListenerIfPossible()
    }

    override fun onDestroy() {
        sensorManager?.unregisterListener(this)
        isListenerRegistered = false
        super.onDestroy()
    }

    /** Android 10+ 걸음 센서 필수 권한 보유 여부 */
    private fun hasActivityRecognitionPermission(): Boolean =
        Build.VERSION.SDK_INT < Build.VERSION_CODES.Q ||
            checkSelfPermission(Manifest.permission.ACTIVITY_RECOGNITION) ==
            PackageManager.PERMISSION_GRANTED

    /**
     * 권한이 있고 아직 미등록이면 걸음 센서 리스너 등록
     *
     * 권한 없이 등록된 리스너는 이벤트를 받지 못하므로 반드시 권한 확인 후
     * 등록한다. onCreate와 onResume 양쪽에서 호출해도 중복 등록되지 않는다.
     */
    private fun registerStepListenerIfPossible() {
        if (isListenerRegistered) return
        val manager = sensorManager ?: return
        val sensor = stepSensor ?: return

        if (!hasActivityRecognitionPermission()) {
            Log.w(TAG, "ACTIVITY_RECOGNITION 권한 없음 → 리스너 등록 보류")
            return
        }

        manager.registerListener(
            this,
            sensor,
            SensorManager.SENSOR_DELAY_NORMAL,
        )
        isListenerRegistered = true
        Log.d(TAG, "걸음 센서 리스너 등록 완료")

        // 앱이 죽어 있어도 걸음 캐시가 갱신되도록 15분 주기 워커 등록
        // (권한이 확인된 시점에만 스케줄)
        StepCacheWorker.schedule(applicationContext)
    }

    override fun onSensorChanged(event: SensorEvent?) {
        val value = event?.values?.firstOrNull()?.toLong() ?: return
        latestSteps = value
        // 캐시 영속화 — 앱 재시작 후 즉시 사용 + 백그라운드 isolate 폴백용
        StepCacheStore.write(applicationContext, value)
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

        // 권한이 없으면 일회성 리스너도 이벤트를 못 받으므로 대기 없이 캐시 반환
        if (!hasActivityRecognitionPermission()) {
            Log.w(TAG, "ACTIVITY_RECOGNITION 권한 없음 → 영속 캐시 반환")
            result.success(loadCachedSteps())
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
                    StepCacheStore.write(applicationContext, steps)
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

    private fun loadCachedSteps(): Long = StepCacheStore.loadLatestSteps(this)
}
