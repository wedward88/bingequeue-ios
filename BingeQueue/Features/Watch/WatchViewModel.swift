import Foundation

@MainActor
final class WatchViewModel: ObservableObject {
    @Published var searchQuery = ""
    @Published var mediaFilter: MediaTypeFilter = .all
    @Published var searchResults: [SearchResult] = []
    @Published var discoverResults: [SearchResult] = []
    @Published var watchList: [WatchListItem] = []
    @Published var subscriptions: [Subscription] = []
    @Published var selectedProviderId: Int?
    @Published var isSearching = false
    @Published var isLoadingWatchList = false
    @Published var errorMessage: String?
    @Published var selectedResult: SearchResult?
    @Published var titleProviders: [TitleWatchProvider] = []
    @Published var isLoadingDetail = false

    private let api: APIClient
    private let localStore: LocalLibraryStore
    private var searchTask: Task<Void, Never>?
    private var isLocal = false

    init(api: APIClient = .shared, localStore: LocalLibraryStore = .shared) {
        self.api = api
        self.localStore = localStore
    }

    var subscribedProviders: [StreamingProvider] {
        subscriptions.compactMap(\.streamingProvider)
    }

    func load(isLocal: Bool) async {
        // Account sessions use the API only; guest sessions use on-device storage only.
        self.isLocal = isLocal
        isLoadingWatchList = true
        defer { isLoadingWatchList = false }
        do {
            if isLocal {
                watchList = localStore.fetchWatchList()
                subscriptions = localStore.fetchSubscriptions()
                if selectedProviderId == nil, let first = subscribedProviders.first {
                    selectedProviderId = first.providerId
                }
                if let providerId = selectedProviderId {
                    do {
                        discoverResults = try await api.discoverByProvider(
                            providerId: providerId,
                            mediaType: mediaFilter
                        )
                    } catch {
                        discoverResults = []
                    }
                }
            } else {
                async let list = api.fetchWatchList()
                async let subs = api.fetchSubscriptions()
                watchList = try await list
                subscriptions = try await subs
                if selectedProviderId == nil, let first = subscribedProviders.first {
                    selectedProviderId = first.providerId
                    await discover(providerId: first.providerId)
                } else if let selectedProviderId {
                    await discover(providerId: selectedProviderId)
                }
            }
            WidgetSync.publish(
                subscriptions: subscriptions,
                watchList: watchList,
                isGuest: isLocal
            )
        } catch {
            errorMessage = UserFacingError.message(from: error)
        }
    }

    func scheduleSearch() {
        searchTask?.cancel()
        let query = searchQuery
        let filter = mediaFilter
        searchTask = Task {
            try? await Task.sleep(nanoseconds: 350_000_000)
            guard !Task.isCancelled else { return }
            await search(query: query, mediaType: filter)
        }
    }

    func search(query: String, mediaType: MediaTypeFilter) async {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            searchResults = []
            return
        }
        isSearching = true
        defer { isSearching = false }
        do {
            searchResults = try await api.searchTitles(query: trimmed, mediaType: mediaType)
        } catch {
            errorMessage = UserFacingError.message(from: error)
        }
    }

    func discover(providerId: Int) async {
        selectedProviderId = providerId
        isSearching = true
        defer { isSearching = false }
        do {
            discoverResults = try await api.discoverByProvider(
                providerId: providerId,
                mediaType: mediaFilter
            )
        } catch {
            errorMessage = UserFacingError.message(from: error)
        }
    }

    func openDetail(_ result: SearchResult) async {
        selectedResult = result
        isLoadingDetail = true
        defer { isLoadingDetail = false }
        do {
            titleProviders = try await api.fetchTitleProviders(
                type: result.mediaType,
                id: result.mediaId
            )
        } catch {
            titleProviders = []
            errorMessage = UserFacingError.message(from: error)
        }
    }

    func openDetail(_ item: WatchListItem) async {
        await openDetail(SearchResult(from: item))
    }

    func addToWatchList(_ result: SearchResult) async {
        do {
            if isLocal {
                let providers = try await matchingProviders(for: result)
                let item = try localStore.addWatchListItem(
                    from: result,
                    streamingProviders: providers
                )
                if !watchList.contains(where: {
                    $0.mediaId == item.mediaId && $0.mediaType == item.mediaType
                }) {
                    watchList.insert(item, at: 0)
                }
            } else {
                let item = try await api.addToWatchList(result)
                if !watchList.contains(where: {
                    $0.mediaId == item.mediaId && $0.mediaType == item.mediaType
                }) {
                    watchList.insert(item, at: 0)
                }
            }
            WidgetSync.publish(watchList: watchList, isGuest: isLocal)
        } catch {
            errorMessage = UserFacingError.message(from: error)
        }
    }

    func removeFromWatchList(mediaId: Int, mediaType: String) async {
        guard let item = watchList.first(where: {
            $0.mediaId == mediaId && $0.mediaType == mediaType
        }) else { return }
        await removeWatchListItem(item)
    }

    func removeWatchListItem(_ item: WatchListItem) async {
        do {
            if isLocal {
                watchList = localStore.removeWatchListItem(id: item.id)
            } else {
                watchList = try await api.removeFromWatchList(id: item.id)
            }
            WidgetSync.publish(watchList: watchList, isGuest: isLocal)
        } catch {
            errorMessage = UserFacingError.message(from: error)
        }
    }

    func reorderWatchList(from source: IndexSet, to destination: Int) async {
        watchList.move(fromOffsets: source, toOffset: destination)
        do {
            if isLocal {
                try localStore.reorderWatchList(orderedItemIds: watchList.map(\.id))
            } else {
                try await api.reorderWatchList(orderedItemIds: watchList.map(\.id))
            }
            WidgetSync.publish(watchList: watchList, isGuest: isLocal)
        } catch {
            errorMessage = UserFacingError.message(from: error)
            await load(isLocal: isLocal)
        }
    }

    func watchListItem(for result: SearchResult) -> WatchListItem? {
        watchList.first { $0.mediaId == result.mediaId && $0.mediaType == result.mediaType }
    }

    func isOnWatchList(_ result: SearchResult) -> Bool {
        watchList.contains { $0.mediaId == result.mediaId && $0.mediaType == result.mediaType }
    }

    private func matchingProviders(for result: SearchResult) async throws -> [WatchListProvider] {
        let titleProviders = try await api.fetchTitleProviders(
            type: result.mediaType,
            id: result.mediaId
        )
        let subscribedTmdbIds = Set(subscribedProviders.map(\.providerId))
        return titleProviders.compactMap { provider in
            guard subscribedTmdbIds.contains(provider.id) else { return nil }
            return WatchListProvider(
                id: provider.id,
                name: provider.providerName,
                logoUrl: provider.logoPath ?? "",
                providerId: provider.id
            )
        }
    }
}
