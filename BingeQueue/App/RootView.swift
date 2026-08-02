import SwiftUI

struct RootView: View {
    @EnvironmentObject private var auth: AuthSession

    var body: some View {
        Group {
            if auth.isRestoring {
                ZStack {
                    BrandBackground()
                    ProgressView()
                        .tint(Brand.primary)
                }
            } else if auth.isActive {
                // Recreate tabs when switching guest ↔ account so local and cloud
                // libraries never share in-memory state.
                MainTabView()
                    .id(auth.mode)
            } else {
                SignInView()
            }
        }
    }
}

struct MainTabView: View {
    @EnvironmentObject private var auth: AuthSession
    @StateObject private var watchViewModel = WatchViewModel()

    var body: some View {
        TabView {
            SubscriptionsView()
                .tabItem {
                    Label("Subscriptions", systemImage: "creditcard")
                }

            WatchView(viewModel: watchViewModel)
                .tabItem {
                    Label("Search", systemImage: "magnifyingglass")
                }
                // Reload when returning from Subscriptions so new local plans appear.
                .onAppear {
                    Task { await watchViewModel.load(isLocal: auth.isGuest) }
                }

            WatchListTabView(viewModel: watchViewModel)
                .tabItem {
                    Label("Watch List", systemImage: "list.bullet")
                }
                .badge(watchViewModel.watchList.isEmpty ? 0 : watchViewModel.watchList.count)
        }
        .tint(Brand.primary)
        .task {
            await watchViewModel.load(isLocal: auth.isGuest)
        }
    }
}

struct ProfileAvatar: View {
    let urlString: String?
    let name: String?

    var body: some View {
        Group {
            if let urlString, let url = URL(string: urlString) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().scaledToFill()
                    default:
                        placeholder
                    }
                }
            } else {
                placeholder
            }
        }
        .frame(width: 28, height: 28)
        .clipShape(Circle())
    }

    private var placeholder: some View {
        ZStack {
            Circle().fill(Brand.base300)
            Text(initials)
                .font(.caption.weight(.semibold))
                .foregroundStyle(Brand.baseContent)
        }
    }

    private var initials: String {
        let parts = (name ?? "?").split(separator: " ")
        let letters = parts.prefix(2).compactMap(\.first)
        return letters.isEmpty ? "?" : String(letters)
    }
}
