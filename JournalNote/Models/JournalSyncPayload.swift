//
//  JournalSyncPayload.swift
//  JournalNote
//

import Foundation

/// A versioned, JSON-safe snapshot of the WCDB-backed journal data.
/// Device-specific onboarding timestamps are intentionally not included.
struct JournalSyncPayload: Codable {
    static let currentVersion = 1

    let version: Int
    let exportedAt: Date
    let entries: [JournalSyncEntry]
    let checkIns: [JournalSyncCheckIn]
    let futureLetters: [JournalSyncLetter]
    let themeMode: String
    let unlockedBadgeIDs: [String]

    init(
        entries: [JournalSyncEntry],
        checkIns: [JournalSyncCheckIn],
        futureLetters: [JournalSyncLetter],
        themeMode: String,
        unlockedBadgeIDs: [String],
        exportedAt: Date = Date()
    ) {
        version = Self.currentVersion
        self.exportedAt = exportedAt
        self.entries = entries
        self.checkIns = checkIns
        self.futureLetters = futureLetters
        self.themeMode = themeMode
        self.unlockedBadgeIDs = unlockedBadgeIDs
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
