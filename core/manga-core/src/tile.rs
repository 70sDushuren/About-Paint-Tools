//! Sparse 256x256 Copy-on-Write (CoW) tiled raster layer storage.
//!
//! Empty regions allocate zero bytes, allowing high-DPI manga pages
//! (e.g., B4 600DPI = 6071x8598) to remain well within iPad RAM budgets.

use std::collections::HashMap;
use std::sync::Arc;

/// Tile edge length in pixels (256x256 RGBA8 = 256 KiB per allocated tile).
pub const TILE_SIZE: usize = 256;
pub const BYTES_PER_PIXEL: usize = 4;
pub const TILE_BYTE_LEN: usize = TILE_SIZE * TILE_SIZE * BYTES_PER_PIXEL;

/// Integer tile coordinate in canvas space.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]
pub struct TileCoord {
    pub tx: i32,
    pub ty: i32,
}

impl TileCoord {
    /// Maps a pixel coordinate to its enclosing tile coordinate and local pixel offset.
    pub fn from_pixel(px: i32, py: i32) -> (Self, usize, usize) {
        let size = TILE_SIZE as i32;
        let tx = px.div_euclid(size);
        let ty = py.div_euclid(size);
        let lx = px.rem_euclid(size) as usize;
        let ly = py.rem_euclid(size) as usize;
        (Self { tx, ty }, lx, ly)
    }
}

/// Raw RGBA8 pixel buffer for a single 256x256 tile.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct TileData {
    pixels: Vec<u8>,
}

impl TileData {
    /// Creates a transparent (all-zero) tile.
    pub fn new_transparent() -> Self {
        Self {
            pixels: vec![0u8; TILE_BYTE_LEN],
        }
    }

    #[inline]
    pub fn get_pixel(&self, lx: usize, ly: usize) -> [u8; 4] {
        let idx = (ly * TILE_SIZE + lx) * BYTES_PER_PIXEL;
        [
            self.pixels[idx],
            self.pixels[idx + 1],
            self.pixels[idx + 2],
            self.pixels[idx + 3],
        ]
    }

    #[inline]
    pub fn set_pixel(&mut self, lx: usize, ly: usize, rgba: [u8; 4]) {
        let idx = (ly * TILE_SIZE + lx) * BYTES_PER_PIXEL;
        self.pixels[idx..idx + 4].copy_from_slice(&rgba);
    }

    pub fn is_empty(&self) -> bool {
        self.pixels.iter().all(|&b| b == 0)
    }

    pub fn as_bytes(&self) -> &[u8] {
        &self.pixels
    }

    pub fn from_bytes(pixels: Vec<u8>) -> Option<Self> {
        if pixels.len() != TILE_BYTE_LEN {
            return None;
        }
        Some(Self { pixels })
    }
}

/// Sparse raster layer backed by `Arc<TileData>` for O(1) Copy-on-Write snapshots.
#[derive(Debug, Clone)]
pub struct TileLayer {
    pub width: u32,
    pub height: u32,
    tiles: HashMap<TileCoord, Arc<TileData>>,
}

impl TileLayer {
    pub fn new(width: u32, height: u32) -> Self {
        Self {
            width,
            height,
            tiles: HashMap::new(),
        }
    }

    /// Number of currently allocated non-empty tiles.
    pub fn allocated_tile_count(&self) -> usize {
        self.tiles.len()
    }

    /// Approximate heap memory consumed by allocated tiles in bytes.
    pub fn memory_bytes(&self) -> usize {
        self.tiles.len() * TILE_BYTE_LEN
    }

    pub fn clear(&mut self) {
        self.tiles.clear();
    }

    /// Returns all allocated tiles sorted deterministically by `(ty, tx)` for reproducible `.mnga` v2 encoding.
    pub fn sorted_tiles(&self) -> Vec<(TileCoord, Arc<TileData>)> {
        let mut entries: Vec<(TileCoord, Arc<TileData>)> = self
            .tiles
            .iter()
            .filter(|(_, t)| !t.is_empty())
            .map(|(&c, t)| (c, Arc::clone(t)))
            .collect();
        entries.sort_by_key(|(c, _)| (c.ty, c.tx));
        entries
    }

    pub fn get_tile(&self, coord: TileCoord) -> Option<Arc<TileData>> {
        self.tiles.get(&coord).cloned()
    }

    pub fn set_tile(&mut self, coord: TileCoord, tile: Option<Arc<TileData>>) {
        match tile {
            Some(t) if !t.is_empty() => {
                self.tiles.insert(coord, t);
            }
            _ => {
                self.tiles.remove(&coord);
            }
        }
    }

    pub fn get_pixel(&self, x: u32, y: u32) -> [u8; 4] {
        if x >= self.width || y >= self.height {
            return [0, 0, 0, 0];
        }
        let (coord, lx, ly) = TileCoord::from_pixel(x as i32, y as i32);
        self.tiles
            .get(&coord)
            .map(|t| t.get_pixel(lx, ly))
            .unwrap_or([0, 0, 0, 0])
    }

    /// Writes a single pixel using Copy-on-Write (`Arc::make_mut`), preserving
    /// previously snapshotted undo tiles without cloning untouched tiles.
    pub fn set_pixel(&mut self, x: u32, y: u32, rgba: [u8; 4]) -> Option<TileCoord> {
        if x >= self.width || y >= self.height {
            return None;
        }
        let (coord, lx, ly) = TileCoord::from_pixel(x as i32, y as i32);
        if rgba[3] == 0 && !self.tiles.contains_key(&coord) {
            return None;
        }
        let entry = self
            .tiles
            .entry(coord)
            .or_insert_with(|| Arc::new(TileData::new_transparent()));
        Arc::make_mut(entry).set_pixel(lx, ly, rgba);
        Some(coord)
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn sparse_b4_600dpi_layer_allocates_zero_bytes_initially() {
        let layer = TileLayer::new(6071, 8598);
        assert_eq!(layer.allocated_tile_count(), 0);
        assert_eq!(layer.memory_bytes(), 0);
        assert_eq!(layer.get_pixel(3000, 4000), [0, 0, 0, 0]);
    }

    #[test]
    fn writing_pixel_allocates_only_target_tile_and_supports_cow() {
        let mut layer = TileLayer::new(6071, 8598);
        let coord = layer.set_pixel(513, 257, [20, 30, 40, 255]).unwrap();
        assert_eq!(coord, TileCoord { tx: 2, ty: 1 });
        assert_eq!(layer.allocated_tile_count(), 1);
        assert_eq!(layer.get_pixel(513, 257), [20, 30, 40, 255]);

        // Snapshot tile before second write; Arc::make_mut should detach cleanly.
        let snapshot = layer.get_tile(coord).unwrap();
        layer.set_pixel(513, 257, [255, 0, 0, 255]);
        assert_eq!(snapshot.get_pixel(1, 1), [20, 30, 40, 255]);
        assert_eq!(layer.get_pixel(513, 257), [255, 0, 0, 255]);
    }
}
