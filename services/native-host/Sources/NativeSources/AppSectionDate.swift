import Foundation

/// Turns an app's group heading into the day it stands for. The headings are the app's own words, read in English; a
/// heading that is not understood gives no date, so the chat is listed without a time rather than under a wrong day.
enum AppSectionDate {
    private static let months = ["jan", "feb", "mar", "apr", "may", "jun", "jul", "aug", "sep", "oct", "nov", "dec"]

    /// Noon of the day the heading names, never later than `now`. Noon keeps it on that calendar day in any time zone shift.
    static func date(for section: String?, now: Date, calendar: Calendar = .current) -> Date? {
        guard let section else { return nil }
        let heading = section.trimmingCharacters(in: .whitespaces)
        switch heading.lowercased() {
        case "today": return now
        case "yesterday": return noon(daysBack: 1, from: now, calendar: calendar)
        default: break
        }
        let parts = heading.split(separator: " ")
        guard parts.count == 2, let month = months.firstIndex(of: parts[0].lowercased().prefix(3).description),
              let day = Int(parts[1]), (1...31).contains(day) else { return nil }
        var components = calendar.dateComponents([.year], from: now)
        components.month = month + 1
        components.day = day
        components.hour = 12
        guard var candidate = calendar.date(from: components) else { return nil }
        // "Dec 30" read in January means last year.
        if candidate > now, let previous = calendar.date(byAdding: .year, value: -1, to: candidate) { candidate = previous }
        return candidate
    }

    private static func noon(daysBack: Int, from now: Date, calendar: Calendar) -> Date? {
        guard let day = calendar.date(byAdding: .day, value: -daysBack, to: calendar.startOfDay(for: now)) else { return nil }
        return calendar.date(byAdding: .hour, value: 12, to: day)
    }
}
