import SwiftUI

struct SubscriptionsView: View {
    @EnvironmentObject private var auth: AuthSession
    @StateObject private var viewModel = SubscriptionsViewModel()
    @State private var showAddSheet = false
    @State private var editing: Subscription?

    var body: some View {
        NavigationStack {
            ZStack {
                BrandBackground()

                Group {
                    if viewModel.isLoading && viewModel.subscriptions.isEmpty {
                        ProgressView()
                            .tint(Brand.primary)
                    } else if viewModel.subscriptions.isEmpty {
                        ContentUnavailableView(
                            "No subscriptions",
                            systemImage: "creditcard",
                            description: Text("Add the streaming services you pay for.")
                        )
                    } else {
                        List {
                            Section {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("Monthly stack")
                                        .font(.subheadline.weight(.medium))
                                        .foregroundStyle(Brand.secondary)
                                        .textCase(nil)

                                    Text(viewModel.formattedMonthlyTotal)
                                        .font(.system(size: 36, weight: .bold, design: .rounded))
                                        .foregroundStyle(Brand.primary)
                                        .monospacedDigit()

                                    Text("\(viewModel.subscriptions.count) service\(viewModel.subscriptions.count == 1 ? "" : "s")")
                                        .font(.footnote)
                                        .foregroundStyle(Brand.secondary)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.vertical, 8)
                                .listRowBackground(Brand.surface)
                                .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16))
                            }

                            Section {
                                ForEach(viewModel.subscriptions) { subscription in
                                    SubscriptionRow(subscription: subscription)
                                        .listRowBackground(Brand.surface)
                                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                            Button(role: .destructive) {
                                                Task { await viewModel.delete(subscription) }
                                            } label: {
                                                Label("Delete", systemImage: "trash")
                                            }
                                            Button {
                                                editing = subscription
                                            } label: {
                                                Label("Edit", systemImage: "pencil")
                                            }
                                            .tint(Brand.secondary)
                                        }
                                        .onTapGesture {
                                            editing = subscription
                                        }
                                }
                            } header: {
                                Text("Your services")
                            }
                        }
                        .scrollContentBackground(.hidden)
                    }
                }
            }
            .navigationTitle("Subscriptions")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    BrandNavTitle()
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showAddSheet = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
                ToolbarItem(placement: .topBarLeading) {
                    ProfileMenu()
                }
            }
            .task {
                await viewModel.load(isLocal: auth.isGuest)
            }
            .refreshable {
                await viewModel.load(isLocal: auth.isGuest)
            }
            .sheet(isPresented: $showAddSheet) {
                AddSubscriptionSheet(viewModel: viewModel)
            }
            .sheet(item: $editing) { subscription in
                EditSubscriptionSheet(viewModel: viewModel, subscription: subscription)
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
}

struct SubscriptionRow: View {
    let subscription: Subscription

    var body: some View {
        HStack(spacing: 12) {
            ProviderLogo(path: subscription.streamingProvider?.logoUrl)
                .frame(width: 40, height: 40)

            VStack(alignment: .leading, spacing: 2) {
                Text(subscription.streamingProvider?.displayName ?? "Unknown")
                    .font(.headline)
                    .foregroundStyle(Brand.baseContent)
            }

            Spacer()

            Text(formattedCost)
                .font(.body.monospacedDigit().weight(.medium))
                .foregroundStyle(Brand.baseContent)
        }
        .padding(.vertical, 4)
    }

    private var formattedCost: String {
        guard let cost = subscription.cost, let value = Decimal(string: cost) else {
            return "—"
        }
        return SubscriptionsViewModel.currencyFormatter.string(from: value as NSDecimalNumber) ?? cost
    }
}

struct ProviderLogo: View {
    let path: String?

    var body: some View {
        Group {
            if let url = AppConfig.tmdbImageURL(path: path, size: .logo) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().scaledToFit()
                    default:
                        placeholder
                    }
                }
            } else {
                placeholder
            }
        }
        .background(Brand.base200)
        .clipShape(RoundedRectangle(cornerRadius: Brand.buttonCornerRadius))
    }

    private var placeholder: some View {
        Image(systemName: "tv")
            .foregroundStyle(Brand.secondary)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct ProfileMenu: View {
    @EnvironmentObject private var auth: AuthSession

    var body: some View {
        Menu {
            if auth.isGuest {
                Text("On this iPhone only")
                Text("Separate from any signed-in account")
                Button("Sign in with Google") {
                    Task { await auth.signInWithGoogle() }
                }
                Divider()
                Button("Leave local mode", role: .destructive) {
                    auth.signOut()
                }
            } else {
                if let name = auth.user?.name {
                    Text(name)
                }
                if let email = auth.user?.email {
                    Text(email)
                }
                Text("Synced with your account")
                Divider()
                Button("Sign Out", role: .destructive) {
                    auth.signOut()
                }
            }
        } label: {
            if auth.isGuest {
                Image(systemName: "iphone")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Brand.primary)
                    .frame(width: 28, height: 28)
            } else {
                ProfileAvatar(urlString: auth.user?.image, name: auth.user?.name)
            }
        }
    }
}
