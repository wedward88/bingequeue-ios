import Foundation

struct UserProfile: Codable, Equatable, Identifiable {
    let id: String
    let name: String?
    let email: String?
    let image: String?
}

struct StreamingProvider: Codable, Equatable, Identifiable, Hashable {
    let id: Int
    let name: String
    let logoUrl: String
    let providerId: Int

    var displayName: String {
        AppConfig.commonProviderLabels[providerId] ?? name
    }

    var suggestedCost: String {
        AppConfig.suggestedProviderCosts[providerId] ?? ""
    }
}

struct Subscription: Codable, Equatable, Identifiable {
    let id: Int
    let userId: String
    let cost: String?
    let streamingProviderId: Int
    let streamingProvider: StreamingProvider?

    var monthlyCost: Decimal {
        guard let cost, let value = Decimal(string: cost) else { return 0 }
        return value
    }
}

struct SearchResult: Codable, Equatable, Hashable, Identifiable {
    let mediaId: Int
    let mediaType: String
    let originalName: String?
    let originalTitle: String?
    let overview: String?
    let posterPath: String?
    let watchListId: Int?

    var id: String { "\(mediaType)-\(mediaId)" }

    enum CodingKeys: String, CodingKey {
        case mediaId = "id"
        case mediaType = "media_type"
        case originalName = "original_name"
        case originalTitle = "original_title"
        case overview
        case posterPath = "poster_path"
        case watchListId
    }

    var displayTitle: String {
        if mediaType == "tv" {
            return originalName ?? originalTitle ?? "Untitled"
        }
        return originalTitle ?? originalName ?? "Untitled"
    }

    var isOnWatchList: Bool {
        (watchListId ?? 0) > 0
    }

    init(
        mediaId: Int,
        mediaType: String,
        originalName: String?,
        originalTitle: String?,
        overview: String?,
        posterPath: String?,
        watchListId: Int? = nil
    ) {
        self.mediaId = mediaId
        self.mediaType = mediaType
        self.originalName = originalName
        self.originalTitle = originalTitle
        self.overview = overview
        self.posterPath = posterPath
        self.watchListId = watchListId
    }

    init(from item: WatchListItem) {
        self.init(
            mediaId: item.mediaId,
            mediaType: item.mediaType,
            originalName: item.originalName,
            originalTitle: item.originalTitle,
            overview: item.overview,
            posterPath: item.posterPath.isEmpty ? nil : item.posterPath,
            watchListId: item.id
        )
    }
}

struct WatchListItem: Codable, Equatable, Identifiable, Hashable {
    let id: Int
    let mediaId: Int
    let mediaType: String
    let originalTitle: String?
    let originalName: String?
    let posterPath: String
    let overview: String
    let streamingProviders: [WatchListProvider]

    var displayTitle: String {
        if mediaType == "tv" {
            return originalName ?? originalTitle ?? "Untitled"
        }
        return originalTitle ?? originalName ?? "Untitled"
    }
}

struct WatchListProvider: Codable, Equatable, Identifiable, Hashable {
    let id: Int
    let name: String
    let logoUrl: String
    let providerId: Int
}

struct TitleWatchProvider: Codable, Equatable, Identifiable, Hashable {
    let id: Int
    let providerName: String
    let logoPath: String?

    enum CodingKeys: String, CodingKey {
        case id
        case providerName = "provider_name"
        case logoPath = "logo_path"
    }
}

enum MediaTypeFilter: String, CaseIterable, Identifiable {
    case all
    case movie
    case tv

    var id: String { rawValue }

    var label: String {
        switch self {
        case .all: return "All"
        case .movie: return "Movies"
        case .tv: return "TV"
        }
    }
}

struct APIErrorResponse: Codable {
    let error: String
    let code: String?
}

struct MobileAuthResponse: Codable {
    let token: String
    let user: UserProfile
}

struct SubscriptionsResponse: Codable {
    let subscriptions: [Subscription]
}

struct SubscriptionResponse: Codable {
    let subscription: Subscription
}

struct ProvidersResponse: Codable {
    let providers: [StreamingProvider]
    let source: String?
}

struct SearchResponse: Codable {
    let results: [SearchResult]
}

struct WatchListResponse: Codable {
    let items: [WatchListItem]
}

struct WatchListItemResponse: Codable {
    let item: WatchListItem
}

struct TitleProvidersResponse: Codable {
    let providers: [String: TitleWatchProvider]
}

struct ReorderResponse: Codable {
    let success: Bool
}
