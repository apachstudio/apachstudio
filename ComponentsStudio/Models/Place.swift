import Foundation

/// The content shown in a bubble / card. Generated deterministically per world
/// cell so the infinite wrapping field always has stable titles/images.
/// Mirrors `data/bubbles.ts`.
struct Place: Identifiable, Equatable {
    let id: String
    let title: String
    let subtitle: String
    let imageURL: URL?
    /// Deterministic "stays available" count derived from the place id —
    /// stable across renders, no flicker. Shown in the metadata chips on
    /// both the result card and the detail sheet.
    let stays: Int
    /// Deterministic average rating (e.g. 4.8). 4.0–5.0 range so it
    /// always reads as a "premium" place; ties cleanly with the star
    /// chip on the metadata card.
    let rating: Double

    /// Category label shown in the metadata chips. Defaults to "Nature"
    /// so the legacy algorithmic places still get a chip; live callers
    /// (USTop10, PlaceSearchService) pass a real category through.
    let category: String

    init(
        id: String,
        title: String,
        subtitle: String,
        imageURL: URL?,
        stays: Int,
        rating: Double,
        category: String = "Nature"
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.imageURL = imageURL
        self.stays = stays
        self.rating = rating
        self.category = category
    }
}

enum PlaceData {
    private static let nouns = [
        "Lake", "Fern", "Ridge", "Tide", "Canopy", "Dune", "Glacier", "Meadow",
        "Reef", "Summit", "Grove", "Marsh", "Cove", "Cliff", "Stream", "Valley",
        "Aurora", "Mist", "Bloom", "Cascade",
    ]
    private static let adjectives = [
        "Alpine", "Coral", "Hidden", "Golden", "Silent", "Drifting", "Verdant",
        "Frosted", "Amber", "Tidal", "Wild", "Lunar", "Emerald", "Crimson",
        "Quiet", "Boreal", "Sunlit", "Misty", "Pale", "Deep",
    ]

    /// Deterministic non-negative hash for a cell (matches the JS `cellHash`).
    private static func cellHash(_ col: Int, _ row: Int) -> Int {
        let x = sin(Double(col) * 127.1 + Double(row) * 311.7) * 43758.5453
        return Int((x - floor(x)) * 1_000_000)
    }

    /// The place shown at a given world cell — stable across wraps.
    static func place(col: Int, row: Int) -> Place {
        let h = cellHash(col, row)
        let adj = adjectives[h % adjectives.count]
        let noun = nouns[(h / 19) % nouns.count]
        let num = (h % 900) + 100
        // Stays in 6–29; rating in 4.0–4.9 — both deterministic from `h`.
        let stays = 6 + (h % 24)
        let rating = 4.0 + Double((h / 7) % 10) / 10.0
        return Place(
            id: "\(col)_\(row)",
            title: "\(adj) \(noun)",
            subtitle: "No. \(num) · nature",
            imageURL: Photos.url(seed: h),
            stays: stays,
            rating: rating
        )
    }
}

/// Photo source for places. Curated Unsplash landscape IDs tagged by
/// category, so the picker can return a photo whose vibe matches the
/// card's metadata (alpine destination → alpine ridge photo, coastal →
/// fjord, etc.). Served straight off `images.unsplash.com` — no API
/// key, deterministic per seed, hi-res (1200×1600, `q=85`, `auto=format`).
/// `RemoteImage` falls back to `Aurora.cardInk` if any ID ever 404s.
enum Photos {
    /// One entry in the curated pool: a stable Unsplash photo ID
    /// paired with the categories the photo fits. Multiple categories
    /// per entry are fine — many shots are e.g. both alpine AND lake.
    private struct Entry {
        let id: String
        let categories: Set<String>
    }

    /// Curated landscape photo IDs tagged by category. Categories
    /// match the values used by `Place.category` and the Claude prompt:
    /// `alpine`, `forest`, `coastal`, `lake`, `valley`, `aurora`,
    /// `wetland`, `tundra`, `canyon`, `desert`, `glacier`, `volcanic`,
    /// `island`. Unmatched categories silently fall back to the full
    /// pool so cards never end up blank.
    private static let pool: [Entry] = [
        Entry(id: "1506905925346-21bda4d32df4", categories: ["alpine", "tundra"]),         // Norway alpine peaks
        Entry(id: "1469474968028-56623f02e42e", categories: ["alpine", "valley"]),         // Mountain valley dawn
        Entry(id: "1418065460487-3e41a6c84dc5", categories: ["forest"]),                    // Forest light beams
        Entry(id: "1470071459604-3b5ec3a7fe05", categories: ["forest"]),                    // Foggy forest road
        Entry(id: "1441974231531-c6227db76b6e", categories: ["forest"]),                    // Towering canopy from below
        Entry(id: "1501785888041-af3ef285b470", categories: ["alpine", "lake"]),            // Lake + mountain pano
        Entry(id: "1493244040629-496f6d136cc3", categories: ["forest", "alpine"]),          // Misty alpine forest
        Entry(id: "1444090542259-0af8fa96557e", categories: ["valley", "lake"]),            // Yosemite valley sunrise
        Entry(id: "1473773508845-188df298d2d1", categories: ["aurora", "tundra"]),          // Aurora over mountains
        Entry(id: "1505765050516-f72dcac9c60b", categories: ["lake", "alpine"]),            // Reflective lake + peaks
        Entry(id: "1480497490787-505ec076689f", categories: ["lake"]),                      // Mountain lake stillness
        Entry(id: "1518495973542-4542c06a5843", categories: ["alpine", "tundra"]),          // Deep alpine ridge
        Entry(id: "1444065381814-865dc9da92c0", categories: ["forest", "wetland"]),         // Mountain stream
        Entry(id: "1486012329979-67c6a4b5c5b7", categories: ["coastal", "island"]),         // Coastal cliffs at golden hour
        Entry(id: "1500964757637-c85e8a162699", categories: ["alpine"]),                    // Patagonia spires
        Entry(id: "1454496522488-7a8e488e8606", categories: ["coastal", "valley"]),         // Norwegian fjord
        Entry(id: "1505739679850-7adfa4d4dc99", categories: ["alpine"]),                    // Alpine ridge sunlight
        Entry(id: "1464822759023-fed622ff2c3b", categories: ["alpine", "lake"]),            // Mountain lake panorama
    ]

    /// Picks a photo URL whose tagged categories include `category`.
    /// If no entries match (unknown category), falls back to the full
    /// pool so the card still gets a high-quality landscape. The
    /// `seed` rotates the pick deterministically — same seed, same
    /// category, same photo across renders.
    static func url(seed: Int, category: String? = nil) -> URL? {
        let candidates: [Entry] = {
            guard let category, !category.isEmpty else { return pool }
            let filtered = pool.filter { $0.categories.contains(category.lowercased()) }
            return filtered.isEmpty ? pool : filtered
        }()
        guard !candidates.isEmpty else { return nil }
        let id = candidates[abs(seed) % candidates.count].id
        return URL(string:
            "https://images.unsplash.com/photo-\(id)?w=1200&h=1600&fit=crop&q=85&auto=format"
        )
    }
}
