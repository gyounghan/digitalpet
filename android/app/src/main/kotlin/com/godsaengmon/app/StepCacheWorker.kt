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
import androidx.work.CoroutineWorker
import androidx.work.ExistingPeriodicWorkPolicy
import androidx.work.PeriodicWorkRequestBuilder
import androidx.work.WorkManager
import androidx.work.WorkerParameters
import java.util.concurrent.TimeUnit
import kotlin.coroutines.resume
import kotlinx.coroutines.suspendCancellableCoroutine
import kotlinx.coroutines.withTimeoutOrNull

/**
 * 백그라운드 걸음 센서 캐시 워커
 *
 * 앱(액티비티)이 죽어 있어도 15분 주기로 TYPE_STEP_COUNTER를 1회 읽어
 * [StepCacheStore]에 기록한다. Flutter의 WorkManager 백그라운드 작업이
 * MethodChannel 없이도 최신 걸음수를 읽을 수 있게 하는 공급자 역할.
 *
 * Health Connect가 없는 기기에서 "주머니에 넣고 걷는 동안" 걸음이
 * 전혀 안 쌓이던 문제를 해소한다.
 */
class StepCacheWorker(
    context: Context,
    params: WorkerParameters,
) : CoroutineWorker(context, params) {

    companion object {
        private const val TAG = "StepCacheWorker"
        private const val UNIQUE_WORK_NAME = "step_cache_sync"
        private const val SYNC_INTERVAL_MINUTES = 15L
        private const val SENSOR_READ_TIMEOUT_MS = 5_000L

        /**
         * 15분 주기 캐시 작업 등록 (이미 등록돼 있으면 유지)
         *
         * ACTIVITY_RECOGNITION 권한이 허용된 뒤 호출한다.
         */
        fun schedule(context: Context) {
            val request = PeriodicWorkRequestBuilder<StepCacheWorker>(
                SYNC_INTERVAL_MINUTES,
                TimeUnit.MINUTES,
            ).build()
            WorkManager.getInstance(context.applicationContext)
                .enqueueUniquePeriodicWork(
                    UNIQUE_WORK_NAME,
                    ExistingPeriodicWorkPolicy.KEEP,
                    request,
                )
        }
    }

    override suspend fun doWork(): Result {
        val appContext = applicationContext

        if (!hasActivityRecognitionPermission(appContext)) {
            Log.w(TAG, "ACTIVITY_RECOGNITION 권한 없음 → 캐시 생략")
            return Result.success()
        }

        val manager =
            appContext.getSystemService(Context.SENSOR_SERVICE) as? SensorManager
                ?: return Result.success()
        val sensor = manager.getDefaultSensor(Sensor.TYPE_STEP_COUNTER)
            ?: return Result.success()

        val steps = readSensorOnce(manager, sensor)
        if (steps >= 0) {
            StepCacheStore.write(appContext, steps)
            Log.d(TAG, "백그라운드 걸음 캐시 갱신: $steps")
        } else {
            Log.w(TAG, "센서 응답 타임아웃 → 캐시 유지")
        }
        return Result.success()
    }

    private fun hasActivityRecognitionPermission(context: Context): Boolean =
        Build.VERSION.SDK_INT < Build.VERSION_CODES.Q ||
            context.checkSelfPermission(
                Manifest.permission.ACTIVITY_RECOGNITION,
            ) == PackageManager.PERMISSION_GRANTED

    /**
     * 센서를 일회성으로 읽어 누적 걸음수 반환 (타임아웃 시 -1)
     *
     * TYPE_STEP_COUNTER는 리스너 등록 직후 현재 누적값 이벤트를 보내준다.
     */
    private suspend fun readSensorOnce(
        manager: SensorManager,
        sensor: Sensor,
    ): Long = withTimeoutOrNull(SENSOR_READ_TIMEOUT_MS) {
        suspendCancellableCoroutine { continuation ->
            val listener = object : SensorEventListener {
                override fun onSensorChanged(event: SensorEvent?) {
                    val value = event?.values?.firstOrNull()?.toLong() ?: return
                    manager.unregisterListener(this)
                    if (continuation.isActive) {
                        continuation.resume(value)
                    }
                }

                override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) {
                    // 무시
                }
            }

            manager.registerListener(
                listener,
                sensor,
                SensorManager.SENSOR_DELAY_FASTEST,
                Handler(Looper.getMainLooper()),
            )
            continuation.invokeOnCancellation {
                manager.unregisterListener(listener)
            }
        }
    } ?: -1L
}
