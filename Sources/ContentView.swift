import SwiftUI

enum AppTab {
    case items
    case subscriptions
    case upcoming
    case analytics
}

struct ContentView: View {
    @State private var items: [Item] = []
    @State private var isLoading = false
    @State private var apiStatus = "Checking..."
    @State private var errorMessage: String?
    @State private var showingRegistration = false
    @State private var showingLogin = false
    @State private var showingPreferences = false
    @State private var authResponse: AuthResponse?
    @State private var selectedTab: AppTab = .subscriptions
    @State private var upcomingCount = 0

    private let baseURL = "http://localhost:8000"

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("sub-stack")
                    .font(.title.bold())

                Picker("", selection: $selectedTab) {
                    Text("Subscriptions").tag(AppTab.subscriptions)
                    HStack {
                        Text("Upcoming")
                        if upcomingCount > 0 {
                            Text("\(upcomingCount)")
                                .font(.caption2.bold())
                                .foregroundStyle(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(.red)
                                .clipShape(Capsule())
                        }
                    }.tag(AppTab.upcoming)
                    Text("Analytics").tag(AppTab.analytics)
                    Text("Items").tag(AppTab.items)
                }
                .pickerStyle(.segmented)
                .frame(width: 380)

                Spacer()

                if let auth = authResponse {
                    Button {
                        showingPreferences = true
                    } label: {
                        Image(systemName: "bell.badge")
                    }
                    .buttonStyle(.borderless)
                    .help("Notification Preferences")

                    Text(auth.user.email)
                        .foregroundStyle(.secondary)
                    Button("Sign Out") {
                        authResponse = nil
                        upcomingCount = 0
                    }
                } else {
                    Button("Sign In") {
                        showingLogin = true
                    }

                    Button("Sign Up") {
                        showingRegistration = true
                    }
                    .buttonStyle(.borderedProminent)
                }

                Circle()
                    .fill(apiStatus == "healthy" ? .green : .red)
                    .frame(width: 12, height: 12)
                Text(apiStatus)
                    .foregroundStyle(.secondary)
            }
            .padding()
            .background(.bar)

            Divider()

            // Content
            if let error = errorMessage {
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle)
                        .foregroundStyle(.orange)
                    Text(error)
                        .foregroundStyle(.secondary)
                    Text("Start API: cd services/api && uv run fastapi dev")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if isLoading {
                ProgressView("Loading...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                switch selectedTab {
                case .subscriptions:
                    if let auth = authResponse {
                        SubscriptionsView(accessToken: auth.accessToken)
                    } else {
                        signInPrompt
                    }
                case .upcoming:
                    if let auth = authResponse {
                        UpcomingRenewalsView(accessToken: auth.accessToken)
                    } else {
                        signInPrompt
                    }
                case .analytics:
                    if let auth = authResponse {
                        AnalyticsView(accessToken: auth.accessToken)
                    } else {
                        signInPrompt
                    }
                case .items:
                    ItemsTable(items: items)
                }
            }
        }
        .task {
            await loadData()
        }
        .sheet(isPresented: $showingRegistration) {
            RegistrationView(authResponse: $authResponse)
        }
        .sheet(isPresented: $showingLogin) {
            LoginView(authResponse: $authResponse)
        }
        .sheet(isPresented: $showingPreferences) {
            if let auth = authResponse {
                NotificationPreferencesView(accessToken: auth.accessToken)
            }
        }
        .onChange(of: authResponse) { _, newValue in
            if let auth = newValue {
                Task { await loadUpcomingCount(accessToken: auth.accessToken) }
            }
        }
    }

    private var signInPrompt: some View {
        VStack(spacing: 12) {
            Image(systemName: "person.crop.circle")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text("Sign in to manage subscriptions")
                .foregroundStyle(.secondary)
            Button("Sign In") {
                showingLogin = true
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func loadData() async {
        isLoading = true
        errorMessage = nil

        // Check health
        do {
            let url = URL(string: "\(baseURL)/health")!
            let (data, _) = try await URLSession.shared.data(from: url)
            let health = try JSONDecoder().decode(HealthResponse.self, from: data)
            apiStatus = health.status
        } catch {
            apiStatus = "offline"
            errorMessage = "API not running"
            isLoading = false
            return
        }

        // Fetch items
        do {
            let url = URL(string: "\(baseURL)/items")!
            let (data, _) = try await URLSession.shared.data(from: url)
            items = try JSONDecoder().decode([Item].self, from: data)
        } catch {
            errorMessage = "Failed to load items"
        }

        isLoading = false
    }

    private func loadUpcomingCount(accessToken: String) async {
        do {
            var components = URLComponents(string: "\(baseURL)/subscriptions/upcoming")!
            components.queryItems = [URLQueryItem(name: "days", value: "7")]

            var request = URLRequest(url: components.url!)
            request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200
            else { return }

            let decoded = try JSONDecoder().decode(
                UpcomingSubscriptionListResponse.self,
                from: data
            )
            upcomingCount = decoded.totalCount
        } catch {
            // Silently fail - badge is optional
        }
    }
}
