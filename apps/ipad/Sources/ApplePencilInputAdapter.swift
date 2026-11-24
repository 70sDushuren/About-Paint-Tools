import Foundation

#if canImport(UIKit)
import UIKit

/// Hardware-native stylus sample mirrored 1:1 with `manga_core::StrokePoint`.
public struct NativeStrokeSample {
    public let x: Float
    public let y: Float
    public let pressure: Float
    public let altitude: Float
    public let azimuth: Float
    public let rollAngle: Float
    public let timestampMs: Double
    public let isPredicted: Bool
}

/// Extracts 240Hz coalesced touches and low-latency predicted touches from UIKit
/// for direct forwarding into `manga-core` via C-ABI / UniFFI.
public enum ApplePencilInputAdapter {
    public static func extractSamples(
        touch: UITouch,
        event: UIEvent?,
        in view: UIView
    ) -> [NativeStrokeSample] {
        var samples: [NativeStrokeSample] = []

        let coalesced = event?.coalescedTouches(for: touch) ?? [touch]
        samples.reserveCapacity(coalesced.count + 4)

        for item in coalesced {
            samples.append(makeSample(from: item, in: view, isPredicted: false))
        }

        if let predicted = event?.predictedTouches(for: touch) {
            for item in predicted {
                samples.append(makeSample(from: item, in: view, isPredicted: true))
            }
        }

        return samples
    }

    private static func makeSample(
        from touch: UITouch,
        in view: UIView,
        isPredicted: Bool
    ) -> NativeStrokeSample {
        let loc = touch.preciseLocation(in: view)
        let normalizedForce: Float = touch.maximumPossibleForce > 0
            ? Float(touch.force / touch.maximumPossibleForce)
            : 0.5

        let roll: Float
        if #available(iOS 17.5, *) {
            roll = Float(touch.rollAngle)
        } else {
            roll = 0.0
        }

        return NativeStrokeSample(
            x: Float(loc.x),
            y: Float(loc.y),
            pressure: min(max(normalizedForce, 0.0), 1.0),
            altitude: Float(touch.altitudeAngle),
            azimuth: Float(touch.azimuthAngle(in: view)),
            rollAngle: roll,
            timestampMs: touch.timestamp * 1000.0,
            isPredicted: isPredicted
        )
    }
}
#endif
