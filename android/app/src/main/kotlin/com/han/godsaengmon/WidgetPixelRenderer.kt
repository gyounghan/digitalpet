package com.han.godsaengmon

import android.content.Context
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Paint
import android.util.Log
import org.json.JSONArray
import org.json.JSONObject

/// 앱과 동일한 도트 픽셀을 위젯에서 직접 렌더하기 위한 스프라이트 데이터.
///
/// 좌표 데이터는 `tool/generate_pixel_data.py`가 Dart(`pet_pixel_data.dart`)와
/// **동시에** 굽는 `assets/pet_pixel_data.json`에서 읽는다. 즉 도트를 수정하면
/// 스크립트 한 번으로 앱과 위젯이 함께 갱신된다(Kotlin에 좌표 테이블을 손으로
/// 복제하지 않음).
data class WidgetSprite(
    val size: Int,
    val dark: LongArray,
    val body: LongArray,
    val accent: LongArray,
    val accent2: LongArray,
    val accent3: LongArray,
)

/// JSON 스프라이트 로더 (프로세스 수명 동안 1회 파싱 후 캐시)
object WidgetPixelData {
    private const val TAG = "WidgetPixelData"
    private const val ASSET_NAME = "pet_pixel_data.json"
    private const val GRID = 64

    @Volatile
    private var cache: Map<String, WidgetSprite>? = null

    /// 스프라이트 키(`bird_smile1`, `기본이미지`, `dragon2` 등)로 조회
    fun sprite(context: Context, key: String): WidgetSprite? = load(context)[key]

    private fun load(context: Context): Map<String, WidgetSprite> {
        cache?.let { return it }
        val parsed = runCatching { parse(context) }.getOrElse {
            Log.e(TAG, "도트 JSON 파싱 실패", it)
            emptyMap()
        }
        cache = parsed
        return parsed
    }

    private fun parse(context: Context): Map<String, WidgetSprite> {
        val text = context.assets.open(ASSET_NAME)
            .bufferedReader(Charsets.UTF_8).use { it.readText() }
        val root = JSONObject(text)
        val result = HashMap<String, WidgetSprite>(root.length())
        for (key in root.keys()) {
            val obj = root.getJSONObject(key)
            result[key] = WidgetSprite(
                size = GRID,
                dark = toRows(obj.getJSONArray("d")),
                body = toRows(obj.getJSONArray("b")),
                accent = toRows(obj.getJSONArray("a")),
                accent2 = toOptionalRows(obj.optJSONArray("a2")),
                accent3 = toOptionalRows(obj.optJSONArray("a3")),
            )
        }
        return result
    }

    /// 16자리 부호없는 hex 문자열 배열 → Long 행 마스크
    /// (최상위 비트 x=63이 켜진 행은 음수 Long이 되지만 비트 연산만 쓰므로 무해)
    private fun toRows(array: JSONArray): LongArray =
        LongArray(array.length()) { index ->
            java.lang.Long.parseUnsignedLong(array.getString(index), 16)
        }

    /// accent2/accent3처럼 없을 수 있는 레이어용 (구버전 JSON 호환)
    private fun toOptionalRows(array: JSONArray?): LongArray =
        if (array == null) LongArray(0) else toRows(array)
}

/// 홈 위젯용 모션 도트 로더 — `tool/generate_motion_data.py`가 앱
/// (`pet_motion_data.dart`)과 동시에 굽는 `assets/pet_motion_data.json`.
///
/// 스프라이트 키('fluff'/'dragon1'/'dragon2') → 모션 이름('walk'/'joy'/…) →
/// 프레임 3장("f" 배열). 위젯은 RemoteViews ViewFlipper로 프레임을 순환 재생.
/// 앱 홈이 그리는 도트 모션과 100% 동일 좌표 — 스크립트가 자동 동기화.
object WidgetMotionData {
    private const val TAG = "WidgetMotionData"
    private const val ASSET_NAME = "pet_motion_data.json"

    @Volatile
    private var cache: Map<String, Map<String, List<WidgetSprite>>>? = null

    /// 스프라이트 키 + 모션 이름으로 전체 프레임 조회 (없으면 빈 리스트)
    fun frames(context: Context, key: String, motion: String): List<WidgetSprite> =
        load(context)[key]?.get(motion) ?: emptyList()

    /// 대표 프레임(첫 장) 조회 — 정지 이미지 폴백용
    fun sprite(context: Context, key: String, motion: String): WidgetSprite? =
        frames(context, key, motion).firstOrNull()

    private fun load(context: Context): Map<String, Map<String, List<WidgetSprite>>> {
        cache?.let { return it }
        val parsed = runCatching { parse(context) }.getOrElse {
            Log.e(TAG, "모션 JSON 파싱 실패", it)
            emptyMap()
        }
        cache = parsed
        return parsed
    }

    private fun parse(context: Context): Map<String, Map<String, List<WidgetSprite>>> {
        val text = context.assets.open(ASSET_NAME)
            .bufferedReader(Charsets.UTF_8).use { it.readText() }
        val root = JSONObject(text)
        val result = HashMap<String, Map<String, List<WidgetSprite>>>(root.length())
        for (key in root.keys()) {
            val obj = root.getJSONObject(key)
            val size = obj.getInt("size")
            val motions = HashMap<String, List<WidgetSprite>>()
            for (motion in obj.keys()) {
                if (motion == "size") continue
                val frameArray = obj.getJSONObject(motion).getJSONArray("f")
                motions[motion] = List(frameArray.length()) { index ->
                    val frame = frameArray.getJSONObject(index)
                    WidgetSprite(
                        size = size,
                        dark = toRows(frame.getJSONArray("d")),
                        body = toRows(frame.getJSONArray("b")),
                        accent = toRows(frame.getJSONArray("a")),
                        accent2 = toOptionalRows(frame.optJSONArray("a2")),
                        accent3 = toOptionalRows(frame.optJSONArray("a3")),
                    )
                }
            }
            result[key] = motions
        }
        return result
    }

    private fun toRows(array: JSONArray): LongArray =
        LongArray(array.length()) { index ->
            java.lang.Long.parseUnsignedLong(array.getString(index), 16)
        }

    private fun toOptionalRows(array: JSONArray?): LongArray =
        if (array == null) LongArray(0) else toRows(array)
}

/// [WidgetSprite]를 5계조 색으로 Bitmap에 렌더 (앱 _PixelSpritePainter와 동일 규칙)
object WidgetPixelRenderer {
    /// 아웃라인/눈 기본 색 (앱 SpeciesTheme.dotDark와 동일) — darkColor 미지정 시 폴백
    private const val DARK_COLOR = 0xFF14161A.toInt()

    /// 도트가 맞닿는 경계의 안티에일리어싱 흰 실선을 없애기 위한 미세 오버랩 비율
    private const val SEAM_OVERLAP_RATIO = 0.06f

    /// 앱이 계산해 넘긴 5색(dark/body/accent/accent2/accent3)으로 렌더한다.
    /// accent2/accent3가 없거나 0이면 accent로 폴백해 3색 스프라이트도 그대로 그린다.
    /// 그리기 순서 body → accent → accent2 → accent3 → dark 는 앱의 픽셀 우선순위
    /// (dark > a3 > a2 > accent > body)와 동일한 결과를 낸다.
    fun render(
        sprite: WidgetSprite,
        dotColor: Int,
        accentColor: Int,
        sizePx: Int,
        darkColor: Int = DARK_COLOR,
        accent2Color: Int = accentColor,
        accent3Color: Int = accentColor,
    ): Bitmap {
        val n = sprite.size
        val bitmap = Bitmap.createBitmap(sizePx, sizePx, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap)
        val cell = sizePx.toFloat() / n
        val overlap = cell * SEAM_OVERLAP_RATIO

        val bodyPaint = Paint().apply { color = dotColor; isAntiAlias = false }
        val accentPaint = Paint().apply { color = accentColor; isAntiAlias = false }
        val accent2Paint = Paint().apply { color = accent2Color; isAntiAlias = false }
        val accent3Paint = Paint().apply { color = accent3Color; isAntiAlias = false }
        val darkPaint = Paint().apply { color = darkColor; isAntiAlias = false }

        drawLayer(canvas, sprite.body, n, cell, overlap, bodyPaint)
        drawLayer(canvas, sprite.accent, n, cell, overlap, accentPaint)
        drawLayer(canvas, sprite.accent2, n, cell, overlap, accent2Paint)
        drawLayer(canvas, sprite.accent3, n, cell, overlap, accent3Paint)
        drawLayer(canvas, sprite.dark, n, cell, overlap, darkPaint)
        return bitmap
    }

    private fun drawLayer(
        canvas: Canvas,
        rows: LongArray,
        n: Int,
        cell: Float,
        overlap: Float,
        paint: Paint,
    ) {
        for (y in rows.indices) {
            val mask = rows[y]
            if (mask != 0L) drawRow(canvas, mask, y, n, cell, overlap, paint)
        }
    }

    private fun drawRow(
        canvas: Canvas,
        mask: Long,
        y: Int,
        n: Int,
        cell: Float,
        overlap: Float,
        paint: Paint,
    ) {
        val top = y * cell
        for (x in 0 until n) {
            if (mask ushr x and 1L == 0L) continue
            val left = x * cell
            canvas.drawRect(left, top, left + cell + overlap, top + cell + overlap, paint)
        }
    }
}
