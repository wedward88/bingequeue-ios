import Foundation

/// On-device subscriptions + watch list for **guest mode only**.
/// Signed-in accounts use the BingeQueue API and never read or write this store.
struct LocalLibrary: Codable, Equatable {
    var subscriptions: [Subscription]
    var watchList: [WatchListItem]
    var nextSubscriptionId: Int
    var nextWatchListId: Int

    static let empty = LocalLibrary(
        subscriptions: [],
        watchList: [],
        nextSubscriptionId: 1,
        nextWatchListId: 1
    )
}

@MainActor
final class LocalLibraryStore {
    static let shared = LocalLibraryStore()

    /// Guest-only persistence — intentionally separate from any account/cloud data.
    private let fileURL: URL
    private let defaultsKey = "bingequeue.guest.localLibrary"
    private let legacyDefaultsKeys = [
        "servicecycle.guest.localLibrary",
        "servicecycle.localLibrary",
    ]
    private let legacyFileName = "local-library.json"
    private let fileName = "guest-local-library.json"

    private init() {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        fileURL = docs.appendingPathComponent(fileName)
        migrateLegacyIfNeeded(docs: docs)
    }

    private func migrateLegacyIfNeeded(docs: URL) {
        let legacyURL = docs.appendingPathComponent(legacyFileName)
        if !FileManager.default.fileExists(atPath: fileURL.path),
           FileManager.default.fileExists(atPath: legacyURL.path) {
            try? FileManager.default.moveItem(at: legacyURL, to: fileURL)
        }
        if UserDefaults.standard.data(forKey: defaultsKey) == nil {
            for key in legacyDefaultsKeys {
                if let legacy = UserDefaults.standard.data(forKey: key) {
                    UserDefaults.standard.set(legacy, forKey: defaultsKey)
                    UserDefaults.standard.removeObject(forKey: key)
                    break
                }
            }
        }
    }

    func load() -> LocalLibrary {
        if let data = try? Data(contentsOf: fileURL),
           let library = try? JSONDecoder().decode(LocalLibrary.self, from: data) {
            return library
        }
        if let data = UserDefaults.standard.data(forKey: defaultsKey),
           let library = try? JSONDecoder().decode(LocalLibrary.self, from: data) {
            return library
        }
        return .empty
    }

    func save(_ library: LocalLibrary) {
        guard let data = try? JSONEncoder().encode(library) else { return }
        try? data.write(to: fileURL, options: [.atomic])
        UserDefaults.standard.set(data, forKey: defaultsKey)
    }

    func clear() {
        try? FileManager.default.removeItem(at: fileURL)
        UserDefaults.standard.removeObject(forKey: defaultsKey)
        for key in legacyDefaultsKeys {
            UserDefaults.standard.removeObject(forKey: key)
        }
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        try? FileManager.default.removeItem(at: docs.appendingPathComponent(legacyFileName))
    }

    // MARK: - Subscriptions

    func fetchSubscriptions() -> [Subscription] {
        load().subscriptions.sorted {
            ($0.streamingProvider?.name ?? "") < ($1.streamingProvider?.name ?? "")
        }
    }

    @discardableResult
    func addSubscription(provider: StreamingProvider, cost: String?) throws -> Subscription {
        var library = load()
        if library.subscriptions.contains(where: { $0.streamingProviderId == provider.id }) {
            throw LocalStoreError.subscriptionExists
        }
        let subscription = Subscription(
            id: library.nextSubscriptionId,
            userId: "local",
            cost: cost,
            streamingProviderId: provider.id,
            streamingProvider: provider
        )
        library.nextSubscriptionId += 1
        library.subscriptions.append(subscription)
        save(library)
        return subscription
    }

    @discardableResult
    func updateSubscription(id: Int, cost: String?) throws -> Subscription {
        var library = load()
        guard let index = library.subscriptions.firstIndex(where: { $0.id == id }) else {
            throw LocalStoreError.notFound
        }
        let existing = library.subscriptions[index]
        let updated = Subscription(
            id: existing.id,
            userId: existing.userId,
            cost: cost,
            streamingProviderId: existing.streamingProviderId,
            streamingProvider: existing.streamingProvider
        )
        library.subscriptions[index] = updated
        save(library)
        return updated
    }

    func deleteSubscription(id: Int) throws {
        var library = load()
        library.subscriptions.removeAll { $0.id == id }
        save(library)
    }

    // MARK: - Watch list

    func fetchWatchList() -> [WatchListItem] {
        load().watchList
    }

    @discardableResult
    func addWatchListItem(
        from result: SearchResult,
        streamingProviders: [WatchListProvider]
    ) throws -> WatchListItem {
        var library = load()
        if let existing = library.watchList.first(where: {
            $0.mediaId == result.mediaId && $0.mediaType == result.mediaType
        }) {
            return existing
        }
        let item = WatchListItem(
            id: library.nextWatchListId,
            mediaId: result.mediaId,
            mediaType: result.mediaType,
            originalTitle: result.originalTitle,
            originalName: result.originalName,
            posterPath: result.posterPath ?? "",
            overview: result.overview ?? "",
            streamingProviders: streamingProviders
        )
        library.nextWatchListId += 1
        library.watchList.insert(item, at: 0)
        save(library)
        return item
    }

    func removeWatchListItem(id: Int) -> [WatchListItem] {
        var library = load()
        library.watchList.removeAll { $0.id == id }
        save(library)
        return library.watchList
    }

    func reorderWatchList(orderedItemIds: [Int]) throws {
        var library = load()
        let byId = Dictionary(uniqueKeysWithValues: library.watchList.map { ($0.id, $0) })
        guard Set(orderedItemIds) == Set(byId.keys) else {
            throw LocalStoreError.invalidReorder
        }
        library.watchList = orderedItemIds.compactMap { byId[$0] }
        save(library)
    }
}

enum LocalStoreError: LocalizedError {
    case subscriptionExists
    case notFound
    case invalidReorder

    var errorDescription: String? {
        switch self {
        case .subscriptionExists:
            return "Subscription already exists"
        case .notFound:
            return "Item not found."
        case .invalidReorder:
            return "Could not reorder watch list."
        }
    }
}
