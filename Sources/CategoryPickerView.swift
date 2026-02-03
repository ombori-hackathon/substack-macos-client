import SwiftUI

struct CategoryPickerView: View {
    @Binding var selectedCategoryId: Int?
    let categories: [Category]
    let accessToken: String

    @State private var loadedCategories: [Category] = []
    @State private var isLoading = false
    @State private var errorMessage: String?

    private let baseURL = "http://localhost:8000"

    var displayCategories: [Category] {
        categories.isEmpty ? loadedCategories : categories
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if isLoading {
                HStack {
                    ProgressView()
                        .scaleEffect(0.7)
                    Text("Loading categories...")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else if let error = errorMessage {
                HStack {
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundStyle(.orange)
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else {
                Picker("Category", selection: $selectedCategoryId) {
                    Text("None")
                        .tag(nil as Int?)

                    ForEach(displayCategories) { category in
                        HStack(spacing: 6) {
                            Image(systemName: category.icon)
                                .foregroundStyle(category.swiftUIColor)
                            Text(category.name)
                        }
                        .tag(category.id as Int?)
                    }
                }
                .pickerStyle(.menu)
            }
        }
        .onAppear {
            if categories.isEmpty && loadedCategories.isEmpty {
                Task {
                    await loadCategories()
                }
            }
        }
    }

    private func loadCategories() async {
        isLoading = true
        errorMessage = nil

        do {
            let url = URL(string: "\(baseURL)/categories")!
            var request = URLRequest(url: url)
            request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw CategoryError(message: "Invalid response")
            }

            guard httpResponse.statusCode == 200 else {
                throw CategoryError(message: "Server error: \(httpResponse.statusCode)")
            }

            let categoryResponse = try JSONDecoder().decode(CategoryListResponse.self, from: data)

            await MainActor.run {
                loadedCategories = categoryResponse.items
                isLoading = false
            }
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
                isLoading = false
            }
        }
    }
}

struct CategoryError: Error {
    let message: String
}

