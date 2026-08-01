import Foundation

enum WidgetDataStore {
    private static var snapshotURL: URL? {
        AppGroup.containerURL?.appendingPathComponent(AppGroup.snapshotFileName)
    }

    static func load() -> WidgetSnapshot {
        guard let url = snapshotURL,
              let data = try? Data(contentsOf: url),
              let snapshot = try? JSONDecoder().decode(WidgetSnapshot.self, from: data)
        else {
            return .empty
        }
        return snapshot
    }

    static func save(_ snapshot: WidgetSnapshot) {
        guard let url = snapshotURL,
              let data = try? JSONEncoder().encode(snapshot)
        else {
            return
        }
        try? data.write(to: url, options: [.atomic])
    }
}
