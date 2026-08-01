import Foundation

struct WidgetWatchItem: Codable, Equatable, Identifiable {
    var id: Int
    var title: String
    var mediaType: String
}

struct WidgetSnapshot: Codable, Equatable {
    var monthlyTotal: String
    var subscriptionCount: Int
    var watchItems: [WidgetWatchItem]
    var isGuest: Bool
    var updatedAt: Date

    static let empty = WidgetSnapshot(
        monthlyTotal: "$0.00",
        subscriptionCount: 0,
        watchItems: [],
        isGuest: true,
        updatedAt: .distantPast
    )
}

enum AppGroup {
    static let identifier = "group.com.bingequeue.com"
    static let snapshotFileName = "widget-snapshot.json"

    static var containerURL: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: identifier)
    }
}
