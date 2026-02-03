import SwiftUI

struct SubscriptionFormView: View {
    @Environment(\.dismiss) private var dismiss

    let accessToken: String
    let subscription: Subscription?
    let onSave: () -> Void

    @State private var name = ""
    @State private var cost = ""
    @State private var currency: Currency = .USD
    @State private var billingCycle: BillingCycle = .monthly
    @State private var nextBillingDate = Date()
    @State private var category: SubscriptionCategory?  // Deprecated: for backwards compatibility
    @State private var categoryId: Int?
    @State private var categories: [Category] = []
    @State private var reminderDaysBefore = 3
    @State private var isLoading = false
    @State private var errorMessage: String?

    // Original values for change detection
    @State private var originalName = ""
    @State private var originalCost = ""
    @State private var originalCurrency: Currency = .USD
    @State private var originalBillingCycle: BillingCycle = .monthly
    @State private var originalNextBillingDate = Date()
    @State private var originalCategory: SubscriptionCategory?
    @State private var originalCategoryId: Int?
    @State private var originalReminderDaysBefore = 3

    private let baseURL = "http://localhost:8000"

    init(accessToken: String, subscription: Subscription? = nil, onSave: @escaping () -> Void) {
        self.accessToken = accessToken
        self.subscription = subscription
        self.onSave = onSave
    }

    /// Check if any field has changed from original values
    private var hasChanges: Bool {
        guard subscription != nil else { return true } // New subscription always has "changes"
        return name != originalName ||
               cost != originalCost ||
               currency != originalCurrency ||
               billingCycle != originalBillingCycle ||
               !Calendar.current.isDate(nextBillingDate, inSameDayAs: originalNextBillingDate) ||
               categoryId != originalCategoryId ||
               reminderDaysBefore != originalReminderDaysBefore
    }

    /// Check if billing date changed (for reminder rescheduling note)
    private var billingDateChanged: Bool {
        guard subscription != nil else { return false }
        return !Calendar.current.isDate(nextBillingDate, inSameDayAs: originalNextBillingDate)
    }

    var body: some View {
        VStack(spacing: 20) {
            Text(subscription == nil ? "Add Subscription" : "Edit Subscription")
                .font(.title.bold())

            VStack(alignment: .leading, spacing: 16) {
                // Name field
                VStack(alignment: .leading, spacing: 4) {
                    Text("Name")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    TextField("Netflix, Spotify, etc.", text: $name)
                        .textFieldStyle(.roundedBorder)
                }

                // Cost and Currency
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Cost")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        TextField("9.99", text: $cost)
                            .textFieldStyle(.roundedBorder)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Currency")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Picker("", selection: $currency) {
                            ForEach(Currency.allCases, id: \.self) { curr in
                                Text(curr.rawValue).tag(curr)
                            }
                        }
                        .labelsHidden()
                    }
                }

                // Billing Cycle
                VStack(alignment: .leading, spacing: 4) {
                    Text("Billing Cycle")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Picker("", selection: $billingCycle) {
                        ForEach(BillingCycle.allCases, id: \.self) { cycle in
                            Text(cycle.displayName).tag(cycle)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                // Next Billing Date
                VStack(alignment: .leading, spacing: 4) {
                    Text("Next Billing Date")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    DatePicker("", selection: $nextBillingDate, in: Date()..., displayedComponents: .date)
                        .labelsHidden()
                }

                // Category
                VStack(alignment: .leading, spacing: 4) {
                    Text("Category (optional)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    CategoryPickerView(
                        selectedCategoryId: $categoryId,
                        categories: categories,
                        accessToken: accessToken
                    )
                }

                // Reminder
                VStack(alignment: .leading, spacing: 4) {
                    Text("Remind me \(reminderDaysBefore) day(s) before")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Slider(value: Binding(
                        get: { Double(reminderDaysBefore) },
                        set: { reminderDaysBefore = Int($0) }
                    ), in: 0...30, step: 1)
                }

                // Reminder rescheduling note when billing date changes
                if billingDateChanged {
                    HStack(spacing: 6) {
                        Image(systemName: "info.circle.fill")
                            .foregroundStyle(.blue)
                        Text("Reminder will be rescheduled based on new billing date")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }
            }

            if let error = errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
            }

            HStack(spacing: 12) {
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Button(action: save) {
                    if isLoading {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Text(subscription == nil ? "Add" : "Save")
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(!isFormValid || isLoading)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(width: 380)
        .onAppear {
            if let sub = subscription {
                name = sub.name
                cost = String(format: "%.2f", sub.cost)
                currency = Currency(rawValue: sub.currency) ?? .USD
                billingCycle = BillingCycle(rawValue: sub.billingCycle) ?? .monthly
                categoryId = sub.categoryId
                if let cat = sub.category {
                    category = SubscriptionCategory(rawValue: cat)
                }
                reminderDaysBefore = sub.reminderDaysBefore

                let formatter = DateFormatter()
                formatter.dateFormat = "yyyy-MM-dd"
                if let date = formatter.date(from: sub.nextBillingDate) {
                    nextBillingDate = date
                }

                // Store original values for change detection
                originalName = name
                originalCost = cost
                originalCurrency = currency
                originalBillingCycle = billingCycle
                originalNextBillingDate = nextBillingDate
                originalCategoryId = categoryId
                originalCategory = category
                originalReminderDaysBefore = reminderDaysBefore
            }

            // Load categories
            Task { await loadCategories() }
        }
    }

    private var isFormValid: Bool {
        !name.isEmpty && Double(cost) != nil && Double(cost)! > 0
    }

    private func save() {
        // Skip API call if editing and no changes were made
        if subscription != nil && !hasChanges {
            dismiss()
            return
        }

        isLoading = true
        errorMessage = nil

        Task {
            do {
                if let sub = subscription {
                    try await updateSubscription(id: sub.id)
                } else {
                    try await createSubscription()
                }
                await MainActor.run {
                    onSave()
                    dismiss()
                }
            } catch let error as SubscriptionError {
                await MainActor.run {
                    errorMessage = error.message
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Network error: \(error.localizedDescription)"
                    isLoading = false
                }
            }
        }
    }

    private func createSubscription() async throws {
        let url = URL(string: "\(baseURL)/subscriptions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"

        let body = SubscriptionCreate(
            name: name,
            cost: Double(cost) ?? 0,
            currency: currency.rawValue,
            billingCycle: billingCycle.rawValue,
            nextBillingDate: formatter.string(from: nextBillingDate),
            category: nil,  // Deprecated: using categoryId instead
            categoryId: categoryId,
            reminderDaysBefore: reminderDaysBefore
        )
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw SubscriptionError(message: "Invalid response")
        }

        switch httpResponse.statusCode {
        case 201:
            return
        case 401:
            throw SubscriptionError(message: "Please sign in again")
        case 422:
            let error = try JSONDecoder().decode(ValidationError.self, from: data)
            let message = error.detail.first?.msg ?? "Validation error"
            throw SubscriptionError(message: message)
        default:
            throw SubscriptionError(message: "Server error: \(httpResponse.statusCode)")
        }
    }

    private func updateSubscription(id: Int) async throws {
        let url = URL(string: "\(baseURL)/subscriptions/\(id)")!
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        // Add If-Unmodified-Since header for conflict detection
        if let sub = subscription {
            request.setValue(sub.updatedAt, forHTTPHeaderField: "If-Unmodified-Since")
        }

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"

        let body = SubscriptionUpdate(
            name: name,
            cost: Double(cost),
            currency: currency.rawValue,
            billingCycle: billingCycle.rawValue,
            nextBillingDate: formatter.string(from: nextBillingDate),
            category: nil,  // Deprecated: using categoryId instead
            categoryId: categoryId,
            reminderDaysBefore: reminderDaysBefore
        )
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw SubscriptionError(message: "Invalid response")
        }

        switch httpResponse.statusCode {
        case 200:
            return
        case 401:
            throw SubscriptionError(message: "Please sign in again")
        case 404:
            throw SubscriptionError(message: "This subscription was deleted")
        case 409:
            throw SubscriptionError(message: "This subscription was modified by another session. Please close and reopen to see the latest changes.")
        case 422:
            let error = try JSONDecoder().decode(ValidationError.self, from: data)
            let message = error.detail.first?.msg ?? "Validation error"
            throw SubscriptionError(message: message)
        default:
            throw SubscriptionError(message: "Server error: \(httpResponse.statusCode)")
        }
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
            // Silently fail - categories picker will load its own data if needed
        }
    }
}

struct SubscriptionError: Error {
    let message: String
}
