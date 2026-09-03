//
//  PlanTask.swift
//  JournalNote
//

import Foundation

/// The repeat rules presented by the V2.0 plan editor.
enum PlanTaskRule: String, Codable, CaseIterable {
    case once = "仅今天"
    case daily = "每天"
    case weekdays = "工作日"
    case weekends = "每周末"
    case custom = "自定义"

    var shortTitle: String { rawValue }

    var tagColor: (background: String, text: String) {
        switch self {
        case .daily: return ("#EEF0E7", "#6E7D5E")
        case .weekdays, .weekends, .custom: return ("#F5EBDD", "#A06636")
        case .once: return ("#F1EDE4", "#8A7B69")
        }
    }

    func includes(weekday: Int) -> Bool {
        switch self {
        case .once, .daily: return true
        case .weekdays: return (2...6).contains(weekday)
        case .weekends: return weekday == 1 || weekday == 7
        case .custom: return false
        }
    }
}

struct PlanTask: Codable, Identifiable, Equatable {
    var id: String
    var title: String
    var rule: PlanTaskRule
    /// Calendar weekday values use Apple's convention: Sunday = 1 ... Saturday = 7.
    var weekdays: [Int]
    var anchorDate: Date
    var reminderEnabled: Bool
    var reminderHour: Int?
    var reminderMinute: Int?
    var createdAt: Date
    var updatedAt: Date
    var isPaused: Bool
    var pauseDate: Date?
    var endDate: Date?

    init(
        id: String = UUID().uuidString,
        title: String,
        rule: PlanTaskRule = .once,
        weekdays: [Int] = [],
        anchorDate: Date = Date(),
        reminderEnabled: Bool = false,
        reminderHour: Int? = nil,
        reminderMinute: Int? = nil,
        createdAt: Date = Date(),
        isPaused: Bool = false,
        pauseDate: Date? = nil,
        endDate: Date? = nil
    ) {
        self.id = id
        self.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        self.rule = rule
        self.weekdays = Array(Set(weekdays.filter { (1...7).contains($0) })).sorted()
        self.anchorDate = anchorDate
        self.reminderEnabled = reminderEnabled
        self.reminderHour = reminderHour
        self.reminderMinute = reminderMinute
        self.createdAt = createdAt
        updatedAt = createdAt
        self.isPaused = isPaused
        self.pauseDate = pauseDate
        self.endDate = endDate
    }

    var displayRule: String {
        switch rule {
        case .custom:
            let symbols = [1: "日", 2: "一", 3: "二", 4: "三", 5: "四", 6: "五", 7: "六"]
            let text = weekdays.sorted().compactMap { symbols[$0] }.joined(separator: "、")
            return text.isEmpty ? "自定义" : "每周 \(text)"
        default: return rule.rawValue
        }
    }

    func occurs(on date: Date, calendar: Calendar = .current) -> Bool {
        let day = calendar.startOfDay(for: date)
        guard day >= calendar.startOfDay(for: anchorDate) else { return false }
        if let endDate, day >= calendar.startOfDay(for: endDate) { return false }
        if isPaused {
            guard let pauseDate else { return false }
            if day >= calendar.startOfDay(for: pauseDate) { return false }
        }
        if rule == .once { return calendar.isDate(day, inSameDayAs: anchorDate) }
        if rule == .custom { return weekdays.contains(calendar.component(.weekday, from: day)) }
        return rule.includes(weekday: calendar.component(.weekday, from: day))
    }
}

struct PlanTaskInstance: Codable, Identifiable, Equatable {
    let id: String
    let taskID: String
    let date: Date
    var done: Bool
    var doneAt: Date?

    init(taskID: String, date: Date, done: Bool = false, doneAt: Date? = nil, calendar: Calendar = .current) {
        self.taskID = taskID
        self.date = calendar.startOfDay(for: date)
        id = "\(taskID)|\(Int(self.date.timeIntervalSince1970))"
        self.done = done
        self.doneAt = doneAt
    }
}
