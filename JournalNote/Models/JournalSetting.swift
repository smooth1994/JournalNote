//
//  JournalSetting.swift
//  JournalNote
//

import Foundation
import WCDBSwift

final class JournalSetting: TableCodable {
    var key: String = ""
    var value: String = ""

    enum CodingKeys: String, CodingTableKey {
        typealias Root = JournalSetting

        case key
        case value

        static let objectRelationalMapping = TableBinding(CodingKeys.self) {
            BindColumnConstraint(key, isPrimary: true)
            BindColumnConstraint(value, isNotNull: true, defaultTo: "")
        }
    }

    init() {}

    init(key: String, value: String) {
        self.key = key
        self.value = value
    }
}
