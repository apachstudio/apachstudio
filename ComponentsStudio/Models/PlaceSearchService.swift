import Foundation

/// Local-only search backend. Wraps `Catalog.search(_:)` so the rest of
/// the app (notably `SearchModalView`) stays unchanged. No API calls,
/// no network, no API key required — everything resolves off the
/// hand-curated `Catalog.entries` array.
///
/// The function is `async` to keep its signature compatible with the
/// previous Claude-backed version, but it's effectively synchronous.
enum PlaceSearchService {
    // MARK: - Public types

    struct SearchResponse {
        let summary: String
        let places: [Place]
    }

    enum SearchError: LocalizedError {
        case empty
        var errorDescription: String? {
            switch self {
            case .empty: return "No matching places in the catalog."
            }
        }
    }

    // MARK: - Public entry point

    /// Picks 6 entries from `Catalog` whose tags best match the query
    /// and wraps them in a `SearchResponse`. Designed to feel instant
    /// — there's no network hop, just a token-overlap scan.
    static func search(query: String) async throws -> SearchResponse {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let effectiveQuery = trimmed.isEmpty ? "calm beautiful places" : trimmed
        let hits = Catalog.search(effectiveQuery)
        guard !hits.isEmpty else { throw SearchError.empty }

        let summary = Catalog.summary(for: hits, query: effectiveQuery)
        let places = hits.enumerated().map { idx, e in
            Place(
                id: "search-\(idx)-\(e.id)",
                title: e.title,
                subtitle: e.subtitle,
                imageURL: e.imageURL,
                stays: e.stays,
                rating: e.rating,
                category: e.category
            )
        }
        let names = places.map(\.title).joined(separator: ", ")
        print("[PlaceSearch] \(places.count) matches for \"\(effectiveQuery)\" — \(names)")
        return SearchResponse(summary: summary, places: places)
    }
}
