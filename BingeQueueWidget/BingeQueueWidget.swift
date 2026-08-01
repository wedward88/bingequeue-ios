import SwiftUI
import WidgetKit

@main
struct BingeQueueWidgetBundle: WidgetBundle {
    var body: some Widget {
        BingeQueueWidget()
    }
}

struct BingeQueueEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetSnapshot
}

struct BingeQueueProvider: TimelineProvider {
    func placeholder(in context: Context) -> BingeQueueEntry {
        BingeQueueEntry(
            date: Date(),
            snapshot: WidgetSnapshot(
                monthlyTotal: "$42.97",
                subscriptionCount: 3,
                watchItems: [
                    WidgetWatchItem(id: 1, title: "Severance", mediaType: "tv"),
                    WidgetWatchItem(id: 2, title: "Dune: Part Two", mediaType: "movie"),
                    WidgetWatchItem(id: 3, title: "The Bear", mediaType: "tv"),
                    WidgetWatchItem(id: 4, title: "Oppenheimer", mediaType: "movie"),
                    WidgetWatchItem(id: 5, title: "Shōgun", mediaType: "tv"),
                ],
                isGuest: true,
                updatedAt: Date()
            )
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (BingeQueueEntry) -> Void) {
        completion(BingeQueueEntry(date: Date(), snapshot: WidgetDataStore.load()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<BingeQueueEntry>) -> Void) {
        let entry = BingeQueueEntry(date: Date(), snapshot: WidgetDataStore.load())
        let next = Calendar.current.date(byAdding: .minute, value: 30, to: Date()) ?? Date()
        completion(Timeline(entries: [entry], policy: .after(next)))
    }
}

struct BingeQueueWidget: Widget {
    let kind = "BingeQueueWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: BingeQueueProvider()) { entry in
            BingeQueueWidgetView(entry: entry)
                .containerBackground(for: .widget) {
                    widgetBackground
                }
        }
        .configurationDisplayName("BingeQueue")
        .description("Your watch list, with monthly stack total.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }

    private var widgetBackground: some View {
        LinearGradient(
            colors: [
                Color(red: 28 / 255, green: 18 / 255, blue: 48 / 255),
                Color(red: 24 / 255, green: 16 / 255, blue: 42 / 255),
                Color(red: 18 / 255, green: 10 / 255, blue: 28 / 255),
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

struct BingeQueueWidgetView: View {
    @Environment(\.widgetFamily) private var family
    var entry: BingeQueueEntry

    private var primary: Color {
        Color(red: 167 / 255, green: 139 / 255, blue: 250 / 255) // #A78BFA
    }

    private var content: Color {
        Color(red: 240 / 255, green: 232 / 255, blue: 250 / 255) // #F0E8FA
    }

    private var secondary: Color {
        Color(red: 182 / 255, green: 168 / 255, blue: 201 / 255) // #B6A8C9
    }

    var body: some View {
        switch family {
        case .systemSmall:
            smallLayout
        case .systemLarge:
            largeLayout
        default:
            mediumLayout
        }
    }

    private var smallLayout: some View {
        VStack(alignment: .leading, spacing: 6) {
            headerRow(title: "Watch list", showTotal: true)

            if entry.snapshot.watchItems.isEmpty {
                Text("No titles yet")
                    .font(.caption)
                    .foregroundStyle(secondary.opacity(0.85))
                Spacer(minLength: 0)
            } else {
                VStack(alignment: .leading, spacing: 5) {
                    ForEach(entry.snapshot.watchItems.prefix(4)) { item in
                        Text(item.title)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(content)
                            .lineLimit(1)
                    }
                }
                Spacer(minLength: 0)
                if entry.snapshot.watchItems.count > 4 {
                    Text("+\(entry.snapshot.watchItems.count - 4) more")
                        .font(.caption2)
                        .foregroundStyle(secondary)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .padding(4)
    }

    private var mediumLayout: some View {
        VStack(alignment: .leading, spacing: 8) {
            headerRow(title: "Watch list", showTotal: true)

            if entry.snapshot.watchItems.isEmpty {
                Text("Save titles in the app to see them here.")
                    .font(.caption)
                    .foregroundStyle(secondary)
                Spacer(minLength: 0)
            } else {
                ViewThatFits(in: .vertical) {
                    watchListRows(limit: 5, font: .subheadline.weight(.medium), spacing: 6)
                    watchListRows(limit: 4, font: .caption.weight(.medium), spacing: 5)
                }
                Spacer(minLength: 0)
            }
        }
        .padding(4)
    }

    private var largeLayout: some View {
        VStack(alignment: .leading, spacing: 10) {
            headerRow(title: "Watch list", showTotal: true)

            if entry.snapshot.watchItems.isEmpty {
                Text("Save titles in the app to see them here.")
                    .font(.subheadline)
                    .foregroundStyle(secondary)
                Spacer(minLength: 0)
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(entry.snapshot.watchItems.prefix(10)) { item in
                        HStack(spacing: 8) {
                            mediaTypeBadge(item.mediaType)
                            Text(item.title)
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(content)
                                .lineLimit(1)
                            Spacer(minLength: 0)
                        }
                    }
                }
                Spacer(minLength: 0)
                if entry.snapshot.watchItems.count > 10 {
                    Text("+\(entry.snapshot.watchItems.count - 10) more")
                        .font(.caption2)
                        .foregroundStyle(secondary)
                }
            }
        }
        .padding(4)
    }

    private func headerRow(title: String, showTotal: Bool) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(secondary)
            Spacer(minLength: 0)
            if showTotal {
                Text(entry.snapshot.monthlyTotal)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(primary)
                    .minimumScaleFactor(0.8)
                    .lineLimit(1)
            }
        }
    }

    private func watchListRows(limit: Int, font: Font, spacing: CGFloat) -> some View {
        let items = Array(entry.snapshot.watchItems.prefix(limit))
        return VStack(alignment: .leading, spacing: spacing) {
            ForEach(items) { item in
                HStack(spacing: 6) {
                    mediaTypeBadge(item.mediaType)
                    Text(item.title)
                        .font(font)
                        .foregroundStyle(content)
                        .lineLimit(1)
                    Spacer(minLength: 0)
                }
            }
            if entry.snapshot.watchItems.count > limit {
                Text("+\(entry.snapshot.watchItems.count - limit) more")
                    .font(.caption2)
                    .foregroundStyle(secondary)
            }
        }
    }

    private func mediaTypeBadge(_ mediaType: String) -> some View {
        Text(shortMediaType(mediaType))
            .font(.caption2.weight(.bold))
            .foregroundStyle(primary)
            .lineLimit(1)
            .frame(width: 28, alignment: .leading)
    }

    private func shortMediaType(_ mediaType: String) -> String {
        switch mediaType.lowercased() {
        case "movie":
            return "MOV"
        case "tv":
            return "TV"
        default:
            return String(mediaType.prefix(3)).uppercased()
        }
    }
}
