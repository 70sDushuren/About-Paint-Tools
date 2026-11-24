using System;
using System.Runtime.InteropServices;

namespace AboutPaintTools.Windows.Native;

/// <summary>
/// C-ABI stroke sample mirroring `CMangaStrokePoint` in `core/manga-core/include/manga_core.h`.
/// </summary>
[StructLayout(LayoutKind.Sequential)]
public struct CMangaStrokePoint
{
    public float X;
    public float Y;
    public float Pressure;
    public float Altitude;
    public float Azimuth;
    public float RollAngle;
    public double TimestampMs;
    public byte IsPredicted;
}

/// <summary>
/// P/Invoke bindings to Rust `manga_core.dll` (Wave 2, v1.2 — Touchscreen Windows Notebook / 2-in-1 Pad).
/// </summary>
public static partial class MangaCoreNative
{
    private const string DllName = "manga_core";

    public const uint PlatformWindowsTouch = 4;
    public const uint PostureFlat = 0;
    public const uint PostureConvertibleTabletMode = 4;

    [LibraryImport(DllName)]
    public static partial nint manga_canvas_create_preset(uint presetCode);

    [LibraryImport(DllName)]
    public static partial void manga_canvas_destroy(nint handle);

    [LibraryImport(DllName)]
    public static partial uint manga_canvas_width(nint handle);

    [LibraryImport(DllName)]
    public static partial uint manga_canvas_height(nint handle);

    [LibraryImport(DllName)]
    public static partial void manga_canvas_begin_stroke(
        nint handle,
        float baseRadius,
        byte r,
        byte g,
        byte b,
        byte a,
        byte isEraser,
        float stabilizerRadius);

    [LibraryImport(DllName)]
    public static unsafe partial nuint manga_canvas_push_points(
        nint handle,
        CMangaStrokePoint* points,
        nuint count);

    [LibraryImport(DllName)]
    public static partial nuint manga_canvas_end_stroke(nint handle);

    [LibraryImport(DllName)]
    public static partial byte manga_canvas_undo(nint handle);

    [LibraryImport(DllName)]
    public static partial byte manga_canvas_redo(nint handle);

    [LibraryImport(DllName)]
    public static partial uint manga_platform_recommend_layout(
        uint platformCode,
        uint postureCode,
        float widthDp,
        float heightDp);
}
