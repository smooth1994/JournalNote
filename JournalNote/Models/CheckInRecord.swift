//
//  CheckInRecord.swift
//  JournalNote
//

import Foundation
import WCDBSwift

final class CheckInRecord: TableCodable {
    var id: String = UUID().uuidString
    var date: Date = Date()
    var journalEntryId: String?
    var isMakeup: Bool = false
    var createdAt: Date = Date()

    enum CodingKeys: String, CodingTableKey {
        typealias Root = CheckInRecord

        case id
        case date
        case journalEntryId
        case isMakeup
        case createdAt

        static let objectRelationalMapping = TableBinding(CodingKeys.self) {
            BindColumnConstraint(id, isPrimary: true)
            BindColumnConstraint(date, isNotNull: true)
            BindColumnConstraint(journalEntryId)
            BindColumnConstraint(isMakeup, isNotNull: true, defaultTo: false)
            BindColumnConstraint(createdAt, isNotNull: true, defaultTo: Date())
        }
    }

    init() {}

    init(date: Date, journalEntryId: String? = nil, isMakeup: Bool = false) {
        self.date = date
        self.journalEntryId = journalEntryId
        self.isMakeup = isMakeup
        self.createdAt = Date()
    }
}
