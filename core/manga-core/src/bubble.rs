//! `S1/S2 v0.6` — Multi-Language Speech Bubble & Vertical CJK / Horizontal EN-ES Lettering Engine,
//! plus `S3 v0.6` Lightweight EPUB3 / Markdown Chapter Export Packager.

use std::collections::BTreeMap;
use std::fs;
use std::path::{Path, PathBuf};

use crate::project::{CPFF_SCHEMA_VERSION, CPFF_XML_NAMESPACE};
use crate::suite::{can_write_relative_path, SuiteApp};

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
#[repr(u32)]
pub enum TextFlowDirection {
    /// Traditional manga top-to-bottom, right-to-left vertical CJK lettering.
    VerticalRtl = 0,
    /// Standard horizontal left-to-right (English / Spanish / Webtoon).
    HorizontalLtr = 1,
}

#[derive(Debug, Clone, PartialEq)]
pub struct SpeechBubble {
    pub id: String,
    pub panel_id: u64,
    pub x: f32,
    pub y: f32,
    pub width: f32,
    pub height: f32,
    pub direction: TextFlowDirection,
    /// Per-locale dialogue strings (`en`, `zh-Hans`, `zh-Hant`, `yue-Hant`, `es`).
    pub locales: BTreeMap<String, String>,
}

impl SpeechBubble {
    /// Checks whether all 5 canonical languages are populated and within the bubble's safe character budget.
    pub fn audit_five_locales(&self, max_chars_per_bubble: usize) -> (usize, usize) {
        let required = ["en", "zh-Hans", "zh-Hant", "yue-Hant", "es"];
        let mut present = 0usize;
        let mut overflows = 0usize;
        for loc in required {
            if let Some(txt) = self.locales.get(loc) {
                let len = txt.trim().chars().count();
                if len > 0 {
                    present += 1;
                }
                if len > max_chars_per_bubble {
                    overflows += 1;
                }
            }
        }
        (present, overflows)
    }

    /// Recommends vertical CJK vs horizontal EN/ES lettering direction for a given locale.
    pub fn recommended_direction(locale: &str, is_webtoon: bool) -> TextFlowDirection {
        if is_webtoon {
            return TextFlowDirection::HorizontalLtr;
        }
        match locale {
            "zh-Hans" | "zh-Hant" | "yue-Hant" | "zh-HK" | "ja" => TextFlowDirection::VerticalRtl,
            _ => TextFlowDirection::HorizontalLtr,
        }
    }
}

/// Generates a clean, self-contained EPUB3 XHTML chapter document from human-authoritative light novel Markdown (`S3 v0.6`).
pub fn render_novel_chapter_epub_xhtml(
    chapter_title: &str,
    locale: &str,
    markdown: &str,
    illustration_refs: &[&str],
) -> String {
    let mut body = String::new();
    for block in markdown.split("\n\n") {
        let trimmed = block.trim();
        if trimmed.is_empty() {
            continue;
        }
        let escaped = trimmed
            .replace('&', "&amp;")
            .replace('<', "&lt;")
            .replace('>', "&gt;");
        if let Some(h) = escaped.strip_prefix("# ") {
            body.push_str(&format!("    <h1>{}</h1>\n", h.trim()));
        } else {
            body.push_str(&format!("    <p>{}</p>\n", escaped.replace('\n', "<br/>")));
        }
    }
    for illus in illustration_refs {
        let safe = illus.replace('"', "&quot;");
        body.push_str(&format!(
            "    <figure class=\"novel-illustration\"><img src=\"{safe}\" alt=\"Chapter Illustration\"/></figure>\n"
        ));
    }
    format!(
        "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n\
<!DOCTYPE html>\n\
<html xmlns=\"http://www.w3.org/1999/xhtml\" xml:lang=\"{locale}\" lang=\"{locale}\">\n\
  <head>\n\
    <meta charset=\"UTF-8\"/>\n\
    <title>{}</title>\n\
  </head>\n\
  <body>\n\
{body}  </body>\n\
</html>\n",
        chapter_title.replace('&', "&amp;").replace('<', "&lt;")
    )
}

/// Writes an atomic multi-edition publish manifest under `editions/publish_report.xml` (`S1 v0.6`).
pub fn write_publish_manifest_atomic(
    project_dir: &Path,
    print_pages: usize,
    webtoon_slices: usize,
    epub_chapters: usize,
    five_locale_bubbles_ok: bool,
) -> Result<PathBuf, String> {
    let rel = "editions/publish_report.xml";
    can_write_relative_path(SuiteApp::Hub, rel)?;
    let target = project_dir.join(rel);
    if let Some(parent) = target.parent() {
        fs::create_dir_all(parent).map_err(|e| e.to_string())?;
    }
    let xml = format!(
        "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n\
<PublishReport xmlns=\"{CPFF_XML_NAMESPACE}\" schemaVersion=\"{CPFF_SCHEMA_VERSION}\" printPages=\"{print_pages}\" webtoonSlices=\"{webtoon_slices}\" epubChapters=\"{epub_chapters}\" fiveLocaleBubblesOk=\"{}\"/>\n",
        if five_locale_bubbles_ok { "true" } else { "false" }
    );
    let tmp = target.with_file_name(format!(".publish_report.tmp.{}", std::process::id()));
    fs::write(&tmp, xml.as_bytes()).map_err(|e| e.to_string())?;
    fs::rename(&tmp, &target).map_err(|e| e.to_string())?;
    Ok(target)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn speech_bubble_five_locale_audit_and_epub_xhtml_export_work() {
        let mut locales = BTreeMap::new();
        locales.insert("en".into(), "Starlight awakens!".into());
        locales.insert("zh-Hans".into(), "星辉觉醒！".into());
        locales.insert("zh-Hant".into(), "星輝覺醒！".into());
        locales.insert("yue-Hant".into(), "星輝覺醒啦！".into());
        locales.insert("es".into(), "¡Despierta la luz estelar!".into());

        let bubble = SpeechBubble {
            id: "b001".into(),
            panel_id: 1,
            x: 120.0,
            y: 80.0,
            width: 180.0,
            height: 240.0,
            direction: SpeechBubble::recommended_direction("zh-Hans", false),
            locales,
        };
        assert_eq!(bubble.direction, TextFlowDirection::VerticalRtl);
        assert_eq!(
            SpeechBubble::recommended_direction("es", false),
            TextFlowDirection::HorizontalLtr
        );
        assert_eq!(bubble.audit_five_locales(40), (5, 0));

        let xhtml = render_novel_chapter_epub_xhtml(
            "Episode 1",
            "zh-Hans",
            "# 第一话 星辉觉醒\n\n夜风掠过屋顶。",
            &["../illustrations/ch001_plate.png"],
        );
        assert!(xhtml.contains("<h1>第一话 星辉觉醒</h1>"));
        assert!(xhtml.contains("novel-illustration"));
    }
}
