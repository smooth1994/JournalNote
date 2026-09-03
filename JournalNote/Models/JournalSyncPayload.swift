//
//  JournalSyncPayload.swift
//  JournalNote
//

import Foundation

/// A versioned, JSON-safe snapshot of the WCDB-backed journal data.
/// Device-specific onboarding timestamps are intentionally not included.
struct JournalSyncPayload: Codable {
    static let currentVersion = 2

    let version: Int
    let exportedAt: Date
    let entries: [JournalSyncEntry]
    let checkIns: [JournalSyncCheckIn]
    let futureLetters: [JournalSyncLetter]
    let themeMode: String
    let unlockedBadgeIDs: [String]
    let planTasks: [PlanTask]
    let planTaskInstances: [PlanTaskInstance]

    init(
        entries: [JournalSyncEntry],
        checkIns: [JournalSyncCheckIn],
        futureLetters: [JournalSyncLetter],
        themeMode: String,
        unlockedBadgeIDs: [String],
        planTasks: [PlanTask] = [],
        planTaskInstances: [PlanTaskInstance] = [],
        exportedAt: Date = Date()
    ) {
        version = Self.currentVersion
        self.exportedAt = exportedAt
        self.entries = entries
        self.checkIns = checkIns
        self.futureLetters = futureLetters
        self.themeMode = themeMode
        self.unlockedBadgeIDs = unlockedBadgeIDs
        self.planTasks = planTasks
        self.planTaskInstances = planTaskInstances
    }

    private enum CodingKeys: String, CodingKey {
        case version, exportedAt, entries, checkIns, futureLetters, themeMode, unlockedBadgeIDs, planTasks, planTaskInstances
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        version = try values.decode(Int.self, forKey: .version)
        exportedAt = try values.decode(Date.self, forKey: .exportedAt)
        entries = try values.decode([JournalSyncEntry].self, forKey: .entries)
        checkIns = try values.decode([JournalSyncCheckIn].self, forKey: .checkIns)
        futureLetters = try values.decode([JournalSyncLetter].self, forKey: .futureLetters)
        themeMode = try values.decode(String.self, forKey: .themeMode)
        unlockedBadgeIDs = try values.decode([String].self, forKey: .unlockedBadgeIDs)
        planTasks = try values.decodeIfPresent([PlanTask].self, forKey: .planTasks) ?? []
        planTaskInstances = try values.decodeIfPresent([PlanTaskInstance].self, forKey: .planTaskInstances) ?? []
    }
}

struct JournalSyncEntry: Codable {
    let id: String
    let title: String
    let body: String
    let moodRawValue: String
    let tags: String
    let createdAt: Date
    let updatedAt: Date
    let isDraft: Bool

    init(_ entry: JournalEntry) {
        id = entry.id
        title = entry.title
        body = entry.body
        moodRawValue = entry.moodRawValue
        tags = entry.tags
        createdAt = entry.createdAt
        updatedAt = entry.updatedAt
        isDraft = entry.isDraft
    }

    func makeEntry() -> JournalEntry {
        let entry = JournalEntry(
            title: title,
            body: body,
            mood: JournalMood(rawValue: moodRawValue) ?? .happy,
            tags: tags.split(separator: ",").map(String.init),
            createdAt: createdAt,
            isDraft: isDraft
        )
        entry.id = id
        entry.moodRawValue = moodRawValue
        entry.tags = tags
        entry.updatedAt = updatedAt
        return entry
    }
}

struct JournalSyncCheckIn: Codable {
    let id: String
    let date: Date
    let journalEntryId: String?
    let isMakeup: Bool
    let createdAt: Date

    init(_ record: CheckInRecord) {
        id = record.id
        date = record.date
        journalEntryId = record.journalEntryId
        isMakeup = record.isMakeup
        createdAt = record.createdAt
    }

    func makeRecord() -> CheckInRecord {
        let record = CheckInRecord(date: date, journalEntryId: journalEntryId, isMakeup: isMakeup)
        record.id = id
        record.createdAt = createdAt
        return record
    }
}

struct JournalSyncLetter: Codable {
    let id: String
    let body: String
    let openAt: Date
    let createdAt: Date
    let isOpened: Bool

    init(_ letter: FutureLetter) {
        id = letter.id
        body = letter.body
        openAt = letter.openAt
        createdAt = letter.createdAt
        isOpened = letter.isOpened
    }

    func makeLetter() -> FutureLetter {
        let letter = FutureLetter(body: body, openAt: openAt)
        letter.id = id
        letter.createdAt = createdAt
        letter.isOpened = isOpened
        return letter
    }
}
