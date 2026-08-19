//
//  JournalEntry.swift
//  JournalNote
//

import Foundation
import WCDBSwift

final class JournalEntry: TableCodable {
    var id: String = UUID().uuidString
    var title: String = ""
    var body: String = ""
    var moodRawValue: String = JournalMood.happy.rawValue
    var tags: String = ""
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    var isDraft: Bool = false

    enum CodingKeys: String, CodingTableKey {
        typealias Root = JournalEntry

        case id
        case title
        case body
        case moodRawValue
        case tags
        case createdAt
        case updatedAt
        case isDraft

        static let objectRelationalMapping = TableBinding(CodingKeys.self) {
            BindColumnConstraint(id, isPrimary: true)
            BindColumnConstraint(title, isNotNull: true, defaultTo: "")
            BindColumnConstraint(body, isNotNull: true, defaultTo: "")
            BindColumnConstraint(moodRawValue, isNotNull: true, defaultTo: JournalMood.happy.rawValue)
            BindColumnConstraint(tags, isNotNull: true, defaultTo: "")
            BindColumnConstraint(createdAt, isNotNull: true, defaultTo: Date())
            BindColumnConstraint(updatedAt, isNotNull: true, defaultTo: Date())
            BindColumnConstraint(isDraft, isNotNull: true, defaultTo: false)
        }
    }

    init() {}

    init(title: String, body: String, mood: JournalMood, tags: [String], createdAt: Date = Date(), isDraft: Bool = false) {
        self.title = title
        self.body = body
        moodRawValue = mood.rawValue
        self.tags = tags.joined(separator: ",")
        self.createdAt = createdAt
        updatedAt = createdAt
        self.isDraft = isDraft
    }

    var mood: JournalMood {
        JournalMood(rawValue: moodRawValue) ?? .happy
    }

    var tagList: [String] {
        tags
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    var displayTitle: String {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "未命名的片段" : trimmed
    }

    var shortDateText: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "MM.dd · EEE"
        return formatter.string(from: createdAt).uppercased()
    }

    var timestampText: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "yyyy.MM.dd · EEE · HH:mm"
        return formatter.string(from: createdAt).uppercased()
    }

    var excerpt: String {
        let compact = body
            .split(whereSeparator: { $0.isNewline })
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard compact.count > 54 else { return compact }
        let index = compact.index(compact.startIndex, offsetBy: 54)
        return String(compact[..<index]) + "…"
    }
}
