//! `S1/S3 v0.5` — 5-Language Project Glossary (`bible/glossary.xml`), Completeness Auditor,
//! and Read-Only Proper-Noun Autocomplete (`en`, `zh-Hans`, `zh-Hant`, `yue-Hant`, `es`).

use std::fs;
use std::path::{Path, PathBuf};

use crate::project::{CPFF_SCHEMA_VERSION, CPFF_XML_NAMESPACE};
use crate::suite::{can_write_relative_path, SuiteApp};

pub const PROJECT_GLOSSARY_REL_PATH: &str = "bible/glossary.xml";

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct GlossaryTerm {
    pub key: String,
    pub en: String,
    pub zh_hans: String,
    pub zh_hant: String,
    pub yue_hant: String,
    pub es: String,
    pub locked: bool,
}

impl GlossaryTerm {
    pub fn value_for_locale(&self, locale: &str) -> &str {
        match locale {
            "en" => &self.en,
            "zh-Hans" => &self.zh_hans,
            "zh-Hant" => &self.zh_hant,
            "yue-Hant" | "zh-HK" => &self.yue_hant,
            "es" => &self.es,
            _ => &self.en,
        }
    }

    pub fn is_five_locale_complete(&self) -> bool {
        !self.en.trim().is_empty()
            && !self.zh_hans.trim().is_empty()
            && !self.zh_hant.trim().is_empty()
            && !self.yue_hant.trim().is_empty()
            && !self.es.trim().is_empty()
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct GlossaryAuditReport {
    pub total_terms: usize,
    pub complete_5_locale_terms: usize,
    pub missing_cells: usize,
    pub locked_terms: usize,
}

#[derive(Debug, Clone, Default, PartialEq, Eq)]
pub struct ProjectGlossary {
    pub terms: Vec<GlossaryTerm>,
}

fn xml_escape(s: &str) -> String {
    s.replace('&', "&amp;")
        .replace('<', "&lt;")
        .replace('>', "&gt;")
        .replace('"', "&quot;")
}

fn xml_unescape(s: &str) -> String {
    s.replace("&quot;", "\"")
        .replace("&gt;", ">")
        .replace("&lt;", "<")
        .replace("&amp;", "&")
}

fn extract_attr(tag: &str, attr: &str) -> Option<String> {
    let needle = format!("{attr}=\"");
    let start = tag.find(&needle)? + needle.len();
    let rest = &tag[start..];
    let end = rest.find('"')?;
    Some(xml_unescape(&rest[..end]))
}

impl ProjectGlossary {
    pub fn upsert_term(&mut self, term: GlossaryTerm) {
        if let Some(existing) = self.terms.iter_mut().find(|t| t.key == term.key) {
            *existing = term;
        } else {
            self.terms.push(term);
        }
        self.terms.sort_by(|a, b| a.key.cmp(&b.key));
    }

    pub fn audit_completeness(&self) -> GlossaryAuditReport {
        let mut complete = 0usize;
        let mut missing_cells = 0usize;
        let mut locked = 0usize;
        for t in &self.terms {
            if t.locked {
                locked += 1;
            }
            let cells = [&t.en, &t.zh_hans, &t.zh_hant, &t.yue_hant, &t.es];
            let miss = cells.iter().filter(|s| s.trim().is_empty()).count();
            missing_cells += miss;
            if miss == 0 {
                complete += 1;
            }
        }
        GlossaryAuditReport {
            total_terms: self.terms.len(),
            complete_5_locale_terms: complete,
            missing_cells,
            locked_terms: locked,
        }
    }

    /// Returns matching terms for `S3` light-novel proper-noun autocomplete in `locale`.
    pub fn suggest_terms(&self, query: &str, locale: &str) -> Vec<&GlossaryTerm> {
        let q = query.trim().to_lowercase();
        self.terms
            .iter()
            .filter(|t| {
                if q.is_empty() {
                    return true;
                }
                t.key.to_lowercase().contains(&q)
                    || t.value_for_locale(locale).to_lowercase().contains(&q)
                    || t.en.to_lowercase().contains(&q)
                    || t.zh_hans.to_lowercase().contains(&q)
            })
            .collect()
    }

    pub fn to_xml(&self) -> String {
        let mut out = format!(
            "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n\
<ProjectGlossary xmlns=\"{CPFF_XML_NAMESPACE}\" schemaVersion=\"{CPFF_SCHEMA_VERSION}\">\n"
        );
        for t in &self.terms {
            out.push_str(&format!(
                "  <Term key=\"{}\" en=\"{}\" zhHans=\"{}\" zhHant=\"{}\" yueHant=\"{}\" es=\"{}\" locked=\"{}\"/>\n",
                xml_escape(&t.key),
                xml_escape(&t.en),
                xml_escape(&t.zh_hans),
                xml_escape(&t.zh_hant),
                xml_escape(&t.yue_hant),
                xml_escape(&t.es),
                if t.locked { "true" } else { "false" },
            ));
        }
        out.push_str("</ProjectGlossary>\n");
        out
    }

    pub fn parse_xml(xml: &str) -> Result<Self, String> {
        let mut terms = Vec::new();
        for line in xml.lines() {
            let trimmed = line.trim();
            if trimmed.starts_with("<Term ") {
                let key = extract_attr(trimmed, "key")
                    .ok_or_else(|| "ProjectGlossary <Term> missing key".to_string())?;
                terms.push(GlossaryTerm {
                    key,
                    en: extract_attr(trimmed, "en").unwrap_or_default(),
                    zh_hans: extract_attr(trimmed, "zhHans").unwrap_or_default(),
                    zh_hant: extract_attr(trimmed, "zhHant").unwrap_or_default(),
                    yue_hant: extract_attr(trimmed, "yueHant").unwrap_or_default(),
                    es: extract_attr(trimmed, "es").unwrap_or_default(),
                    locked: extract_attr(trimmed, "locked").as_deref() == Some("true"),
                });
            }
        }
        Ok(Self { terms })
    }

    pub fn load_from_project(project_dir: &Path) -> Result<Self, String> {
        let path = project_dir.join(PROJECT_GLOSSARY_REL_PATH);
        if !path.is_file() {
            return Ok(Self::default());
        }
        let xml = fs::read_to_string(&path)
            .map_err(|e| format!("Failed reading '{}': {e}", path.display()))?;
        Self::parse_xml(&xml)
    }

    /// Atomically persists `bible/glossary.xml` strictly under `SuiteApp::Hub` write ownership.
    pub fn save_atomic(&self, project_dir: &Path) -> Result<PathBuf, String> {
        can_write_relative_path(SuiteApp::Hub, PROJECT_GLOSSARY_REL_PATH)?;
        let target = project_dir.join(PROJECT_GLOSSARY_REL_PATH);
        if let Some(parent) = target.parent() {
            fs::create_dir_all(parent).map_err(|e| e.to_string())?;
        }
        let tmp = target.with_file_name(format!(".glossary.tmp.{}", std::process::id()));
        fs::write(&tmp, self.to_xml().as_bytes()).map_err(|e| e.to_string())?;
        fs::rename(&tmp, &target).map_err(|e| e.to_string())?;
        Ok(target)
    }

    /// Exports compact tab-delimited lines (`key\tlocalized_value\ten\tzh_hans\tcomplete`) for C-ABI.
    pub fn export_suggestions_lines(&self, query: &str, locale: &str) -> String {
        self.suggest_terms(query, locale)
            .into_iter()
            .map(|t| {
                format!(
                    "{}\t{}\t{}\t{}\t{}",
                    t.key.replace(['\t', '\n', '\r'], " "),
                    t.value_for_locale(locale).replace(['\t', '\n', '\r'], " "),
                    t.en.replace(['\t', '\n', '\r'], " "),
                    t.zh_hans.replace(['\t', '\n', '\r'], " "),
                    if t.is_five_locale_complete() { "5/5" } else { "incomplete" },
                )
            })
            .collect::<Vec<_>>()
            .join("\n")
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn five_locale_glossary_persists_audits_and_suggests_terms() {
        let root = std::env::temp_dir().join(format!("manga_glossary_test_{}", std::process::id()));
        let _ = fs::remove_dir_all(&root);
        fs::create_dir_all(&root).unwrap();

        let mut g = ProjectGlossary::default();
        g.upsert_term(GlossaryTerm {
            key: "weapon.starlight_blade".into(),
            en: "Starlight Blade".into(),
            zh_hans: "星辉之刃".into(),
            zh_hant: "星輝之刃".into(),
            yue_hant: "星輝之刃".into(),
            es: "Hoja Estelar".into(),
            locked: true,
        });
        g.save_atomic(&root).unwrap();

        let loaded = ProjectGlossary::load_from_project(&root).unwrap();
        let audit = loaded.audit_completeness();
        assert_eq!(audit.total_terms, 1);
        assert_eq!(audit.complete_5_locale_terms, 1);
        assert_eq!(audit.missing_cells, 0);
        assert_eq!(audit.locked_terms, 1);

        let es_hits = loaded.suggest_terms("starlight", "es");
        assert_eq!(es_hits.len(), 1);
        assert_eq!(es_hits[0].value_for_locale("es"), "Hoja Estelar");
        assert!(can_write_relative_path(SuiteApp::Novel, PROJECT_GLOSSARY_REL_PATH).is_err());

        let _ = fs::remove_dir_all(&root);
    }
}
