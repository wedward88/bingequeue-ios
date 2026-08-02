import SwiftUI

struct WatchListTabView: View {
    @EnvironmentObject private var auth: AuthSession
    @ObservedObject var viewModel: WatchViewModel
    @State private var itemPendingDeletion: WatchListItem?
    @State private var editMode: EditMode = .inactive

    private var isEditing: Bool {
        editMode.isEditing
    }

    var body: some View {
        NavigationStack {
            ZStack {
                BrandBackground()

                if viewModel.isLoadingWatchList && viewModel.watchList.isEmpty {
                    ProgressView()
                        .tint(Brand.primary)
                } else if viewModel.watchList.isEmpty {
                    ContentUnavailableView(
                        "Watch list empty",
                        systemImage: "list.bullet",
                        description: Text("Save titles from Search to build your list.")
                    )
                } else {
                    List {
                        Section {
                            ForEach(viewModel.watchList) { item in
                                Button {
                                    guard !isEditing else { return }
                                    Task { await viewModel.openDetail(item) }
                                } label: {
                                    WatchListRow(item: item)
                                }
                                .buttonStyle(.plain)
                                .listRowBackground(Brand.surface)
                                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                    Button(role: .destructive) {
                                        itemPendingDeletion = item
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                            }
                            .onMove(perform: isEditing ? reorder : nil)
                            .moveDisabled(!isEditing)
                        } header: {
                            Text("\(viewModel.watchList.count) saved")
                        }
                    }
                    .scrollContentBackground(.hidden)
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("Watch List")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    BrandNavTitle()
                }
                ToolbarItem(placement: .topBarLeading) {
                    ProfileMenu()
                }
                ToolbarItem(placement: .topBarTrailing) {
                    if !viewModel.watchList.isEmpty {
                        Button(isEditing ? "Done" : "Reorder") {
                            withAnimation {
                                editMode = isEditing ? .inactive : .active
                            }
                        }
                    }
                }
            }
            .environment(\.editMode, $editMode)
            .sheet(item: $viewModel.selectedResult) { result in
                TitleDetailSheet(viewModel: viewModel, result: result)
            }
            .refreshable {
                await viewModel.load(isLocal: auth.isGuest)
            }
            .alert(
                "Remove from Watch List?",
                isPresented: Binding(
                    get: { itemPendingDeletion != nil },
                    set: { if !$0 { itemPendingDeletion = nil } }
                ),
                presenting: itemPendingDeletion
            ) { item in
                Button("Cancel", role: .cancel) {
                    itemPendingDeletion = nil
                }
                Button("Delete", role: .destructive) {
                    Task {
                        await viewModel.removeWatchListItem(item)
                        itemPendingDeletion = nil
                    }
                }
            } message: { item in
                Text("“\(item.displayTitle)” will be removed from your watch list.")
            }
            .alert(
                "Error",
                isPresented: Binding(
                    get: {
                        !(viewModel.errorMessage?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
                    },
                    set: { if !$0 { viewModel.errorMessage = nil } }
                )
            ) {
                Button("OK", role: .cancel) { viewModel.errorMessage = nil }
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
        }
    }

    private func reorder(from source: IndexSet, to destination: Int) {
        Task {
            await viewModel.reorderWatchList(from: source, to: destination)
        }
    }
}

struct WatchListRow: View {
    let item: WatchListItem

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Group {
                if let url = AppConfig.tmdbImageURL(path: item.posterPath, size: .poster) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image.resizable().scaledToFill()
                        default:
                            Color(Brand.base300)
                        }
                    }
                } else {
                    Color(Brand.base300)
                }
            }
            .frame(width: 48, height: 72)
            .clipped()

            VStack(alignment: .leading, spacing: 6) {
                Text(item.displayTitle)
                    .font(.headline)
                    .foregroundStyle(Brand.baseContent)

                Text(item.mediaType.uppercased())
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(Brand.secondary)

                if !item.streamingProviders.isEmpty {
                    // Plain HStack (not a ScrollView) so row swipe-to-delete
                    // doesn’t scroll the logos sideways.
                    HStack(spacing: 6) {
                        ForEach(item.streamingProviders.prefix(6)) { provider in
                            ProviderLogo(path: provider.logoUrl)
                                .frame(width: 22, height: 22)
                        }
                        if item.streamingProviders.count > 6 {
                            Text("+\(item.streamingProviders.count - 6)")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(Brand.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .clipped()
                } else {
                    Text("Not on your plans")
                        .font(.caption)
                        .foregroundStyle(Brand.warning)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 4)
    }
}

struct TitleDetailSheet: View {
    @ObservedObject var viewModel: WatchViewModel
    let result: SearchResult
    @Environment(\.dismiss) private var dismiss

    private var onList: Bool {
        viewModel.isOnWatchList(result)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    poster

                    Text(result.displayTitle)
                        .font(.title2.weight(.bold))
                        .foregroundStyle(Brand.baseContent)

                    Text(result.mediaType.uppercased())
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Brand.secondary)

                    if let overview = result.overview, !overview.isEmpty {
                        Text(overview)
                            .font(.body)
                            .foregroundStyle(Brand.secondary)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Where to watch")
                            .font(.headline)
                            .foregroundStyle(Brand.baseContent)

                        if viewModel.isLoadingDetail {
                            ProgressView()
                        } else if viewModel.titleProviders.isEmpty {
                            Text("No US providers found.")
                                .foregroundStyle(Brand.secondary)
                        } else {
                            ForEach(viewModel.titleProviders) { provider in
                                HStack(spacing: 10) {
                                    ProviderLogo(path: provider.logoPath)
                                        .frame(width: 28, height: 28)
                                    Text(provider.providerName)
                                        .foregroundStyle(Brand.baseContent)
                                }
                            }
                        }
                    }

                    Button {
                        Task {
                            if onList {
                                await viewModel.removeFromWatchList(
                                    mediaId: result.mediaId,
                                    mediaType: result.mediaType
                                )
                            } else {
                                await viewModel.addToWatchList(result)
                            }
                        }
                    } label: {
                        Text(onList ? "Remove from Watch List" : "Add to Watch List")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(onList ? Brand.secondary : Brand.primary)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: Brand.buttonCornerRadius))
                    }
                    .buttonStyle(.plain)

                    TmdbAttributionView()
                }
                .padding()
            }
            .background(BrandBackground())
            .navigationTitle("Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }

    private var poster: some View {
        Group {
            if let url = AppConfig.tmdbImageURL(path: result.posterPath, size: .poster) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().scaledToFit()
                    default:
                        Color(Brand.base300).frame(height: 280)
                    }
                }
            } else {
                Color(Brand.base300).frame(height: 280)
            }
        }
        .frame(maxWidth: .infinity)
        .background(Brand.base200)
    }
}

struct TmdbAttributionView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("CREDITS")
                .font(.caption2.weight(.semibold))
                .tracking(1.4)
                .foregroundStyle(Brand.secondary)

            HStack(alignment: .top, spacing: 12) {
                // SVG isn't natively rendered; show text mark + notice.
                Text("TMDB")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Brand.primary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .overlay(
                        RoundedRectangle(cornerRadius: 2)
                            .stroke(Brand.primary, lineWidth: 1)
                    )

                Text("This product uses the TMDB API but is not endorsed or certified by TMDB.")
                    .font(.caption)
                    .foregroundStyle(Brand.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 8)
    }
}
