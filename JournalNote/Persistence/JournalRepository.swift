//
//  JournalRepository.swift
//  JournalNote
//

import Foundation
import WCDBSwift
import UserNotifications

enum JournalRepositoryError: LocalizedError {
    case databaseUnavailable
    case planTaskDateReadOnly
    case planTaskUnavailable

    var errorDescription: String? {
        switch self {
        case .databaseUnavailable: return "手账暂时无法保存，请稍后再试。"
        case .planTaskDateReadOnly: return "只有今天的任务可以勾选。"
        case .planTaskUnavailable: return "这个任务已经暂停或不属于当天。"
        }
    }
}

/// The single persistence boundary for the app. Journal records and appearance
/// settings both live in WCDB; controllers never write to local files directly.
final class JournalRepository {
    static let shared = JournalRepository()
    static let monthlyMakeupLimit = 10

    private let entriesTableName = "journal_entries"
    private let settingsTableName = "journal_settings"
    private let checkInsTableName = "check_in_records"
    private let futureLettersTableName = "future_letters"
    private let legacyExamplesCleanupKey = "legacy_examples_cleaned_v1"
    private let onboardingCompletedKey = "has_completed_onboarding_v1"
    private let onboardingLastShownKey = "onboarding_last_shown_at_v1"
    private let onboardingInterval: TimeInterval = 12 * 60 * 60
    private let unlockedBadgesKey = "unlocked_badge_ids_v1"
    private let planTasksKey = "plan_tasks_v2"
    private let planInstancesKey = "plan_task_instances_v2"
    private var database: Database?
    private var entriesTable: Table<JournalEntry>?
    private var settingsTable: Table<JournalSetting>?
    private var checkInsTable: Table<CheckInRecord>?
    private var futureLettersTable: Table<FutureLetter>?

    private init() {}

    func prepare() {
        guard database == nil else { return }

        guard let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return
        }

        let databaseURL = documentsURL.appendingPathComponent("ShiguangJournal.db")
        let database = Database(at: databaseURL.path)
        self.database = database

        do {
            try database.create(table: entriesTableName, of: JournalEntry.self)
            try database.create(table: settingsTableName, of: JournalSetting.self)
            try database.create(table: checkInsTableName, of: CheckInRecord.self)
            try database.create(table: futureLettersTableName, of: FutureLetter.self)
            entriesTable = database.getTable(named: entriesTableName, of: JournalEntry.self)
            settingsTable = database.getTable(named: settingsTableName, of: JournalSetting.self)
            checkInsTable = database.getTable(named: checkInsTableName, of: CheckInRecord.self)
            futureLettersTable = database.getTable(named: futureLettersTableName, of: FutureLetter.self)
            removeLegacyExamplesIfNeeded()
        } catch {
            assertionFailure("WCDB setup error: \(error)")
        }
    }

    func allEntries(includeDrafts: Bool = false) -> [JournalEntry] {
        guard let entriesTable else { return [] }

        do {
            let entries = try entriesTable.getObjects(on: JournalEntry.Properties.all)
            return entries
                .filter { includeDrafts || !$0.isDraft }
                .sorted { $0.createdAt > $1.createdAt }
        } catch {
            assertionFailure("WCDB read error: \(error)")
            return []
        }
    }

    func entry(id: String) -> JournalEntry? {
        allEntries(includeDrafts: true).first { $0.id == id }
    }

    func entries(on date: Date, calendar: Calendar = .current) -> [JournalEntry] {
        allEntries().filter { calendar.isDate($0.createdAt, inSameDayAs: date) }
    }

    func save(_ entry: JournalEntry) throws {
        guard let entriesTable else { throw JournalRepositoryError.databaseUnavailable }

        let existing = allEntries(includeDrafts: true).contains { $0.id == entry.id }
        if existing {
            try entriesTable.delete(where: JournalEntry.CodingKeys.id == entry.id)
        }
        try entriesTable.insert(entry)
        if !entry.isDraft {
            try autoCheckInForEntry(entry)
        }
        NotificationCenter.default.post(name: .journalEntriesDidChange, object: nil)
        BadgeManager.shared.checkAndUnlockBadges()
    }

    func delete(_ entry: JournalEntry) throws {
        guard let entriesTable else { throw JournalRepositoryError.databaseUnavailable }
        try entriesTable.delete(where: JournalEntry.CodingKeys.id == entry.id)
        if let checkInsTable,
           let record = checkInForDate(entry.createdAt),
           record.journalEntryId == entry.id {
            if let replacement = entries(on: entry.createdAt).first {
                record.journalEntryId = replacement.id
                try saveCheckIn(record)
            } else {
                try checkInsTable.delete(where: CheckInRecord.CodingKeys.id == record.id)
                NotificationCenter.default.post(name: .checkInDidChange, object: nil)
            }
        }
        NotificationCenter.default.post(name: .journalEntriesDidChange, object: nil)
    }

    func themeMode() -> JournalThemeMode {
        guard let settingsTable else { return .light }

        do {
            let settings = try settingsTable.getObjects(on: JournalSetting.Properties.all)
            let value = settings.first(where: { $0.key == "theme_mode" })?.value
            return JournalThemeMode(rawValue: value ?? "") ?? .light
        } catch {
            return .light
        }
    }

    func saveThemeMode(_ mode: JournalThemeMode) throws {
        guard let settingsTable else { throw JournalRepositoryError.databaseUnavailable }

        let existing = try settingsTable.getObjects(on: JournalSetting.Properties.all)
        if existing.contains(where: { $0.key == "theme_mode" }) {
            try settingsTable.delete(where: JournalSetting.CodingKeys.key == "theme_mode")
        }
        try settingsTable.insert(JournalSetting(key: "theme_mode", value: mode.rawValue))
        NotificationCenter.default.post(name: .journalThemeDidChange, object: mode)
    }

    func hasCompletedOnboarding() -> Bool {
        guard let settingsTable else { return false }

        do {
            let settings = try settingsTable.getObjects(on: JournalSetting.Properties.all)
            return settings.first(where: { $0.key == onboardingCompletedKey })?.value == "1"
        } catch {
            assertionFailure("WCDB onboarding read error: \(error)")
            return false
        }
    }

    /// Returns true on first launch, then only after the 12-hour welcome-page interval.
    func shouldShowOnboarding(now: Date = Date()) -> Bool {
        guard let settingsTable else { return true }

        do {
            let settings = try settingsTable.getObjects(on: JournalSetting.Properties.all)
            guard let value = settings.first(where: { $0.key == onboardingLastShownKey })?.value,
                  let timestamp = TimeInterval(value) else {
                return true
            }
            return now.timeIntervalSince1970 - timestamp >= onboardingInterval
        } catch {
            assertionFailure("WCDB onboarding schedule read error: \(error)")
            return true
        }
    }

    func markOnboardingShown(at date: Date = Date()) throws {
        guard let settingsTable else { throw JournalRepositoryError.databaseUnavailable }

        try settingsTable.delete(where: JournalSetting.CodingKeys.key == onboardingLastShownKey)
        try settingsTable.insert(
            JournalSetting(key: onboardingLastShownKey, value: String(date.timeIntervalSince1970))
        )
    }

    func markOnboardingCompleted() throws {
        guard let settingsTable else { throw JournalRepositoryError.databaseUnavailable }

        try settingsTable.delete(where: JournalSetting.CodingKeys.key == onboardingCompletedKey)
        try settingsTable.insert(JournalSetting(key: onboardingCompletedKey, value: "1"))
    }

    func monthlyEntries(for date: Date, calendar: Calendar = .current) -> [JournalEntry] {
        guard let interval = calendar.dateInterval(of: .month, for: date) else { return [] }
        return allEntries().filter { interval.contains($0.createdAt) }
    }

    func moodCounts(for entries: [JournalEntry]) -> [JournalMood: Int] {
        entries.reduce(into: [:]) { counts, entry in
            counts[entry.mood, default: 0] += 1
        }
    }

    func consecutiveDays(upTo date: Date = Date(), calendar: Calendar = .current) -> Int {
        let recordDays = Set(allEntries().map { calendar.startOfDay(for: $0.createdAt) })
        var cursor = calendar.startOfDay(for: date)
        var result = 0

        while recordDays.contains(cursor) {
            result += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = previous
        }
        return result
    }

    private func removeLegacyExamplesIfNeeded() {
        guard let settingsTable, let entriesTable else { return }

        do {
            let settings = try settingsTable.getObjects(on: JournalSetting.Properties.all)
            guard !settings.contains(where: { $0.key == legacyExamplesCleanupKey }) else { return }

            let legacyExamples = [
                (title: "午后的雷阵雨", body: "雨点砸在遮阳棚上，像小时候外婆家的夏天。什么也没做，但觉得这一天很满。"),
                (title: "巷口的老书店", body: "老板还记得我去年找的那本诗集，说给我留了一本九成新的。旧时光的味道，大概就是纸页发黄的香气。"),
                (title: "给妈妈打了电话", body: "她说家里的栀子开了，让我中秋一定回去。电话挂断后，房间里忽然安静得像一只被放轻的杯子。")
            ]
            let entries = try entriesTable.getObjects(on: JournalEntry.Properties.all)
            for entry in entries where legacyExamples.contains(where: { $0.title == entry.title && $0.body == entry.body }) {
                try entriesTable.delete(where: JournalEntry.CodingKeys.id == entry.id)
            }
            try settingsTable.insert(JournalSetting(key: legacyExamplesCleanupKey, value: "1"))
        } catch {
            assertionFailure("WCDB legacy data cleanup error: \(error)")
        }
    }

    // MARK: - Check-In Records

    func checkInForDate(_ date: Date, calendar: Calendar = .current) -> CheckInRecord? {
        guard let checkInsTable else { return nil }
        let dayStart = calendar.startOfDay(for: date)
        do {
            let records = try checkInsTable.getObjects(on: CheckInRecord.Properties.all)
            return records.first { record in
                let recordDayStart = calendar.startOfDay(for: record.date)
                return recordDayStart == dayStart
            }
        } catch {
            assertionFailure("WCDB check-in read error: \(error)")
            return nil
        }
    }

    func saveCheckIn(_ record: CheckInRecord) throws {
        guard let checkInsTable else { throw JournalRepositoryError.databaseUnavailable }

        let existing = checkInForDate(record.date)
        if let existing = existing {
            try checkInsTable.delete(where: CheckInRecord.CodingKeys.id == existing.id)
        }
        try checkInsTable.insert(record)
        NotificationCenter.default.post(name: .checkInDidChange, object: nil)
    }

    func checkInDates(in month: Date, calendar: Calendar = .current) -> Set<Date> {
        guard let checkInsTable,
              let interval = calendar.dateInterval(of: .month, for: month) else {
            return []
        }

        do {
            let records = try checkInsTable.getObjects(on: CheckInRecord.Properties.all)
            return Set(records
                .filter { interval.contains($0.date) }
                .map { calendar.startOfDay(for: $0.date) })
        } catch {
            assertionFailure("WCDB check-in dates read error: \(error)")
            return []
        }
    }

    func currentStreak(calendar: Calendar = .current) -> Int {
        guard let checkInsTable else { return 0 }

        do {
            let records = try checkInsTable.getObjects(on: CheckInRecord.Properties.all)
            let checkInDays = Set(records.map { calendar.startOfDay(for: $0.date) })

            var cursor = calendar.startOfDay(for: Date())
            var streak = 0

            while checkInDays.contains(cursor) {
                streak += 1
                guard let previous = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
                cursor = previous
            }

            return streak
        } catch {
            assertionFailure("WCDB streak calculation error: \(error)")
            return 0
        }
    }

    func checkInCount(in month: Date, calendar: Calendar = .current) -> Int {
        checkInDates(in: month, calendar: calendar).count
    }

    func longestCheckInStreak(in month: Date, calendar: Calendar = .current) -> Int {
        let days = checkInDates(in: month, calendar: calendar).sorted()
        guard !days.isEmpty else { return 0 }
        var longest = 1
        var current = 1
        for index in 1..<days.count {
            if let previous = calendar.date(byAdding: .day, value: 1, to: days[index - 1]),
               calendar.isDate(previous, inSameDayAs: days[index]) {
                current += 1
                longest = max(longest, current)
            } else {
                current = 1
            }
        }
        return longest
    }

    func makeupCount(in month: Date, calendar: Calendar = .current) -> Int {
        guard let interval = calendar.dateInterval(of: .month, for: month),
              let checkInsTable else {
            return 0
        }

        do {
            let records = try checkInsTable.getObjects(on: CheckInRecord.Properties.all)
            return records.filter { interval.contains($0.date) && $0.isMakeup }.count
        } catch {
            assertionFailure("WCDB makeup count error: \(error)")
            return 0
        }
    }

    func makeupCountThisMonth(calendar: Calendar = .current) -> Int {
        makeupCount(in: Date(), calendar: calendar)
    }

    func canMakeup(for date: Date, calendar: Calendar = .current) -> Bool {
        let dayStart = calendar.startOfDay(for: date)
        let today = calendar.startOfDay(for: Date())

        // 只能补签过去的日期
        guard dayStart < today else { return false }

        // 已经打卡的日期不能补签
        guard checkInForDate(date, calendar: calendar) == nil else { return false }

        // 每月限制2次
        return makeupCount(in: date, calendar: calendar) < Self.monthlyMakeupLimit
    }

    func autoCheckInForEntry(_ entry: JournalEntry, calendar: Calendar = .current) throws {
        let dayStart = calendar.startOfDay(for: entry.createdAt)
        guard checkInForDate(dayStart, calendar: calendar) == nil else { return }

        let record = CheckInRecord(date: dayStart, journalEntryId: entry.id, isMakeup: false)
        try saveCheckIn(record)
    }

    func unlockedBadgeIDs() -> [String] {
        guard let settingsTable else { return [] }
        do {
            let settings = try settingsTable.getObjects(on: JournalSetting.Properties.all)
            guard let value = settings.first(where: { $0.key == unlockedBadgesKey })?.value,
                  let data = value.data(using: .utf8),
                  let ids = try? JSONDecoder().decode([String].self, from: data) else { return [] }
            return ids
        } catch { return [] }
    }

    func saveUnlockedBadgeIDs(_ ids: [String]) throws {
        guard let settingsTable else { throw JournalRepositoryError.databaseUnavailable }
        let data = try JSONEncoder().encode(ids.sorted())
        guard let value = String(data: data, encoding: .utf8) else { return }
        try settingsTable.delete(where: JournalSetting.CodingKeys.key == unlockedBadgesKey)
        try settingsTable.insert(JournalSetting(key: unlockedBadgesKey, value: value))
    }

    // MARK: - Plan tasks

    func allPlanTasks(includePaused: Bool = false) -> [PlanTask] {
        let tasks: [PlanTask] = readSettingJSON(forKey: planTasksKey) ?? []
        return tasks
            .filter { includePaused || !$0.isPaused }
            .sorted { ($0.createdAt, $0.title) < ($1.createdAt, $1.title) }
    }

    func planTask(id: String) -> PlanTask? {
        allPlanTasks(includePaused: true).first { $0.id == id }
    }

    @discardableResult
    func savePlanTask(_ task: PlanTask) throws -> PlanTask {
        var tasks = allPlanTasks(includePaused: true)
        var value = task
        value.updatedAt = Date()
        if let index = tasks.firstIndex(where: { $0.id == value.id }) {
            tasks[index] = value
        } else {
            tasks.append(value)
        }
        try writeSettingJSON(tasks, forKey: planTasksKey)
        schedulePlanReminder(for: value)
        postPlanChange()
        return value
    }

    func deletePlanTask(_ task: PlanTask) throws {
        try deletePlanTask(task, from: Date())
    }

    func deletePlanTask(_ task: PlanTask, from date: Date, calendar: Calendar = .current) throws {
        var tasks = allPlanTasks(includePaused: true)
        if let index = tasks.firstIndex(where: { $0.id == task.id }) {
            tasks[index].endDate = calendar.startOfDay(for: date)
            tasks[index].updatedAt = Date()
        }
        try writeSettingJSON(tasks, forKey: planTasksKey)
        removePlanReminder(for: task)
        postPlanChange()
    }

    func setPlanTaskPaused(_ task: PlanTask, paused: Bool, from date: Date = Date(), calendar: Calendar = .current) throws {
        if !paused, task.isPaused {
            var tasks = allPlanTasks(includePaused: true)
            guard let index = tasks.firstIndex(where: { $0.id == task.id }) else { return }
            let effectiveDate = calendar.startOfDay(for: date)
            var archived = tasks[index]
            archived.isPaused = false
            archived.endDate = effectiveDate
            archived.updatedAt = Date()
            tasks[index] = archived

            var resumed = task
            resumed.id = UUID().uuidString
            resumed.anchorDate = effectiveDate
            resumed.createdAt = Date()
            resumed.updatedAt = resumed.createdAt
            resumed.isPaused = false
            resumed.pauseDate = nil
            resumed.endDate = nil
            tasks.append(resumed)
            try writeSettingJSON(tasks, forKey: planTasksKey)
            removePlanReminder(for: archived)
            schedulePlanReminder(for: resumed)
            postPlanChange()
            return
        }
        var updated = task
        updated.isPaused = paused
        updated.pauseDate = paused ? calendar.startOfDay(for: date) : nil
        _ = try savePlanTask(updated)
    }

    /// Creates a new revision from the selected day onward, preserving the archived revision.
    func replacePlanTask(_ task: PlanTask, effectiveFrom date: Date, calendar: Calendar = .current) throws {
        var tasks = allPlanTasks(includePaused: true)
        guard let index = tasks.firstIndex(where: { $0.id == task.id }) else {
            _ = try savePlanTask(task)
            return
        }
        let effectiveDate = calendar.startOfDay(for: date)
        var archived = tasks[index]
        archived.endDate = effectiveDate
        archived.updatedAt = Date()
        tasks[index] = archived

        var revision = task
        revision.id = UUID().uuidString
        revision.anchorDate = effectiveDate
        revision.createdAt = Date()
        revision.updatedAt = revision.createdAt
        revision.isPaused = false
        revision.pauseDate = nil
        revision.endDate = nil
        tasks.append(revision)
        try writeSettingJSON(tasks, forKey: planTasksKey)
        removePlanReminder(for: archived)
        schedulePlanReminder(for: revision)

        var instances = planTaskInstancesStorage()
        if calendar.isDateInToday(effectiveDate), let old = instances.first(where: { $0.taskID == task.id && calendar.isDate($0.date, inSameDayAs: effectiveDate) }) {
            instances.append(PlanTaskInstance(taskID: revision.id, date: effectiveDate, done: old.done, doneAt: old.doneAt, calendar: calendar))
            try writeSettingJSON(instances, forKey: planInstancesKey)
        }
        postPlanChange()
    }

    /// Returns lazily-generated instances for active tasks matching the date.
    func planTaskInstances(for date: Date, calendar: Calendar = .current) -> [PlanTaskInstance] {
        let day = calendar.startOfDay(for: date)
        let stored = planTaskInstancesStorage()
        return allPlanTasks(includePaused: true).compactMap { task in
            guard task.occurs(on: day, calendar: calendar) else { return nil }
            return stored.first(where: { $0.taskID == task.id && calendar.isDate($0.date, inSameDayAs: day) })
                ?? PlanTaskInstance(taskID: task.id, date: day, calendar: calendar)
        }
    }

    func allPlanTaskInstances() -> [PlanTaskInstance] {
        planTaskInstancesStorage()
    }

    func planTaskInstance(taskID: String, date: Date, calendar: Calendar = .current) -> PlanTaskInstance? {
        planTaskInstances(for: date, calendar: calendar).first { $0.taskID == taskID }
    }

    /// Completing a task is deliberately restricted to the local current day.
    @discardableResult
    func setPlanTaskDone(taskID: String, on date: Date, done: Bool, calendar: Calendar = .current) throws -> PlanTaskInstance {
        let day = calendar.startOfDay(for: date)
        guard calendar.isDateInToday(day) else { throw JournalRepositoryError.planTaskDateReadOnly }
        guard let task = planTask(id: taskID), task.occurs(on: day, calendar: calendar) else {
            throw JournalRepositoryError.planTaskUnavailable
        }

        var instances = planTaskInstancesStorage()
        let index = instances.firstIndex { $0.taskID == taskID && calendar.isDate($0.date, inSameDayAs: day) }
        var instance = PlanTaskInstance(taskID: taskID, date: day, done: done, doneAt: done ? Date() : nil, calendar: calendar)
        if let index {
            instance = instances[index]
            instance.done = done
            instance.doneAt = done ? (instance.doneAt ?? Date()) : nil
            instances[index] = instance
        } else {
            instances.append(instance)
        }
        try writeSettingJSON(instances, forKey: planInstancesKey)
        postPlanChange()
        BadgeManager.shared.checkAndUnlockBadges()
        return instance
    }

    func planCompletion(for date: Date = Date(), calendar: Calendar = .current) -> (completed: Int, total: Int) {
        let instances = planTaskInstances(for: date, calendar: calendar)
        return (instances.filter(\.done).count, instances.count)
    }

    func planHasIncompleteTasks(on date: Date = Date(), calendar: Calendar = .current) -> Bool {
        let result = planCompletion(for: date, calendar: calendar)
        return result.total > result.completed
    }

    func consecutivePlanCompletion(upTo date: Date = Date(), calendar: Calendar = .current) -> Int {
        var cursor = calendar.startOfDay(for: date)
        var count = 0
        while true {
            let completion = planCompletion(for: cursor, calendar: calendar)
            guard completion.total > 0, completion.completed == completion.total else { break }
            count += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = previous
        }
        return count
    }

    private func planTaskInstancesStorage() -> [PlanTaskInstance] {
        readSettingJSON(forKey: planInstancesKey) ?? []
    }

    private func readSettingJSON<T: Decodable>(forKey key: String) -> T? {
        guard let settingsTable else { return nil }
        do {
            let settings = try settingsTable.getObjects(on: JournalSetting.Properties.all)
            guard let value = settings.first(where: { $0.key == key })?.value,
                  let data = value.data(using: .utf8) else { return nil }
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            assertionFailure("WCDB plan setting read error: \(error)")
            return nil
        }
    }

    private func writeSettingJSON<T: Encodable>(_ value: T, forKey key: String) throws {
        guard let settingsTable else { throw JournalRepositoryError.databaseUnavailable }
        let data = try JSONEncoder().encode(value)
        guard let string = String(data: data, encoding: .utf8) else { throw JournalRepositoryError.databaseUnavailable }
        try settingsTable.delete(where: JournalSetting.CodingKeys.key == key)
        try settingsTable.insert(JournalSetting(key: key, value: string))
    }

    private func postPlanChange() {
        NotificationCenter.default.post(name: .planTasksDidChange, object: nil)
    }

    private func schedulePlanReminder(for task: PlanTask) {
        guard task.reminderEnabled, let hour = task.reminderHour, let minute = task.reminderMinute else {
            removePlanReminder(for: task)
            return
        }
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound]) { granted, _ in
            guard granted else { return }
            let content = UNMutableNotificationContent()
            content.title = "计划提醒"
            content.body = task.title
            content.sound = .default
            var components = DateComponents()
            components.hour = hour
            components.minute = minute
            if task.rule == .once {
                components.year = Calendar.current.component(.year, from: task.anchorDate)
                components.month = Calendar.current.component(.month, from: task.anchorDate)
                components.day = Calendar.current.component(.day, from: task.anchorDate)
            } else if task.rule == .custom || task.rule == .weekdays || task.rule == .weekends {
                // One request per weekday keeps repeating reminders aligned with the task rule.
                let weekdays = task.rule == .custom ? task.weekdays : (1...7).filter { task.rule.includes(weekday: $0) }
                for weekday in weekdays {
                    components.weekday = weekday
                    let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
                    center.add(UNNotificationRequest(identifier: "plan-\(task.id)-\(weekday)", content: content, trigger: trigger))
                }
                return
            }
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: task.rule != .once)
            center.add(UNNotificationRequest(identifier: "plan-\(task.id)", content: content, trigger: trigger))
        }
    }

    private func removePlanReminder(for task: PlanTask) {
        let ids = ["plan-\(task.id)"] + (1...7).map { "plan-\(task.id)-\($0)" }
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ids)
    }

    // MARK: - Future Mailbox

    /// Returns letters in the order in which they are scheduled to open.
    func futureLetters() -> [FutureLetter] {
        guard let futureLettersTable else { return [] }
        do {
            return try futureLettersTable
                .getObjects(on: FutureLetter.Properties.all)
                .map { letter in
                    do {
                        letter.body = try FutureLetterCipher.decrypt(letter.body)
                    } catch {
                        // Keep the ciphertext intact so a transient Keychain error never overwrites it.
                    }
                    return letter
                }
                .sorted { $0.openAt < $1.openAt }
        } catch {
            assertionFailure("WCDB future letter read error: \(error)")
            return []
        }
    }

    func saveFutureLetter(_ letter: FutureLetter) throws {
        guard let futureLettersTable else { throw JournalRepositoryError.databaseUnavailable }

        let existing = futureLetters().contains { $0.id == letter.id }
        if existing {
            try futureLettersTable.delete(where: FutureLetter.CodingKeys.id == letter.id)
        }
        let plainText = letter.body
        letter.body = try FutureLetterCipher.encrypt(plainText)
        defer { letter.body = plainText }
        try futureLettersTable.insert(letter)
        NotificationCenter.default.post(name: .futureLettersDidChange, object: nil)
    }

    // MARK: - Local Network Sync

    func makeSyncPayload() throws -> JournalSyncPayload {
        guard let checkInsTable, let futureLettersTable else { throw JournalRepositoryError.databaseUnavailable }
        let records = try checkInsTable.getObjects(on: CheckInRecord.Properties.all)
        let letters = try futureLettersTable
            .getObjects(on: FutureLetter.Properties.all)
            .map { letter in
                letter.body = try FutureLetterCipher.decrypt(letter.body)
                return JournalSyncLetter(letter)
            }
        return JournalSyncPayload(
            entries: allEntries(includeDrafts: true).map(JournalSyncEntry.init),
            checkIns: records.map(JournalSyncCheckIn.init),
            futureLetters: letters,
            themeMode: themeMode().rawValue,
            unlockedBadgeIDs: unlockedBadgeIDs(),
            planTasks: allPlanTasks(includePaused: true),
            planTaskInstances: allPlanTaskInstances()
        )
    }

    /// Merges a remote snapshot by stable IDs. Existing local data is kept when
    /// it is newer, so receiving on either device is safe to repeat.
    func mergeSyncPayload(_ payload: JournalSyncPayload) throws {
        guard (1...JournalSyncPayload.currentVersion).contains(payload.version),
              let entriesTable,
              let checkInsTable,
              let futureLettersTable else {
            throw JournalRepositoryError.databaseUnavailable
        }

        let localEntries = Dictionary(uniqueKeysWithValues: allEntries(includeDrafts: true).map { ($0.id, $0) })
        for item in payload.entries {
            if let local = localEntries[item.id], local.updatedAt > item.updatedAt { continue }
            try entriesTable.delete(where: JournalEntry.CodingKeys.id == item.id)
            try entriesTable.insert(item.makeEntry())
        }

        for item in payload.checkIns {
            let incoming = item.makeRecord()
            if let local = checkInForDate(incoming.date), local.createdAt >= incoming.createdAt { continue }
            if let local = checkInForDate(incoming.date) {
                try checkInsTable.delete(where: CheckInRecord.CodingKeys.id == local.id)
            }
            try checkInsTable.delete(where: CheckInRecord.CodingKeys.id == incoming.id)
            try checkInsTable.insert(incoming)
        }

        let localLetters = Dictionary(uniqueKeysWithValues: futureLetters().map { ($0.id, $0) })
        for item in payload.futureLetters {
            if let local = localLetters[item.id], local.createdAt > item.createdAt { continue }
            let letter = item.makeLetter()
            letter.body = try FutureLetterCipher.encrypt(letter.body)
            try futureLettersTable.delete(where: FutureLetter.CodingKeys.id == letter.id)
            try futureLettersTable.insert(letter)
        }

        if let mode = JournalThemeMode(rawValue: payload.themeMode) {
            try saveThemeMode(mode)
        }
        let mergedBadgeIDs = Set(unlockedBadgeIDs()).union(payload.unlockedBadgeIDs)
        try saveUnlockedBadgeIDs(Array(mergedBadgeIDs))
        if !payload.planTasks.isEmpty {
            var localTasks = allPlanTasks(includePaused: true)
            for incoming in payload.planTasks {
                if let index = localTasks.firstIndex(where: { $0.id == incoming.id }) {
                    if localTasks[index].updatedAt < incoming.updatedAt { localTasks[index] = incoming }
                } else {
                    localTasks.append(incoming)
                }
            }
            try writeSettingJSON(localTasks, forKey: planTasksKey)
        }
        if !payload.planTaskInstances.isEmpty {
            var localInstances = planTaskInstancesStorage()
            for incoming in payload.planTaskInstances {
                if let index = localInstances.firstIndex(where: { $0.id == incoming.id }) {
                    let localDate = localInstances[index].doneAt ?? .distantPast
                    let incomingDate = incoming.doneAt ?? .distantPast
                    if incomingDate > localDate { localInstances[index] = incoming }
                } else {
                    localInstances.append(incoming)
                }
            }
            try writeSettingJSON(localInstances, forKey: planInstancesKey)
        }
        NotificationCenter.default.post(name: .journalEntriesDidChange, object: nil)
        NotificationCenter.default.post(name: .checkInDidChange, object: nil)
        NotificationCenter.default.post(name: .futureLettersDidChange, object: nil)
        postPlanChange()
        BadgeManager.shared.checkAndUnlockBadges()
    }
}
