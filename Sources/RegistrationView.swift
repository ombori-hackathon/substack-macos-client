import SwiftUI

struct RegistrationView: View {
    @Environment(\.dismiss) private var dismiss

    @Binding var authResponse: AuthResponse?

    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var isLoading = false
    @State private var errorMessage: String?

    private let baseURL = "http://localhost:8000"

    var body: some View {
        VStack(spacing: 20) {
            Text("Create Account")
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
                    SecureField("Min 8 chars, 1 number, 1 special", text: $password)
                        .textFieldStyle(.roundedBorder)
                        .textContentType(.newPassword)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Confirm Password")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    SecureField("Repeat password", text: $confirmPassword)
                        .textFieldStyle(.roundedBorder)
                        .textContentType(.newPassword)
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

                Button(action: register) {
                    if isLoading {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Text("Sign Up")
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
        !email.isEmpty &&
        !password.isEmpty &&
        password == confirmPassword &&
        password.count >= 8
    }

    private func register() {
        guard password == confirmPassword else {
            errorMessage = "Passwords do not match"
            return
        }

        isLoading = true
        errorMessage = nil

        Task {
            do {
                let response = try await performRegistration()
                await MainActor.run {
                    authResponse = response
                    dismiss()
                }
            } catch let error as RegistrationError {
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

    private func performRegistration() async throws -> AuthResponse {
        let url = URL(string: "\(baseURL)/auth/register")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body = RegisterRequest(email: email, password: password)
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw RegistrationError(message: "Invalid response")
        }

        switch httpResponse.statusCode {
        case 201:
            return try JSONDecoder().decode(AuthResponse.self, from: data)
        case 409:
            let error = try JSONDecoder().decode(APIError.self, from: data)
            throw RegistrationError(message: error.detail)
        case 422:
            let error = try JSONDecoder().decode(ValidationError.self, from: data)
            let message = error.detail.first?.msg ?? "Validation error"
            throw RegistrationError(message: message)
        default:
            throw RegistrationError(message: "Server error: \(httpResponse.statusCode)")
        }
    }
}

struct RegistrationError: Error {
    let message: String
}
