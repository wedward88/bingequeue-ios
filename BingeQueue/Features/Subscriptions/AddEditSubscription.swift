import SwiftUI

struct AddSubscriptionSheet: View {
    @ObservedObject var viewModel: SubscriptionsViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var selected: StreamingProvider?
    @State private var cost = ""
    @State private var query = ""
    @State private var searchTask: Task<Void, Never>?

    var body: some View {
        NavigationStack {
            Form {
                Section("Popular services") {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 96), spacing: 8)], spacing: 8) {
                        ForEach(viewModel.commonProviders) { provider in
                            providerChip(provider)
                        }
                    }
                    .padding(.vertical, 4)
                }

                Section("Search all providers") {
                    TextField("Search providers", text: $query)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .onChange(of: query) { _, newValue in
                            searchTask?.cancel()
                            searchTask = Task {
                                try? await Task.sleep(nanoseconds: 300_000_000)
                                guard !Task.isCancelled else { return }
                                await viewModel.searchProviders(query: newValue)
                            }
                        }

                    ForEach(viewModel.searchProviders) { provider in
                        Button {
                            select(provider)
                        } label: {
                            HStack {
                                ProviderLogo(path: provider.logoUrl)
                                    .frame(width: 28, height: 28)
                                Text(provider.name)
                                    .foregroundStyle(Brand.baseContent)
                                Spacer()
                                if selected?.id == provider.id {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(Brand.primary)
                                }
                            }
                        }
                        .disabled(viewModel.isSubscribed(to: provider))
                    }
                }

                if selected != nil {
                    Section("Monthly cost") {
                        TextField("0.00", text: $cost)
                            .keyboardType(.decimalPad)
                    }
                }
            }
            .navigationTitle("Add subscription")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task {
                            guard let selected else { return }
                            if await viewModel.add(provider: selected, cost: cost) {
                                dismiss()
                            }
                        }
                    }
                    .disabled(selected == nil || viewModel.isSaving)
                }
            }
        }
    }

    @ViewBuilder
    private func providerChip(_ provider: StreamingProvider) -> some View {
        let subscribed = viewModel.isSubscribed(to: provider)
        let isSelected = selected?.id == provider.id

        Button {
            guard !subscribed else { return }
            select(provider)
        } label: {
            VStack(spacing: 6) {
                ProviderLogo(path: provider.logoUrl)
                    .frame(width: 36, height: 36)
                Text(provider.displayName)
                    .font(.caption2)
                    .lineLimit(1)
                    .foregroundStyle(Brand.baseContent)
            }
            .frame(maxWidth: .infinity)
            .padding(8)
            .background(isSelected ? Brand.primary.opacity(0.15) : Brand.surface)
            .overlay(
                RoundedRectangle(cornerRadius: Brand.buttonCornerRadius)
                    .stroke(isSelected ? Brand.primary : Brand.base300, lineWidth: 1)
            )
            .opacity(subscribed ? 0.4 : 1)
        }
        .buttonStyle(.plain)
        .disabled(subscribed)
    }

    private func select(_ provider: StreamingProvider) {
        selected = provider
        if cost.isEmpty {
            cost = provider.suggestedCost
        }
    }
}

struct EditSubscriptionSheet: View {
    @ObservedObject var viewModel: SubscriptionsViewModel
    let subscription: Subscription
    @Environment(\.dismiss) private var dismiss
    @State private var cost = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack(spacing: 12) {
                        ProviderLogo(path: subscription.streamingProvider?.logoUrl)
                            .frame(width: 40, height: 40)
                        Text(subscription.streamingProvider?.displayName ?? "Subscription")
                            .font(.headline)
                    }
                }

                Section("Monthly cost") {
                    TextField("0.00", text: $cost)
                        .keyboardType(.decimalPad)
                }
            }
            .navigationTitle("Edit subscription")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task {
                            if await viewModel.update(subscription, cost: cost) {
                                dismiss()
                            }
                        }
                    }
                    .disabled(viewModel.isSaving)
                }
            }
            .onAppear {
                cost = subscription.cost ?? ""
            }
        }
    }
}
