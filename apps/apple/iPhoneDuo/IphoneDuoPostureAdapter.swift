import Foundation
import CoreGraphics

/// Foldable posture and hinge-avoidance adapter for **iPhone Duo** (Wave 1, v0.8–v0.9 → v1.0).
///
/// - **Folded Cover Screen (`foldedCompact`)**: One-handed Light Novel prose editing,
///   hands-free Gemma 4 voice continuity notes, and quick thumbnail sketches.
/// - **Unfolded Dual-Pane (`unfoldedDualPane`)**: Splits workspace across the physical
///   hinge crease (left pane: Outline / Novel / AI Reference; right pane: Manga Canvas).
public enum IphoneDuoPostureAdapter {
    public struct PostureSnapshot: Sendable {
        public let posture: FoldPostureKind
        public let hingeExclusionWidthPt: CGFloat
        public let recommendedDualEngineSplit: Bool
    }

    /// Evaluates current logical viewport bounds and crease width into a deterministic posture snapshot.
    public static func evaluate(
        viewportSizePt: CGSize,
        reportedCreaseWidthPt: CGFloat = 0,
        isHalfOpenTabletop: Bool = false
    ) -> PostureSnapshot {
        if isHalfOpenTabletop {
            return PostureSnapshot(
                posture: .tabletopHalfOpen,
                hingeExclusionWidthPt: max(reportedCreaseWidthPt, 12),
                recommendedDualEngineSplit: true
            )
        }

        let wideEnoughForDuo = max(viewportSizePt.width, viewportSizePt.height) >= 680
            && min(viewportSizePt.width, viewportSizePt.height) >= 580

        if wideEnoughForDuo {
            return PostureSnapshot(
                posture: .unfoldedDualPane,
                hingeExclusionWidthPt: max(reportedCreaseWidthPt, 16),
                recommendedDualEngineSplit: true
            )
        }

        return PostureSnapshot(
            posture: .foldedCompact,
            hingeExclusionWidthPt: 0,
            recommendedDualEngineSplit: false
        )
    }
}
