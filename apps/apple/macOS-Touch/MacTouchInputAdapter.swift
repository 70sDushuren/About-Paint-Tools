import Foundation

#if canImport(AppKit)
import AppKit

/// Touchscreen MacBook (`macOS Touch`) input adapter fusing direct screen multi-touch
/// (`NSTouch` with palm rejection) and tablet/Sidecar stylus pressure (`NSEvent.tabletPoint`).
@MainActor
public enum MacTouchInputAdapter {
    /// Converts a macOS pointer or pen-tablet `NSEvent` into a `NativeStrokeSample`.
    public static func sample(from event: NSEvent, in view: NSView) -> NativeStrokeSample {
        let loc = view.convert(event.locationInWindow, from: nil)
        let pressure: Float = event.pressure > 0 ? event.pressure : 0.5
        let tilt = event.tilt
        let tiltMag = hypot(Float(tilt.x), Float(tilt.y))
        let altitude = max(0.0, Float.pi * 0.5 - min(tiltMag, Float.pi * 0.5))
        let azimuth = atan2(Float(tilt.y), Float(tilt.x))
        let rollRad = Float(event.rotation) * Float.pi / 180.0

        return NativeStrokeSample(
            x: Float(loc.x),
            y: Float(view.bounds.height - loc.y),
            pressure: min(max(pressure, 0.0), 1.0),
            altitude: altitude,
            azimuth: azimuth,
            rollAngle: rollRad,
            timestampMs: event.timestamp * 1000.0,
            isPredicted: false
        )
    }

    /// Filters direct touchscreen `NSTouch` events to distinguish intentional 2-finger
    /// canvas pan/zoom/undo gestures from accidental palm contact during stylus drawing.
    public static func activeDirectTouchCount(in event: NSEvent, view: NSView) -> Int {
        event.touches(matching: .touching, in: view)
            .filter { $0.type == .direct }
            .count
    }
}
#endif
