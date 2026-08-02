import SwiftUI
import UIKit

struct WatchView: View {
    @EnvironmentObject private var auth: AuthSession
    @ObservedObject var viewModel: WatchViewModel
    @FocusState private var isSearchFocused: Bool

    var body: some View {
        NavigationStack {
            ZStack {
                BrandBackground()

                VStack(spacing: 0) {
                    searchBar
                    filterBar
                    if viewModel.searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        providerBrowser
                    }
                    resultsGrid
                }
            }
            .navigationTitle("Search")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    BrandNavTitle()
                }
                ToolbarItem(placement: .topBarLeading) {
                    ProfileMenu()
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") {
                        dismissSearchKeyboard()
                    }
                }
            }
            .onChange(of: viewModel.selectedResult) { _, result in
                if result != nil {
                    dismissSearchKeyboard()
                }
            }
            .onDisappear {
                dismissSearchKeyboard()
            }
            .sheet(item: $viewModel.selectedResult) { result in
                TitleDetailSheet(viewModel: viewModel, result: result)
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

    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(Brand.secondary)
            TextField("Search movies & TV", text: $viewModel.searchQuery)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .focused($isSearchFocused)
                .submitLabel(.search)
                .onSubmit {
                    dismissSearchKeyboard()
                }
                .onChange(of: viewModel.searchQuery) { _, _ in
                    viewModel.scheduleSearch()
                }
            if !viewModel.searchQuery.isEmpty {
                Button {
                    viewModel.searchQuery = ""
                    viewModel.searchResults = []
                    dismissSearchKeyboard()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(Brand.secondary)
                }
            }
        }
        .padding(12)
        .background(Brand.surface)
        .padding(.horizontal)
        .padding(.top, 8)
    }

    private var filterBar: some View {
        Picker("Media", selection: $viewModel.mediaFilter) {
            ForEach(MediaTypeFilter.allCases) { filter in
                Text(filter.label).tag(filter)
            }
        }
        .pickerStyle(.segmented)
        .padding(.horizontal)
        .padding(.vertical, 8)
        .onChange(of: viewModel.mediaFilter) { _, _ in
            if viewModel.searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                if let providerId = viewModel.selectedProviderId {
                    Task { await viewModel.discover(providerId: providerId) }
                }
            } else {
                viewModel.scheduleSearch()
            }
        }
    }

    private var providerBrowser: some View {
        Group {
            if viewModel.subscribedProviders.isEmpty {
                Text("Add subscriptions to browse titles by service.")
                    .font(.footnote)
                    .foregroundStyle(Brand.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(viewModel.subscribedProviders) { provider in
                            Button {
                                dismissSearchKeyboard()
                                Task { await viewModel.discover(providerId: provider.providerId) }
                            } label: {
                                HStack(spacing: 6) {
                                    ProviderLogo(path: provider.logoUrl)
                                        .frame(width: 22, height: 22)
                                    Text(provider.displayName)
                                        .font(.caption.weight(.medium))
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 8)
                                .background(
                                    viewModel.selectedProviderId == provider.providerId
                                        ? Brand.primary.opacity(0.15)
                                        : Brand.surface
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: Brand.buttonCornerRadius)
                                        .stroke(
                                            viewModel.selectedProviderId == provider.providerId
                                                ? Brand.primary
                                                : Brand.base300,
                                            lineWidth: 1
                                        )
                                )
                                .foregroundStyle(Brand.baseContent)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
        .padding(.bottom, 8)
    }

    private var resultsGrid: some View {
        let results = viewModel.searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? viewModel.discoverResults
            : viewModel.searchResults

        return Group {
            if viewModel.isSearching && results.isEmpty {
                Spacer()
                ProgressView().tint(Brand.primary)
                Spacer()
            } else if results.isEmpty {
                ContentUnavailableView(
                    "No titles",
                    systemImage: "film",
                    description: Text(
                        viewModel.searchQuery.isEmpty
                            ? "Browse by subscription or search for a title."
                            : "Try a different search."
                    )
                )
            } else {
                ScrollView {
                    LazyVGrid(
                        columns: [GridItem(.adaptive(minimum: 110), spacing: 12)],
                        spacing: 12
                    ) {
                        ForEach(results) { result in
                            PosterCard(
                                result: result,
                                isOnWatchList: viewModel.isOnWatchList(result)
                            ) {
                                dismissSearchKeyboard()
                                Task { await viewModel.openDetail(result) }
                            } onToggleWatchList: {
                                Task {
                                    if viewModel.isOnWatchList(result) {
                                        await viewModel.removeFromWatchList(
                                            mediaId: result.mediaId,
                                            mediaType: result.mediaType
                                        )
                                    } else {
                                        await viewModel.addToWatchList(result)
                                    }
                                }
                            }
                        }
                    }
                    .padding()

                    TmdbAttributionView()
                        .padding(.horizontal)
                        .padding(.bottom, 24)
                }
                .scrollDismissesKeyboard(.interactively)
            }
        }
    }

    private func dismissSearchKeyboard() {
        isSearchFocused = false
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder),
            to: nil,
            from: nil,
            for: nil
        )
    }
}

struct PosterCard: View {
    let result: SearchResult
    let isOnWatchList: Bool
    let onTap: () -> Void
    let onToggleWatchList: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ZStack(alignment: .topTrailing) {
                Button(action: onTap) {
                    poster
                }
                .buttonStyle(.plain)

                Button(action: onToggleWatchList) {
                    Image(systemName: isOnWatchList ? "bookmark.fill" : "bookmark")
                        .font(.caption.weight(.bold))
                        .padding(6)
                        .background(.ultraThinMaterial)
                        .clipShape(Circle())
                }
                .padding(6)
            }

            Text(result.displayTitle)
                .font(.caption)
                .foregroundStyle(Brand.baseContent)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
                // Reserve two lines so the grid doesn’t stagger when titles wrap.
                .frame(maxWidth: .infinity, minHeight: 34, alignment: .topLeading)
        }
    }

    private var poster: some View {
        Group {
            if let url = AppConfig.tmdbImageURL(path: result.posterPath, size: .poster) {
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
        .frame(height: 160)
        .frame(maxWidth: .infinity)
        .clipped()
        .background(Brand.base200)
    }
}
