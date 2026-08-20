//
//  BadgeManager.swift
//  JournalNote
//

import Foundation

final class BadgeManager {
    static let shared = BadgeManager()

    private let unlockedBadgesKey = "unlocked_badge_ids"
    private var unlockedBadgeIDs: Set<String> = []

    private init() {
        loadUnlockedBadges()
    }

    // MARK: - Public Methods

    func allBadges() -> [Badge] {
        Badge.allBadges
    }

    func badges(forSeries series: BadgeSeries) -> [Badge] {
        Badge.allBadges.filter { $0.series == series }
    }

    func isUnlocked(_ badgeID: String) -> Bool {
        unlockedBadgeIDs.contains(badgeID)
    }

    func unlockedBadges() -> [Badge] {
        Badge.allBadges.filter { isUnlocked($0.id) }
    }

    func progressForBadge(_ badge: Badge) -> (current: Int, target: Int) {
        let target = badge.unlockCondition.targetValue
        let current: Int

        switch badge.unlockCondition {
        case .consecutiveDays:
            current = JournalRepository.shared.currentStreak()

        case .totalEntries:
            current = JournalRepository.shared.allEntries().count

        case .moodCount(let moodRaw, _):
            let entries = JournalRepository.shared.allEntries()
            current = entries.filter { $0.moodRawValue == moodRaw }.count

        case .entriesInMonth:
            current = JournalRepository.shared.monthlyEntries(for: Date()).count
        }

        return (current, target)
    }

    /// 检查并解锁符合条件的徽章，返回新解锁的徽章列表
    @discardableResult
    func checkAndUnlockBadges() -> [Badge] {
        var newlyUnlocked: [Badge] = []

        for badge in Badge.allBadges where !isUnlocked(badge.id) {
            let (current, target) = progressForBadge(badge)
            if current >= target {
                unlock(badge.id)
                newlyUnlocked.append(badge)
            }
        }

        if !newlyUnlocked.isEmpty {
            NotificationCenter.default.post(
                name: .badgeUnlocked,
                object: newlyUnlocked
            )
        }

        return newlyUnlocked
    }

    // MARK: - Private Methods

    private func loadUnlockedBadges() {
        if let data = UserDefaults.standard.array(forKey: unlockedBadgesKey) as? [String] {
            unlockedBadgeIDs = Set(data)
        }
    }

    private func saveUnlockedBadges() {
        UserDefaults.standard.set(Array(unlockedBadgeIDs), forKey: unlockedBadgesKey)
    }

    private func unlock(_ badgeID: String) {
        unlockedBadgeIDs.insert(badgeID)
        saveUnlockedBadges()
    }
}
