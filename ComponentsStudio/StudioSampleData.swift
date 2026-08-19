import Foundation

/// Curated sample `Place` values for Component Studio stages — ported
/// from bubble-cloud's `ComponentStudioView` beach + pizza pools.
enum StudioSampleData {
    private static func unsplash(_ id: String) -> URL? {
        URL(string:
            "https://images.unsplash.com/photo-\(id)?w=1200&h=1600&fit=crop&q=85&auto=format"
        )
    }

    // MARK: - Pizza bubble card

    static let pizzaPlace = Place(
        id: "studio-pizza-main",
        title: "Margherita",
        subtitle: "Wood-fired",
        imageURL: unsplash("1513104890138-7c749659a591"),
        stays: 0,
        rating: 0,
        category: "food"
    )

    static let pizzaIngredients: [Place] = [
        Place(id: "ing-tomato", title: "Tomato", subtitle: "",
              imageURL: unsplash("1518977822534-7049a61ee0c2"),
              stays: 0, rating: 0, category: "food"),
        Place(id: "ing-mozzarella", title: "Mozzarella", subtitle: "",
              imageURL: unsplash("1486297678162-eb2a19b0a32d"),
              stays: 0, rating: 0, category: "food"),
        Place(id: "ing-basil", title: "Basil", subtitle: "",
              imageURL: unsplash("1457530378978-8bac673b8062"),
              stays: 0, rating: 0, category: "food"),
        Place(id: "ing-olive-oil", title: "Olive Oil", subtitle: "",
              imageURL: unsplash("1474979266404-7eaacbcd87c5"),
              stays: 0, rating: 0, category: "food"),
        Place(id: "ing-garlic", title: "Garlic", subtitle: "",
              imageURL: unsplash("1540148426945-6cf22a6b2383"),
              stays: 0, rating: 0, category: "food"),
        Place(id: "ing-flour", title: "Flour", subtitle: "",
              imageURL: unsplash("1568254183919-78a4f43a2877"),
              stays: 0, rating: 0, category: "food"),
    ]

    // MARK: - Vertical deck

    private struct BeachSample {
        let title: String
        let subtitle: String
        let category: String
        let stays: Int
        let rating: Double
        let photoID: String

        func toPlace(id: String) -> Place {
            Place(
                id: id,
                title: title,
                subtitle: subtitle,
                imageURL: unsplash(photoID),
                stays: stays,
                rating: rating,
                category: category
            )
        }
    }

    private static let beachSamples: [BeachSample] = [
        BeachSample(title: "Big Sur", subtitle: "California · coastal drive", category: "coastal", stays: 12, rating: 4.8, photoID: "1486012329979-67c6a4b5c5b7"),
        BeachSample(title: "Acadia", subtitle: "Maine · granite coast", category: "coastal", stays: 13, rating: 4.7, photoID: "1454496522488-7a8e488e8606"),
        BeachSample(title: "Yosemite Valley", subtitle: "California · alpine valley", category: "valley", stays: 19, rating: 4.8, photoID: "1444090542259-0af8fa96557e"),
        BeachSample(title: "Lake Tahoe", subtitle: "California · alpine lake", category: "lake", stays: 17, rating: 4.7, photoID: "1501785888041-af3ef285b470"),
        BeachSample(title: "Crater Lake", subtitle: "Oregon · caldera blue", category: "lake", stays: 11, rating: 4.8, photoID: "1505765050516-f72dcac9c60b"),
        BeachSample(title: "Lake Powell", subtitle: "Utah/Arizona · canyon lake", category: "lake", stays: 12, rating: 4.7, photoID: "1480497490787-505ec076689f"),
    ]

    static let deckPlaces: [Place] = beachSamples.enumerated().map { idx, s in
        s.toPlace(id: "studio-deck-\(idx)-\(s.title)")
    }

    static let blurFocusQuery = "beach summer vibes for family"

    // MARK: - Shaders

    /// High-contrast portrait on saturated orange — matches Abduzeedo Photo Ripple demo.
    static let shaderPhotoURL = URL(string: "https://i.pinimg.com/736x/df/17/26/df17268484ce6c16d33ddf6ff73fbad3.jpg")

    /// Colorful, detail-rich wallpaper for the Refractive Photo lens, so the
    /// refraction / magnification / chromatic fringe read clearly behind the
    /// draggable glass (Victor Baro tutorial uses a wallpaper-like backdrop).
    static let wallpaperURL = unsplash("1502082553048-f009c37129b9")
}
