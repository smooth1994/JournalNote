//
//  JournalNoteTests.swift
//  JournalNoteTests
//
//  Created by mac on 2026/8/19.
//

import Testing
import UIKit
@testable import JournalNote

struct JournalNoteTests {

    @Test func futureLetterContentIsEncryptedAndCanBeDecrypted() throws {
        let plainText = "写给未来的自己"
        let encrypted = try FutureLetterCipher.encrypt(plainText)

        #expect(encrypted != plainText)
        #expect(try FutureLetterCipher.decrypt(encrypted) == plainText)
    }

    @Test func badgeConfigurationHasUniqueIdentifiersAndAllSeries() {
        let badges = Badge.allBadges
        #expect(Set(badges.map(\.id)).count == badges.count)
        #expect(Set(badges.map(\.series)) == Set(BadgeSeries.allCases))

        for mood in JournalMood.allCases {
            let targets = badges.compactMap { badge -> Int? in
                guard case .moodCount(let moodRawValue, let target) = badge.unlockCondition,
                      moodRawValue == mood.rawValue else { return nil }
                return target
            }
            #expect(targets.sorted() == [10, 50, 100, 1000])
        }
    }

    @Test @MainActor func rootTabBarContainsV11Destinations() {
        let controller = JournalTabBarController()
        controller.loadViewIfNeeded()
        let titles = controller.viewControllers?.compactMap { $0.tabBarItem.title } ?? []
        #expect(titles == ["时光轴", "日历", "徽章", "我的"])
        #expect(controller.viewControllers?[2].tabBarItem.image != nil)
    }

}
