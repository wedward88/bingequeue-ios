import Foundation

enum AppConfig {
    #if DEBUG
    /// Authenticated account calls in Debug (local Next.js).
    static let apiBaseURL = URL(string: "http://localhost:3000")!
    #else
    static let apiBaseURL = URL(string: "https://api.bingequeue.com")!
    #endif

    /// Public TMDB proxies (providers / search / discover). Always production so
    /// guest mode and on-device Debug builds work without a local server.
    static let publicAPIBaseURL = URL(string: "https://api.bingequeue.com")!

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

    /// Offline / guest-mode catalog (TMDB provider IDs + logo paths).
    /// Used when `/api/providers` is unreachable so popular chips still appear.
    static let bundledCommonProviders: [StreamingProvider] = [
        .init(id: 8, name: "Netflix", logoUrl: "/pbpMk2JmcoNnQwx5JGpXngfoWtp.jpg", providerId: 8),
        .init(id: 337, name: "Disney Plus", logoUrl: "/97yvRBw1GzX7fXprcF80er19ot.jpg", providerId: 337),
        .init(id: 15, name: "Hulu", logoUrl: "/bxBlRPEPpMVDc4jMhSrTf2339DW.jpg", providerId: 15),
        .init(id: 1899, name: "Max", logoUrl: "/fksCUZ9QDWZMUwL2LgMtLckROUN.jpg", providerId: 1899),
        .init(id: 9, name: "Amazon Prime Video", logoUrl: "/pvske1MyAoymrs5bguRfVqYiM9a.jpg", providerId: 9),
        .init(id: 350, name: "Apple TV Plus", logoUrl: "/2E03IAZsX4ZaUqM7tXlctEPMGWS.jpg", providerId: 350),
        .init(id: 386, name: "Peacock Premium", logoUrl: "/2aGrp1xw3qhwCYvNGAJZPdjfeeX.jpg", providerId: 386),
        .init(id: 531, name: "Paramount Plus", logoUrl: "/h5DcR0J2EESLitnhR8xLG1QymTE.jpg", providerId: 531),
        .init(id: 283, name: "Crunchyroll", logoUrl: "/fzN5Jok5Ig1eJ7gyNGoMhnLSCfh.jpg", providerId: 283),
        .init(id: 43, name: "Starz", logoUrl: "/yIKwylTLP1u8gl84Is7FItpYLGL.jpg", providerId: 43),
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
