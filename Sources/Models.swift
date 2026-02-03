import Foundation
import SwiftUI

// MARK: - Color Extension for Hex

extension Color {
    init?(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")

        guard hexSanitized.count == 6 else { return nil }

        var rgb: UInt64 = 0
        guard Scanner(string: hexSanitized).scanHexInt64(&rgb) else { return nil }

        let red = Double((rgb & 0xFF0000) >> 16) / 255.0
        let green = Double((rgb & 0x00FF00) >> 8) / 255.0
        let blue = Double(rgb & 0x0000FF) / 255.0

        self.init(red: red, green: green, blue: blue)
    }

    func toHex() -> String {
        guard let components = NSColor(self).cgColor.components else { return "#808080" }
        let r = Int(components[0] * 255)
        let g = Int(components[1] * 255)
        let b = Int(components[2] * 255)
        return String(format: "#%02X%02X%02X", r, g, b)
    }
}

struct Item: Codable, Identifiable {
    let id: Int
    let name: String
    let description: String
    let price: Double
}

struct HealthResponse: Codable {
    let status: String
}

// MARK: - Auth Models

struct RegisterRequest: Codable {
    let email: String
    let password: String
}

struct LoginRequest: Codable {
    let email: String
    let password: String
}

struct User: Codable, Identifiable, Equatable {
    let id: Int
    let email: String
}

struct AuthResponse: Codable, Equatable {
    let user: User
    let accessToken: String
    let tokenType: String

    enum CodingKeys: String, CodingKey {
        case user
        case accessToken = "access_token"
        case tokenType = "token_type"
    }
}

struct APIError: Codable {
    let detail: String
}

struct ValidationError: Codable {
    let detail: [ValidationErrorDetail]
}

struct ValidationErrorDetail: Codable {
    let loc: [String]
    let msg: String
    let type: String
}

// MARK: - Subscription Models

enum BillingCycle: String, Codable, CaseIterable {
    case weekly
    case monthly
    case quarterly
    case yearly

    var displayName: String {
        rawValue.capitalized
    }
}

enum Currency: String, Codable, CaseIterable {
    case USD, EUR, GBP, CAD, AUD, JPY, CHF, SEK, NOK, DKK

    var symbol: String {
        switch self {
        case .USD, .CAD, .AUD: return "$"
        case .EUR: return "€"
        case .GBP: return "£"
        case .JPY: return "¥"
        case .CHF: return "CHF "
        case .SEK, .NOK, .DKK: return "kr "
        }
    }
}

enum SubscriptionCategory: String, Codable, CaseIterable {
    case streaming
    case software
    case utilities
    case gaming
    case other

    var displayName: String {
        rawValue.capitalized
    }

    var iconName: String {
        switch self {
        case .streaming: return "play.tv"
        case .software: return "app.badge"
        case .utilities: return "bolt.fill"
        case .gaming: return "gamecontroller.fill"
        case .other: return "ellipsis.circle"
        }
    }
}

enum SortField: String, Codable, CaseIterable {
    case nextBillingDate = "next_billing_date"
    case name
    case cost
    case createdAt = "created_at"

    var displayName: String {
        switch self {
        case .nextBillingDate: return "Next Billing"
        case .name: return "Name"
        case .cost: return "Cost"
        case .createdAt: return "Created"
        }
    }
}

enum SortOrder: String, Codable, CaseIterable {
    case asc
    case desc

    var displayName: String {
        switch self {
        case .asc: return "Ascending"
        case .desc: return "Descending"
        }
    }
}

enum SubscriptionStatusFilter: String, Codable, CaseIterable {
    case active
    case cancelled
    case all

    var displayName: String {
        switch self {
        case .active: return "Active"
        case .cancelled: return "Cancelled"
        case .all: return "All"
        }
    }
}

struct Subscription: Codable, Identifiable {
    let id: Int
    let userId: Int
    let name: String
    let cost: Double
    let currency: String
    let billingCycle: String
    let nextBillingDate: String
    let category: String?  // Deprecated: use categoryId
    let categoryId: Int?
    let reminderDaysBefore: Int
    let createdAt: String
    let updatedAt: String
    let status: String
    let cancelledAt: String?
    let cancellationReason: String?
    let cancellationEffectiveDate: String?
    let wasFreeTrial: Bool
    let lastUsedAt: String?

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case name
        case cost
        case currency
        case billingCycle = "billing_cycle"
        case nextBillingDate = "next_billing_date"
        case category
        case categoryId = "category_id"
        case reminderDaysBefore = "reminder_days_before"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case status
        case cancelledAt = "cancelled_at"
        case cancellationReason = "cancellation_reason"
        case cancellationEffectiveDate = "cancellation_effective_date"
        case wasFreeTrial = "was_free_trial"
        case lastUsedAt = "last_used_at"
    }

    var formattedCost: String {
        let currencyEnum = Currency(rawValue: currency) ?? .USD
        return String(format: "%@%.2f", currencyEnum.symbol, cost)
    }

    var formattedNextBillingDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        if let date = formatter.date(from: nextBillingDate) {
            formatter.dateStyle = .medium
            return formatter.string(from: date)
        }
        return nextBillingDate
    }

    var isCancelled: Bool {
        status == "cancelled"
    }

    var formattedCancelledAt: String? {
        guard let cancelledAt = cancelledAt else { return nil }
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = isoFormatter.date(from: cancelledAt) {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            return formatter.string(from: date)
        }
        return cancelledAt
    }

    var formattedEffectiveDate: String? {
        guard let effectiveDate = cancellationEffectiveDate else { return nil }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        if let date = formatter.date(from: effectiveDate) {
            formatter.dateStyle = .medium
            return formatter.string(from: date)
        }
        return effectiveDate
    }
}

struct SubscriptionCreate: Codable {
    let name: String
    let cost: Double
    let currency: String
    let billingCycle: String
    let nextBillingDate: String
    let category: String?  // Deprecated: use categoryId
    let categoryId: Int?
    let reminderDaysBefore: Int

    enum CodingKeys: String, CodingKey {
        case name
        case cost
        case currency
        case billingCycle = "billing_cycle"
        case nextBillingDate = "next_billing_date"
        case category
        case categoryId = "category_id"
        case reminderDaysBefore = "reminder_days_before"
    }
}

struct SubscriptionUpdate: Codable {
    var name: String?
    var cost: Double?
    var currency: String?
    var billingCycle: String?
    var nextBillingDate: String?
    var category: String?  // Deprecated: use categoryId
    var categoryId: Int?
    var reminderDaysBefore: Int?

    enum CodingKeys: String, CodingKey {
        case name
        case cost
        case currency
        case billingCycle = "billing_cycle"
        case nextBillingDate = "next_billing_date"
        case category
        case categoryId = "category_id"
        case reminderDaysBefore = "reminder_days_before"
    }
}

struct CurrencyTotal: Codable {
    let currency: String
    let total: Double
    let monthlyEquivalent: Double

    enum CodingKeys: String, CodingKey {
        case currency
        case total
        case monthlyEquivalent = "monthly_equivalent"
    }

    var formattedTotal: String {
        let currencyEnum = Currency(rawValue: currency) ?? .USD
        return String(format: "%@%.2f", currencyEnum.symbol, total)
    }

    var formattedMonthlyEquivalent: String {
        let currencyEnum = Currency(rawValue: currency) ?? .USD
        return String(format: "%@%.2f/mo", currencyEnum.symbol, monthlyEquivalent)
    }
}

struct SubscriptionListResponse: Codable {
    let items: [Subscription]
    let totalCount: Int
    let offset: Int
    let limit: Int
    let totalsByCurrency: [CurrencyTotal]

    enum CodingKeys: String, CodingKey {
        case items
        case totalCount = "total_count"
        case offset
        case limit
        case totalsByCurrency = "totals_by_currency"
    }
}

// MARK: - Category Models

struct Category: Codable, Identifiable, Equatable {
    let id: Int
    let name: String
    let icon: String
    let color: String
    let isSystem: Bool
    let displayOrder: Int
    let subscriptionCount: Int

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case icon
        case color
        case isSystem = "is_system"
        case displayOrder = "display_order"
        case subscriptionCount = "subscription_count"
    }

    var swiftUIColor: Color {
        Color(hex: color) ?? .gray
    }
}

struct CategoryCreate: Codable {
    let name: String
    let icon: String
    let color: String
}

struct CategoryUpdate: Codable {
    var name: String?
    var icon: String?
    var color: String?
}

struct CategoryListResponse: Codable {
    let items: [Category]
    let totalCount: Int
    let customCount: Int
    let maxCustomAllowed: Int

    enum CodingKeys: String, CodingKey {
        case items
        case totalCount = "total_count"
        case customCount = "custom_count"
        case maxCustomAllowed = "max_custom_allowed"
    }
}

struct AvailableIconsResponse: Codable {
    let icons: [String]
}

// MARK: - Cancellation Models

struct CancellationRequest: Codable {
    let reason: String?
    let effectiveDate: String?

    enum CodingKeys: String, CodingKey {
        case reason
        case effectiveDate = "effective_date"
    }
}

struct ReactivateRequest: Codable {
    let nextBillingDate: String?

    enum CodingKeys: String, CodingKey {
        case nextBillingDate = "next_billing_date"
    }
}

struct EstimatedSavings: Codable {
    let currency: String
    let monthlyAmount: Double
    let totalSaved: Double
    let monthsSinceCancellation: Int

    enum CodingKeys: String, CodingKey {
        case currency
        case monthlyAmount = "monthly_amount"
        case totalSaved = "total_saved"
        case monthsSinceCancellation = "months_since_cancellation"
    }

    var formattedMonthlyAmount: String {
        let currencyEnum = Currency(rawValue: currency) ?? .USD
        return String(format: "%@%.2f/mo", currencyEnum.symbol, monthlyAmount)
    }

    var formattedTotalSaved: String {
        let currencyEnum = Currency(rawValue: currency) ?? .USD
        return String(format: "%@%.2f", currencyEnum.symbol, totalSaved)
    }
}

struct CancellationResponse: Codable {
    let id: Int
    let userId: Int
    let name: String
    let cost: Double
    let currency: String
    let billingCycle: String
    let nextBillingDate: String
    let category: String?
    let reminderDaysBefore: Int
    let createdAt: String
    let updatedAt: String
    let status: String
    let cancelledAt: String?
    let cancellationReason: String?
    let cancellationEffectiveDate: String?
    let wasFreeTrial: Bool
    let estimatedSavings: EstimatedSavings?

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case name
        case cost
        case currency
        case billingCycle = "billing_cycle"
        case nextBillingDate = "next_billing_date"
        case category
        case reminderDaysBefore = "reminder_days_before"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case status
        case cancelledAt = "cancelled_at"
        case cancellationReason = "cancellation_reason"
        case cancellationEffectiveDate = "cancellation_effective_date"
        case wasFreeTrial = "was_free_trial"
        case estimatedSavings = "estimated_savings"
    }
}

struct CurrencySavings: Codable {
    let currency: String
    let monthlyAmount: Double
    let totalSaved: Double
    let monthsSinceCancellation: Double

    enum CodingKeys: String, CodingKey {
        case currency
        case monthlyAmount = "monthly_amount"
        case totalSaved = "total_saved"
        case monthsSinceCancellation = "months_since_cancellation"
    }

    var formattedMonthlyAmount: String {
        let currencyEnum = Currency(rawValue: currency) ?? .USD
        return String(format: "%@%.2f/mo", currencyEnum.symbol, monthlyAmount)
    }

    var formattedTotalSaved: String {
        let currencyEnum = Currency(rawValue: currency) ?? .USD
        return String(format: "%@%.2f", currencyEnum.symbol, totalSaved)
    }
}

struct SavingsSummaryResponse: Codable {
    let savingsByCurrency: [CurrencySavings]
    let cancelledCount: Int

    enum CodingKeys: String, CodingKey {
        case savingsByCurrency = "savings_by_currency"
        case cancelledCount = "cancelled_count"
    }
}

// MARK: - User Profile & Notification Preferences

struct UserProfile: Codable {
    let id: Int
    let email: String
    let emailNotificationsEnabled: Bool
    let pushNotificationsEnabled: Bool
    let timezone: String

    enum CodingKeys: String, CodingKey {
        case id
        case email
        case emailNotificationsEnabled = "email_notifications_enabled"
        case pushNotificationsEnabled = "push_notifications_enabled"
        case timezone
    }
}

struct NotificationPreferencesUpdate: Codable {
    var emailNotificationsEnabled: Bool?
    var pushNotificationsEnabled: Bool?
    var timezone: String?

    enum CodingKeys: String, CodingKey {
        case emailNotificationsEnabled = "email_notifications_enabled"
        case pushNotificationsEnabled = "push_notifications_enabled"
        case timezone
    }
}

struct NotificationPreferencesResponse: Codable {
    let emailNotificationsEnabled: Bool
    let pushNotificationsEnabled: Bool
    let timezone: String

    enum CodingKeys: String, CodingKey {
        case emailNotificationsEnabled = "email_notifications_enabled"
        case pushNotificationsEnabled = "push_notifications_enabled"
        case timezone
    }
}

// MARK: - Upcoming Subscriptions

struct UpcomingSubscription: Codable, Identifiable {
    let id: Int
    let name: String
    let cost: Double
    let currency: String
    let nextBillingDate: String
    let daysUntilRenewal: Int
    let reminderSent: Bool

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case cost
        case currency
        case nextBillingDate = "next_billing_date"
        case daysUntilRenewal = "days_until_renewal"
        case reminderSent = "reminder_sent"
    }

    var formattedCost: String {
        let currencyEnum = Currency(rawValue: currency) ?? .USD
        return String(format: "%@%.2f", currencyEnum.symbol, cost)
    }

    var formattedNextBillingDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        if let date = formatter.date(from: nextBillingDate) {
            formatter.dateStyle = .medium
            return formatter.string(from: date)
        }
        return nextBillingDate
    }

    var urgencyColor: String {
        if daysUntilRenewal <= 1 {
            return "red"
        } else if daysUntilRenewal <= 3 {
            return "orange"
        } else if daysUntilRenewal <= 7 {
            return "yellow"
        }
        return "green"
    }
}

struct UpcomingSubscriptionListResponse: Codable {
    let items: [UpcomingSubscription]
    let totalCount: Int

    enum CodingKeys: String, CodingKey {
        case items
        case totalCount = "total_count"
    }
}

// MARK: - Reminder Log

struct ReminderLog: Codable, Identifiable {
    let id: Int
    let userId: Int
    let subscriptionId: Int
    let reminderType: String
    let scheduledFor: String
    let sentAt: String
    let status: String
    let errorMessage: String?
    let emailId: String?

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case subscriptionId = "subscription_id"
        case reminderType = "reminder_type"
        case scheduledFor = "scheduled_for"
        case sentAt = "sent_at"
        case status
        case errorMessage = "error_message"
        case emailId = "email_id"
    }

    var formattedSentAt: String {
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = isoFormatter.date(from: sentAt) {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .short
            return formatter.string(from: date)
        }
        return sentAt
    }

    var statusIcon: String {
        switch status {
        case "sent": return "checkmark.circle.fill"
        case "failed": return "xmark.circle.fill"
        case "skipped": return "minus.circle.fill"
        default: return "questionmark.circle"
        }
    }

    var statusColor: String {
        switch status {
        case "sent": return "green"
        case "failed": return "red"
        case "skipped": return "orange"
        default: return "gray"
        }
    }
}

struct ReminderLogListResponse: Codable {
    let items: [ReminderLog]
    let totalCount: Int
    let offset: Int
    let limit: Int

    enum CodingKeys: String, CodingKey {
        case items
        case totalCount = "total_count"
        case offset
        case limit
    }
}

// MARK: - Monthly Cost Analytics

struct CategoryCost: Codable, Identifiable {
    let category: String
    let monthlyCost: Double
    let subscriptionCount: Int
    let freeTrialCount: Int

    var id: String { category }

    enum CodingKeys: String, CodingKey {
        case category
        case monthlyCost = "monthly_cost"
        case subscriptionCount = "subscription_count"
        case freeTrialCount = "free_trial_count"
    }

    var displayCategory: String {
        category == "uncategorized" ? "Other" : category.capitalized
    }

    var categoryEnum: SubscriptionCategory? {
        SubscriptionCategory(rawValue: category)
    }

    var iconName: String {
        categoryEnum?.iconName ?? "ellipsis.circle"
    }
}

struct CurrencyMonthlyCost: Codable, Identifiable {
    let currency: String
    let totalMonthlyCost: Double
    let projectedYearlyCost: Double
    let subscriptionCount: Int
    let freeTrialCount: Int
    let categories: [CategoryCost]

    var id: String { currency }

    enum CodingKeys: String, CodingKey {
        case currency
        case totalMonthlyCost = "total_monthly_cost"
        case projectedYearlyCost = "projected_yearly_cost"
        case subscriptionCount = "subscription_count"
        case freeTrialCount = "free_trial_count"
        case categories
    }

    var formattedMonthlyCost: String {
        let currencyEnum = Currency(rawValue: currency) ?? .USD
        return String(format: "%@%.2f", currencyEnum.symbol, totalMonthlyCost)
    }

    var formattedYearlyCost: String {
        let currencyEnum = Currency(rawValue: currency) ?? .USD
        return String(format: "%@%.2f", currencyEnum.symbol, projectedYearlyCost)
    }
}

struct MonthComparison: Codable, Identifiable {
    let currency: String
    let currentMonthCost: Double
    let previousMonthCost: Double
    let difference: Double
    let percentageChange: Double?

    var id: String { currency }

    enum CodingKeys: String, CodingKey {
        case currency
        case currentMonthCost = "current_month_cost"
        case previousMonthCost = "previous_month_cost"
        case difference
        case percentageChange = "percentage_change"
    }

    var formattedDifference: String {
        let currencyEnum = Currency(rawValue: currency) ?? .USD
        let sign = difference >= 0 ? "+" : ""
        return String(format: "%@%@%.2f", sign, currencyEnum.symbol, abs(difference))
    }

    var formattedPercentageChange: String {
        guard let change = percentageChange else { return "N/A" }
        let sign = change >= 0 ? "+" : ""
        return String(format: "%@%.1f%%", sign, change)
    }

    var changeColor: String {
        if difference > 0 {
            return "red"  // Spending increased
        } else if difference < 0 {
            return "green"  // Spending decreased (savings)
        }
        return "gray"
    }
}

struct FreeTrialSubscription: Codable, Identifiable {
    let id: Int
    let name: String
    let cost: Double
    let currency: String
    let category: String?
    let billingCycle: String

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case cost
        case currency
        case category
        case billingCycle = "billing_cycle"
    }

    var formattedPotentialCost: String {
        let currencyEnum = Currency(rawValue: currency) ?? .USD
        return String(format: "%@%.2f", currencyEnum.symbol, cost)
    }

    var displayCategory: String {
        category?.capitalized ?? "Uncategorized"
    }
}

struct MonthlyCostResponse: Codable {
    let month: String
    let calculationDate: String
    let costsByCurrency: [CurrencyMonthlyCost]
    let comparison: [MonthComparison]
    let freeTrials: [FreeTrialSubscription]
    let freeTrialTotalCount: Int
    let totalSubscriptionCount: Int
    let activeCount: Int

    enum CodingKeys: String, CodingKey {
        case month
        case calculationDate = "calculation_date"
        case costsByCurrency = "costs_by_currency"
        case comparison
        case freeTrials = "free_trials"
        case freeTrialTotalCount = "free_trial_total_count"
        case totalSubscriptionCount = "total_subscription_count"
        case activeCount = "active_count"
    }

    var formattedMonth: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM"
        if let date = formatter.date(from: month) {
            formatter.dateFormat = "MMMM yyyy"
            return formatter.string(from: date)
        }
        return month
    }
}

// MARK: - Spending Analytics (Trends, Forgotten, Savings Suggestions)

struct MonthlySpendingPoint: Codable, Identifiable {
    let month: String
    let totalMonthlyCost: Double
    let subscriptionCount: Int

    var id: String { month }

    enum CodingKeys: String, CodingKey {
        case month
        case totalMonthlyCost = "total_monthly_cost"
        case subscriptionCount = "subscription_count"
    }

    var formattedMonth: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM"
        if let date = formatter.date(from: month) {
            formatter.dateFormat = "MMM"
            return formatter.string(from: date)
        }
        return month
    }
}

struct SpendingTrendResponse: Codable, Identifiable {
    let currency: String
    let dataPoints: [MonthlySpendingPoint]
    let averageMonthlyCost: Double
    let trendDirection: String
    let trendPercentage: Double?

    var id: String { currency }

    enum CodingKeys: String, CodingKey {
        case currency
        case dataPoints = "data_points"
        case averageMonthlyCost = "average_monthly_cost"
        case trendDirection = "trend_direction"
        case trendPercentage = "trend_percentage"
    }

    var formattedAverageCost: String {
        let currencyEnum = Currency(rawValue: currency) ?? .USD
        return String(format: "%@%.2f", currencyEnum.symbol, averageMonthlyCost)
    }

    var trendIcon: String {
        switch trendDirection {
        case "increasing": return "arrow.up.right"
        case "decreasing": return "arrow.down.right"
        default: return "arrow.right"
        }
    }

    var trendColor: String {
        switch trendDirection {
        case "increasing": return "red"
        case "decreasing": return "green"
        default: return "gray"
        }
    }

    var formattedTrendPercentage: String {
        guard let percentage = trendPercentage else { return "" }
        let sign = percentage >= 0 ? "+" : ""
        return String(format: "%@%.1f%%", sign, percentage)
    }
}

struct ForgottenSubscription: Codable, Identifiable {
    let id: Int
    let name: String
    let monthlyCost: Double
    let currency: String
    let lastUsedAt: String?
    let daysSinceUsed: Int?

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case monthlyCost = "monthly_cost"
        case currency
        case lastUsedAt = "last_used_at"
        case daysSinceUsed = "days_since_used"
    }

    var formattedMonthlyCost: String {
        let currencyEnum = Currency(rawValue: currency) ?? .USD
        return String(format: "%@%.2f/mo", currencyEnum.symbol, monthlyCost)
    }

    var formattedLastUsed: String {
        if let lastUsedAt = lastUsedAt {
            let isoFormatter = ISO8601DateFormatter()
            isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = isoFormatter.date(from: lastUsedAt) {
                let formatter = DateFormatter()
                formatter.dateStyle = .medium
                return formatter.string(from: date)
            }
            return lastUsedAt
        }
        return "Never used"
    }

    var urgencyLevel: String {
        guard let days = daysSinceUsed else { return "high" }  // Never used
        if days >= 90 { return "high" }
        if days >= 60 { return "medium" }
        return "low"
    }

    var urgencyColor: String {
        switch urgencyLevel {
        case "high": return "red"
        case "medium": return "orange"
        default: return "yellow"
        }
    }
}

struct ForgottenSubscriptionsResponse: Codable {
    let subscriptions: [ForgottenSubscription]
    let totalCount: Int
    let totalMonthlyWaste: [String: Double]

    enum CodingKeys: String, CodingKey {
        case subscriptions
        case totalCount = "total_count"
        case totalMonthlyWaste = "total_monthly_waste"
    }

    func formattedWaste(for currency: String) -> String {
        let currencyEnum = Currency(rawValue: currency) ?? .USD
        let amount = totalMonthlyWaste[currency] ?? 0
        return String(format: "%@%.2f/mo", currencyEnum.symbol, amount)
    }
}

struct RankedSubscription: Codable, Identifiable {
    let id: Int
    let name: String
    let monthlyCost: Double
    let currency: String
    let percentageOfTotal: Double

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case monthlyCost = "monthly_cost"
        case currency
        case percentageOfTotal = "percentage_of_total"
    }

    var formattedMonthlyCost: String {
        let currencyEnum = Currency(rawValue: currency) ?? .USD
        return String(format: "%@%.2f", currencyEnum.symbol, monthlyCost)
    }

    var formattedPercentage: String {
        String(format: "%.1f%%", percentageOfTotal)
    }
}

struct TopSubscriptionsResponse: Codable, Identifiable {
    let currency: String
    let subscriptions: [RankedSubscription]
    let totalMonthlyCost: Double

    var id: String { currency }

    enum CodingKeys: String, CodingKey {
        case currency
        case subscriptions
        case totalMonthlyCost = "total_monthly_cost"
    }

    var formattedTotalCost: String {
        let currencyEnum = Currency(rawValue: currency) ?? .USD
        return String(format: "%@%.2f", currencyEnum.symbol, totalMonthlyCost)
    }
}

struct SavingsSuggestion: Codable, Identifiable {
    let subscriptionId: Int
    let subscriptionName: String
    let monthlyCost: Double
    let currency: String
    let suggestionType: String
    let reason: String
    let potentialMonthlySavings: Double
    let confidence: String

    var id: Int { subscriptionId }

    enum CodingKeys: String, CodingKey {
        case subscriptionId = "subscription_id"
        case subscriptionName = "subscription_name"
        case monthlyCost = "monthly_cost"
        case currency
        case suggestionType = "suggestion_type"
        case reason
        case potentialMonthlySavings = "potential_monthly_savings"
        case confidence
    }

    var formattedSavings: String {
        let currencyEnum = Currency(rawValue: currency) ?? .USD
        return String(format: "%@%.2f/mo", currencyEnum.symbol, potentialMonthlySavings)
    }

    var suggestionIcon: String {
        switch suggestionType {
        case "unused": return "clock.badge.xmark"
        case "duplicate_category": return "rectangle.on.rectangle"
        case "high_cost": return "exclamationmark.triangle"
        default: return "lightbulb"
        }
    }

    var suggestionTypeDisplay: String {
        switch suggestionType {
        case "unused": return "Unused"
        case "duplicate_category": return "Duplicate"
        case "high_cost": return "High Cost"
        default: return suggestionType.capitalized
        }
    }

    var confidenceColor: String {
        switch confidence {
        case "high": return "red"
        case "medium": return "orange"
        default: return "yellow"
        }
    }
}

struct SavingsSuggestionsResponse: Codable {
    let suggestions: [SavingsSuggestion]
    let totalPotentialSavings: [String: Double]

    enum CodingKeys: String, CodingKey {
        case suggestions
        case totalPotentialSavings = "total_potential_savings"
    }

    func formattedTotalSavings(for currency: String) -> String {
        let currencyEnum = Currency(rawValue: currency) ?? .USD
        let amount = totalPotentialSavings[currency] ?? 0
        return String(format: "%@%.2f/mo", currencyEnum.symbol, amount)
    }
}

struct SpendingAnalyticsResponse: Codable {
    let trendsByCurrency: [SpendingTrendResponse]
    let topSubscriptionsByCurrency: [TopSubscriptionsResponse]
    let forgottenSubscriptions: ForgottenSubscriptionsResponse
    let savingsSuggestions: SavingsSuggestionsResponse
    let generatedAt: String

    enum CodingKeys: String, CodingKey {
        case trendsByCurrency = "trends_by_currency"
        case topSubscriptionsByCurrency = "top_subscriptions_by_currency"
        case forgottenSubscriptions = "forgotten_subscriptions"
        case savingsSuggestions = "savings_suggestions"
        case generatedAt = "generated_at"
    }
}

// MARK: - Search & Filter

struct SubscriptionFilters: Equatable {
    var search: String = ""
    var billingCycle: BillingCycle?
    var costMin: Double?
    var costMax: Double?
    var categoryId: Int?
    var status: SubscriptionStatusFilter = .active
    var sortBy: SortField = .nextBillingDate
    var sortOrder: SortOrder = .asc

    var hasActiveFilters: Bool {
        !search.isEmpty ||
        billingCycle != nil ||
        costMin != nil ||
        costMax != nil ||
        categoryId != nil
    }

    mutating func clearFilters() {
        search = ""
        billingCycle = nil
        costMin = nil
        costMax = nil
        categoryId = nil
    }
}
