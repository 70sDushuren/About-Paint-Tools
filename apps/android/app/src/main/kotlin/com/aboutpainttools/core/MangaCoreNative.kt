package com.aboutpainttools.core

/**
 * JNI bridge contract mirroring `core/manga-core/include/manga_core.h` (`libmanga_core.so`).
 * Shared across Android Pads and Foldable Phones (Wave 2, v1.1).
 */
object MangaCoreNative {
    init {
        System.loadLibrary("manga_core")
    }

    const val PLATFORM_ANDROID_PAD_FOLDABLE: Int = 3

    const val POSTURE_FLAT: Int = 0
    const val POSTURE_FOLDED_COMPACT: Int = 1
    const val POSTURE_UNFOLDED_DUAL_PANE: Int = 2
    const val POSTURE_TABLETOP_HALF_OPEN: Int = 3

    external fun createCanvasPreset(presetCode: Int): Long
    external fun destroyCanvas(handle: Long)
    external fun canvasWidth(handle: Long): Int
    external fun canvasHeight(handle: Long): Int
    external fun beginStroke(
        handle: Long,
        baseRadius: Float,
        r: Int,
        g: Int,
        b: Int,
        a: Int,
        isEraser: Boolean,
        stabilizerRadius: Float
    )
    external fun endStroke(handle: Long): Int
    external fun undo(handle: Long): Boolean
    external fun redo(handle: Long): Boolean

    /** Queries Rust `manga_platform_recommend_layout` for deterministic foldable/tablet UI layout. */
    external fun recommendWorkspaceLayout(
        platformCode: Int,
        postureCode: Int,
        widthDp: Float,
        heightDp: Float
    ): Int
}
