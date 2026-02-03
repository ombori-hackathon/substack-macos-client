import Foundation
import UserNotifications

class NotificationManager: ObservableObject {
    @MainActor static let shared = NotificationManager()

    @MainActor @Published var isAuthorized = false

    @MainActor
    private init() {
        Task {
            await checkAuthorization()
        }
    }

    @MainActor
    func checkAuthorization() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        isAuthorized = settings.authorizationStatus == .authorized
    }

    @MainActor
    func requestAuthorization() async -> Bool {
        do {
            let granted = try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound, .badge])
            isAuthorized = granted
            return granted
        } catch {
            print("Notification authorization error: \(error)")
            return false
        }
    }

    @MainActor
    func scheduleRenewalReminder(
        subscriptionId: Int,
        subscriptionName: String,
        cost: String,
        renewalDate: Date,
        daysBeforeRenewal: Int
    ) async {
        if !isAuthorized {
            let granted = await requestAuthorization()
            if !granted { return }
        }

        // Remove any existing notification for this subscription
        let identifier = "renewal-\(subscriptionId)"
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: [identifier]
        )

        // Calculate trigger date (X days before renewal at 9 AM local time)
        let calendar = Calendar.current
        guard let triggerDate = calendar.date(
            byAdding: .day,
            value: -daysBeforeRenewal,
            to: renewalDate
        ) else { return }

        // Set to 9 AM
        var components = calendar.dateComponents(
            [.year, .month, .day],
            from: triggerDate
        )
        components.hour = 9
        components.minute = 0

        // Don't schedule if trigger date is in the past
        guard let scheduledDate = calendar.date(from: components),
              scheduledDate > Date()
        else { return }

        // Create notification content
        let content = UNMutableNotificationContent()
        content.title = "Subscription Renewal Reminder"
        content.body = "\(subscriptionName) (\(cost)) renews in \(daysBeforeRenewal) day\(daysBeforeRenewal == 1 ? "" : "s")"
        content.sound = .default
        content.categoryIdentifier = "RENEWAL_REMINDER"
        content.userInfo = ["subscriptionId": subscriptionId]

        // Create trigger
        let trigger = UNCalendarNotificationTrigger(
            dateMatching: components,
            repeats: false
        )

        // Create request
        let request = UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: trigger
        )

        do {
            try await UNUserNotificationCenter.current().add(request)
            print("Scheduled notification for \(subscriptionName) on \(scheduledDate)")
        } catch {
            print("Failed to schedule notification: \(error)")
        }
    }

    func cancelRenewalReminder(subscriptionId: Int) {
        let identifier = "renewal-\(subscriptionId)"
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: [identifier]
        )
    }

    func cancelAllReminders() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }

    func getPendingNotifications() async -> [UNNotificationRequest] {
        return await UNUserNotificationCenter.current().pendingNotificationRequests()
    }
}
