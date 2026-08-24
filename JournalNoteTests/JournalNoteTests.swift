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

    @Test func monthlyMakeupLimitIsTen() {
        #expect(JournalRepository.monthlyMakeupLimit == 10)
    }

    @Test func syncPayloadRoundTripsJournalEntry() throws {
        let entry = JournalEntry(title: "局域网同步", body: "另一台设备也能看到。", mood: .calm, tags: ["同步"])
        let payload = JournalSyncPayload(
            entries: [JournalSyncEntry(entry)],
            checkIns: [],
            futureLetters: [],
            themeMode: JournalThemeMode.light.rawValue,
            unlockedBadgeIDs: []
        )
        let data = try JSONEncoder().encode(payload)
        let decoded = try JSONDecoder().decode(JournalSyncPayload.self, from: data)
        let restored = try #require(decoded.entries.first?.makeEntry())

        #expect(decoded.version == JournalSyncPayload.currentVersion)
        #expect(restored.id == entry.id)
        #expect(restored.title == entry.title)
        #expect(restored.body == entry.body)
        #expect(restored.tags == entry.tags)
    }

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
        #expect(titles == ["时光轴", "日历", "我的"])
        #expect(controller.viewControllers?[2].tabBarItem.image != nil)

        let rootControllers = controller.viewControllers?
            .compactMap { $0 as? UINavigationController }
            .compactMap(\.viewControllers.first) ?? []
        rootControllers.forEach { $0.loadViewIfNeeded() }
        #expect(rootControllers.allSatisfy { $0.navigationItem.largeTitleDisplayMode == .never })
    }

    @Test @MainActor func badgeCenterIsAvailableFromProfile() {
        let profile = ProfileViewController()
        let navigationController = UINavigationController(rootViewController: profile)
        profile.loadViewIfNeeded()

        let badgeButton = allSubviews(in: profile.view)
            .compactMap { $0 as? UIButton }
            .first { $0.title(for: .normal) == "徽章中心" }
        #expect(badgeButton != nil)

        badgeButton?.sendActions(for: .touchUpInside)
        #expect(navigationController.topViewController is BadgeViewController)
    }

    @Test @MainActor func profileProvidesDataSyncActionsAndReceiveStartsLocked() {
        let profile = ProfileViewController()
        profile.loadViewIfNeeded()
        let buttonTitles = allSubviews(in: profile.view)
            .compactMap { ($0 as? UIButton)?.title(for: .normal) }
        #expect(buttonTitles.contains("导出数据"))
        #expect(buttonTitles.contains("接收数据"))

        let receive = DataReceiveViewController()
        receive.loadViewIfNeeded()
        let acknowledgeButton = allSubviews(in: receive.view)
            .compactMap { $0 as? UIButton }
            .first { $0.title(for: .normal) == "我知道了" }
        #expect(acknowledgeButton?.isEnabled == false)
    }

    @MainActor
    private func allSubviews(in view: UIView) -> [UIView] {
        view.subviews + view.subviews.flatMap(allSubviews)
    }

}
