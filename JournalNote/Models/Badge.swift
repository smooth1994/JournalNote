//
//  Badge.swift
//  JournalNote
//

import Foundation

enum BadgeSeries: String, Codable, CaseIterable {
    case persistence = "坚持系列"
    case time = "时光系列"
    case mood = "心情系列"
}

enum BadgeCondition: Codable {
    case consecutiveDays(Int)
    case totalEntries(Int)
    case moodCount(String, Int)
    case entriesInMonth(Int)

    var targetValue: Int {
        switch self {
        case .consecutiveDays(let days): return days
        case .totalEntries(let count): return count
        case .moodCount(_, let count): return count
        case .entriesInMonth(let count): return count
        }
    }
}

struct Badge: Codable {
    let id: String
    let series: BadgeSeries
    let emoji: String
    let name: String
    let description: String
    let unlockCondition: BadgeCondition

    static let allBadges: [Badge] = [
        // 坚持系列
        Badge(
            id: "first_entry",
            series: .persistence,
            emoji: "✍️",
            name: "初次落笔",
            description: "完成第一篇手账",
            unlockCondition: .totalEntries(1)
        ),
        Badge(
            id: "seven_days",
            series: .persistence,
            emoji: "🔥",
            name: "七日不辍",
            description: "连续打卡 7 天",
            unlockCondition: .consecutiveDays(7)
        ),
        Badge(
            id: "one_month",
            series: .persistence,
            emoji: "📅",
            name: "一月有成",
            description: "连续打卡 30 天",
            unlockCondition: .consecutiveDays(30)
        ),
        Badge(
            id: "four_seasons",
            series: .persistence,
            emoji: "🌸",
            name: "四季流转",
            description: "连续打卡 100 天",
            unlockCondition: .consecutiveDays(100)
        ),
        Badge(
            id: "one_year",
            series: .persistence,
            emoji: "🎊",
            name: "年度拾光",
            description: "连续打卡 365 天",
            unlockCondition: .consecutiveDays(365)
        ),
        Badge(
            id: "morning_habit",
            series: .persistence,
            emoji: "🌅",
            name: "晨间习惯",
            description: "累计记录 50 篇",
            unlockCondition: .totalEntries(50)
        ),
        Badge(
            id: "persistence_100_entries",
            series: .persistence,
            emoji: "📚",
            name: "百篇成册",
            description: "累计记录 100 篇",
            unlockCondition: .totalEntries(100)
        ),
        Badge(
            id: "persistence_500_entries",
            series: .persistence,
            emoji: "🏛️",
            name: "笔耕不息",
            description: "累计记录 500 篇",
            unlockCondition: .totalEntries(500)
        ),
        Badge(
            id: "persistence_1000_entries",
            series: .persistence,
            emoji: "👑",
            name: "千篇传记",
            description: "累计记录 1000 篇",
            unlockCondition: .totalEntries(1000)
        ),
        Badge(
            id: "thousand_days",
            series: .persistence,
            emoji: "🌟",
            name: "千日如一",
            description: "连续打卡 1000 天",
            unlockCondition: .consecutiveDays(1000)
        ),

        // 时光系列
        Badge(
            id: "time_10",
            series: .time,
            emoji: "⏰",
            name: "时光收集者",
            description: "累计记录 10 篇",
            unlockCondition: .totalEntries(10)
        ),
        Badge(
            id: "time_30",
            series: .time,
            emoji: "📖",
            name: "故事编织者",
            description: "累计记录 30 篇",
            unlockCondition: .totalEntries(30)
        ),
        Badge(
            id: "time_50",
            series: .time,
            emoji: "🧵",
            name: "时光成章",
            description: "累计记录 50 篇",
            unlockCondition: .totalEntries(50)
        ),
        Badge(
            id: "time_100",
            series: .time,
            emoji: "✨",
            name: "记忆守护者",
            description: "累计记录 100 篇",
            unlockCondition: .totalEntries(100)
        ),
        Badge(
            id: "time_500",
            series: .time,
            emoji: "💫",
            name: "岁月长河",
            description: "累计记录 500 篇",
            unlockCondition: .totalEntries(500)
        ),
        Badge(
            id: "time_1000",
            series: .time,
            emoji: "🌌",
            name: "千里拾光",
            description: "累计记录 1000 篇",
            unlockCondition: .totalEntries(1000)
        ),
        Badge(
            id: "month_active",
            series: .time,
            emoji: "🗓",
            name: "月度活跃",
            description: "单月记录 20 篇",
            unlockCondition: .entriesInMonth(20)
        ),
        Badge(
            id: "month_50",
            series: .time,
            emoji: "🗓️",
            name: "月满而记",
            description: "单月记录 50 篇",
            unlockCondition: .entriesInMonth(50)
        ),
        Badge(
            id: "month_100",
            series: .time,
            emoji: "📆",
            name: "月度传奇",
            description: "单月记录 100 篇",
            unlockCondition: .entriesInMonth(100)
        ),

        // 心情系列
        Badge(
            id: "mood_happy",
            series: .mood,
            emoji: "😊",
            name: "快乐时光",
            description: "记录 10 次快乐心情",
            unlockCondition: .moodCount("happy", 10)
        ),
        Badge(
            id: "mood_happy_50",
            series: .mood,
            emoji: "😄",
            name: "快乐常在",
            description: "记录 50 次快乐心情",
            unlockCondition: .moodCount("happy", 50)
        ),
        Badge(
            id: "mood_happy_100",
            series: .mood,
            emoji: "🌞",
            name: "快乐满溢",
            description: "记录 100 次快乐心情",
            unlockCondition: .moodCount("happy", 100)
        ),
        Badge(
            id: "mood_happy_1000",
            series: .mood,
            emoji: "🌈",
            name: "快乐星河",
            description: "记录 1000 次快乐心情",
            unlockCondition: .moodCount("happy", 1000)
        ),
        Badge(
            id: "mood_calm",
            series: .mood,
            emoji: "🌿",
            name: "平静如水",
            description: "记录 10 次平静心情",
            unlockCondition: .moodCount("calm", 10)
        ),
        Badge(
            id: "mood_calm_50",
            series: .mood,
            emoji: "🍃",
            name: "心自安然",
            description: "记录 50 次平静心情",
            unlockCondition: .moodCount("calm", 50)
        ),
        Badge(
            id: "mood_calm_100",
            series: .mood,
            emoji: "🪷",
            name: "澄澈百日",
            description: "记录 100 次平静心情",
            unlockCondition: .moodCount("calm", 100)
        ),
        Badge(
            id: "mood_calm_1000",
            series: .mood,
            emoji: "🏞️",
            name: "静水深流",
            description: "记录 1000 次平静心情",
            unlockCondition: .moodCount("calm", 1000)
        ),
        Badge(
            id: "mood_thoughtful",
            series: .mood,
            emoji: "🌧",
            name: "雨夜思绪",
            description: "记录 10 次思绪心情",
            unlockCondition: .moodCount("thoughtful", 10)
        ),
        Badge(
            id: "mood_thoughtful_50",
            series: .mood,
            emoji: "🌦️",
            name: "思绪成诗",
            description: "记录 50 次思绪心情",
            unlockCondition: .moodCount("thoughtful", 50)
        ),
        Badge(
            id: "mood_thoughtful_100",
            series: .mood,
            emoji: "📝",
            name: "百转千回",
            description: "记录 100 次思绪心情",
            unlockCondition: .moodCount("thoughtful", 100)
        ),
        Badge(
            id: "mood_thoughtful_1000",
            series: .mood,
            emoji: "🌠",
            name: "思接千载",
            description: "记录 1000 次思绪心情",
            unlockCondition: .moodCount("thoughtful", 1000)
        ),
        Badge(
            id: "mood_missing",
            series: .mood,
            emoji: "🌙",
            name: "月下怀念",
            description: "记录 10 次怀念心情",
            unlockCondition: .moodCount("missing", 10)
        ),
        Badge(
            id: "mood_missing_50",
            series: .mood,
            emoji: "💌",
            name: "念念不忘",
            description: "记录 50 次怀念心情",
            unlockCondition: .moodCount("missing", 50)
        ),
        Badge(
            id: "mood_missing_100",
            series: .mood,
            emoji: "🌙",
            name: "月明长念",
            description: "记录 100 次怀念心情",
            unlockCondition: .moodCount("missing", 100)
        ),
        Badge(
            id: "mood_missing_1000",
            series: .mood,
            emoji: "⭐",
            name: "长情如星",
            description: "记录 1000 次怀念心情",
            unlockCondition: .moodCount("missing", 1000)
        ),
        Badge(
            id: "mood_reflective",
            series: .mood,
            emoji: "🍂",
            name: "秋日反思",
            description: "记录 10 次反思心情",
            unlockCondition: .moodCount("reflective", 10)
        ),
        Badge(
            id: "mood_reflective_50",
            series: .mood,
            emoji: "🍁",
            name: "回望有痕",
            description: "记录 50 次反思心情",
            unlockCondition: .moodCount("reflective", 50)
        ),
        Badge(
            id: "mood_reflective_100",
            series: .mood,
            emoji: "🔍",
            name: "百思有得",
            description: "记录 100 次反思心情",
            unlockCondition: .moodCount("reflective", 100)
        ),
        Badge(
            id: "mood_reflective_1000",
            series: .mood,
            emoji: "🧭",
            name: "明心见性",
            description: "记录 1000 次反思心情",
            unlockCondition: .moodCount("reflective", 1000)
        ),
    ]
}
