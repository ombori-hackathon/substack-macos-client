import SwiftUI

struct CategoryManagementView: View {
    let accessToken: String
    @Environment(\.dismiss) private var dismiss

    @State private var categories: [Category] = []
    @State private var availableIcons: [String] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var customCount = 0
    @State private var maxCustomAllowed = 20

    @State private var showCreateSheet = false
    @State private var showEditSheet = false
    @State private var selectedCategory: Category?

    private let baseURL = "http://localhost:8000"

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Manage Categories")
                    .font(.title2)
                    .fontWeight(.semibold)
                Spacer()
                Button("Done") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
            }
            .padding()

            Divider()

            if isLoading {
                Spacer()
                ProgressView("Loading categories...")
                Spacer()
            } else if let error = errorMessage {
                Spacer()
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle)
                        .foregroundStyle(.orange)
                    Text(error)
                        .foregroundStyle(.secondary)
                    Button("Retry") {
                        Task { await loadCategories() }
                    }
                    .buttonStyle(.bordered)
                }
                Spacer()
            } else {
                // Category list
                List {
                    Section("System Categories") {
                        ForEach(categories.filter { $0.isSystem }) { category in
                            CategoryRow(category: category, onEdit: {
                                selectedCategory = category
                                showEditSheet = true
                            })
                        }
                    }

                    Section {
                        ForEach(categories.filter { !$0.isSystem }) { category in
                            CategoryRow(category: category, onEdit: {
                                selectedCategory = category
                                showEditSheet = true
                            }, onDelete: {
                                Task { await deleteCategory(category) }
                            })
                        }
                    } header: {
                        HStack {
                            Text("Custom Categories")
                            Spacer()
                            Text("\(customCount)/\(maxCustomAllowed)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .listStyle(.inset)

                Divider()

                // Add button
                HStack {
                    Spacer()
                    Button {
                        showCreateSheet = true
                    } label: {
                        Label("Add Category", systemImage: "plus")
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(customCount >= maxCustomAllowed)
                    Spacer()
                }
                .padding()
            }
        }
        .frame(minWidth: 400, minHeight: 500)
        .onAppear {
            Task {
                await loadCategories()
                await loadAvailableIcons()
            }
        }
        .sheet(isPresented: $showCreateSheet) {
            CategoryFormView(
                mode: .create,
                accessToken: accessToken,
                availableIcons: availableIcons,
                onSave: {
                    Task { await loadCategories() }
                }
            )
        }
        .sheet(isPresented: $showEditSheet) {
            if let category = selectedCategory {
                CategoryFormView(
                    mode: .edit(category),
                    accessToken: accessToken,
                    availableIcons: availableIcons,
                    onSave: {
                        Task { await loadCategories() }
                    }
                )
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

            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                throw CategoryError(message: "Failed to load categories")
            }

            let categoryResponse = try JSONDecoder().decode(CategoryListResponse.self, from: data)

            await MainActor.run {
                categories = categoryResponse.items
                customCount = categoryResponse.customCount
                maxCustomAllowed = categoryResponse.maxCustomAllowed
                isLoading = false
            }
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
                isLoading = false
            }
        }
    }

    private func loadAvailableIcons() async {
        do {
            let url = URL(string: "\(baseURL)/categories/icons")!
            var request = URLRequest(url: url)
            request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                return
            }

            let iconResponse = try JSONDecoder().decode(AvailableIconsResponse.self, from: data)

            await MainActor.run {
                availableIcons = iconResponse.icons
            }
        } catch {
            // Silently fail - icons will use a default set
        }
    }

    private func deleteCategory(_ category: Category) async {
        do {
            let url = URL(string: "\(baseURL)/categories/\(category.id)")!
            var request = URLRequest(url: url)
            request.httpMethod = "DELETE"
            request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

            let (_, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 204 else {
                throw CategoryError(message: "Failed to delete category")
            }

            await loadCategories()
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
            }
        }
    }
}

struct CategoryRow: View {
    let category: Category
    var onEdit: (() -> Void)?
    var onDelete: (() -> Void)?

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: category.icon)
                .font(.title2)
                .foregroundStyle(category.swiftUIColor)
                .frame(width: 30)

            VStack(alignment: .leading, spacing: 2) {
                Text(category.name)
                    .fontWeight(.medium)
                if category.subscriptionCount > 0 {
                    Text("\(category.subscriptionCount) subscription\(category.subscriptionCount == 1 ? "" : "s")")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            if category.isSystem {
                Text("System")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.secondary.opacity(0.1))
                    .clipShape(Capsule())
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .contextMenu {
            Button {
                onEdit?()
            } label: {
                Label("Edit", systemImage: "pencil")
            }

            if !category.isSystem {
                Divider()
                Button(role: .destructive) {
                    onDelete?()
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
        }
    }
}

enum CategoryFormMode {
    case create
    case edit(Category)
}

struct CategoryFormView: View {
    let mode: CategoryFormMode
    let accessToken: String
    let availableIcons: [String]
    let onSave: () -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var selectedIcon = "folder"
    @State private var selectedColor = Color.gray

    @State private var isLoading = false
    @State private var errorMessage: String?

    private let baseURL = "http://localhost:8000"

    private var isSystemCategory: Bool {
        if case .edit(let category) = mode {
            return category.isSystem
        }
        return false
    }

    private var title: String {
        switch mode {
        case .create: return "New Category"
        case .edit: return "Edit Category"
        }
    }

    private var isFormValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text(title)
                    .font(.title3)
                    .fontWeight(.semibold)
                Spacer()
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
            }
            .padding()

            Divider()

            Form {
                if !isSystemCategory {
                    TextField("Name", text: $name)
                        .textFieldStyle(.roundedBorder)
                }

                Section("Icon") {
                    LazyVGrid(columns: Array(repeating: GridItem(.fixed(44)), count: 8), spacing: 8) {
                        ForEach(availableIcons.isEmpty ? defaultIcons : availableIcons, id: \.self) { icon in
                            Button {
                                selectedIcon = icon
                            } label: {
                                Image(systemName: icon)
                                    .font(.title2)
                                    .frame(width: 40, height: 40)
                                    .background(selectedIcon == icon ? selectedColor.opacity(0.2) : Color.clear)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(selectedIcon == icon ? selectedColor : .secondary)
                        }
                    }
                }

                Section("Color") {
                    ColorPicker("Category Color", selection: $selectedColor)
                }

                // Preview
                Section("Preview") {
                    HStack(spacing: 12) {
                        Image(systemName: selectedIcon)
                            .font(.title)
                            .foregroundStyle(selectedColor)
                            .frame(width: 40)
                        Text(name.isEmpty ? "Category Name" : name)
                            .fontWeight(.medium)
                            .foregroundStyle(name.isEmpty ? .secondary : .primary)
                    }
                    .padding(.vertical, 8)
                }

                if let error = errorMessage {
                    Section {
                        HStack {
                            Image(systemName: "exclamationmark.triangle")
                                .foregroundStyle(.red)
                            Text(error)
                                .foregroundStyle(.red)
                        }
                    }
                }
            }
            .formStyle(.grouped)

            Divider()

            HStack {
                Spacer()
                Button("Save") {
                    Task { await saveCategory() }
                }
                .buttonStyle(.borderedProminent)
                .disabled(!isFormValid || isLoading)
                .keyboardShortcut(.defaultAction)
            }
            .padding()
        }
        .frame(width: 450, height: 500)
        .onAppear {
            if case .edit(let category) = mode {
                name = category.name
                selectedIcon = category.icon
                selectedColor = category.swiftUIColor
            }
        }
    }

    private var defaultIcons: [String] {
        [
            "play.tv.fill", "laptopcomputer", "heart.fill", "creditcard.fill",
            "book.fill", "cart.fill", "ellipsis.circle.fill", "star.fill",
            "gamecontroller.fill", "music.note", "film.fill", "folder.fill",
            "gearshape.fill", "message.fill", "envelope.fill", "cloud.fill"
        ]
    }

    private func saveCategory() async {
        isLoading = true
        errorMessage = nil

        do {
            switch mode {
            case .create:
                try await createCategory()
            case .edit(let category):
                try await updateCategory(id: category.id)
            }

            await MainActor.run {
                onSave()
                dismiss()
            }
        } catch let error as CategoryError {
            await MainActor.run {
                errorMessage = error.message
                isLoading = false
            }
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
                isLoading = false
            }
        }
    }

    private func createCategory() async throws {
        let url = URL(string: "\(baseURL)/categories")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        let body = CategoryCreate(
            name: name.trimmingCharacters(in: .whitespaces),
            icon: selectedIcon,
            color: selectedColor.toHex()
        )
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw CategoryError(message: "Invalid response")
        }

        switch httpResponse.statusCode {
        case 201:
            return
        case 400:
            let error = try JSONDecoder().decode(APIError.self, from: data)
            throw CategoryError(message: error.detail)
        case 409:
            let error = try JSONDecoder().decode(APIError.self, from: data)
            throw CategoryError(message: error.detail)
        case 422:
            let error = try JSONDecoder().decode(ValidationError.self, from: data)
            throw CategoryError(message: error.detail.first?.msg ?? "Validation error")
        default:
            throw CategoryError(message: "Server error: \(httpResponse.statusCode)")
        }
    }

    private func updateCategory(id: Int) async throws {
        let url = URL(string: "\(baseURL)/categories/\(id)")!
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        let body = CategoryUpdate(
            name: isSystemCategory ? nil : name.trimmingCharacters(in: .whitespaces),
            icon: selectedIcon,
            color: selectedColor.toHex()
        )
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw CategoryError(message: "Invalid response")
        }

        switch httpResponse.statusCode {
        case 200:
            return
        case 400:
            let error = try JSONDecoder().decode(APIError.self, from: data)
            throw CategoryError(message: error.detail)
        case 409:
            let error = try JSONDecoder().decode(APIError.self, from: data)
            throw CategoryError(message: error.detail)
        case 422:
            let error = try JSONDecoder().decode(ValidationError.self, from: data)
            throw CategoryError(message: error.detail.first?.msg ?? "Validation error")
        default:
            throw CategoryError(message: "Server error: \(httpResponse.statusCode)")
        }
    }
}
