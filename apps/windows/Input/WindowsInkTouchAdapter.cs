using System;
using AboutPaintTools.Windows.Native;

namespace AboutPaintTools.Windows.Input;

/// <summary>
/// Normalizes Windows Ink (`WM_POINTER` / WinUI 3 `PointerPointProperties`) stylus & touch
/// samples into `CMangaStrokePoint` and handles 2-in-1 slate/tablet posture transitions.
/// </summary>
public static class WindowsInkTouchAdapter
{
    public static CMangaStrokePoint NormalizePointerSample(
        float x,
        float y,
        float pressure,
        float xTiltDeg,
        float yTiltDeg,
        float twistDeg,
        double timestampMs)
    {
        float tx = xTiltDeg * (MathF.PI / 180f);
        float ty = yTiltDeg * (MathF.PI / 180f);
        float tiltMag = MathF.Min(MathF.Sqrt(tx * tx + ty * ty), MathF.PI * 0.5f);
        float altitude = MathF.Max(0f, MathF.PI * 0.5f - tiltMag);
        float azimuth = MathF.Atan2(ty, tx);

        return new CMangaStrokePoint
        {
            X = x,
            Y = y,
            Pressure = Math.Clamp(pressure, 0f, 1f),
            Altitude = altitude,
            Azimuth = azimuth,
            RollAngle = twistDeg * (MathF.PI / 180f),
            TimestampMs = timestampMs,
            IsPredicted = 0
        };
    }

    public static uint RecommendLayout(bool isConvertibleTabletMode, float widthDp, float heightDp)
    {
        uint posture = isConvertibleTabletMode
            ? MangaCoreNative.PostureConvertibleTabletMode
            : MangaCoreNative.PostureFlat;
        return MangaCoreNative.manga_platform_recommend_layout(
            MangaCoreNative.PlatformWindowsTouch,
            posture,
            widthDp,
            heightDp);
    }
}
