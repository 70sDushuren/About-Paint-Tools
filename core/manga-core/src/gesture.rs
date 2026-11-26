//! `v0.8` — Apple Trio Touch & Foldable Ergonomics (2/3-finger undo/redo, Apple Pencil Pro
//! squeeze radial menu, palm rejection, iPhone Duo hinge-safe pane geometry) and Live
//! 5-Language Runtime Catalog (`en`, `zh-Hans`, `zh-Hant`, `yue-Hant`, `es`).

use crate::platform::FoldPosture;

/// Deterministic multi-touch & stylus gesture actions shared across all 6 hardware targets.
#[repr(u32)]
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum GestureAction {
    None = 0,
    Undo = 1,
    Redo = 2,
    ToggleRadialMenu = 3,
    RejectPalm = 4,
    PanZoomCanvas = 5,
}

/// Evaluates touch/stylus telemetry into a deterministic canvas gesture action (`v0.8`).
pub fn resolve_touch_gesture(
    touch_count: u8,
    duration_ms: f32,
    max_travel_px: f32,
    contact_radius_px: f32,
    stylus_active: bool,
    pencil_squeeze: bool,
) -> GestureAction {
    if pencil_squeeze {
        return GestureAction::ToggleRadialMenu;
    }
    if stylus_active && touch_count == 1 && contact_radius_px >= 18.0 {
        return GestureAction::RejectPalm;
    }
    if touch_count == 2 && duration_ms <= 300.0 && max_travel_px <= 18.0 {
        return GestureAction::Undo;
    }
    if touch_count == 3 && duration_ms <= 300.0 && max_travel_px <= 22.0 {
        return GestureAction::Redo;
    }
    if touch_count == 2 && max_travel_px > 18.0 {
        return GestureAction::PanZoomCanvas;
    }
    GestureAction::None
}

/// Deterministic hinge-safe pane widths for foldable dual-pane layouts (`iPhone Duo` & `Android Fold`).
#[derive(Debug, Clone, Copy, PartialEq)]
pub struct FoldablePaneGeometry {
    pub left_pane_width_dp: f32,
    pub right_pane_width_dp: f32,
    pub hinge_exclusion_dp: f32,
    pub is_split: bool,
}

/// Computes zero-overlap left/right pane dimensions around a physical fold hinge.
pub fn compute_foldable_pane_geometry(
    viewport_width_dp: f32,
    posture: FoldPosture,
    reported_crease_dp: f32,
) -> FoldablePaneGeometry {
    match posture {
        FoldPosture::UnfoldedDualPane if viewport_width_dp >= 600.0 => {
            let hinge = reported_crease_dp.max(16.0);
            let usable = (viewport_width_dp - hinge).max(0.0);
            let half = usable * 0.5;
            FoldablePaneGeometry {
                left_pane_width_dp: half,
                right_pane_width_dp: half,
                hinge_exclusion_dp: hinge,
                is_split: true,
            }
        }
        FoldPosture::TabletopHalfOpen => {
            let hinge = reported_crease_dp.max(12.0);
            FoldablePaneGeometry {
                left_pane_width_dp: viewport_width_dp,
                right_pane_width_dp: viewport_width_dp,
                hinge_exclusion_dp: hinge,
                is_split: true,
            }
        }
        _ => FoldablePaneGeometry {
            left_pane_width_dp: viewport_width_dp,
            right_pane_width_dp: 0.0,
            hinge_exclusion_dp: 0.0,
            is_split: false,
        },
    }
}

/// Supported 5-language UI locales (`en`, `zh-Hans`, `zh-Hant`, `yue-Hant`, `es`).
#[repr(u32)]
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum UiLocale {
    En = 0,
    ZhHans = 1,
    ZhHant = 2,
    YueHant = 3,
    Es = 4,
}

impl UiLocale {
    pub const ALL: [UiLocale; 5] = [
        Self::En,
        Self::ZhHans,
        Self::ZhHant,
        Self::YueHant,
        Self::Es,
    ];

    pub fn from_u32(code: u32) -> Option<Self> {
        match code {
            0 => Some(Self::En),
            1 => Some(Self::ZhHans),
            2 => Some(Self::ZhHant),
            3 => Some(Self::YueHant),
            4 => Some(Self::Es),
            _ => None,
        }
    }

    pub fn code(self) -> &'static str {
        match self {
            Self::En => "en",
            Self::ZhHans => "zh-Hans",
            Self::ZhHant => "zh-Hant",
            Self::YueHant => "yue-Hant",
            Self::Es => "es",
        }
    }

    pub fn native_label(self) -> &'static str {
        match self {
            Self::En => "English",
            Self::ZhHans => "简体中文",
            Self::ZhHant => "繁體中文",
            Self::YueHant => "廣東話",
            Self::Es => "Español",
        }
    }

    /// Resolves core high-frequency shell labels in O(1) without disk I/O for instant 5-language live switching.
    pub fn translate_core_key(self, key: &str) -> Option<&'static str> {
        match (key, self) {
            ("workspace.focus", Self::En) => Some("Focus Mode"),
            ("workspace.focus", Self::ZhHans) => Some("专注插画模式"),
            ("workspace.focus", Self::ZhHant) => Some("專注插畫模式"),
            ("workspace.focus", Self::YueHant) => Some("專注畫畫模式"),
            ("workspace.focus", Self::Es) => Some("Modo enfoque"),

            ("workspace.manga", Self::En) => Some("Manga Studio"),
            ("workspace.manga", Self::ZhHans) => Some("漫画工作台"),
            ("workspace.manga", Self::ZhHant) => Some("漫畫工作台"),
            ("workspace.manga", Self::YueHant) => Some("漫畫工作枱"),
            ("workspace.manga", Self::Es) => Some("Estudio manga"),

            ("workspace.dual_studio", Self::En) => Some("Dual Studio"),
            ("workspace.dual_studio", Self::ZhHans) => Some("小说×漫画双引擎"),
            ("workspace.dual_studio", Self::ZhHant) => Some("小說×漫畫雙引擎"),
            ("workspace.dual_studio", Self::YueHant) => Some("小說×漫畫雙引擎"),
            ("workspace.dual_studio", Self::Es) => Some("Estudio dual"),

            ("action.undo", Self::En) => Some("Undo"),
            ("action.undo", Self::ZhHans) => Some("撤销"),
            ("action.undo", Self::ZhHant) => Some("復原"),
            ("action.undo", Self::YueHant) => Some("還原"),
            ("action.undo", Self::Es) => Some("Deshacer"),

            ("action.redo", Self::En) => Some("Redo"),
            ("action.redo", Self::ZhHans) => Some("重做"),
            ("action.redo", Self::ZhHant) => Some("重做"),
            ("action.redo", Self::YueHant) => Some("重做"),
            ("action.redo", Self::Es) => Some("Rehacer"),

            ("tool.brush.short", Self::En) => Some("Brush"),
            ("tool.brush.short", Self::ZhHans) => Some("画笔"),
            ("tool.brush.short", Self::ZhHant) => Some("畫筆"),
            ("tool.brush.short", Self::YueHant) => Some("畫筆"),
            ("tool.brush.short", Self::Es) => Some("Pincel"),

            ("tool.fill.short", Self::En) => Some("Fill"),
            ("tool.fill.short", Self::ZhHans) => Some("填色"),
            ("tool.fill.short", Self::ZhHant) => Some("填色"),
            ("tool.fill.short", Self::YueHant) => Some("填色"),
            ("tool.fill.short", Self::Es) => Some("Relleno"),

            ("ai.pledge.badge", Self::En) => Some("On-Device Offline · Zero Artwork Training"),
            ("ai.pledge.badge", Self::ZhHans) => Some("端侧离线 · 零画作上传训练"),
            ("ai.pledge.badge", Self::ZhHant) => Some("裝置端離線 · 零畫作上傳訓練"),
            ("ai.pledge.badge", Self::YueHant) => Some("本機離線 · 絕唔上傳畫作訓練"),
            ("ai.pledge.badge", Self::Es) => Some("Local sin conexión · Sin entrenar con tus obras"),

            _ => None,
        }
    }
}

/// Audits that every short tool/action key across all 5 locales satisfies its compact touch `max_chars` limit.
pub fn audit_five_locale_truncation() -> (usize, usize) {
    let checked_keys: [(&str, usize); 8] = [
        ("workspace.focus", 20),
        ("workspace.manga", 20),
        ("workspace.dual_studio", 20),
        ("action.undo", 12),
        ("action.redo", 12),
        ("tool.brush.short", 10),
        ("tool.fill.short", 10),
        ("ai.pledge.badge", 64),
    ];
    let mut total_checked = 0usize;
    let mut violations = 0usize;
    for (key, max_chars) in checked_keys {
        for locale in UiLocale::ALL {
            total_checked += 1;
            match locale.translate_core_key(key) {
                Some(val) if !val.is_empty() && val.chars().count() <= max_chars => {}
                _ => violations += 1,
            }
        }
    }
    (total_checked, violations)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn apple_trio_gestures_foldable_hinge_and_5_locales_work() {
        assert_eq!(
            resolve_touch_gesture(2, 120.0, 4.0, 6.0, false, false),
            GestureAction::Undo
        );
        assert_eq!(
            resolve_touch_gesture(3, 140.0, 6.0, 6.0, false, false),
            GestureAction::Redo
        );
        assert_eq!(
            resolve_touch_gesture(0, 0.0, 0.0, 0.0, true, true),
            GestureAction::ToggleRadialMenu
        );
        assert_eq!(
            resolve_touch_gesture(1, 50.0, 2.0, 24.0, true, false),
            GestureAction::RejectPalm
        );
        assert_eq!(
            resolve_touch_gesture(2, 420.0, 60.0, 6.0, false, false),
            GestureAction::PanZoomCanvas
        );

        let duo = compute_foldable_pane_geometry(780.0, FoldPosture::UnfoldedDualPane, 20.0);
        assert!(duo.is_split);
        assert!((duo.hinge_exclusion_dp - 20.0).abs() < 1e-4);
        assert!((duo.left_pane_width_dp - 380.0).abs() < 1e-4);
        assert!((duo.right_pane_width_dp - 380.0).abs() < 1e-4);

        let (checked, violations) = audit_five_locale_truncation();
        assert_eq!(checked, 40);
        assert_eq!(violations, 0);
        assert_eq!(UiLocale::YueHant.translate_core_key("action.undo"), Some("還原"));
        assert_eq!(UiLocale::Es.translate_core_key("tool.brush.short"), Some("Pincel"));
    }
}
