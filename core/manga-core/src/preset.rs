//! Dual-track canvas presets covering both B&W Page Manga (print 600DPI)
//! and Full-Color Webtoon / Anime Illustration workflows.

/// Primary production track associated with a canvas preset.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
#[repr(u32)]
pub enum ProductionTrack {
    BwPageManga = 0,
    ColorWebtoon = 1,
}

/// Print guide margins in pixels for B&W manga pages (bleed, trim, inner live frame).
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct MangaPageGuides {
    pub bleed_px: u32,
    pub trim_inset_px: u32,
    pub safe_frame_inset_px: u32,
}

/// Optional vertical slicing metadata for Webtoon long-strip export.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct WebtoonSliceSpec {
    pub slice_height_px: u32,
    pub viewport_preview_height_px: u32,
}

/// Concrete canvas specification created from a `CanvasPreset`.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct CanvasSpec {
    pub width: u32,
    pub height: u32,
    pub dpi: u32,
    pub track: ProductionTrack,
    pub guides: Option<MangaPageGuides>,
    pub webtoon: Option<WebtoonSliceSpec>,
}

/// Built-in dual-track presets for v0.1 new-document creation.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
#[repr(u32)]
pub enum CanvasPreset {
    /// Japanese commercial manga manuscript: B4 (257 x 364 mm) at 600 DPI.
    B4PrintManga600Dpi = 0,
    /// Doujinshi / standard print page: A4 (210 x 297 mm) at 600 DPI.
    A4PrintManga600Dpi = 1,
    /// Standard Webtoon vertical strip (800 x 12800 px, 10 slices of 1280 px).
    WebtoonStrip800 = 2,
    /// High-res Webtoon vertical strip (1600 x 25600 px, 10 slices of 2560 px).
    WebtoonStrip1600 = 3,
    /// 4K anime illustration canvas (3840 x 2160 px at 300 DPI).
    Illustration4K = 4,
}

impl CanvasPreset {
    pub fn from_u32(code: u32) -> Option<Self> {
        match code {
            0 => Some(Self::B4PrintManga600Dpi),
            1 => Some(Self::A4PrintManga600Dpi),
            2 => Some(Self::WebtoonStrip800),
            3 => Some(Self::WebtoonStrip1600),
            4 => Some(Self::Illustration4K),
            _ => None,
        }
    }

    /// Converts millimeters to pixels at a given DPI (rounded).
    pub const fn mm_to_px(mm: u32, dpi: u32) -> u32 {
        // 1 inch = 25.4 mm -> (mm * dpi * 10 + 127) / 254
        (mm * dpi * 10 + 127) / 254
    }

    pub const fn spec(self) -> CanvasSpec {
        match self {
            Self::B4PrintManga600Dpi => CanvasSpec {
                width: 6071,
                height: 8598,
                dpi: 600,
                track: ProductionTrack::BwPageManga,
                guides: Some(MangaPageGuides {
                    bleed_px: Self::mm_to_px(5, 600),
                    trim_inset_px: Self::mm_to_px(20, 600),
                    safe_frame_inset_px: Self::mm_to_px(38, 600),
                }),
                webtoon: None,
            },
            Self::A4PrintManga600Dpi => CanvasSpec {
                width: 4961,
                height: 7016,
                dpi: 600,
                track: ProductionTrack::BwPageManga,
                guides: Some(MangaPageGuides {
                    bleed_px: Self::mm_to_px(3, 600),
                    trim_inset_px: Self::mm_to_px(15, 600),
                    safe_frame_inset_px: Self::mm_to_px(30, 600),
                }),
                webtoon: None,
            },
            Self::WebtoonStrip800 => CanvasSpec {
                width: 800,
                height: 12800,
                dpi: 300,
                track: ProductionTrack::ColorWebtoon,
                guides: None,
                webtoon: Some(WebtoonSliceSpec {
                    slice_height_px: 1280,
                    viewport_preview_height_px: 1422,
                }),
            },
            Self::WebtoonStrip1600 => CanvasSpec {
                width: 1600,
                height: 25600,
                dpi: 300,
                track: ProductionTrack::ColorWebtoon,
                guides: None,
                webtoon: Some(WebtoonSliceSpec {
                    slice_height_px: 2560,
                    viewport_preview_height_px: 2844,
                }),
            },
            Self::Illustration4K => CanvasSpec {
                width: 3840,
                height: 2160,
                dpi: 300,
                track: ProductionTrack::ColorWebtoon,
                guides: None,
                webtoon: None,
            },
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn b4_manga_preset_has_expected_600dpi_dimensions_and_guides() {
        let spec = CanvasPreset::B4PrintManga600Dpi.spec();
        assert_eq!(spec.width, 6071);
        assert_eq!(spec.height, 8598);
        assert_eq!(spec.dpi, 600);
        assert_eq!(spec.track, ProductionTrack::BwPageManga);
        let guides = spec.guides.expect("B4 manga preset must carry print guides");
        assert!(guides.bleed_px > 0 && guides.trim_inset_px > guides.bleed_px);
        assert!(guides.safe_frame_inset_px > guides.trim_inset_px);
    }

    #[test]
    fn webtoon_presets_carry_slice_specs() {
        let spec = CanvasPreset::WebtoonStrip800.spec();
        assert_eq!(spec.track, ProductionTrack::ColorWebtoon);
        let slice = spec.webtoon.expect("Webtoon preset must carry slice spec");
        assert_eq!(spec.height % slice.slice_height_px, 0);
        assert_eq!(spec.height / slice.slice_height_px, 10);
    }
}
