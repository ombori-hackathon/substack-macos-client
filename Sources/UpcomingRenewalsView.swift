import SwiftUI

struct UpcomingRenewalsView: View {
    let accessToken: String
    @State private var upcoming: [UpcomingSubscription] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var daysAhead = 7

    private let baseURL = "http://localhost:8000"

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Upcoming Renewals")
                    .font(.headline)

                Spacer()

                Picker("Days ahead", selection: $daysAhead) {
                    Text("7 days").tag(7)
                    Text("14 days").tag(14)
                    Text("30 days").tag(30)
                }
                .pickerStyle(.segmented)
                .frame(width: 200)

                Button {
                    Task { await loadUpcoming() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.borderless)
            }
            .padding()

            Divider()

            // Content
            if isLoading {
                ProgressView("Loading...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = errorMessage {
                VStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle)
                        .foregroundStyle(.orange)
                    Text(error)
                        .foregroundStyle(.secondary)
                    Button("Retry") {
                        Task { await loadUpcoming() }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if upcoming.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "calendar.badge.checkmark")
                        .font(.largeTitle)
                        .foregroundStyle(.green)
                    Text("No renewals in the next \(daysAhead) days")
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(upcoming) { subscription in
                    UpcomingSubscriptionRow(subscription: subscription)
                }
            }
        }
        .task {
            await loadUpcoming()
        }
        .onChange(of: daysAhead) { _, _ in
            Task { await loadUpcoming() }
        }
    }

    private func loadUpcoming() async {
        isLoading = true
        errorMessage = nil

        do {
            var components = URLComponents(string: "\(baseURL)/subscriptions/upcoming")!
            components.queryItems = [URLQueryItem(name: "days", value: String(daysAhead))]

            var request = URLRequest(url: components.url!)
            request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw URLError(.badServerResponse)
            }

            if httpResponse.statusCode == 200 {
                let decoded = try JSONDecoder().decode(
                    UpcomingSubscriptionListResponse.self,
                    from: data
                )
                upcoming = decoded.items
            } else if httpResponse.statusCode == 401 {
                errorMessage = "Session expired. Please sign in again."
            } else {
                errorMessage = "Failed to load upcoming renewals"
            }
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }
}

struct UpcomingSubscriptionRow: View {
    let subscription: UpcomingSubscription

    var urgencyColor: Color {
        switch subscription.urgencyColor {
        case "red": return .red
        case "orange": return .orange
        case "yellow": return .yellow
        default: return .green
        }
    }

    var body: some View {
        HStack {
            Circle()
                .fill(urgencyColor)
                .frame(width: 10, height: 10)

            VStack(alignment: .leading, spacing: 2) {
                Text(subscription.name)
                    .font(.headline)
                Text(subscription.formattedNextBillingDate)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(subscription.formattedCost)
                    .font(.headline)

                HStack(spacing: 4) {
                    if subscription.daysUntilRenewal == 0 {
                        Text("Today")
                            .font(.caption)
                            .foregroundStyle(.red)
                    } else if subscription.daysUntilRenewal == 1 {
                        Text("Tomorrow")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    } else {
                        Text("\(subscription.daysUntilRenewal) days")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    if subscription.reminderSent {
                        Image(systemName: "bell.fill")
                            .font(.caption)
                            .foregroundStyle(.blue)
                            .help("Reminder sent")
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }
}
