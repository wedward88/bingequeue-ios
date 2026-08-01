import Foundation

enum AppConfig {
    #if DEBUG
    static let apiBaseURL = URL(string: "http://localhost:3000")!
    #else
    static let apiBaseURL = URL(string: "https://bingequeue.com")!
    #endif

    static let tmdbPosterBaseURL = "https://image.tmdb.org/t/p/w500"
    static let tmdbPosterLargeBaseURL = "https://image.tmdb.org/t/p/w780"
    static let tmdbLogoBaseURL = "https://image.tmdb.org/t/p/w92"

    /// Suggested US monthly list prices keyed by TMDB provider id (mirrors web commonProviders).
    static let suggestedProviderCosts: [Int: String] = [
        8: "19.99",
        337: "11.99",
        15: "11.99",
        1899: "18.49",
        9: "14.99",
        350: "12.99",
        386: "10.99",
        531: "8.99",
        283: "11.99",
        43: "11.99",
    ]

    static let commonProviderLabels: [Int: String] = [
        8: "Netflix",
        337: "Disney+",
        15: "Hulu",
        1899: "Max",
        9: "Prime Video",
        350: "Apple TV+",
        386: "Peacock",
        531: "Paramount+",
        283: "Crunchyroll",
        43: "Starz",
    ]

    static var googleClientID: String {
        Bundle.main.object(forInfoDictionaryKey: "GIDClientID") as? String ?? ""
    }

    static var googleServerClientID: String {
        Bundle.main.object(forInfoDictionaryKey: "GIDServerClientID") as? String ?? ""
    }

    /// Builds a full TMDB image URL. Paths from the API are absolute (`/abc.jpg`),
    /// so we must concatenate — `URL(relativeTo:)` would resolve them against the host root.
    static func tmdbImageURL(path: String?, size: TMDBImageSize = .poster) -> URL? {
        guard let path, !path.isEmpty else { return nil }
        if path.hasPrefix("http://") || path.hasPrefix("https://") {
            return URL(string: path)
        }
        let base: String
        switch size {
        case .poster:
            base = tmdbPosterBaseURL
        case .posterLarge:
            base = tmdbPosterLargeBaseURL
        case .logo:
            base = tmdbLogoBaseURL
        }
        let normalized = path.hasPrefix("/") ? path : "/\(path)"
        return URL(string: base + normalized)
    }
}

enum TMDBImageSize {
    case poster
    case posterLarge
    case logo
}
