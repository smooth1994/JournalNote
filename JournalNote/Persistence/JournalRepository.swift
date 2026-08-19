//
//  JournalRepository.swift
//  JournalNote
//

import Foundation
import WCDBSwift

enum JournalRepositoryError: LocalizedError {
    case databaseUnavailable

    var errorDescription: String? {
        "手账暂时无法保存，请稍后再试。"
    }
}

/// The single persistence boundary for the app. Journal records and appearance
/// settings both live in WCDB; controllers never write to local files directly.
final class JournalRepository {
    static let shared = JournalRepository()

    private let entriesTableName = "journal_entries"
    private let settingsTableName = "journal_settings"
    private var database: Database?
    private var entriesTable: Table<JournalEntry>?
    private var settingsTable: Table<JournalSetting>?

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
            entriesTable = database.getTable(named: entriesTableName, of: JournalEntry.self)
            settingsTable = database.getTable(named: settingsTableName, of: JournalSetting.self)
            insertFirstRunExamplesIfNeeded()
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
        NotificationCenter.default.post(name: .journalEntriesDidChange, object: nil)
    }

    func delete(_ entry: JournalEntry) throws {
        guard let entriesTable else { throw JournalRepositoryError.databaseUnavailable }
        try entriesTable.delete(where: JournalEntry.CodingKeys.id == entry.id)
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

    private func insertFirstRunExamplesIfNeeded() {
        guard allEntries(includeDrafts: true).isEmpty else { return }

        let calendar = Calendar.current
        let today = Date()
        let examples: [JournalEntry] = [
            JournalEntry(
                title: "午后的雷阵雨",
                body: "雨点砸在遮阳棚上，像小时候外婆家的夏天。什么也没做，但觉得这一天很满。",
                mood: .thoughtful,
                tags: ["日常", "雨天"],
                createdAt: today
            ),
            JournalEntry(
                title: "巷口的老书店",
                body: "老板还记得我去年找的那本诗集，说给我留了一本九成新的。旧时光的味道，大概就是纸页发黄的香气。",
                mood: .calm,
                tags: ["日常", "旧物"],
                createdAt: calendar.date(byAdding: .day, value: -1, to: today) ?? today
            ),
            JournalEntry(
                title: "给妈妈打了电话",
                body: "她说家里的栀子开了，让我中秋一定回去。电话挂断后，房间里忽然安静得像一只被放轻的杯子。",
                mood: .missing,
                tags: ["家人", "想念"],
                createdAt: calendar.date(byAdding: .day, value: -3, to: today) ?? today
            )
        ]

        guard let entriesTable else { return }
        do {
            for entry in examples {
                try entriesTable.insert(entry)
            }
        } catch {
            assertionFailure("WCDB example data error: \(error)")
        }
    }
}
