import SwiftUI

struct SubscriptionsTable: View {
    let subscriptions: [Subscription]
    let categories: [Category]
    let onEdit: (Subscription) -> Void
    let onDelete: (Subscription) -> Void
    let onCancel: (Subscription) -> Void
    let onReactivate: (Subscription) -> Void

    @State private var selection: Subscription.ID?

    private func categoryFor(_ subscription: Subscription) -> Category? {
        if let categoryId = subscription.categoryId {
            return categories.first { $0.id == categoryId }
        }
        return nil
    }

    var body: some View {
        Table(subscriptions, selection: $selection) {
            TableColumn("Name") { subscription in
                HStack(spacing: 6) {
                    Text(subscription.name)
                    if subscription.isCancelled {
                        Text("Cancelled")
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.orange.opacity(0.15))
                            .foregroundStyle(.orange)
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                    }
                }
            }
            .width(min: 100, ideal: 180)

            TableColumn("Cost") { subscription in
                Text(subscription.formattedCost)
                    .monospacedDigit()
            }
            .width(80)

            TableColumn("Cycle") { subscription in
                Text(subscription.billingCycle.capitalized)
            }
            .width(80)

            TableColumn("Next Billing") { subscription in
                if subscription.isCancelled {
                    if let effectiveDate = subscription.formattedEffectiveDate {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Ends")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            Text(effectiveDate)
                        }
                    } else {
                        Text("-")
                            .foregroundStyle(.tertiary)
                    }
                } else {
                    Text(subscription.formattedNextBillingDate)
                }
            }
            .width(120)

            TableColumn("Category") { subscription in
                if let category = categoryFor(subscription) {
                    HStack(spacing: 6) {
                        Image(systemName: category.icon)
                            .foregroundStyle(category.swiftUIColor)
                        Text(category.name)
                    }
                } else {
                    Text("-")
                        .foregroundStyle(.tertiary)
                }
            }
            .width(110)
        }
        .contextMenu(forSelectionType: Subscription.ID.self) { ids in
            if let id = ids.first, let sub = subscriptions.first(where: { $0.id == id }) {
                Button("Edit") {
                    onEdit(sub)
                }

                Divider()

                if sub.isCancelled {
                    Button {
                        onReactivate(sub)
                    } label: {
                        Label("Reactivate", systemImage: "arrow.uturn.backward")
                    }
                } else {
                    Button {
                        onCancel(sub)
                    } label: {
                        Label("Mark as Cancelled", systemImage: "xmark.circle")
                    }
                }

                Divider()

                Button("Delete", role: .destructive) {
                    onDelete(sub)
                }
            }
        } primaryAction: { ids in
            if let id = ids.first, let sub = subscriptions.first(where: { $0.id == id }) {
                onEdit(sub)
            }
        }
    }
}
