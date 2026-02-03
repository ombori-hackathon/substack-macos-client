import SwiftUI

struct LoginView: View {
    @Environment(\.dismiss) private var dismiss

    @Binding var authResponse: AuthResponse?

    @State private var email = ""
    @State private var password = ""
    @State private var isLoading = false
    @State private var errorMessage: String?

    private let baseURL = "http://localhost:8000"

    var body: some View {
        VStack(spacing: 20) {
            Text("Sign In")
                .font(.title.bold())

            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Email")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    TextField("email@example.com", text: $email)
                        .textFieldStyle(.roundedBorder)
                        .textContentType(.emailAddress)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Password")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    SecureField("Enter your password", text: $password)
                        .textFieldStyle(.roundedBorder)
                        .textContentType(.password)
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

                Button(action: login) {
                    if isLoading {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Text("Sign In")
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(!isFormValid || isLoading)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(width: 320)
    }

    private var isFormValid: Bool {
        !email.isEmpty && !password.isEmpty
    }

    private func login() {
        isLoading = true
        errorMessage = nil

        Task {
            do {
                let response = try await performLogin()
                await MainActor.run {
                    authResponse = response
                    dismiss()
                }
            } catch let error as LoginError {
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

    private func performLogin() async throws -> AuthResponse {
        let url = URL(string: "\(baseURL)/auth/login")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body = LoginRequest(email: email, password: password)
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw LoginError(message: "Invalid response")
        }

        switch httpResponse.statusCode {
        case 200:
            return try JSONDecoder().decode(AuthResponse.self, from: data)
        case 401:
            let error = try JSONDecoder().decode(APIError.self, from: data)
            throw LoginError(message: error.detail)
        case 422:
            let error = try JSONDecoder().decode(ValidationError.self, from: data)
            let message = error.detail.first?.msg ?? "Validation error"
            throw LoginError(message: message)
        default:
            throw LoginError(message: "Server error: \(httpResponse.statusCode)")
        }
    }
}

struct LoginError: Error {
    let message: String
}
