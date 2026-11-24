package com.aboutpainttools.input

import android.view.MotionEvent
import androidx.window.layout.FoldingFeature
import androidx.window.layout.WindowLayoutInfo
import com.aboutpainttools.core.MangaCoreNative

/**
 * Hardware-native stylus sample mirrored 1:1 with `manga_core::StrokePoint`.
 */
data class AndroidStrokeSample(
    val x: Float,
    val y: Float,
    val pressure: Float,
    val altitudeRad: Float,
    val azimuthRad: Float,
    val timestampMs: Double,
    val isEraserTool: Boolean,
    val isPredicted: Boolean = false
)

/**
 * Extracts high-frequency batched `MotionEvent` historical points (S-Pen / M-Pencil / USI 2.0)
 * and resolves Jetpack WindowManager `FoldingFeature` hinge posture into `manga-core` posture codes.
 */
object AndroidStylusAndFoldAdapter {
    fun extractSamples(event: MotionEvent, pointerIndex: Int = 0): List<AndroidStrokeSample> {
        val toolType = event.getToolType(pointerIndex)
        val isEraser = toolType == MotionEvent.TOOL_TYPE_ERASER
        val out = ArrayList<AndroidStrokeSample>(event.historySize + 1)

        for (h in 0 until event.historySize) {
            val tilt = event.getHistoricalAxisValue(MotionEvent.AXIS_TILT, pointerIndex, h)
            val orientation = event.getHistoricalAxisValue(MotionEvent.AXIS_ORIENTATION, pointerIndex, h)
            out.add(
                AndroidStrokeSample(
                    x = event.getHistoricalX(pointerIndex, h),
                    y = event.getHistoricalY(pointerIndex, h),
                    pressure = event.getHistoricalPressure(pointerIndex, h).coerceIn(0f, 1f),
                    altitudeRad = ((Math.PI / 2.0) - tilt.toDouble()).coerceAtLeast(0.0).toFloat(),
                    azimuthRad = orientation,
                    timestampMs = event.getHistoricalEventTime(h).toDouble(),
                    isEraserTool = isEraser
                )
            )
        }

        val tilt = event.getAxisValue(MotionEvent.AXIS_TILT, pointerIndex)
        val orientation = event.getAxisValue(MotionEvent.AXIS_ORIENTATION, pointerIndex)
        out.add(
            AndroidStrokeSample(
                x = event.getX(pointerIndex),
                y = event.getY(pointerIndex),
                pressure = event.getPressure(pointerIndex).coerceIn(0f, 1f),
                altitudeRad = ((Math.PI / 2.0) - tilt.toDouble()).coerceAtLeast(0.0).toFloat(),
                azimuthRad = orientation,
                timestampMs = event.eventTime.toDouble(),
                isEraserTool = isEraser
            )
        )
        return out
    }

    fun resolveFoldPosture(layoutInfo: WindowLayoutInfo, widthDp: Float): Int {
        val fold = layoutInfo.displayFeatures.filterIsInstance<FoldingFeature>().firstOrNull()
        return when {
            fold == null && widthDp < 520f -> MangaCoreNative.POSTURE_FOLDED_COMPACT
            fold == null -> MangaCoreNative.POSTURE_FLAT
            fold.state == FoldingFeature.State.HALF_OPENED &&
                fold.orientation == FoldingFeature.Orientation.HORIZONTAL ->
                MangaCoreNative.POSTURE_TABLETOP_HALF_OPEN
            fold.state == FoldingFeature.State.FLAT &&
                fold.orientation == FoldingFeature.Orientation.VERTICAL ->
                MangaCoreNative.POSTURE_UNFOLDED_DUAL_PANE
            else -> MangaCoreNative.POSTURE_FLAT
        }
    }
}
