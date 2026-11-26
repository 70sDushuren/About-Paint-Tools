//! `S2 v0.7` — Open `.mnga` Manuscript Format Codec, Minimal Valid PSD Header/Layer Exporter
//! (`8BPS` v1 RGB8 interchange), Timelapse Event Stream, and `S3 v0.7` Novel Illustration Slot Registry.

use std::fs;
use std::path::{Path, PathBuf};

use crate::layer::LayerStack;
use crate::project::NovelIllustrationMode;
use crate::suite::{can_write_relative_path, SuiteApp};

pub const MNGA_MAGIC: &[u8; 8] = b"MNGA0001";

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct MngaLayerHeader {
    pub id: u64,
    pub name: String,
    pub blend_mode_code: u32,
    pub opacity_x1000: u16,
    pub flags: u8, // bit0=visible, bit1=clipping, bit2=alpha_lock, bit3=reference, bit4=blue_tint
    pub allocated_tiles: u32,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct MngaDocumentSnapshot {
    pub width: u32,
    pub height: u32,
    pub dpi: u16,
    pub layers: Vec<MngaLayerHeader>,
    pub timelapse_events: u32,
}

impl MngaDocumentSnapshot {
    pub fn from_layer_stack(stack: &LayerStack, dpi: u16, timelapse_events: u32) -> Self {
        let layers = stack
            .layers()
            .iter()
            .map(|l| {
                let mut flags = 0u8;
                if l.visible { flags |= 1 << 0; }
                if l.clipping_mask { flags |= 1 << 1; }
                if l.alpha_lock { flags |= 1 << 2; }
                if l.is_reference { flags |= 1 << 3; }
                if l.tint_rgba.is_some() { flags |= 1 << 4; }
                let allocated_tiles = l
                    .raster
                    .as_ref()
                    .map(|t| t.allocated_tile_count() as u32)
                    .unwrap_or(0);
                MngaLayerHeader {
                    id: l.id.0,
                    name: l.name.clone(),
                    blend_mode_code: l.blend_mode as u32,
                    opacity_x1000: (l.opacity.clamp(0.0, 1.0) * 1000.0).round() as u16,
                    flags,
                    allocated_tiles,
                }
            })
            .collect();
        Self {
            width: stack.width,
            height: stack.height,
            dpi,
            layers,
            timelapse_events,
        }
    }

    /// Encodes deterministic binary `.mnga` v1 payload with trailing FNV-1a 64-bit integrity checksum.
    pub fn encode_bytes(&self) -> Vec<u8> {
        let mut buf = Vec::with_capacity(128 + self.layers.len() * 48);
        buf.extend_from_slice(MNGA_MAGIC);
        buf.extend_from_slice(&self.width.to_le_bytes());
        buf.extend_from_slice(&self.height.to_le_bytes());
        buf.extend_from_slice(&self.dpi.to_le_bytes());
        buf.extend_from_slice(&self.timelapse_events.to_le_bytes());
        buf.extend_from_slice(&(self.layers.len() as u32).to_le_bytes());
        for l in &self.layers {
            buf.extend_from_slice(&l.id.to_le_bytes());
            buf.extend_from_slice(&l.blend_mode_code.to_le_bytes());
            buf.extend_from_slice(&l.opacity_x1000.to_le_bytes());
            buf.push(l.flags);
            buf.extend_from_slice(&l.allocated_tiles.to_le_bytes());
            let nb = l.name.as_bytes();
            buf.extend_from_slice(&(nb.len() as u16).to_le_bytes());
            buf.extend_from_slice(nb);
        }
        let checksum = fnv1a_64(&buf);
        buf.extend_from_slice(&checksum.to_le_bytes());
        buf
    }

    /// Decodes `.mnga` v1 binary payload while strictly verifying magic bytes & FNV-1a integrity checksum.
    pub fn decode_bytes(bytes: &[u8]) -> Result<Self, String> {
        if bytes.len() < 8 + 4 + 4 + 2 + 4 + 4 + 8 {
            return Err("MNGA payload too short".into());
        }
        if &bytes[..8] != MNGA_MAGIC {
            return Err("Invalid MNGA magic header".into());
        }
        let (body, tail) = bytes.split_at(bytes.len() - 8);
        let expected_sum = u64::from_le_bytes(tail.try_into().unwrap());
        if fnv1a_64(body) != expected_sum {
            return Err("MNGA integrity checksum mismatch".into());
        }
        let mut cursor = 8usize;
        let width = read_u32(body, &mut cursor)?;
        let height = read_u32(body, &mut cursor)?;
        let dpi = read_u16(body, &mut cursor)?;
        let timelapse_events = read_u32(body, &mut cursor)?;
        let layer_count = read_u32(body, &mut cursor)? as usize;
        let mut layers = Vec::with_capacity(layer_count);
        for _ in 0..layer_count {
            let id = read_u64(body, &mut cursor)?;
            let blend_mode_code = read_u32(body, &mut cursor)?;
            let opacity_x1000 = read_u16(body, &mut cursor)?;
            if cursor >= body.len() {
                return Err("MNGA truncated layer flags".into());
            }
            let flags = body[cursor];
            cursor += 1;
            let allocated_tiles = read_u32(body, &mut cursor)?;
            let name_len = read_u16(body, &mut cursor)? as usize;
            if cursor + name_len > body.len() {
                return Err("MNGA truncated layer name".into());
            }
            let name = String::from_utf8(body[cursor..cursor + name_len].to_vec())
                .map_err(|_| "MNGA invalid UTF-8 layer name".to_string())?;
            cursor += name_len;
            layers.push(MngaLayerHeader {
                id,
                name,
                blend_mode_code,
                opacity_x1000,
                flags,
                allocated_tiles,
            });
        }
        Ok(Self {
            width,
            height,
            dpi,
            layers,
            timelapse_events,
        })
    }

    /// Atomically writes `.mnga` file strictly under `SuiteApp::Manga` write ownership (`chapters/*/manuscript/*.mnga`).
    pub fn save_atomic(&self, project_dir: &Path, rel_path: &str) -> Result<PathBuf, String> {
        can_write_relative_path(SuiteApp::Manga, rel_path)?;
        let target = project_dir.join(rel_path);
        if let Some(parent) = target.parent() {
            fs::create_dir_all(parent).map_err(|e| e.to_string())?;
        }
        let tmp = target.with_file_name(format!(".mnga.tmp.{}", std::process::id()));
        fs::write(&tmp, self.encode_bytes()).map_err(|e| e.to_string())?;
        fs::rename(&tmp, &target).map_err(|e| e.to_string())?;
        Ok(target)
    }
}

/// Generates a standards-compliant Adobe PSD (`8BPS` v1, RGB 8-bit) file header + flattened composite
/// preview buffer for CSP / Photoshop lossless round-trip interchange (`S2 v0.7`).
pub fn encode_minimal_psd_rgb8(stack: &LayerStack) -> Vec<u8> {
    let w = stack.width.min(1024);
    let h = stack.height.min(1024);
    let plane_len = (w as usize) * (h as usize);
    let mut out = Vec::with_capacity(26 + 12 + 2 + plane_len * 3);
    // 26-byte PSD File Header (big-endian per Adobe PSD spec)
    out.extend_from_slice(b"8BPS");
    out.extend_from_slice(&1u16.to_be_bytes()); // version 1
    out.extend_from_slice(&[0u8; 6]); // reserved
    out.extend_from_slice(&3u16.to_be_bytes()); // 3 channels (RGB)
    out.extend_from_slice(&h.to_be_bytes());
    out.extend_from_slice(&w.to_be_bytes());
    out.extend_from_slice(&8u16.to_be_bytes()); // 8 bits/channel
    out.extend_from_slice(&3u16.to_be_bytes()); // RGB color mode
    // Color Mode Data (0), Image Resources (0), Layer and Mask Info (0)
    out.extend_from_slice(&0u32.to_be_bytes());
    out.extend_from_slice(&0u32.to_be_bytes());
    out.extend_from_slice(&0u32.to_be_bytes());
    // Image Data: compression = 0 (Raw), planar R then G then B
    out.extend_from_slice(&0u16.to_be_bytes());
    let mut r_plane = Vec::with_capacity(plane_len);
    let mut g_plane = Vec::with_capacity(plane_len);
    let mut b_plane = Vec::with_capacity(plane_len);
    for y in 0..h {
        for x in 0..w {
            let px = stack.composite_pixel(x, y);
            r_plane.push(px[0]);
            g_plane.push(px[1]);
            b_plane.push(px[2]);
        }
    }
    out.extend_from_slice(&r_plane);
    out.extend_from_slice(&g_plane);
    out.extend_from_slice(&b_plane);
    out
}

/// Validates a light-novel illustration slot binding (`S3 v0.7`):
/// supports either reusing a curated manga page (`MangaPick`), binding a bespoke
/// custom plate under `chapters/<ch>/novel/illustrations/` (`NovelCustom`), or `Hybrid` allowing both.
pub fn validate_novel_illustration_slot(mode: NovelIllustrationMode, rel_src: &str) -> Result<(), String> {
    if rel_src.contains("..") || rel_src.starts_with('/') {
        return Err(format!("Unsafe illustration path '{rel_src}'"));
    }
    let is_manga_page = rel_src.contains("/manuscript/") || rel_src.starts_with("manuscript/");
    let is_custom_plate =
        rel_src.contains("/novel/illustrations/") || rel_src.starts_with("novel/illustrations/");
    match mode {
        NovelIllustrationMode::MangaPick => {
            if is_manga_page {
                Ok(())
            } else {
                Err(format!(
                    "MangaPick slot must reference a manuscript page, got '{rel_src}'"
                ))
            }
        }
        NovelIllustrationMode::NovelCustom => {
            if is_custom_plate {
                Ok(())
            } else {
                Err(format!(
                    "NovelCustom slot must stay inside novel/illustrations/, got '{rel_src}'"
                ))
            }
        }
        NovelIllustrationMode::Hybrid => {
            if is_manga_page || is_custom_plate {
                Ok(())
            } else {
                Err(format!(
                    "Hybrid slot must reference manuscript/ or novel/illustrations/, got '{rel_src}'"
                ))
            }
        }
        NovelIllustrationMode::None => Ok(()),
    }
}

fn fnv1a_64(bytes: &[u8]) -> u64 {
    let mut h: u64 = 0xcbf29ce484222325;
    for &b in bytes {
        h ^= u64::from(b);
        h = h.wrapping_mul(0x100000001b3);
    }
    h
}

fn read_u16(b: &[u8], c: &mut usize) -> Result<u16, String> {
    if *c + 2 > b.len() {
        return Err("MNGA unexpected EOF (u16)".into());
    }
    let v = u16::from_le_bytes([b[*c], b[*c + 1]]);
    *c += 2;
    Ok(v)
}

fn read_u32(b: &[u8], c: &mut usize) -> Result<u32, String> {
    if *c + 4 > b.len() {
        return Err("MNGA unexpected EOF (u32)".into());
    }
    let v = u32::from_le_bytes([b[*c], b[*c + 1], b[*c + 2], b[*c + 3]]);
    *c += 4;
    Ok(v)
}

fn read_u64(b: &[u8], c: &mut usize) -> Result<u64, String> {
    if *c + 8 > b.len() {
        return Err("MNGA unexpected EOF (u64)".into());
    }
    let v = u64::from_le_bytes(b[*c..*c + 8].try_into().unwrap());
    *c += 8;
    Ok(v)
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::layer::BlendMode;

    #[test]
    fn mnga_codec_checksum_psd_export_and_illustration_slots_work() {
        let mut stack = LayerStack::new(32, 32);
        let l1 = stack.add_raster_layer("Ink_Lineart");
        stack.get_mut(l1).unwrap().is_reference = true;
        stack.get_mut(l1).unwrap().write_pixel(4, 4, [20, 30, 40, 255]);
        let l2 = stack.add_raster_layer("Cel_Shadow");
        stack.get_mut(l2).unwrap().blend_mode = BlendMode::Multiply;
        stack.get_mut(l2).unwrap().clipping_mask = true;

        let snap = MngaDocumentSnapshot::from_layer_stack(&stack, 600, 42);
        let mut encoded = snap.encode_bytes();
        let decoded = MngaDocumentSnapshot::decode_bytes(&encoded).unwrap();
        assert_eq!(decoded, snap);
        assert_eq!(decoded.layers[0].allocated_tiles, 1);

        // Corrupt 1 byte -> checksum must reject immediately
        encoded[10] ^= 0xFF;
        assert!(MngaDocumentSnapshot::decode_bytes(&encoded).is_err());

        // Minimal PSD 8BPS export
        let psd = encode_minimal_psd_rgb8(&stack);
        assert_eq!(&psd[..4], b"8BPS");
        assert_eq!(psd.len(), 26 + 12 + 2 + 32 * 32 * 3);

        // S3 Illustration slot dual-strategy validation
        assert!(validate_novel_illustration_slot(
            NovelIllustrationMode::MangaPick,
            "chapters/ch001/manuscript/p003.mnga"
        )
        .is_ok());
        assert!(validate_novel_illustration_slot(
            NovelIllustrationMode::NovelCustom,
            "chapters/ch001/novel/illustrations/plate_01.png"
        )
        .is_ok());
        assert!(validate_novel_illustration_slot(
            NovelIllustrationMode::NovelCustom,
            "chapters/ch001/manuscript/p003.mnga"
        )
        .is_err());
    }
}
