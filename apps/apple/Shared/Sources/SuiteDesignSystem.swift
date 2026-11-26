import Foundation

#if canImport(SwiftUI)
import SwiftUI

// MARK: - Decision #1: Unified Tri-App Color Identity Tokens (MIT Clean-Room)

public enum SuiteColorTokens {
    /// S1 `创想空间 / NoemaDock` — Indigo accent on clean studio slate
    public static let hubAccent = Color(red: 0.310, green: 0.486, blue: 1.000)          // #4F7CFF
    public static let hubSurface = Color(red: 0.965, green: 0.972, blue: 0.988)         // #F6F8FC
    public static let hubCard = Color(red: 1.000, green: 1.000, blue: 1.000)

    /// S2 `雕龙 / DracoNib` — Crimson-Coral accent on zero-tint OLED Studio Charcoal
    public static let mangaAccent = Color(red: 1.000, green: 0.420, blue: 0.290)        // #FF6B4A
    public static let mangaCharcoal = Color(red: 0.067, green: 0.071, blue: 0.086)      // #111216
    public static let mangaPanel = Color(red: 0.106, green: 0.114, blue: 0.137)         // #1B1D23
    public static let mangaBorder = Color(red: 0.200, green: 0.212, blue: 0.251)

    /// S3 `文心 / LitteraCore` — Calm Sage accent on eye-friendly paper themes
    public static let novelAccent = Color(red: 0.184, green: 0.659, blue: 0.545)        // #2FA88B
    public static let novelWarmPaper = Color(red: 0.980, green: 0.973, blue: 0.957)     // #FAF8F4
    public static let novelSepia = Color(red: 0.953, green: 0.929, blue: 0.878)         // #F3EDE0
    public static let novelNightInk = Color(red: 0.094, green: 0.102, blue: 0.122)      // #181A1F

    /// Read-only AI sandbox dashed border & DivergenceNote amber pill
    public static let aiSandboxViolet = Color(red: 0.545, green: 0.361, blue: 0.965)    // #8B5CF6
    public static let divergenceAmber = Color(red: 0.851, green: 0.467, blue: 0.024)    // #D97706
}

// MARK: - Decision #2: Clean-Room MIT 24x24 Geometric Vector Icons (1.75px Stroke)

public enum SuiteIconGlyph: String, CaseIterable, Sendable, Identifiable {
    // S1 Hub (6)
    case hubOverview
    case hubNewProject
    case hubDualBoard
    case hubIngest
    case hubLocaleAudit
    case hubPublish
    // S2 Manga (6)
    case mangaPen
    case mangaEraser
    case mangaStabilizer
    case mangaLayers
    case mangaPanels
    case mangaUndo
    // S3 Novel (6)
    case novelProse
    case novelOutline
    case novelTheme
    case novelZen
    case novelAiRef
    case novelLock

    public var id: String { rawValue }
}

/// Pure SwiftUI geometric icon renderer (24x24dp design grid, 1.75px rounded strokes, 100% original MIT code).
public struct SuiteVectorIcon: View {
    public let glyph: SuiteIconGlyph
    public let size: CGFloat
    public let strokeWidth: CGFloat

    public init(_ glyph: SuiteIconGlyph, size: CGFloat = 22, strokeWidth: CGFloat = 1.75) {
        self.glyph = glyph
        self.size = size
        self.strokeWidth = strokeWidth
    }

    public var body: some View {
        Canvas { context, canvasSize in
            let scale = min(canvasSize.width, canvasSize.height) / 24.0
            var path = Path()

            switch glyph {
            case .hubOverview:
                path.addRoundedRect(in: CGRect(x: 3, y: 3, width: 8, height: 8), cornerSize: CGSize(width: 2, height: 2))
                path.addRoundedRect(in: CGRect(x: 13, y: 3, width: 8, height: 8), cornerSize: CGSize(width: 2, height: 2))
                path.addRoundedRect(in: CGRect(x: 3, y: 13, width: 8, height: 8), cornerSize: CGSize(width: 2, height: 2))
                path.addRoundedRect(in: CGRect(x: 13, y: 13, width: 8, height: 8), cornerSize: CGSize(width: 2, height: 2))
            case .hubNewProject:
                path.addRoundedRect(in: CGRect(x: 4, y: 4, width: 16, height: 16), cornerSize: CGSize(width: 3, height: 3))
                path.move(to: CGPoint(x: 12, y: 8))
                path.addLine(to: CGPoint(x: 12, y: 16))
                path.move(to: CGPoint(x: 8, y: 12))
                path.addLine(to: CGPoint(x: 16, y: 12))
            case .hubDualBoard:
                path.addRoundedRect(in: CGRect(x: 3, y: 4, width: 7.5, height: 16), cornerSize: CGSize(width: 2, height: 2))
                path.addRoundedRect(in: CGRect(x: 13.5, y: 4, width: 7.5, height: 16), cornerSize: CGSize(width: 2, height: 2))
            case .hubIngest:
                path.move(to: CGPoint(x: 12, y: 4))
                path.addLine(to: CGPoint(x: 12, y: 15))
                path.move(to: CGPoint(x: 8, y: 11))
                path.addLine(to: CGPoint(x: 12, y: 15))
                path.addLine(to: CGPoint(x: 16, y: 11))
                path.move(to: CGPoint(x: 4, y: 19))
                path.addLine(to: CGPoint(x: 20, y: 19))
            case .hubLocaleAudit:
                path.addEllipse(in: CGRect(x: 3, y: 3, width: 18, height: 18))
                path.move(to: CGPoint(x: 3, y: 12))
                path.addLine(to: CGPoint(x: 21, y: 12))
                path.addEllipse(in: CGRect(x: 8, y: 3, width: 8, height: 18))
            case .hubPublish:
                path.move(to: CGPoint(x: 4, y: 12))
                path.addLine(to: CGPoint(x: 20, y: 4))
                path.addLine(to: CGPoint(x: 15, y: 20))
                path.addLine(to: CGPoint(x: 11, y: 13))
                path.closeSubpath()
            case .mangaPen:
                path.move(to: CGPoint(x: 18, y: 4))
                path.addLine(to: CGPoint(x: 20, y: 6))
                path.addLine(to: CGPoint(x: 9, y: 17))
                path.addLine(to: CGPoint(x: 4, y: 20))
                path.addLine(to: CGPoint(x: 7, y: 15))
                path.closeSubpath()
            case .mangaEraser:
                path.move(to: CGPoint(x: 14, y: 5))
                path.addLine(to: CGPoint(x: 20, y: 11))
                path.addLine(to: CGPoint(x: 12, y: 19))
                path.addLine(to: CGPoint(x: 5, y: 19))
                path.addLine(to: CGPoint(x: 4, y: 15))
                path.closeSubpath()
            case .mangaStabilizer:
                path.move(to: CGPoint(x: 4, y: 17))
                path.addCurve(to: CGPoint(x: 20, y: 7), control1: CGPoint(x: 9, y: 17), control2: CGPoint(x: 14, y: 7))
                path.addEllipse(in: CGRect(x: 17.5, y: 4.5, width: 5, height: 5))
            case .mangaLayers:
                path.move(to: CGPoint(x: 12, y: 4))
                path.addLine(to: CGPoint(x: 20, y: 8.5))
                path.addLine(to: CGPoint(x: 12, y: 13))
                path.addLine(to: CGPoint(x: 4, y: 8.5))
                path.closeSubpath()
                path.move(to: CGPoint(x: 4, y: 13.5))
                path.addLine(to: CGPoint(x: 12, y: 18))
                path.addLine(to: CGPoint(x: 20, y: 13.5))
            case .mangaPanels:
                path.addRoundedRect(in: CGRect(x: 3.5, y: 3.5, width: 17, height: 17), cornerSize: CGSize(width: 2, height: 2))
                path.move(to: CGPoint(x: 3.5, y: 11))
                path.addLine(to: CGPoint(x: 20.5, y: 9))
                path.move(to: CGPoint(x: 12, y: 10))
                path.addLine(to: CGPoint(x: 12, y: 20.5))
            case .mangaUndo:
                path.move(to: CGPoint(x: 8, y: 7))
                path.addLine(to: CGPoint(x: 4, y: 11))
                path.addLine(to: CGPoint(x: 8, y: 15))
                path.move(to: CGPoint(x: 4, y: 11))
                path.addLine(to: CGPoint(x: 15, y: 11))
                path.addQuadCurve(to: CGPoint(x: 15, y: 19), control: CGPoint(x: 20, y: 11))
            case .novelProse:
                path.addRoundedRect(in: CGRect(x: 5, y: 3, width: 14, height: 18), cornerSize: CGSize(width: 2, height: 2))
                path.move(to: CGPoint(x: 8, y: 8))
                path.addLine(to: CGPoint(x: 16, y: 8))
                path.move(to: CGPoint(x: 8, y: 12))
                path.addLine(to: CGPoint(x: 16, y: 12))
                path.move(to: CGPoint(x: 8, y: 16))
                path.addLine(to: CGPoint(x: 13, y: 16))
            case .novelOutline:
                path.move(to: CGPoint(x: 4, y: 6))
                path.addLine(to: CGPoint(x: 20, y: 6))
                path.move(to: CGPoint(x: 8, y: 12))
                path.addLine(to: CGPoint(x: 20, y: 12))
                path.move(to: CGPoint(x: 8, y: 18))
                path.addLine(to: CGPoint(x: 18, y: 18))
            case .novelTheme:
                path.addEllipse(in: CGRect(x: 6, y: 6, width: 12, height: 12))
                path.move(to: CGPoint(x: 12, y: 2.5))
                path.addLine(to: CGPoint(x: 12, y: 4.5))
                path.move(to: CGPoint(x: 12, y: 19.5))
                path.addLine(to: CGPoint(x: 12, y: 21.5))
                path.move(to: CGPoint(x: 2.5, y: 12))
                path.addLine(to: CGPoint(x: 4.5, y: 12))
                path.move(to: CGPoint(x: 19.5, y: 12))
                path.addLine(to: CGPoint(x: 21.5, y: 12))
            case .novelZen:
                path.move(to: CGPoint(x: 4, y: 9))
                path.addLine(to: CGPoint(x: 4, y: 4))
                path.addLine(to: CGPoint(x: 9, y: 4))
                path.move(to: CGPoint(x: 15, y: 4))
                path.addLine(to: CGPoint(x: 20, y: 4))
                path.addLine(to: CGPoint(x: 20, y: 9))
                path.move(to: CGPoint(x: 20, y: 15))
                path.addLine(to: CGPoint(x: 20, y: 20))
                path.addLine(to: CGPoint(x: 15, y: 20))
                path.move(to: CGPoint(x: 9, y: 20))
                path.addLine(to: CGPoint(x: 4, y: 20))
                path.addLine(to: CGPoint(x: 4, y: 15))
            case .novelAiRef:
                path.move(to: CGPoint(x: 12, y: 3))
                path.addLine(to: CGPoint(x: 14.5, y: 9.5))
                path.addLine(to: CGPoint(x: 21, y: 12))
                path.addLine(to: CGPoint(x: 14.5, y: 14.5))
                path.addLine(to: CGPoint(x: 12, y: 21))
                path.addLine(to: CGPoint(x: 9.5, y: 14.5))
                path.addLine(to: CGPoint(x: 3, y: 12))
                path.addLine(to: CGPoint(x: 9.5, y: 9.5))
                path.closeSubpath()
            case .novelLock:
                path.addRoundedRect(in: CGRect(x: 5, y: 11, width: 14, height: 10), cornerSize: CGSize(width: 2.5, height: 2.5))
                path.move(to: CGPoint(x: 8, y: 11))
                path.addLine(to: CGPoint(x: 8, y: 7.5))
                path.addArc(center: CGPoint(x: 12, y: 7.5), radius: 4, startAngle: .degrees(180), endAngle: .degrees(0), clockwise: false)
                path.addLine(to: CGPoint(x: 16, y: 11))
            }

            let scaled = path.applying(CGAffineTransform(scaleX: scale, y: scale))
            context.stroke(
                scaled,
                with: .foreground,
                style: StrokeStyle(lineWidth: strokeWidth, lineCap: .round, lineJoin: .round)
            )
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Decision #2: 4-Element Hint Popover Standard

/// Standard 4-element Hint metadata (Title + Role, Action Summary, Shortcut/Gesture, Safety/Write-Ownership Cue).
public struct ToolHintSpec: Sendable, Identifiable {
    public let id: String
    public let glyph: SuiteIconGlyph
    public let title: String
    public let roleBadge: String
    public let summary: String
    public let shortcut: String
    public let ownershipCue: String

    public init(
        id: String,
        glyph: SuiteIconGlyph,
        title: String,
        roleBadge: String,
        summary: String,
        shortcut: String,
        ownershipCue: String
    ) {
        self.id = id
        self.glyph = glyph
        self.title = title
        self.roleBadge = roleBadge
        self.summary = summary
        self.shortcut = shortcut
        self.ownershipCue = ownershipCue
    }
}

/// Compact 4-element Hint Popover rendered on hover, touch long-press (350ms), or `?` Hint Mode tap.
public struct FourElementHintPopover: View {
    public let spec: ToolHintSpec
    public let accent: Color

    public init(spec: ToolHintSpec, accent: Color) {
        self.spec = spec
        self.accent = accent
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                SuiteVectorIcon(spec.glyph, size: 18)
                    .foregroundStyle(accent)
                Text(spec.title)
                    .font(.subheadline.bold())
                Spacer()
                Text(spec.roleBadge)
                    .font(.caption2.bold())
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(accent.opacity(0.16))
                    .foregroundStyle(accent)
                    .clipShape(Capsule())
            }

            Text(spec.summary)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Divider()

            HStack {
                Text(spec.shortcut)
                    .font(.caption2.monospaced().bold())
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Color.secondary.opacity(0.14))
                    .clipShape(RoundedRectangle(cornerRadius: 5))
                Spacer()
                Text(spec.ownershipCue)
                    .font(.caption2.monospaced())
                    .foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .frame(width: 264)
    }
}

/// 44x44pt touch-friendly Icon-First rail button with integrated Hover / Long-Press / `?` Hint Mode Popover.
public struct RailIconHintButton: View {
    public let spec: ToolHintSpec
    public let isSelected: Bool
    public let accent: Color
    public let isDarkChrome: Bool
    public let hintModeActive: Bool
    public let action: () -> Void

    @State private var showHintPopover = false
    @State private var hoverTask: Task<Void, Never>?

    public init(
        spec: ToolHintSpec,
        isSelected: Bool,
        accent: Color,
        isDarkChrome: Bool = false,
        hintModeActive: Bool = false,
        action: @escaping () -> Void
    ) {
        self.spec = spec
        self.isSelected = isSelected
        self.accent = accent
        self.isDarkChrome = isDarkChrome
        self.hintModeActive = hintModeActive
        self.action = action
    }

    public var body: some View {
        Button {
            if hintModeActive {
                showHintPopover.toggle()
            } else {
                action()
            }
        } label: {
            ZStack(alignment: .topTrailing) {
                SuiteVectorIcon(spec.glyph, size: 22)
                    .foregroundStyle(iconForeground)
                    .frame(width: 44, height: 44)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(isSelected ? accent.opacity(isDarkChrome ? 0.28 : 0.16) : Color.clear)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .strokeBorder(
                                isSelected ? accent : (hintModeActive ? accent.opacity(0.45) : Color.clear),
                                style: StrokeStyle(lineWidth: isSelected ? 1.5 : 1, dash: hintModeActive && !isSelected ? [3, 3] : [])
                            )
                    )

                if hintModeActive {
                    Text("?")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 14, height: 14)
                        .background(accent)
                        .clipShape(Circle())
                        .offset(x: 3, y: -3)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(spec.title)
        .accessibilityHint(spec.summary)
        .simultaneousGesture(
            LongPressGesture(minimumDuration: 0.35)
                .onEnded { _ in
                    showHintPopover = true
                }
        )
        .onHover { hovering in
            hoverTask?.cancel()
            if hovering {
                hoverTask = Task { @MainActor in
                    try? await Task.sleep(nanoseconds: 240_000_000)
                    if !Task.isCancelled {
                        showHintPopover = true
                    }
                }
            } else if !hintModeActive {
                showHintPopover = false
            }
        }
        .popover(isPresented: $showHintPopover, arrowEdge: .trailing) {
            FourElementHintPopover(spec: spec, accent: accent)
        }
    }

    private var iconForeground: Color {
        if isSelected { return accent }
        return isDarkChrome ? Color.white.opacity(0.78) : Color.primary.opacity(0.78)
    }
}

/// Reusable dashed violet badge/container visually marking read-only `ai_assist/` sandboxes (Decision #1).
public struct AiSandboxReadOnlyBanner: View {
    public let title: String
    public let subtitle: String

    public init(title: String, subtitle: String) {
        self.title = title
        self.subtitle = subtitle
    }

    public var body: some View {
        HStack(spacing: 10) {
            SuiteVectorIcon(.novelAiRef, size: 18)
                .foregroundStyle(SuiteColorTokens.aiSandboxViolet)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption.bold())
                    .foregroundStyle(SuiteColorTokens.aiSandboxViolet)
                Text(subtitle)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text("ai_reference_only")
                .font(.caption2.monospaced())
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(SuiteColorTokens.aiSandboxViolet.opacity(0.14))
                .foregroundStyle(SuiteColorTokens.aiSandboxViolet)
                .clipShape(Capsule())
        }
        .padding(10)
        .background(SuiteColorTokens.aiSandboxViolet.opacity(0.06))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(
                    SuiteColorTokens.aiSandboxViolet.opacity(0.7),
                    style: StrokeStyle(lineWidth: 1.25, dash: [5, 4])
                )
        )
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}
#endif
