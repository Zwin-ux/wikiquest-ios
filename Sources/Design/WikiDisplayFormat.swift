import Foundation

enum WikiDisplayFormat {
    static func todayLabel(now: Date = Date(), locale: Locale = .current) -> String {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.dateFormat = "EEEE, MMMM d"
        return formatter.string(from: now)
    }

    static func resetCountdown(now: Date = Date()) -> String {
        var calendar = Calendar(identifier: .gregorian)
        if let utc = TimeZone(secondsFromGMT: 0) {
            calendar.timeZone = utc
        }
        let startOfToday = calendar.startOfDay(for: now)
        guard let nextMidnight = calendar.date(byAdding: .day, value: 1, to: startOfToday) else {
            return "00:00:00"
        }
        let remaining = max(0, Int(nextMidnight.timeIntervalSince(now)))
        let hours = remaining / 3_600
        let minutes = (remaining % 3_600) / 60
        let seconds = remaining % 60
        return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }

    static func time(milliseconds: Int) -> String {
        let total = max(0, milliseconds / 1_000)
        return "\(total / 60):\(String(format: "%02d", total % 60))"
    }
}
