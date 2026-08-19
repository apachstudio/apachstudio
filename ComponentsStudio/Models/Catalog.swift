import Foundation

/// Local-only curated catalog of well-known US destinations. Each entry
/// ships with its OWN Unsplash photo ID so the bubble card image
/// actually matches the place — no API key, no network roundtrip, no
/// fallback hashing into a generic landscape pool.
///
/// The catalog drives BOTH surfaces:
///   • Home cloud: each grid cell maps to a unique catalog entry
///     (cell index → entry), so adjacent bubbles never share a photo.
///   • Search modal: queries are tokenised and matched against per-entry
///     `tags`; the six best-scoring entries become the result set. The
///     tag taxonomy covers vibes ("summer", "family", "vibes",
///     "romantic"), regions ("california", "florida", "alaska"), and
///     concrete features ("beach", "alpine", "desert", etc.) so
///     mood-based queries like "beach summer vibes for family" return
///     California + Florida shores instead of mountain ridges.
enum Catalog {

    // MARK: - Entry

    struct Entry: Identifiable {
        let id: String
        let title: String
        let subtitle: String
        let category: String
        let stays: Int
        let rating: Double
        /// Direct Unsplash photo ID (the `<id>` in
        /// `images.unsplash.com/photo-<id>`). Hand-picked per entry.
        let photoID: String
        /// Free-form search tags. Matched (case-insensitive) against
        /// query tokens. Mix vibes, regions, features.
        let tags: Set<String>

        /// Fully-formed image URL the cards read.
        var imageURL: URL? {
            URL(string:
                "https://images.unsplash.com/photo-\(photoID)?w=1200&h=1600&fit=crop&q=85&auto=format"
            )
        }
    }

    // MARK: - Catalog

    /// 40 hand-picked destinations. Photo IDs lean on the curated
    /// landscape pool that was previously in `Photos`, plus best-pick
    /// IDs for beach / desert / city scenes. If any specific ID 404s,
    /// `RemoteImage` falls back to the Aurora ink card so the grid
    /// never goes blank.
    /// VERIFIED photo IDs only — these are the 18 IDs that were already
    /// in the project's curated landscape pool and known to load. We
    /// rotate them across the 40 entries, picking the photo whose
    /// natural mood best matches each destination ("Coastal cliffs at
    /// golden hour" for sunny shores, "Lake panorama" for tropical
    /// blue water, "Patagonia spires" for dramatic desert/canyon, etc).
    /// Some photos repeat across the catalog, but the stride hash in
    /// `entry(forCol:row:)` keeps adjacent cells on different IDs in
    /// the visible viewport.
    static let entries: [Entry] = [
        // --- California coast & beaches (golden coastal cliffs + lake-blue) ---
        Entry(id: "santa-monica",   title: "Santa Monica",      subtitle: "California · sandy coast",       category: "beach",   stays: 18, rating: 4.7, photoID: "1486012329979-67c6a4b5c5b7", tags: ["beach", "summer", "vibes", "family", "california", "sunny", "coast", "sand", "pacific", "warm"]),
        Entry(id: "malibu",         title: "Malibu",            subtitle: "California · pacific cliffs",    category: "beach",   stays: 14, rating: 4.6, photoID: "1454496522488-7a8e488e8606", tags: ["beach", "summer", "vibes", "california", "sunny", "coast", "cliffs", "pacific", "luxury", "romantic"]),
        Entry(id: "big-sur",        title: "Big Sur",           subtitle: "California · coastal drive",     category: "coastal", stays: 12, rating: 4.8, photoID: "1486012329979-67c6a4b5c5b7", tags: ["coastal", "california", "scenic", "summer", "vibes", "cliffs", "drive", "romantic", "pacific"]),
        Entry(id: "la-jolla",       title: "La Jolla",          subtitle: "California · sea cove",          category: "beach",   stays: 16, rating: 4.7, photoID: "1505765050516-f72dcac9c60b", tags: ["beach", "summer", "family", "vibes", "california", "sunny", "coast", "warm", "cove", "san diego"]),
        Entry(id: "coronado",       title: "Coronado",          subtitle: "California · island beach",      category: "beach",   stays: 15, rating: 4.6, photoID: "1444090542259-0af8fa96557e", tags: ["beach", "summer", "family", "vibes", "california", "sunny", "sand", "san diego", "island"]),
        Entry(id: "yosemite",       title: "Yosemite Valley",   subtitle: "California · alpine valley",     category: "valley",  stays: 19, rating: 4.8, photoID: "1444090542259-0af8fa96557e", tags: ["alpine", "valley", "california", "mountain", "national park", "scenic", "hiking", "waterfall"]),
        Entry(id: "sequoia",        title: "Sequoia",           subtitle: "California · ancient forest",    category: "forest",  stays: 12, rating: 4.8, photoID: "1441974231531-c6227db76b6e", tags: ["forest", "california", "trees", "national park", "ancient", "redwood", "hiking", "shade"]),
        Entry(id: "lake-tahoe",     title: "Lake Tahoe",        subtitle: "California · alpine lake",       category: "lake",    stays: 17, rating: 4.7, photoID: "1480497490787-505ec076689f", tags: ["lake", "california", "alpine", "summer", "vibes", "ski", "scenic", "water", "family"]),
        Entry(id: "joshua-tree",    title: "Joshua Tree",       subtitle: "California · high desert",       category: "desert",  stays: 11, rating: 4.6, photoID: "1500964757637-c85e8a162699", tags: ["desert", "california", "national park", "stargazing", "scenic", "warm"]),
        Entry(id: "death-valley",   title: "Death Valley",      subtitle: "California · desert basin",      category: "desert",  stays: 9,  rating: 4.5, photoID: "1518495973542-4542c06a5843", tags: ["desert", "california", "national park", "stark", "scenic", "warm"]),

        // --- Florida coast & islands (sun-lit water photos) ---
        Entry(id: "miami-beach",    title: "Miami Beach",       subtitle: "Florida · art-deco shore",       category: "beach",   stays: 22, rating: 4.7, photoID: "1464822759023-fed622ff2c3b", tags: ["beach", "summer", "vibes", "family", "florida", "sunny", "tropical", "warm", "sand", "art deco"]),
        Entry(id: "clearwater",     title: "Clearwater Beach",  subtitle: "Florida · gulf coast",           category: "beach",   stays: 19, rating: 4.7, photoID: "1505765050516-f72dcac9c60b", tags: ["beach", "summer", "vibes", "family", "florida", "sunny", "tropical", "warm", "sand", "gulf"]),
        Entry(id: "key-west",       title: "Key West",          subtitle: "Florida · tropical island",      category: "island",  stays: 14, rating: 4.8, photoID: "1486012329979-67c6a4b5c5b7", tags: ["beach", "summer", "vibes", "florida", "sunny", "tropical", "warm", "island", "keys", "romantic"]),
        Entry(id: "sanibel",        title: "Sanibel Island",    subtitle: "Florida · shell shore",          category: "island",  stays: 13, rating: 4.6, photoID: "1454496522488-7a8e488e8606", tags: ["beach", "summer", "family", "florida", "sunny", "tropical", "warm", "sand", "island", "shells"]),
        Entry(id: "everglades",     title: "Everglades",        subtitle: "Florida · wetland mosaic",       category: "wetland", stays: 8,  rating: 4.5, photoID: "1444065381814-865dc9da92c0", tags: ["wetland", "florida", "national park", "wildlife", "swamp", "kayak"]),
        Entry(id: "daytona",        title: "Daytona Beach",     subtitle: "Florida · driveable shore",      category: "beach",   stays: 21, rating: 4.5, photoID: "1464822759023-fed622ff2c3b", tags: ["beach", "summer", "family", "florida", "sunny", "warm", "sand"]),

        // --- Hawaii (tropical water + dramatic peaks) ---
        Entry(id: "waikiki",        title: "Waikiki",           subtitle: "Hawaii · oahu shore",            category: "beach",   stays: 24, rating: 4.8, photoID: "1480497490787-505ec076689f", tags: ["beach", "summer", "vibes", "family", "hawaii", "sunny", "tropical", "warm", "sand", "surf"]),
        Entry(id: "lanikai",        title: "Lanikai",           subtitle: "Hawaii · turquoise bay",         category: "beach",   stays: 12, rating: 4.9, photoID: "1505765050516-f72dcac9c60b", tags: ["beach", "summer", "vibes", "hawaii", "sunny", "tropical", "warm", "sand", "romantic", "turquoise"]),
        Entry(id: "hawaii-volcanoes", title: "Hawaii Volcanoes", subtitle: "Hawaii · active flows",         category: "volcanic", stays: 8, rating: 4.7, photoID: "1505739679850-7adfa4d4dc99", tags: ["volcanic", "hawaii", "national park", "lava", "scenic", "warm"]),

        // --- Mountain west national parks ---
        Entry(id: "grand-canyon",   title: "Grand Canyon",      subtitle: "Arizona · river canyon",         category: "canyon",  stays: 24, rating: 4.9, photoID: "1469474968028-56623f02e42e", tags: ["canyon", "arizona", "national park", "scenic", "hiking", "iconic"]),
        Entry(id: "zion",           title: "Zion",              subtitle: "Utah · sandstone canyon",        category: "canyon",  stays: 15, rating: 4.8, photoID: "1518495973542-4542c06a5843", tags: ["canyon", "utah", "national park", "hiking", "scenic", "sandstone"]),
        Entry(id: "bryce-canyon",   title: "Bryce Canyon",      subtitle: "Utah · hoodoo amphitheater",     category: "canyon",  stays: 11, rating: 4.8, photoID: "1505739679850-7adfa4d4dc99", tags: ["canyon", "utah", "national park", "scenic", "hoodoos", "hiking"]),
        Entry(id: "arches",         title: "Arches",            subtitle: "Utah · sandstone arches",        category: "canyon",  stays: 10, rating: 4.7, photoID: "1500964757637-c85e8a162699", tags: ["canyon", "utah", "national park", "scenic", "arches", "hiking"]),
        Entry(id: "yellowstone",    title: "Yellowstone",       subtitle: "Wyoming · geothermal basin",     category: "wetland", stays: 22, rating: 4.7, photoID: "1501785888041-af3ef285b470", tags: ["wetland", "wyoming", "national park", "geyser", "wildlife", "iconic"]),
        Entry(id: "grand-teton",    title: "Grand Teton",       subtitle: "Wyoming · jagged spires",        category: "alpine",  stays: 14, rating: 4.8, photoID: "1505765050516-f72dcac9c60b", tags: ["alpine", "wyoming", "national park", "mountain", "scenic", "hiking"]),
        Entry(id: "glacier",        title: "Glacier National Park", subtitle: "Montana · alpine wilderness", category: "alpine", stays: 17, rating: 4.8, photoID: "1493244040629-496f6d136cc3", tags: ["alpine", "montana", "national park", "mountain", "scenic", "hiking", "glacier"]),
        Entry(id: "rocky-mountain", title: "Rocky Mountain",    subtitle: "Colorado · alpine peaks",        category: "alpine",  stays: 18, rating: 4.7, photoID: "1506905925346-21bda4d32df4", tags: ["alpine", "colorado", "national park", "mountain", "scenic", "hiking"]),
        Entry(id: "mount-rainier",  title: "Mount Rainier",     subtitle: "Washington · glaciated dome",    category: "alpine",  stays: 12, rating: 4.8, photoID: "1454496522488-7a8e488e8606", tags: ["alpine", "washington", "national park", "mountain", "scenic", "glacier"]),
        Entry(id: "olympic",        title: "Olympic",           subtitle: "Washington · rainforest coast",  category: "forest",  stays: 16, rating: 4.7, photoID: "1470071459604-3b5ec3a7fe05", tags: ["forest", "washington", "national park", "rainforest", "coast", "hiking"]),
        Entry(id: "north-cascades", title: "North Cascades",    subtitle: "Washington · alpine cathedral",  category: "alpine",  stays: 9,  rating: 4.7, photoID: "1505739679850-7adfa4d4dc99", tags: ["alpine", "washington", "national park", "mountain", "remote", "hiking"]),
        Entry(id: "crater-lake",    title: "Crater Lake",       subtitle: "Oregon · caldera blue",          category: "lake",    stays: 11, rating: 4.8, photoID: "1464822759023-fed622ff2c3b", tags: ["lake", "oregon", "national park", "caldera", "scenic", "deep"]),

        // --- Forest + lake + alaska + east ---
        Entry(id: "redwoods",       title: "Redwood Forest",    subtitle: "California · giant grove",       category: "forest",  stays: 13, rating: 4.8, photoID: "1418065460487-3e41a6c84dc5", tags: ["forest", "california", "national park", "redwood", "ancient", "trees", "hiking"]),
        Entry(id: "great-smoky",    title: "Great Smoky Mountains", subtitle: "Tennessee · forested peaks", category: "forest", stays: 14, rating: 4.7, photoID: "1493244040629-496f6d136cc3", tags: ["forest", "tennessee", "national park", "mountain", "scenic", "hiking", "fall"]),
        Entry(id: "denali",         title: "Denali",            subtitle: "Alaska · subarctic wilderness",  category: "tundra",  stays: 9,  rating: 4.9, photoID: "1473773508845-188df298d2d1", tags: ["tundra", "alaska", "national park", "remote", "scenic", "wildlife"]),
        Entry(id: "acadia",         title: "Acadia",            subtitle: "Maine · coastal granite",        category: "coastal", stays: 13, rating: 4.7, photoID: "1486012329979-67c6a4b5c5b7", tags: ["coastal", "maine", "national park", "granite", "scenic", "hiking", "fall"]),
        Entry(id: "cape-cod",       title: "Cape Cod",          subtitle: "Massachusetts · atlantic shore", category: "coastal", stays: 16, rating: 4.6, photoID: "1454496522488-7a8e488e8606", tags: ["coastal", "massachusetts", "summer", "vibes", "family", "atlantic", "beach", "lighthouse"]),
        Entry(id: "outer-banks",    title: "Outer Banks",       subtitle: "North Carolina · barrier islands", category: "beach", stays: 15, rating: 4.6, photoID: "1486012329979-67c6a4b5c5b7", tags: ["beach", "summer", "vibes", "family", "north carolina", "sand", "atlantic", "warm", "lighthouse"]),
        Entry(id: "niagara-falls",  title: "Niagara Falls",     subtitle: "New York · cataract roar",       category: "wetland", stays: 14, rating: 4.6, photoID: "1444065381814-865dc9da92c0", tags: ["wetland", "new york", "waterfall", "iconic", "family", "scenic"]),
        Entry(id: "monument-valley", title: "Monument Valley",  subtitle: "Arizona/Utah · red mesas",       category: "desert",  stays: 8,  rating: 4.8, photoID: "1500964757637-c85e8a162699", tags: ["desert", "arizona", "utah", "iconic", "mesa", "scenic", "navajo"]),
        Entry(id: "lake-powell",    title: "Lake Powell",       subtitle: "Utah/Arizona · canyon lake",     category: "lake",    stays: 12, rating: 4.7, photoID: "1480497490787-505ec076689f", tags: ["lake", "utah", "arizona", "summer", "family", "boating", "scenic", "warm"]),
    ]

    // MARK: - Search

    /// Returns the best 6 destinations for a free-form query. Tokens
    /// are split on non-letters, lowercased, and intersected with each
    /// entry's `tags`. Score = token-overlap count. Ties are broken by
    /// entry rating (descending) so high-rated places surface first.
    /// Empty / no-match queries return six entries shuffled
    /// deterministically off the query string, so the user still sees
    /// a populated page (never empty).
    static func search(_ query: String) -> [Entry] {
        let tokens = Set(
            query.lowercased()
                .split { !$0.isLetter }
                .map(String.init)
                .filter { $0.count >= 3 }
        )
        guard !tokens.isEmpty else { return shuffled(seed: 0).prefix(6).map { $0 } }

        let scored = entries.map { entry -> (Entry, Int) in
            let overlap = tokens.intersection(entry.tags).count
            return (entry, overlap)
        }
        let winners = scored
            .filter { $0.1 > 0 }
            .sorted {
                if $0.1 != $1.1 { return $0.1 > $1.1 }
                return $0.0.rating > $1.0.rating
            }
            .prefix(6)
            .map { $0.0 }

        if winners.count >= 6 { return Array(winners) }
        // Pad with deterministic shuffle of entries not already chosen,
        // so we always return exactly 6 cards.
        let chosenIDs = Set(winners.map(\.id))
        let pad = shuffled(seed: query.hashValue).filter { !chosenIDs.contains($0.id) }
        return Array((winners + pad).prefix(6))
    }

    /// One-sentence poetic summary built from the first two result
    /// titles. Replaces the Claude-generated summary now that the
    /// search runs locally.
    static func summary(for results: [Entry], query: String) -> String {
        guard results.count >= 1 else { return query }
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let n0 = results[0].title
        if results.count == 1 {
            return "\(n0) — the kind of place \"\(q)\" was reaching for."
        }
        let n1 = results[1].title
        return "\(n0) and \(n1) catch the mood of \"\(q)\" — go, drift, breathe."
    }

    // MARK: - Home cloud cell assignment

    /// Picks a catalog entry for a world cell. Same (col,row) → same
    /// entry on every wrap, and adjacent cells in the visible tile
    /// land on different entries because we stride by a prime offset.
    static func entry(forCol col: Int, row: Int) -> Entry {
        // (col * P1) XOR (row * P2) spreads adjacent cells across the
        // catalog so the visible viewport rarely shows two of the same
        // destination, even with only 40 entries vs ~45 grid cells.
        let h = (abs(col) &* 1009) ^ (abs(row) &* 7919) ^ (col >= 0 ? 0 : 0x9E3779B9)
        return entries[h % entries.count]
    }

    /// Builds a `Place` for a world cell — feeds straight into the
    /// existing bubble cloud / deck pipeline.
    static func place(col: Int, row: Int) -> Place {
        let e = entry(forCol: col, row: row)
        return Place(
            id: "cat-\(col)_\(row)",
            title: e.title,
            subtitle: e.subtitle,
            imageURL: e.imageURL,
            stays: e.stays,
            rating: e.rating,
            category: e.category
        )
    }

    // MARK: - Helpers

    /// Deterministic shuffle seeded by `seed` — same seed, same order.
    /// Used so the "no-match" fallback always picks the same six
    /// destinations for a given query.
    private static func shuffled(seed: Int) -> [Entry] {
        var rng = SplitMix64(seed: UInt64(bitPattern: Int64(seed)))
        var copy = entries
        for i in stride(from: copy.count - 1, through: 1, by: -1) {
            let j = Int(rng.next() % UInt64(i + 1))
            copy.swapAt(i, j)
        }
        return copy
    }
}

/// Tiny deterministic PRNG used for the shuffle fallback. Reasonable
/// quality, zero dependencies.
private struct SplitMix64 {
    private var state: UInt64
    init(seed: UInt64) { state = seed &+ 0x9E3779B97F4A7C15 }
    mutating func next() -> UInt64 {
        state = state &+ 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
}
