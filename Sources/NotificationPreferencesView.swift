import SwiftUI

struct NotificationPreferencesView: View {
    let accessToken: String
    @Environment(\.dismiss) private var dismiss

    @State private var emailEnabled = true
    @State private var pushEnabled = true
    @State private var timezone = "UTC"
    @State private var isLoading = false
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var successMessage: String?

    @ObservedObject private var notificationManager = NotificationManager.shared

    private let baseURL = "http://localhost:8000"

    // Common timezones
    private let timezones = [
        "UTC",
        "America/New_York",
        "America/Chicago",
        "America/Denver",
        "America/Los_Angeles",
        "Europe/London",
        "Europe/Paris",
        "Europe/Berlin",
        "Asia/Tokyo",
        "Asia/Shanghai",
        "Australia/Sydney",
    ]

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Notification Preferences")
                    .font(.headline)
                Spacer()
                Button("Done") {
                    dismiss()
                }
            }
            .padding()

            Divider()

            if isLoading {
                ProgressView("Loading preferences...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                Form {
                    Section {
                        Toggle("Email Notifications", isOn: $emailEnabled)
                            .help("Receive email reminders before subscriptions renew")

                        Toggle("Push Notifications", isOn: $pushEnabled)
                            .help("Receive local notifications on this Mac")

                        Picker("Timezone", selection: $timezone) {
                            ForEach(timezones, id: \.self) { tz in
                                Text(tz).tag(tz)
                            }
                        }
                        .help("Your local timezone for reminder scheduling")
                    } header: {
                        Text("Reminder Settings")
                    }

                    Section {
                        HStack {
                            Image(systemName: notificationManager.isAuthorized
                                  ? "checkmark.circle.fill"
                                  : "xmark.circle.fill")
                                .foregroundStyle(notificationManager.isAuthorized
                                                 ? .green
                                                 : .red)
                            Text(notificationManager.isAuthorized
                                 ? "Push notifications authorized"
                                 : "Push notifications not authorized")

                            Spacer()

                            if !notificationManager.isAuthorized {
                                Button("Enable") {
                                    Task {
                                        await notificationManager.requestAuthorization()
                                    }
                                }
                            }
                        }
                    } header: {
                        Text("System Permissions")
                    }

                    if let error = errorMessage {
                        Section {
                            Label(error, systemImage: "exclamationmark.triangle")
                                .foregroundStyle(.red)
                        }
                    }

                    if let success = successMessage {
                        Section {
                            Label(success, systemImage: "checkmark.circle")
                                .foregroundStyle(.green)
                        }
                    }
                }
                .formStyle(.grouped)
                .padding()

                Divider()

                HStack {
                    Spacer()
                    Button("Save") {
                        Task { await savePreferences() }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isSaving)
                }
                .padding()
            }
        }
        .frame(width: 400, height: 400)
        .task {
            await loadPreferences()
        }
    }

    private func loadPreferences() async {
        isLoading = true
        errorMessage = nil

        do {
            var request = URLRequest(url: URL(string: "\(baseURL)/users/me")!)
            request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200
            else {
                errorMessage = "Failed to load preferences"
                isLoading = false
                return
            }

            let profile = try JSONDecoder().decode(UserProfile.self, from: data)
            emailEnabled = profile.emailNotificationsEnabled
            pushEnabled = profile.pushNotificationsEnabled
            timezone = profile.timezone
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    private func savePreferences() async {
        isSaving = true
        errorMessage = nil
        successMessage = nil

        do {
            var request = URLRequest(url: URL(string: "\(baseURL)/users/me/notifications")!)
            request.httpMethod = "PATCH"
            request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")

            let update = NotificationPreferencesUpdate(
                emailNotificationsEnabled: emailEnabled,
                pushNotificationsEnabled: pushEnabled,
                timezone: timezone
            )

            let encoder = JSONEncoder()
            request.httpBody = try encoder.encode(update)

            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw URLError(.badServerResponse)
            }

            if httpResponse.statusCode == 200 {
                let result = try JSONDecoder().decode(
                    NotificationPreferencesResponse.self,
                    from: data
                )
                emailEnabled = result.emailNotificationsEnabled
                pushEnabled = result.pushNotificationsEnabled
                timezone = result.timezone
                successMessage = "Preferences saved"
            } else if httpResponse.statusCode == 422 {
                if let apiError = try? JSONDecoder().decode(APIError.self, from: data) {
                    errorMessage = apiError.detail
                } else {
                    errorMessage = "Invalid timezone"
                }
            } else {
                errorMessage = "Failed to save preferences"
            }
        } catch {
            errorMessage = error.localizedDescription
        }

        isSaving = false
    }
}
