import SwiftUI

struct CancellationFormView: View {
    let accessToken: String
    let subscription: Subscription
    let onCancelled: (CancellationResponse) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var reason: String = ""
    @State private var effectiveDate: Date = Date()
    @State private var useCustomDate = false
    @State private var isLoading = false
    @State private var errorMessage: String?

    private let baseURL = "http://localhost:8000"

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Cancel Subscription")
                    .font(.headline)
                Spacer()
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding()

            Divider()

            // Form content
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Subscription info
                    VStack(alignment: .leading, spacing: 8) {
                        Text(subscription.name)
                            .font(.title2)
                            .fontWeight(.semibold)
                        HStack {
                            Text(subscription.formattedCost)
                                .foregroundStyle(.secondary)
                            Text("/")
                                .foregroundStyle(.tertiary)
                            Text(subscription.billingCycle.capitalized)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(nsColor: .controlBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                    // Reason field
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Reason for cancelling (optional)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        TextEditor(text: $reason)
                            .frame(height: 80)
                            .font(.body)
                            .scrollContentBackground(.hidden)
                            .padding(8)
                            .background(Color(nsColor: .controlBackgroundColor))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
                            )
                        Text("\(reason.count)/500")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                    }

                    // Effective date
                    VStack(alignment: .leading, spacing: 8) {
                        Toggle("Set custom effective date", isOn: $useCustomDate)
                            .toggleStyle(.checkbox)

                        if useCustomDate {
                            DatePicker(
                                "Effective date",
                                selection: $effectiveDate,
                                in: Date()...,
                                displayedComponents: .date
                            )
                            .datePickerStyle(.field)
                        } else {
                            Text("Cancellation will be effective on your next billing date: \(subscription.formattedNextBillingDate)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding()
                    .background(Color(nsColor: .controlBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                    // Error message
                    if let error = errorMessage {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.orange)
                            Text(error)
                                .foregroundStyle(.secondary)
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.orange.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
                .padding()
            }

            Divider()

            // Action buttons
            HStack {
                Button("Keep Subscription") {
                    dismiss()
                }
                .keyboardShortcut(.escape, modifiers: [])

                Spacer()

                Button(action: { Task { await cancelSubscription() } }) {
                    if isLoading {
                        ProgressView()
                            .scaleEffect(0.7)
                            .frame(width: 80)
                    } else {
                        Text("Cancel Subscription")
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
                .disabled(isLoading || reason.count > 500)
            }
            .padding()
        }
        .frame(width: 400, height: 450)
    }

    private func cancelSubscription() async {
        isLoading = true
        errorMessage = nil

        do {
            let url = URL(string: "\(baseURL)/subscriptions/\(subscription.id)/cancel")!
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")

            // Build request body
            var requestBody: [String: Any] = [:]
            if !reason.isEmpty {
                requestBody["reason"] = reason
            }
            if useCustomDate {
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyy-MM-dd"
                requestBody["effective_date"] = formatter.string(from: effectiveDate)
            }

            if !requestBody.isEmpty {
                request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
            }

            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw SubscriptionError(message: "Invalid response")
            }

            switch httpResponse.statusCode {
            case 200:
                let cancellationResponse = try JSONDecoder().decode(CancellationResponse.self, from: data)
                await MainActor.run {
                    onCancelled(cancellationResponse)
                    dismiss()
                }
            case 400:
                let apiError = try? JSONDecoder().decode(APIError.self, from: data)
                errorMessage = apiError?.detail ?? "Subscription is already cancelled"
            case 404:
                errorMessage = "Subscription not found"
            default:
                errorMessage = "Failed to cancel subscription"
            }
        } catch {
            errorMessage = "Network error: \(error.localizedDescription)"
        }

        isLoading = false
    }
}
