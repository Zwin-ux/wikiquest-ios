import Foundation
import UserNotifications

@MainActor
final class ReminderStore: ObservableObject {
    @Published var statusText = "Daily reminder off"
    @Published var isEnabled = false
    @Published var lastError: String?

    private let dailyIdentifier = "wikiquest.daily-mystery.reminder"
    private let streakIdentifier = "wikiquest.streak.recovery.reminder"

    func enableDailyReminders() async {
        do {
            let center = UNUserNotificationCenter.current()
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            guard granted else {
                isEnabled = false
                statusText = "Notifications denied"
                return
            }
            try await scheduleDailyMystery(center: center)
            try await scheduleStreakRecovery(center: center)
            isEnabled = true
            statusText = "Daily reminder on"
            Haptics.success()
        } catch {
            lastError = error.localizedDescription
            statusText = "Reminder setup failed"
            Haptics.error()
        }
    }

    func disableDailyReminders() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: [dailyIdentifier, streakIdentifier]
        )
        isEnabled = false
        statusText = "Daily reminder off"
        Haptics.light()
    }

    private func scheduleDailyMystery(center: UNUserNotificationCenter) async throws {
        var date = DateComponents()
        date.hour = 9
        date.minute = 0
        let content = UNMutableNotificationContent()
        content.title = "Daily Mystery is open"
        content.body = "Six clues. One Wikipedia article."
        content.sound = .default
        content.categoryIdentifier = "wikiquest.daily"
        let request = UNNotificationRequest(
            identifier: dailyIdentifier,
            content: content,
            trigger: UNCalendarNotificationTrigger(dateMatching: date, repeats: true)
        )
        try await center.add(request)
    }

    private func scheduleStreakRecovery(center: UNUserNotificationCenter) async throws {
        var date = DateComponents()
        date.hour = 20
        date.minute = 0
        let content = UNMutableNotificationContent()
        content.title = "Keep the streak alive"
        content.body = "Finish today’s route before reset."
        content.sound = .default
        content.categoryIdentifier = "wikiquest.streak"
        let request = UNNotificationRequest(
            identifier: streakIdentifier,
            content: content,
            trigger: UNCalendarNotificationTrigger(dateMatching: date, repeats: true)
        )
        try await center.add(request)
    }
}
