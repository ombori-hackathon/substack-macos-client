import SwiftUI
import Charts

struct AnalyticsView: View {
    let accessToken: String

    @State private var monthlyCosts: MonthlyCostResponse?
    @State private var spendingAnalytics: SpendingAnalyticsResponse?
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var selectedMonth: String?
    @State private var selectedTab = 0

    private let baseURL = "http://localhost:8000"

    var body: some View {
        Group {
            if isLoading {
                ProgressView("Loading analytics...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = errorMessage {
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle)
                        .foregroundStyle(.orange)
                    Text(error)
                        .foregroundStyle(.secondary)
                    Button("Retry") {
                        Task { await loadAllAnalytics() }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let costs = monthlyCosts {
                if costs.costsByCurrency.isEmpty && (spendingAnalytics?.trendsByCurrency.isEmpty ?? true) {
                    emptyState
                } else {
                    analyticsContent(costs)
                }
            }
        }
        .task {
            await loadAllAnalytics()
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "chart.pie")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text("No subscriptions yet")
                .font(.title3)
            Text("Add subscriptions to see your spending analytics")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private func analyticsContent(_ costs: MonthlyCostResponse) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Header with month and tab picker
                HStack {
                    Text(costs.formattedMonth)
                        .font(.title2.bold())
                    Spacer()
                    Picker("View", selection: $selectedTab) {
                        Text("Overview").tag(0)
                        Text("Insights").tag(1)
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 200)
                }
                .padding(.horizontal)

                if selectedTab == 0 {
                    overviewTab(costs)
                } else {
                    insightsTab
                }
            }
            .padding()
        }
    }

    @ViewBuilder
    private func overviewTab(_ costs: MonthlyCostResponse) -> some View {
        // Cost summary cards per currency
        ForEach(costs.costsByCurrency) { currencyCost in
            MonthlyCostCard(
                currencyCost: currencyCost,
                comparison: costs.comparison.first { $0.currency == currencyCost.currency }
            )
        }

        // Spending Trend Chart (6 months)
        if let analytics = spendingAnalytics, !analytics.trendsByCurrency.isEmpty {
            SpendingTrendChart(trends: analytics.trendsByCurrency)
        }

        // Category breakdown chart
        if let firstCurrency = costs.costsByCurrency.first,
           !firstCurrency.categories.isEmpty {
            CategoryBreakdownChart(categories: firstCurrency.categories, currency: firstCurrency.currency)
        }

        // Top Subscriptions
        if let analytics = spendingAnalytics, !analytics.topSubscriptionsByCurrency.isEmpty {
            TopSubscriptionsChart(topSubscriptions: analytics.topSubscriptionsByCurrency)
        }

        // Month comparison chart
        if !costs.comparison.isEmpty {
            MonthComparisonChart(comparisons: costs.comparison)
        }

        // Free trials section
        if !costs.freeTrials.isEmpty {
            FreeTrialsSection(freeTrials: costs.freeTrials)
        }
    }

    @ViewBuilder
    private var insightsTab: some View {
        if let analytics = spendingAnalytics {
            // Forgotten Subscriptions
            if analytics.forgottenSubscriptions.totalCount > 0 {
                ForgottenSubscriptionsCard(
                    forgotten: analytics.forgottenSubscriptions,
                    accessToken: accessToken,
                    onMarkUsed: { await loadAllAnalytics() }
                )
            }

            // Savings Suggestions
            if !analytics.savingsSuggestions.suggestions.isEmpty {
                SavingsSuggestionsSection(suggestions: analytics.savingsSuggestions)
            }

            // No insights available
            if analytics.forgottenSubscriptions.totalCount == 0 &&
               analytics.savingsSuggestions.suggestions.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "checkmark.circle")
                        .font(.system(size: 48))
                        .foregroundStyle(.green)
                    Text("You're doing great!")
                        .font(.title3.bold())
                    Text("No unused subscriptions or savings opportunities detected.")
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
            }
        } else {
            ProgressView("Loading insights...")
        }
    }

    private func loadAllAnalytics() async {
        isLoading = true
        errorMessage = nil

        async let costsTask: Void = loadMonthlyCosts()
        async let analyticsTask: Void = loadSpendingAnalytics()

        _ = await (costsTask, analyticsTask)

        isLoading = false
    }

    private func loadMonthlyCosts() async {
        do {
            var components = URLComponents(string: "\(baseURL)/subscriptions/monthly-costs")!
            if let month = selectedMonth {
                components.queryItems = [URLQueryItem(name: "month", value: month)]
            }

            var request = URLRequest(url: components.url!)
            request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw URLError(.badServerResponse)
            }

            if httpResponse.statusCode == 200 {
                let decoder = JSONDecoder()
                monthlyCosts = try decoder.decode(MonthlyCostResponse.self, from: data)
            } else {
                let errorResponse = try? JSONDecoder().decode(APIError.self, from: data)
                errorMessage = errorResponse?.detail ?? "Failed to load analytics"
            }
        } catch {
            errorMessage = "Network error: \(error.localizedDescription)"
        }
    }

    private func loadSpendingAnalytics() async {
        do {
            let url = URL(string: "\(baseURL)/subscriptions/analytics")!
            var request = URLRequest(url: url)
            request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                return
            }

            let decoder = JSONDecoder()
            spendingAnalytics = try decoder.decode(SpendingAnalyticsResponse.self, from: data)
        } catch {
            // Silently fail - insights are supplementary
            print("Failed to load spending analytics: \(error)")
        }
    }
}

// MARK: - Monthly Cost Card

struct MonthlyCostCard: View {
    let currencyCost: CurrencyMonthlyCost
    let comparison: MonthComparison?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Monthly Spending (\(currencyCost.currency))")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text(currencyCost.formattedMonthlyCost)
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                }

                Spacer()

                if let comp = comparison {
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("vs Last Month")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        HStack(spacing: 4) {
                            Image(systemName: comp.difference >= 0 ? "arrow.up.right" : "arrow.down.right")
                            Text(comp.formattedDifference)
                        }
                        .font(.headline)
                        .foregroundColor(comp.difference > 0 ? .red : (comp.difference < 0 ? .green : .secondary))

                        if comp.percentageChange != nil {
                            Text(comp.formattedPercentageChange)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            Divider()

            HStack {
                VStack(alignment: .leading) {
                    Text("Projected Yearly")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(currencyCost.formattedYearlyCost)
                        .font(.title3.bold())
                }

                Spacer()

                VStack(alignment: .trailing) {
                    Text("Active Subscriptions")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("\(currencyCost.subscriptionCount - currencyCost.freeTrialCount)")
                        .font(.title3.bold())
                }

                if currencyCost.freeTrialCount > 0 {
                    Spacer()
                    VStack(alignment: .trailing) {
                        Text("Free Trials")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("\(currencyCost.freeTrialCount)")
                            .font(.title3.bold())
                            .foregroundStyle(.blue)
                    }
                }
            }
        }
        .padding()
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal)
    }
}

// MARK: - Category Breakdown Chart

struct CategoryBreakdownChart: View {
    let categories: [CategoryCost]
    let currency: String

    private var chartCategories: [CategoryCost] {
        categories.filter { $0.monthlyCost > 0 }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Spending by Category")
                .font(.headline)
                .padding(.horizontal)

            if chartCategories.isEmpty {
                Text("No paid subscriptions to display")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            } else {
                HStack(alignment: .top, spacing: 24) {
                    // Pie Chart
                    Chart(chartCategories) { category in
                        SectorMark(
                            angle: .value("Cost", category.monthlyCost),
                            innerRadius: .ratio(0.5),
                            angularInset: 1
                        )
                        .foregroundStyle(by: .value("Category", category.displayCategory))
                        .cornerRadius(4)
                    }
                    .frame(width: 200, height: 200)

                    // Legend with amounts
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(chartCategories) { category in
                            HStack {
                                Image(systemName: category.iconName)
                                    .frame(width: 20)
                                Text(category.displayCategory)
                                Spacer()
                                let currencyEnum = Currency(rawValue: currency) ?? .USD
                                Text(String(format: "%@%.2f", currencyEnum.symbol, category.monthlyCost))
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .frame(minWidth: 200)
                }
                .padding()
                .background(.regularMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal)
            }
        }
    }
}

// MARK: - Month Comparison Chart

struct MonthComparisonChart: View {
    let comparisons: [MonthComparison]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Month-over-Month")
                .font(.headline)
                .padding(.horizontal)

            Chart {
                ForEach(comparisons) { comp in
                    BarMark(
                        x: .value("Month", "Previous"),
                        y: .value("Cost", comp.previousMonthCost)
                    )
                    .foregroundStyle(.gray.opacity(0.6))
                    .position(by: .value("Currency", comp.currency))

                    BarMark(
                        x: .value("Month", "Current"),
                        y: .value("Cost", comp.currentMonthCost)
                    )
                    .foregroundStyle(comp.difference > 0 ? .red : .green)
                    .position(by: .value("Currency", comp.currency))
                }
            }
            .chartLegend(position: .bottom)
            .frame(height: 200)
            .padding()
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal)
        }
    }
}

// MARK: - Free Trials Section

struct FreeTrialsSection: View {
    let freeTrials: [FreeTrialSubscription]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "gift")
                    .foregroundStyle(.blue)
                Text("Free Trials")
                    .font(.headline)
                Text("(\(freeTrials.count))")
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal)

            VStack(spacing: 8) {
                ForEach(freeTrials) { trial in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(trial.name)
                                .font(.body)
                            Text(trial.displayCategory)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        VStack(alignment: .trailing) {
                            Text(trial.formattedPotentialCost)
                                .foregroundStyle(.secondary)
                            Text("after trial")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                }
            }
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal)
        }
    }
}

// MARK: - Spending Trend Chart

struct SpendingTrendChart: View {
    let trends: [SpendingTrendResponse]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .foregroundStyle(.blue)
                Text("6-Month Spending Trend")
                    .font(.headline)
            }
            .padding(.horizontal)

            ForEach(trends) { trend in
                VStack(alignment: .leading, spacing: 8) {
                    // Currency header with trend indicator
                    HStack {
                        Text(trend.currency)
                            .font(.subheadline.bold())

                        Spacer()

                        HStack(spacing: 4) {
                            Image(systemName: trend.trendIcon)
                            Text(trend.trendDirection.capitalized)
                            if !trend.formattedTrendPercentage.isEmpty {
                                Text("(\(trend.formattedTrendPercentage))")
                            }
                        }
                        .font(.caption)
                        .foregroundColor(colorForTrend(trend.trendColor))

                        Spacer()

                        Text("Avg: \(trend.formattedAverageCost)/mo")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    // Line chart
                    Chart(trend.dataPoints) { point in
                        LineMark(
                            x: .value("Month", point.formattedMonth),
                            y: .value("Cost", point.totalMonthlyCost)
                        )
                        .foregroundStyle(.blue)
                        .interpolationMethod(.catmullRom)

                        AreaMark(
                            x: .value("Month", point.formattedMonth),
                            y: .value("Cost", point.totalMonthlyCost)
                        )
                        .foregroundStyle(.blue.opacity(0.1))
                        .interpolationMethod(.catmullRom)

                        PointMark(
                            x: .value("Month", point.formattedMonth),
                            y: .value("Cost", point.totalMonthlyCost)
                        )
                        .foregroundStyle(.blue)
                    }
                    .frame(height: 150)
                    .chartYAxis {
                        AxisMarks(position: .leading)
                    }
                }
                .padding()
                .background(.regularMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .padding(.horizontal)
        }
    }

    private func colorForTrend(_ colorName: String) -> Color {
        switch colorName {
        case "red": return .red
        case "green": return .green
        default: return .secondary
        }
    }
}

// MARK: - Top Subscriptions Chart

struct TopSubscriptionsChart: View {
    let topSubscriptions: [TopSubscriptionsResponse]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "chart.bar.fill")
                    .foregroundStyle(.purple)
                Text("Top Subscriptions")
                    .font(.headline)
            }
            .padding(.horizontal)

            ForEach(topSubscriptions) { top in
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(top.currency)
                            .font(.subheadline.bold())
                        Spacer()
                        Text("Total: \(top.formattedTotalCost)/mo")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    ForEach(top.subscriptions) { sub in
                        HStack {
                            Text(sub.name)
                                .lineLimit(1)
                                .frame(width: 120, alignment: .leading)

                            GeometryReader { geo in
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(.purple.gradient)
                                    .frame(width: geo.size.width * (sub.percentageOfTotal / 100))
                            }
                            .frame(height: 20)

                            Text(sub.formattedPercentage)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .frame(width: 50, alignment: .trailing)

                            Text(sub.formattedMonthlyCost)
                                .font(.caption.bold())
                                .frame(width: 70, alignment: .trailing)
                        }
                    }
                }
                .padding()
                .background(.regularMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .padding(.horizontal)
        }
    }
}

// MARK: - Forgotten Subscriptions Card

struct ForgottenSubscriptionsCard: View {
    let forgotten: ForgottenSubscriptionsResponse
    let accessToken: String
    let onMarkUsed: () async -> Void

    @State private var isMarking: Int? = nil

    private let baseURL = "http://localhost:8000"

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "clock.badge.xmark")
                    .foregroundStyle(.orange)
                Text("Forgotten Subscriptions")
                    .font(.headline)
                Text("(\(forgotten.totalCount))")
                    .foregroundStyle(.secondary)

                Spacer()

                // Total waste
                VStack(alignment: .trailing) {
                    Text("Potential Waste")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    HStack(spacing: 4) {
                        ForEach(Array(forgotten.totalMonthlyWaste.keys.sorted()), id: \.self) { currency in
                            Text(forgotten.formattedWaste(for: currency))
                                .font(.caption.bold())
                                .foregroundStyle(.orange)
                        }
                    }
                }
            }
            .padding(.horizontal)

            VStack(spacing: 1) {
                ForEach(forgotten.subscriptions) { sub in
                    HStack {
                        Circle()
                            .fill(colorForUrgency(sub.urgencyColor))
                            .frame(width: 8, height: 8)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(sub.name)
                                .font(.body)
                            Text(sub.formattedLastUsed)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Text(sub.formattedMonthlyCost)
                            .foregroundStyle(.secondary)

                        Button(action: {
                            Task { await markAsUsed(sub.id) }
                        }) {
                            if isMarking == sub.id {
                                ProgressView()
                                    .scaleEffect(0.7)
                            } else {
                                Text("Mark Used")
                                    .font(.caption)
                            }
                        }
                        .buttonStyle(.bordered)
                        .disabled(isMarking != nil)
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 10)
                    .background(Color(nsColor: .controlBackgroundColor))
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal)
        }
    }

    private func colorForUrgency(_ colorName: String) -> Color {
        switch colorName {
        case "red": return .red
        case "orange": return .orange
        default: return .yellow
        }
    }

    private func markAsUsed(_ subscriptionId: Int) async {
        isMarking = subscriptionId
        defer { isMarking = nil }

        do {
            let url = URL(string: "\(baseURL)/subscriptions/\(subscriptionId)/mark-used")!
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

            let (_, response) = try await URLSession.shared.data(for: request)

            if let httpResponse = response as? HTTPURLResponse,
               httpResponse.statusCode == 200 {
                await onMarkUsed()
            }
        } catch {
            print("Failed to mark as used: \(error)")
        }
    }
}

// MARK: - Savings Suggestions Section

struct SavingsSuggestionsSection: View {
    let suggestions: SavingsSuggestionsResponse

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "lightbulb.fill")
                    .foregroundStyle(.yellow)
                Text("Savings Suggestions")
                    .font(.headline)

                Spacer()

                // Total potential savings
                VStack(alignment: .trailing) {
                    Text("Potential Savings")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    HStack(spacing: 4) {
                        ForEach(Array(suggestions.totalPotentialSavings.keys.sorted()), id: \.self) { currency in
                            Text(suggestions.formattedTotalSavings(for: currency))
                                .font(.caption.bold())
                                .foregroundStyle(.green)
                        }
                    }
                }
            }
            .padding(.horizontal)

            VStack(spacing: 12) {
                ForEach(suggestions.suggestions) { suggestion in
                    SuggestionCard(suggestion: suggestion)
                }
            }
            .padding(.horizontal)
        }
    }
}

struct SuggestionCard: View {
    let suggestion: SavingsSuggestion

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Icon
            Image(systemName: suggestion.suggestionIcon)
                .font(.title2)
                .foregroundColor(colorForConfidence(suggestion.confidenceColor))
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(suggestion.subscriptionName)
                        .font(.body.bold())

                    Spacer()

                    // Confidence badge
                    Text(suggestion.confidence.uppercased())
                        .font(.caption2.bold())
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(colorForConfidence(suggestion.confidenceColor).opacity(0.2))
                        .foregroundColor(colorForConfidence(suggestion.confidenceColor))
                        .clipShape(Capsule())
                }

                Text(suggestion.reason)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)

                HStack {
                    Label(suggestion.suggestionTypeDisplay, systemImage: "tag")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Spacer()

                    Text("Save \(suggestion.formattedSavings)")
                        .font(.caption.bold())
                        .foregroundStyle(.green)
                }
            }
        }
        .padding()
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func colorForConfidence(_ colorName: String) -> Color {
        switch colorName {
        case "red": return .red
        case "orange": return .orange
        default: return .yellow
        }
    }
}
