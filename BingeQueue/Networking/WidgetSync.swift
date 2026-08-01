import Foundation
import WidgetKit

enum WidgetSync {
    private static let currencyFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        return formatter
    }()

    static func publish(
        subscriptions: [Subscription]? = nil,
        watchList: [WatchListItem]? = nil,
        isGuest: Bool
    ) {
        var snapshot = WidgetDataStore.load()
        snapshot.isGuest = isGuest
        snapshot.updatedAt = Date()

        if let subscriptions {
            let total = subscriptions.reduce(Decimal(0)) { $0 + $1.monthlyCost }
            snapshot.monthlyTotal =
                currencyFormatter.string(from: total as NSDecimalNumber) ?? "$0.00"
            snapshot.subscriptionCount = subscriptions.count
        }

        if let watchList {
            snapshot.watchItems = watchList.prefix(12).map {
                WidgetWatchItem(
                    id: $0.id,
                    title: $0.displayTitle,
                    mediaType: $0.mediaType
                )
            }
        }

        WidgetDataStore.save(snapshot)
        WidgetCenter.shared.reloadAllTimelines()
    }
}
