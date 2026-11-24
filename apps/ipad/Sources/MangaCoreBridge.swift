import Foundation

/// Swift-side mirror of `MangaCanvasPreset` in `core/manga-core/include/manga_core.h`.
public enum CanvasPresetKind: UInt32, CaseIterable, Sendable {
    case b4PrintManga600Dpi = 0
    case a4PrintManga600Dpi = 1
    case webtoonStrip800 = 2
    case webtoonStrip1600 = 3
    case illustration4K = 4
}

#if canImport(MangaCoreFFI)
import MangaCoreFFI

/// Type-safe RAII wrapper over the Rust `MangaCanvasHandle` C-ABI.
public final class MangaCanvasEngine {
    private var handle: OpaquePointer

    public init?(preset: CanvasPresetKind) {
        guard let ptr = manga_canvas_create_preset(preset.rawValue) else {
            return nil
        }
        self.handle = ptr
    }

    deinit {
        manga_canvas_destroy(handle)
    }

    public var width: UInt32 { manga_canvas_width(handle) }
    public var height: UInt32 { manga_canvas_height(handle) }
    public var allocatedTiles: Int { Int(manga_canvas_allocated_tiles(handle)) }

    public func setViewport(panX: Float, panY: Float, zoom: Float, rotationRad: Float) {
        manga_canvas_set_viewport(handle, panX, panY, zoom, rotationRad)
    }

    public func beginStroke(
        radius: Float,
        rgba: (UInt8, UInt8, UInt8, UInt8),
        isEraser: Bool = false,
        stabilizerRadius: Float = 4.0
    ) {
        manga_canvas_begin_stroke(
            handle,
            radius,
            rgba.0,
            rgba.1,
            rgba.2,
            rgba.3,
            isEraser ? 1 : 0,
            stabilizerRadius
        )
    }

    @discardableResult
    public func pushPoints(_ samples: [NativeStrokeSample]) -> Int {
        guard !samples.isEmpty else { return 0 }
        let cPoints = samples.map { s in
            CMangaStrokePoint(
                x: s.x,
                y: s.y,
                pressure: s.pressure,
                altitude: s.altitude,
                azimuth: s.azimuth,
                roll_angle: s.rollAngle,
                timestamp_ms: s.timestampMs,
                is_predicted: s.isPredicted ? 1 : 0
            )
        }
        return cPoints.withUnsafeBufferPointer { buf in
            Int(manga_canvas_push_points(handle, buf.baseAddress, buf.count))
        }
    }

    @discardableResult
    public func endStroke() -> Int {
        Int(manga_canvas_end_stroke(handle))
    }

    @discardableResult
    public func undo() -> Bool {
        manga_canvas_undo(handle) != 0
    }

    @discardableResult
    public func redo() -> Bool {
        manga_canvas_redo(handle) != 0
    }
}
#endif
