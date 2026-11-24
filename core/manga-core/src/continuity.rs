//! Continuity Log & Script Supervisor store (`.mnga` SQLite schema + in-memory model).
//!
//! Designed to persist alongside canvas tiles inside `.mnga` archives and be
//! queried/updated either manually or by the embedded local Gemma 4 E2B/E4B assistant.

/// Canonical SQLite DDL embedded inside `.mnga` archives for Script Supervision & Story Planning.
pub const CONTINUITY_SQLITE_DDL: &str = r#"
CREATE TABLE IF NOT EXISTS character_sheets (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    palette_json TEXT NOT NULL,
    traits_json TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS continuity_entries (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    chapter INTEGER NOT NULL,
    page INTEGER NOT NULL,
    panel INTEGER NOT NULL,
    characters_json TEXT NOT NULL,
    outfit_state TEXT NOT NULL DEFAULT '',
    lighting_dir TEXT NOT NULL DEFAULT '',
    props_note TEXT NOT NULL DEFAULT '',
    source TEXT NOT NULL DEFAULT 'manual'
);

CREATE TABLE IF NOT EXISTS continuity_review_pins (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    page INTEGER NOT NULL,
    panel INTEGER NOT NULL,
    x REAL NOT NULL,
    y REAL NOT NULL,
    message TEXT NOT NULL,
    dismissed INTEGER NOT NULL DEFAULT 0
);
"#;

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum NoteSource {
    Manual,
    VoiceGemma4,
    VisionCriticGemma4,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct CharacterSheet {
    pub id: String,
    pub name: String,
    pub palette: Vec<(String, [u8; 4])>,
    pub traits: Vec<String>,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct ContinuityEntry {
    pub id: u64,
    pub chapter: u32,
    pub page: u32,
    pub panel: u32,
    pub characters: Vec<String>,
    pub outfit_state: String,
    pub lighting_dir: String,
    pub props_note: String,
    pub source: NoteSource,
}

/// Non-destructive editorial review pin dropped on canvas by Gemma 4 Vision Critic.
#[derive(Debug, Clone, PartialEq)]
pub struct ContinuityReviewPin {
    pub id: u64,
    pub page: u32,
    pub panel: u32,
    pub x: f32,
    pub y: f32,
    pub message: String,
    pub dismissed: bool,
}

#[derive(Debug, Clone, Default)]
pub struct ContinuityLog {
    next_entry_id: u64,
    next_pin_id: u64,
    pub sheets: Vec<CharacterSheet>,
    pub entries: Vec<ContinuityEntry>,
    pub pins: Vec<ContinuityReviewPin>,
}

impl ContinuityLog {
    pub fn new() -> Self {
        Self {
            next_entry_id: 1,
            next_pin_id: 1,
            sheets: Vec::new(),
            entries: Vec::new(),
            pins: Vec::new(),
        }
    }

    pub fn add_sheet(&mut self, sheet: CharacterSheet) {
        self.sheets.push(sheet);
    }

    #[allow(clippy::too_many_arguments)]
    pub fn add_entry(
        &mut self,
        chapter: u32,
        page: u32,
        panel: u32,
        characters: Vec<String>,
        outfit_state: impl Into<String>,
        lighting_dir: impl Into<String>,
        props_note: impl Into<String>,
        source: NoteSource,
    ) -> u64 {
        let id = self.next_entry_id;
        self.next_entry_id += 1;
        self.entries.push(ContinuityEntry {
            id,
            chapter,
            page,
            panel,
            characters,
            outfit_state: outfit_state.into(),
            lighting_dir: lighting_dir.into(),
            props_note: props_note.into(),
            source,
        });
        id
    }

    pub fn add_review_pin(
        &mut self,
        page: u32,
        panel: u32,
        x: f32,
        y: f32,
        message: impl Into<String>,
    ) -> u64 {
        let id = self.next_pin_id;
        self.next_pin_id += 1;
        self.pins.push(ContinuityReviewPin {
            id,
            page,
            panel,
            x,
            y,
            message: message.into(),
            dismissed: false,
        });
        id
    }

    pub fn entries_for_page(&self, chapter: u32, page: u32) -> Vec<&ContinuityEntry> {
        self.entries
            .iter()
            .filter(|e| e.chapter == chapter && e.page == page)
            .collect()
    }
}
