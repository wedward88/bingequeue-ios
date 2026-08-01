import Foundation

@MainActor
final class SubscriptionsViewModel: ObservableObject {
    @Published var subscriptions: [Subscription] = []
    @Published var commonProviders: [StreamingProvider] = []
    @Published var searchProviders: [StreamingProvider] = []
    @Published var isLoading = false
    @Published var isSaving = false
    @Published var errorMessage: String?
    @Published var searchQuery = ""

    private let api: APIClient
    private let localStore: LocalLibraryStore
    private var isLocal = false

    init(api: APIClient = .shared, localStore: LocalLibraryStore = .shared) {
        self.api = api
        self.localStore = localStore
    }

    var monthlyTotal: Decimal {
        subscriptions.reduce(0) { $0 + $1.monthlyCost }
    }

    var formattedMonthlyTotal: String {
        Self.currencyFormatter.string(from: monthlyTotal as NSDecimalNumber) ?? "$0.00"
    }

    static let currencyFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        return formatter
    }()

    func load(isLocal: Bool) async {
        // Account sessions use the API only; guest sessions use on-device storage only.
        self.isLocal = isLocal
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            if isLocal {
                subscriptions = localStore.fetchSubscriptions()
                do {
                    commonProviders = try await api.fetchProviders()
                } catch {
                    // Guest mode can still manage local data if the API is offline.
                    commonProviders = []
                }
            } else {
                async let providers = api.fetchProviders()
                async let subs = api.fetchSubscriptions()
                subscriptions = try await subs.sorted {
                    ($0.streamingProvider?.name ?? "") < ($1.streamingProvider?.name ?? "")
                }
                commonProviders = try await providers
            }
            WidgetSync.publish(subscriptions: subscriptions, isGuest: isLocal)
        } catch {
            if let message = UserFacingError.message(from: error) {
                errorMessage = message
            }
        }
    }

    func searchProviders(query: String) async {
        searchQuery = query
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            searchProviders = []
            return
        }
        do {
            searchProviders = try await api.fetchProviders(query: query)
        } catch {
            errorMessage = UserFacingError.message(from: error)
        }
    }

    func add(provider: StreamingProvider, cost: String) async -> Bool {
        isSaving = true
        defer { isSaving = false }
        do {
            let created: Subscription
            if isLocal {
                created = try localStore.addSubscription(
                    provider: provider,
                    cost: cost.isEmpty ? nil : cost
                )
            } else {
                created = try await api.createSubscription(
                    streamingProviderId: provider.id,
                    cost: cost.isEmpty ? nil : cost
                )
            }
            subscriptions.append(created)
            subscriptions.sort {
                ($0.streamingProvider?.name ?? "") < ($1.streamingProvider?.name ?? "")
            }
            WidgetSync.publish(subscriptions: subscriptions, isGuest: isLocal)
            return true
        } catch {
            errorMessage = UserFacingError.message(from: error)
            return false
        }
    }

    func update(_ subscription: Subscription, cost: String) async -> Bool {
        isSaving = true
        defer { isSaving = false }
        do {
            let updated: Subscription
            if isLocal {
                updated = try localStore.updateSubscription(
                    id: subscription.id,
                    cost: cost.isEmpty ? nil : cost
                )
            } else {
                updated = try await api.updateSubscription(
                    id: subscription.id,
                    streamingProviderId: subscription.streamingProviderId,
                    cost: cost.isEmpty ? nil : cost
                )
            }
            if let index = subscriptions.firstIndex(where: { $0.id == subscription.id }) {
                subscriptions[index] = updated
            }
            WidgetSync.publish(subscriptions: subscriptions, isGuest: isLocal)
            return true
        } catch {
            errorMessage = UserFacingError.message(from: error)
            return false
        }
    }

    func delete(_ subscription: Subscription) async {
        do {
            if isLocal {
                try localStore.deleteSubscription(id: subscription.id)
            } else {
                try await api.deleteSubscription(id: subscription.id)
            }
            subscriptions.removeAll { $0.id == subscription.id }
            WidgetSync.publish(subscriptions: subscriptions, isGuest: isLocal)
        } catch {
            errorMessage = UserFacingError.message(from: error)
        }
    }

    func isSubscribed(to provider: StreamingProvider) -> Bool {
        subscriptions.contains { $0.streamingProviderId == provider.id }
    }
}
