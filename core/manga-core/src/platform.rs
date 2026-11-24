//! Cross-platform hardware capabilities, foldable hinge posture, and deterministic
//! adaptive workspace layout engine shared across all 6 target platforms:
//!
//! - **Wave 1 (`v0.9` Beta -> `v1.0` Release — Apple Touch & Foldable Family)**:
//!   1. `IpadOs` — iPad (240Hz Apple Pencil Pro, ProMotion)
//!   2. `MacOsTouch` — Touchscreen MacBook (direct screen touch + trackpad + keyboard shortcuts)
//!   3. `IphoneDuo` — Apple Foldable iPhone Duo (folded quick-sketch/novel <-> unfolded dual-pane)
//! - **Wave 2 (`v1.1` – `v1.3` — Post-1.0 Cross-Ecosystem Compatibility)**:
//!   4. `AndroidPadFoldable` — Android Pad & Foldable Phones (`v1.1`, Jetpack WindowManager + S-Pen/USI)
//!   5. `WindowsTouch` — Touchscreen Windows Notebook / 2-in-1 Pad (`v1.2`, WinUI 3 + Windows Ink)
//!   6. `LinuxTouch` — Touchscreen Linux Notebook / Pad (`v1.3`, Rust GTK4/Wayland `zwp_tablet_v2`)

/// Target runtime platform across both release waves.
#[repr(u32)]
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum TargetPlatform {
    IpadOs = 0,
    MacOsTouch = 1,
    IphoneDuo = 2,
    AndroidPadFoldable = 3,
    WindowsTouch = 4,
    LinuxTouch = 5,
}

impl TargetPlatform {
    pub fn from_u32(code: u32) -> Option<Self> {
        match code {
            0 => Some(Self::IpadOs),
            1 => Some(Self::MacOsTouch),
            2 => Some(Self::IphoneDuo),
            3 => Some(Self::AndroidPadFoldable),
            4 => Some(Self::WindowsTouch),
            5 => Some(Self::LinuxTouch),
            _ => None,
        }
    }

    pub fn as_str(self) -> &'static str {
        match self {
            Self::IpadOs => "ipados",
            Self::MacOsTouch => "macos-touch",
            Self::IphoneDuo => "iphone-duo",
            Self::AndroidPadFoldable => "android-pad-foldable",
            Self::WindowsTouch => "windows-touch",
            Self::LinuxTouch => "linux-touch",
        }
    }

    /// Release wave number: `1` for `v0.9`/`v1.0` Apple trio, `2` for post-`v1.0` expansion.
    pub fn release_wave(self) -> u8 {
        match self {
            Self::IpadOs | Self::MacOsTouch | Self::IphoneDuo => 1,
            Self::AndroidPadFoldable | Self::WindowsTouch | Self::LinuxTouch => 2,
        }
    }

    /// Target milestone string from the official roadmap.
    pub fn target_milestone(self) -> &'static str {
        match self {
            Self::IpadOs | Self::MacOsTouch | Self::IphoneDuo => "v0.9",
            Self::AndroidPadFoldable => "v1.1",
            Self::WindowsTouch => "v1.2",
            Self::LinuxTouch => "v1.3",
        }
    }

    /// Default hardware input & graphics backend capabilities for this platform.
    pub fn capabilities(self) -> InputCapabilities {
        match self {
            Self::IpadOs => InputCapabilities {
                direct_touch: true,
                predicted_touches_240hz: true,
                stylus_tilt: true,
                stylus_barrel_roll: true,
                stylus_hover: true,
                stylus_side_button_or_squeeze: true,
                physical_keyboard_shortcuts: true,
                foldable_hinge_aware: false,
                gpu_backend: "Metal (wgpu)",
                stylus_protocol: "UIKit 240Hz + Apple Pencil Pro",
            },
            Self::MacOsTouch => InputCapabilities {
                direct_touch: true,
                predicted_touches_240hz: false,
                stylus_tilt: true,
                stylus_barrel_roll: true,
                stylus_hover: true,
                stylus_side_button_or_squeeze: true,
                physical_keyboard_shortcuts: true,
                foldable_hinge_aware: false,
                gpu_backend: "Metal (wgpu)",
                stylus_protocol: "AppKit Direct Touch + NSEvent tabletPoint / Sidecar",
            },
            Self::IphoneDuo => InputCapabilities {
                direct_touch: true,
                predicted_touches_240hz: true,
                stylus_tilt: true,
                stylus_barrel_roll: false,
                stylus_hover: true,
                stylus_side_button_or_squeeze: false,
                physical_keyboard_shortcuts: false,
                foldable_hinge_aware: true,
                gpu_backend: "Metal (wgpu)",
                stylus_protocol: "UIKit Adaptive Touch + Foldable HingeSafeArea",
            },
            Self::AndroidPadFoldable => InputCapabilities {
                direct_touch: true,
                predicted_touches_240hz: true,
                stylus_tilt: true,
                stylus_barrel_roll: false,
                stylus_hover: true,
                stylus_side_button_or_squeeze: true,
                physical_keyboard_shortcuts: true,
                foldable_hinge_aware: true,
                gpu_backend: "Vulkan (wgpu)",
                stylus_protocol: "MotionEvent Historical + FrontBufferedRenderer (S-Pen / M-Pencil / USI 2.0)",
            },
            Self::WindowsTouch => InputCapabilities {
                direct_touch: true,
                predicted_touches_240hz: false,
                stylus_tilt: true,
                stylus_barrel_roll: true,
                stylus_hover: true,
                stylus_side_button_or_squeeze: true,
                physical_keyboard_shortcuts: true,
                foldable_hinge_aware: false,
                gpu_backend: "DirectX 12 (wgpu)",
                stylus_protocol: "WM_POINTER / Windows Ink PointerPointProperties",
            },
            Self::LinuxTouch => InputCapabilities {
                direct_touch: true,
                predicted_touches_240hz: false,
                stylus_tilt: true,
                stylus_barrel_roll: true,
                stylus_hover: true,
                stylus_side_button_or_squeeze: true,
                physical_keyboard_shortcuts: true,
                foldable_hinge_aware: false,
                gpu_backend: "Vulkan (wgpu)",
                stylus_protocol: "Wayland zwp_tablet_v2 + libinput Multi-Touch",
            },
        }
    }
}

/// Physical fold / convertible posture reported by the native OS shell.
#[repr(u32)]
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum FoldPosture {
    /// Standard flat screen (iPad, desktop touch laptop, flat Android tablet).
    Flat = 0,
    /// Folded shut / cover screen active (iPhone Duo folded, Galaxy Fold cover).
    FoldedCompact = 1,
    /// Unfolded flat across a central hinge (iPhone Duo unfolded, Android foldable open).
    UnfoldedDualPane = 2,
    /// Half-open tabletop / tent / laptop-like angle (top display canvas, bottom controls/novel).
    TabletopHalfOpen = 3,
    /// 2-in-1 Windows/Linux notebook folded 360 degrees into pure tablet mode.
    ConvertibleTabletMode = 4,
}

impl FoldPosture {
    pub fn from_u32(code: u32) -> Option<Self> {
        match code {
            0 => Some(Self::Flat),
            1 => Some(Self::FoldedCompact),
            2 => Some(Self::UnfoldedDualPane),
            3 => Some(Self::TabletopHalfOpen),
            4 => Some(Self::ConvertibleTabletMode),
            _ => None,
        }
    }
}

/// Safe exclusion rectangle of a physical hinge/crease in logical display points (`dp`).
#[derive(Debug, Clone, Copy, PartialEq)]
pub struct HingeBounds {
    pub x: f32,
    pub y: f32,
    pub width: f32,
    pub height: f32,
    pub is_vertical: bool,
}

/// Hardware input & rendering capabilities for a target platform.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct InputCapabilities {
    pub direct_touch: bool,
    pub predicted_touches_240hz: bool,
    pub stylus_tilt: bool,
    pub stylus_barrel_roll: bool,
    pub stylus_hover: bool,
    pub stylus_side_button_or_squeeze: bool,
    pub physical_keyboard_shortcuts: bool,
    pub foldable_hinge_aware: bool,
    pub gpu_backend: &'static str,
    pub stylus_protocol: &'static str,
}

/// Deterministic workspace layout recommendation consumed by all 6 native UI shells.
#[repr(u32)]
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum WorkspaceLayoutHint {
    /// Compact single-pane focus (quick sketch, voice continuity note, or light novel writing).
    SinglePaneCompact = 0,
    /// Full tablet studio (canvas + collapsible side drawers + touch/pencil gestures).
    TabletTouchStudio = 1,
    /// Dual-pane split anchored around a physical vertical fold hinge (left: novel/outline/AI ref, right: manga canvas).
    DualPaneAcrossHinge = 2,
    /// Half-open tabletop layout (top screen: canvas / preview; bottom screen: tool deck / novel keyboard).
    TabletopCanvasTopControlsBottom = 3,
    /// Desktop + touch hybrid (top menu bar + keyboard shortcuts + enlarged touch-friendly hit targets).
    DesktopTouchHybrid = 4,
}

/// Computes the deterministic workspace layout hint for any `(platform, posture, viewport_dp)`.
pub fn recommend_workspace_layout(
    platform: TargetPlatform,
    posture: FoldPosture,
    width_dp: f32,
    height_dp: f32,
) -> WorkspaceLayoutHint {
    match posture {
        FoldPosture::FoldedCompact => WorkspaceLayoutHint::SinglePaneCompact,
        FoldPosture::TabletopHalfOpen => WorkspaceLayoutHint::TabletopCanvasTopControlsBottom,
        FoldPosture::UnfoldedDualPane => {
            if width_dp >= 600.0 {
                WorkspaceLayoutHint::DualPaneAcrossHinge
            } else {
                WorkspaceLayoutHint::SinglePaneCompact
            }
        }
        FoldPosture::ConvertibleTabletMode => WorkspaceLayoutHint::TabletTouchStudio,
        FoldPosture::Flat => match platform {
            TargetPlatform::MacOsTouch | TargetPlatform::WindowsTouch | TargetPlatform::LinuxTouch => {
                if width_dp >= 960.0 && height_dp >= 540.0 {
                    WorkspaceLayoutHint::DesktopTouchHybrid
                } else {
                    WorkspaceLayoutHint::TabletTouchStudio
                }
            }
            TargetPlatform::IpadOs | TargetPlatform::AndroidPadFoldable => {
                if width_dp < 520.0 {
                    WorkspaceLayoutHint::SinglePaneCompact
                } else {
                    WorkspaceLayoutHint::TabletTouchStudio
                }
            }
            TargetPlatform::IphoneDuo => {
                if width_dp >= 600.0 {
                    WorkspaceLayoutHint::DualPaneAcrossHinge
                } else {
                    WorkspaceLayoutHint::SinglePaneCompact
                }
            }
        },
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn wave_1_and_wave_2_platforms_match_roadmap() {
        assert_eq!(TargetPlatform::IpadOs.release_wave(), 1);
        assert_eq!(TargetPlatform::MacOsTouch.release_wave(), 1);
        assert_eq!(TargetPlatform::IphoneDuo.release_wave(), 1);
        assert_eq!(TargetPlatform::IphoneDuo.target_milestone(), "v0.9");

        assert_eq!(TargetPlatform::AndroidPadFoldable.release_wave(), 2);
        assert_eq!(TargetPlatform::AndroidPadFoldable.target_milestone(), "v1.1");
        assert_eq!(TargetPlatform::WindowsTouch.release_wave(), 2);
        assert_eq!(TargetPlatform::WindowsTouch.target_milestone(), "v1.2");
        assert_eq!(TargetPlatform::LinuxTouch.release_wave(), 2);
        assert_eq!(TargetPlatform::LinuxTouch.target_milestone(), "v1.3");
    }

    #[test]
    fn iphone_duo_and_android_foldable_adapt_cleanly_across_postures() {
        // Folded cover screen -> compact quick sketch / light novel mode
        assert_eq!(
            recommend_workspace_layout(TargetPlatform::IphoneDuo, FoldPosture::FoldedCompact, 390.0, 844.0),
            WorkspaceLayoutHint::SinglePaneCompact
        );
        // Unfolded iPhone Duo -> dual-pane split across hinge
        assert_eq!(
            recommend_workspace_layout(TargetPlatform::IphoneDuo, FoldPosture::UnfoldedDualPane, 760.0, 844.0),
            WorkspaceLayoutHint::DualPaneAcrossHinge
        );
        // Android foldable half-open -> tabletop mode
        assert_eq!(
            recommend_workspace_layout(
                TargetPlatform::AndroidPadFoldable,
                FoldPosture::TabletopHalfOpen,
                720.0,
                840.0
            ),
            WorkspaceLayoutHint::TabletopCanvasTopControlsBottom
        );
    }

    #[test]
    fn touch_laptops_and_2in1_convertibles_switch_between_desktop_and_tablet_modes() {
        // Touchscreen MacBook / Windows / Linux laptop open normally -> DesktopTouchHybrid
        for p in [
            TargetPlatform::MacOsTouch,
            TargetPlatform::WindowsTouch,
            TargetPlatform::LinuxTouch,
        ] {
            assert_eq!(
                recommend_workspace_layout(p, FoldPosture::Flat, 1440.0, 900.0),
                WorkspaceLayoutHint::DesktopTouchHybrid
            );
            // 2-in-1 folded 360 degrees into tablet mode -> TabletTouchStudio
            assert_eq!(
                recommend_workspace_layout(p, FoldPosture::ConvertibleTabletMode, 1280.0, 800.0),
                WorkspaceLayoutHint::TabletTouchStudio
            );
            assert!(p.capabilities().direct_touch);
        }
    }

    #[test]
    fn ipad_split_view_one_third_falls_back_to_compact_layout() {
        assert_eq!(
            recommend_workspace_layout(TargetPlatform::IpadOs, FoldPosture::Flat, 375.0, 1024.0),
            WorkspaceLayoutHint::SinglePaneCompact
        );
        assert_eq!(
            recommend_workspace_layout(TargetPlatform::IpadOs, FoldPosture::Flat, 1024.0, 1366.0),
            WorkspaceLayoutHint::TabletTouchStudio
        );
    }
}
