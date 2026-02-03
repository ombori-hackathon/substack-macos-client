import SwiftUI

struct SubscriptionsView: View {
    let accessToken: String

    @State private var subscriptions: [Subscription] = []
    @State private var totalsByCurrency: [CurrencyTotal] = []
    @State private var totalCount = 0
    @State private var currentOffset = 0
    @State private var isLoading = false
    @State private var isLoadingMore = false
    @State private var errorMessage: String?
    @State private var showingAddForm = false
    @State private var subscriptionToEdit: Subscription?
    @State private var subscriptionToDelete: Subscription?
    @State private var isOffline = false

    // Undo delete state
    @State private var recentlyDeleted: Subscription?
    @State private var undoTask: Task<Void, Never>?
    @State private var undoCountdown = 10
    @State private var isRestoring = false

    // Sorting and filtering
    @State private var sortBy: SortField = .nextBillingDate
    @State private var sortOrder: SortOrder = .asc
    @State private var categoryFilter: SubscriptionCategory?  // Deprecated
    @State private var categoryIdFilter: Int?
    @State private var categories: [Category] = []
    @State private var statusFilter: SubscriptionStatusFilter = .active
    @State private var showCategoryManagement = false

    // Search and advanced filtering
    @State private var searchText = ""
    @State private var billingCycleFilter: BillingCycle?
    @State private var costMin: Double?
    @State private var costMax: Double?
    @State private var searchDebounceTask: Task<Void, Never>?

    // Cancellation state
    @State private var subscriptionToCancel: Subscription?
    @State private var savingsSummary: SavingsSummaryResponse?

    private let baseURL = "http://localhost:8000"
    private let pageLimit = 50
    private let cacheKey = "cached_subscriptions"
    private let cacheTTLKey = "cached_subscriptions_ttl"
    private let cacheTTL: TimeInterval = 5 * 60 // 5 minutes

    private var hasActiveFilters: Bool {
        !searchText.isEmpty || billingCycleFilter != nil || costMin != nil || costMax != nil || categoryIdFilter != nil
    }

    var body: some View {
        VStack(spacing: 0) {
            toolbarRow1
            toolbarRow2
            totalsBanner
            Divider()
            mainContent
        }
        .task {
            await loadCategories()
            await loadSubscriptions(reset: true)
        }
        .onChange(of: sortBy) { _, _ in
            Task { await loadSubscriptions(reset: true) }
        }
        .onChange(of: sortOrder) { _, _ in
            Task { await loadSubscriptions(reset: true) }
        }
        .onChange(of: categoryIdFilter) { _, _ in
            Task { await loadSubscriptions(reset: true) }
        }
        .onChange(of: statusFilter) { _, _ in
            Task {
                await loadSubscriptions(reset: true)
                if statusFilter == .cancelled {
                    await loadSavingsSummary()
                }
            }
        }
        .onChange(of: billingCycleFilter) { _, _ in
            Task { await loadSubscriptions(reset: true) }
        }
        .onChange(of: costMin) { _, _ in
            Task { await loadSubscriptions(reset: true) }
        }
        .onChange(of: costMax) { _, _ in
            Task { await loadSubscriptions(reset: true) }
        }
        .sheet(isPresented: $showCategoryManagement) {
            CategoryManagementView(accessToken: accessToken)
                .onDisappear {
                    Task { await loadCategories() }
                }
        }
        .sheet(item: $subscriptionToCancel) { sub in
            CancellationFormView(
                accessToken: accessToken,
                subscription: sub,
                onCancelled: { _ in
                    Task {
                        await loadSubscriptions(reset: true)
                        await loadSavingsSummary()
                    }
                }
            )
        }
        .sheet(isPresented: $showingAddForm) {
            SubscriptionFormView(accessToken: accessToken) {
                Task { await loadSubscriptions(reset: true) }
            }
        }
        .sheet(item: $subscriptionToEdit) { sub in
            SubscriptionFormView(accessToken: accessToken, subscription: sub) {
                Task { await loadSubscriptions(reset: true) }
            }
        }
        .alert("Delete Subscription?", isPresented: Binding(
            get: { subscriptionToDelete != nil },
            set: { if !$0 { subscriptionToDelete = nil } }
        )) {
            Button("Cancel", role: .cancel) {
                subscriptionToDelete = nil
            }
            Button("Delete", role: .destructive) {
                if let sub = subscriptionToDelete {
                    Task { await deleteSubscription(sub) }
                }
            }
        } message: {
            if let sub = subscriptionToDelete {
                Text("Are you sure you want to delete \"\(sub.name)\"?")
            }
        }
        .overlay(alignment: .bottom) {
            if let deleted = recentlyDeleted {
                UndoToastView(
                    subscriptionName: deleted.name,
                    countdown: undoCountdown,
                    isRestoring: isRestoring,
                    onUndo: { Task { await restoreSubscription(deleted) } },
                    onDismiss: { dismissUndoToast() }
                )
                .padding(.bottom, 20)
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .animation(.easeInOut(duration: 0.3), value: recentlyDeleted?.id)
            }
        }
    }

    private func loadSubscriptions(reset: Bool) async {
        if reset {
            isLoading = true
            currentOffset = 0
        }
        errorMessage = nil
        isOffline = false

        do {
            var urlComponents = URLComponents(string: "\(baseURL)/subscriptions")!
            urlComponents.queryItems = [
                URLQueryItem(name: "sort_by", value: sortBy.rawValue),
                URLQueryItem(name: "order", value: sortOrder.rawValue),
                URLQueryItem(name: "limit", value: String(pageLimit)),
                URLQueryItem(name: "offset", value: String(currentOffset)),
                URLQueryItem(name: "status", value: statusFilter.rawValue)
            ]
            if let categoryId = categoryIdFilter {
                urlComponents.queryItems?.append(URLQueryItem(name: "category_id", value: String(categoryId)))
            }
            // Search filter
            if !searchText.isEmpty {
                urlComponents.queryItems?.append(URLQueryItem(name: "search", value: searchText))
            }
            // Billing cycle filter
            if let cycle = billingCycleFilter {
                urlComponents.queryItems?.append(URLQueryItem(name: "billing_cycle", value: cycle.rawValue))
            }
            // Cost range filters
            if let min = costMin {
                urlComponents.queryItems?.append(URLQueryItem(name: "cost_min", value: String(min)))
            }
            if let max = costMax {
                urlComponents.queryItems?.append(URLQueryItem(name: "cost_max", value: String(max)))
            }

            var request = URLRequest(url: urlComponents.url!)
            request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw SubscriptionError(message: "Invalid response")
            }

            switch httpResponse.statusCode {
            case 200:
                let listResponse = try JSONDecoder().decode(SubscriptionListResponse.self, from: data)
                if reset {
                    subscriptions = listResponse.items
                } else {
                    subscriptions.append(contentsOf: listResponse.items)
                }
                totalCount = listResponse.totalCount
                totalsByCurrency = listResponse.totalsByCurrency
                currentOffset = subscriptions.count

                // Cache the response
                saveToCache(data)
            case 401:
                errorMessage = "Session expired. Please sign in again."
            default:
                errorMessage = "Failed to load subscriptions"
            }
        } catch {
            // Try to load from cache on network error
            if let cached = loadFromCache() {
                isOffline = true
                subscriptions = cached.items
                totalCount = cached.totalCount
                totalsByCurrency = cached.totalsByCurrency
            } else {
                errorMessage = "Network error: \(error.localizedDescription)"
            }
        }

        isLoading = false
    }

    private func loadMore() async {
        isLoadingMore = true
        await loadSubscriptions(reset: false)
        isLoadingMore = false
    }

    // MARK: - Search Debounce

    private func triggerDebouncedSearch() {
        // Cancel previous debounce task
        searchDebounceTask?.cancel()

        // Start new debounce task with 300ms delay
        searchDebounceTask = Task {
            try? await Task.sleep(nanoseconds: 300_000_000)  // 300ms
            if !Task.isCancelled {
                await loadSubscriptions(reset: true)
            }
        }
    }

    private func clearAllFilters() {
        searchText = ""
        billingCycleFilter = nil
        costMin = nil
        costMax = nil
        categoryIdFilter = nil
        Task { await loadSubscriptions(reset: true) }
    }

    private func deleteSubscription(_ subscription: Subscription) async {
        subscriptionToDelete = nil

        do {
            let url = URL(string: "\(baseURL)/subscriptions/\(subscription.id)")!
            var request = URLRequest(url: url)
            request.httpMethod = "DELETE"
            request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

            let (_, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                return
            }

            switch httpResponse.statusCode {
            case 204:
                // Remove from local list immediately
                subscriptions.removeAll { $0.id == subscription.id }
                totalCount = max(0, totalCount - 1)

                // Show undo toast
                showUndoToast(for: subscription)
            case 404:
                errorMessage = "Subscription was already deleted"
                await loadSubscriptions(reset: true)
            default:
                errorMessage = "Failed to delete subscription"
            }
        } catch {
            errorMessage = "Network error while deleting"
        }
    }

    private func showUndoToast(for subscription: Subscription) {
        // Cancel any existing undo timer
        undoTask?.cancel()

        withAnimation {
            recentlyDeleted = subscription
            undoCountdown = 10
        }

        // Start countdown timer
        undoTask = Task {
            for remaining in (0...9).reversed() {
                try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
                if Task.isCancelled { return }
                await MainActor.run {
                    undoCountdown = remaining
                }
            }
            // Timer expired, dismiss toast
            if !Task.isCancelled {
                await MainActor.run {
                    dismissUndoToast()
                }
            }
        }
    }

    private func dismissUndoToast() {
        undoTask?.cancel()
        undoTask = nil
        withAnimation {
            recentlyDeleted = nil
            undoCountdown = 10
        }
    }

    private func restoreSubscription(_ subscription: Subscription) async {
        isRestoring = true

        do {
            let url = URL(string: "\(baseURL)/subscriptions/\(subscription.id)/restore")!
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                errorMessage = "Invalid response"
                isRestoring = false
                return
            }

            switch httpResponse.statusCode {
            case 200:
                // Parse restored subscription
                let restored = try JSONDecoder().decode(Subscription.self, from: data)
                // Add back to list at appropriate position
                subscriptions.append(restored)
                subscriptions.sort { lhs, rhs in
                    // Re-sort based on current sort settings
                    switch sortBy {
                    case .name:
                        return sortOrder == .asc ? lhs.name < rhs.name : lhs.name > rhs.name
                    case .cost:
                        return sortOrder == .asc ? lhs.cost < rhs.cost : lhs.cost > rhs.cost
                    case .nextBillingDate:
                        return sortOrder == .asc ? lhs.nextBillingDate < rhs.nextBillingDate : lhs.nextBillingDate > rhs.nextBillingDate
                    case .createdAt:
                        return sortOrder == .asc ? lhs.createdAt < rhs.createdAt : lhs.createdAt > rhs.createdAt
                    }
                }
                totalCount += 1
                dismissUndoToast()
            case 400:
                errorMessage = "Subscription is not deleted"
                dismissUndoToast()
            case 404:
                errorMessage = "Subscription not found"
                dismissUndoToast()
            default:
                errorMessage = "Failed to restore subscription"
            }
        } catch {
            errorMessage = "Network error while restoring"
        }

        isRestoring = false
    }

    // MARK: - Cancel/Reactivate

    private func reactivateSubscription(_ subscription: Subscription) async {
        do {
            let url = URL(string: "\(baseURL)/subscriptions/\(subscription.id)/reactivate")!
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                errorMessage = "Invalid response"
                return
            }

            switch httpResponse.statusCode {
            case 200:
                // Reload subscriptions to reflect the change
                await loadSubscriptions(reset: true)
                await loadSavingsSummary()
            case 400:
                let apiError = try? JSONDecoder().decode(APIError.self, from: data)
                errorMessage = apiError?.detail ?? "Subscription is not cancelled"
            case 404:
                errorMessage = "Subscription not found"
            default:
                errorMessage = "Failed to reactivate subscription"
            }
        } catch {
            errorMessage = "Network error while reactivating"
        }
    }

    private func loadSavingsSummary() async {
        do {
            let url = URL(string: "\(baseURL)/subscriptions/savings")!
            var request = URLRequest(url: url)
            request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                return
            }

            let summary = try JSONDecoder().decode(SavingsSummaryResponse.self, from: data)
            savingsSummary = summary
        } catch {
            // Silently fail - savings display is optional
        }
    }

    // MARK: - Caching

    private func saveToCache(_ data: Data) {
        UserDefaults.standard.set(data, forKey: cacheKey)
        UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: cacheTTLKey)
    }

    private func loadFromCache() -> SubscriptionListResponse? {
        guard let cachedTime = UserDefaults.standard.object(forKey: cacheTTLKey) as? TimeInterval else {
            return nil
        }

        let elapsed = Date().timeIntervalSince1970 - cachedTime
        if elapsed > cacheTTL {
            // Cache expired
            return nil
        }

        guard let data = UserDefaults.standard.data(forKey: cacheKey) else {
            return nil
        }

        return try? JSONDecoder().decode(SubscriptionListResponse.self, from: data)
    }

    private func loadCategories() async {
        do {
            let url = URL(string: "\(baseURL)/categories")!
            var request = URLRequest(url: url)
            request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                return
            }

            let categoryResponse = try JSONDecoder().decode(CategoryListResponse.self, from: data)

            await MainActor.run {
                categories = categoryResponse.items
            }
        } catch {
            // Silently fail - will use default categories or empty list
        }
    }

    // MARK: - Toolbar Views

    private var toolbarRow1: some View {
        HStack {
            Text("Subscriptions")
                .font(.headline)

            if isOffline {
                Label("Offline", systemImage: "wifi.slash")
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.orange.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            }

            Spacer()

            Picker("Status", selection: $statusFilter) {
                ForEach(SubscriptionStatusFilter.allCases, id: \.self) { status in
                    Text(status.displayName).tag(status)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 200)

            Button(action: { showingAddForm = true }) {
                Label("Add", systemImage: "plus")
            }
        }
        .padding(.horizontal)
        .padding(.top)
        .padding(.bottom, 8)
    }

    private var toolbarRow2: some View {
        HStack(spacing: 8) {
            searchField
            filterControls
            sortControls

            if hasActiveFilters {
                Button {
                    clearAllFilters()
                } label: {
                    Label("Clear", systemImage: "xmark.circle")
                }
                .buttonStyle(.bordered)
                .tint(.orange)
            }

            Spacer()

            Button {
                showCategoryManagement = true
            } label: {
                Image(systemName: "folder.badge.gearshape")
            }
            .help("Manage Categories")
        }
        .padding(.horizontal)
        .padding(.bottom, 8)
    }

    private var searchField: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField("Search subscriptions...", text: $searchText)
                .textFieldStyle(.plain)
                .onChange(of: searchText) { _, _ in
                    triggerDebouncedSearch()
                }
            if !searchText.isEmpty {
                Button {
                    searchText = ""
                    Task { await loadSubscriptions(reset: true) }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(6)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .frame(maxWidth: 200)
    }

    private var filterControls: some View {
        HStack(spacing: 8) {
            Picker("Cycle", selection: $billingCycleFilter) {
                Text("All Cycles").tag(nil as BillingCycle?)
                ForEach(BillingCycle.allCases, id: \.self) { cycle in
                    Text(cycle.displayName).tag(cycle as BillingCycle?)
                }
            }
            .pickerStyle(.menu)
            .frame(width: 110)

            Picker("Category", selection: $categoryIdFilter) {
                Text("All Categories").tag(nil as Int?)
                ForEach(categories) { cat in
                    HStack {
                        Image(systemName: cat.icon)
                            .foregroundStyle(cat.swiftUIColor)
                        Text(cat.name)
                    }.tag(cat.id as Int?)
                }
            }
            .pickerStyle(.menu)
            .frame(width: 130)

            CostRangeFilterView(costMin: $costMin, costMax: $costMax)
        }
    }

    private var sortControls: some View {
        HStack(spacing: 8) {
            Divider()
                .frame(height: 20)

            Picker("Sort", selection: $sortBy) {
                ForEach(SortField.allCases, id: \.self) { field in
                    Text(field.displayName).tag(field)
                }
            }
            .pickerStyle(.menu)
            .frame(width: 110)

            Button {
                sortOrder = sortOrder == .asc ? .desc : .asc
            } label: {
                Image(systemName: sortOrder == .asc ? "arrow.up" : "arrow.down")
            }
            .help(sortOrder == .asc ? "Ascending" : "Descending")
        }
    }

    @ViewBuilder
    private var totalsBanner: some View {
        if statusFilter == .cancelled, let savings = savingsSummary, savings.cancelledCount > 0 {
            savingsBannerView(savings: savings)
        } else if !totalsByCurrency.isEmpty && statusFilter != .cancelled {
            totalsBannerView
        }
    }

    private func savingsBannerView(savings: SavingsSummaryResponse) -> some View {
        HStack {
            Image(systemName: "leaf.fill")
                .foregroundStyle(.green)
            Text("Savings from \(savings.cancelledCount) cancelled subscription\(savings.cancelledCount == 1 ? "" : "s"):")
                .foregroundStyle(.secondary)
            ForEach(savings.savingsByCurrency, id: \.currency) { saving in
                VStack(alignment: .leading, spacing: 2) {
                    Text(saving.formattedMonthlyAmount)
                        .fontWeight(.medium)
                    if saving.totalSaved > 0 {
                        Text("(\(saving.formattedTotalSaved) saved)")
                            .font(.caption)
                            .foregroundStyle(.green)
                    }
                }
            }
            Spacer()
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color.green.opacity(0.05))
    }

    private var totalsBannerView: some View {
        HStack {
            Text("Monthly totals:")
                .foregroundStyle(.secondary)
            ForEach(totalsByCurrency, id: \.currency) { total in
                Text(total.formattedMonthlyEquivalent)
                    .fontWeight(.medium)
            }
            Spacer()
        }
        .padding(.horizontal)
        .padding(.bottom, 8)
    }

    @ViewBuilder
    private var mainContent: some View {
        if let error = errorMessage, !isOffline {
            errorView(error: error)
        } else if isLoading && subscriptions.isEmpty {
            loadingView
        } else if subscriptions.isEmpty {
            emptyStateView
        } else {
            subscriptionListView
        }
    }

    private func errorView(error: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.largeTitle)
                .foregroundStyle(.orange)
            Text(error)
                .foregroundStyle(.secondary)
            Button("Retry") {
                Task { await loadSubscriptions(reset: true) }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var loadingView: some View {
        ProgressView("Loading subscriptions...")
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyStateView: some View {
        VStack(spacing: 12) {
            if hasActiveFilters {
                Image(systemName: "magnifyingglass")
                    .font(.largeTitle)
                    .foregroundStyle(.secondary)
                Text("No subscriptions match your filters")
                    .foregroundStyle(.secondary)
                Button("Clear Filters") {
                    clearAllFilters()
                }
                .buttonStyle(.borderedProminent)
            } else {
                Image(systemName: "creditcard")
                    .font(.largeTitle)
                    .foregroundStyle(.secondary)
                Text("No subscriptions yet")
                    .foregroundStyle(.secondary)
                Button("Add Subscription") {
                    showingAddForm = true
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var subscriptionListView: some View {
        VStack(spacing: 0) {
            SubscriptionsTable(
                subscriptions: subscriptions,
                categories: categories,
                onEdit: { sub in subscriptionToEdit = sub },
                onDelete: { sub in subscriptionToDelete = sub },
                onCancel: { sub in subscriptionToCancel = sub },
                onReactivate: { sub in Task { await reactivateSubscription(sub) } }
            )

            if subscriptions.count < totalCount {
                paginationFooter
            }
        }
    }

    private var paginationFooter: some View {
        HStack {
            Text("Showing \(subscriptions.count) of \(totalCount)")
                .foregroundStyle(.secondary)
            Spacer()
            if isLoadingMore {
                ProgressView()
                    .scaleEffect(0.7)
            } else {
                Button("Load More") {
                    Task { await loadMore() }
                }
            }
        }
        .padding()
        .background(Color(nsColor: .controlBackgroundColor))
    }
}

// MARK: - Undo Toast View

struct UndoToastView: View {
    let subscriptionName: String
    let countdown: Int
    let isRestoring: Bool
    let onUndo: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "trash")
                .foregroundStyle(.secondary)

            Text("\"\(subscriptionName)\" deleted")
                .lineLimit(1)

            Spacer()

            if isRestoring {
                ProgressView()
                    .scaleEffect(0.7)
                    .frame(width: 60)
            } else {
                Button(action: onUndo) {
                    HStack(spacing: 4) {
                        Text("Undo")
                        Text("(\(countdown)s)")
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                }
                .buttonStyle(.bordered)
            }

            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(nsColor: .controlBackgroundColor))
                .shadow(color: .black.opacity(0.15), radius: 8, y: 4)
        }
        .frame(maxWidth: 400)
    }
}
