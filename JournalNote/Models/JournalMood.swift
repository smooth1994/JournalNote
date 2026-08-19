//
//  JournalMood.swift
//  JournalNote
//

import UIKit

enum JournalMood: String, CaseIterable {
    case happy
    case calm
    case thoughtful
    case missing
    case reflective

    var title: String {
        switch self {
        case .happy: return "开心"
        case .calm: return "平静"
        case .thoughtful: return "思绪"
        case .missing: return "想念"
        case .reflective: return "感怀"
        }
    }

    var emoji: String {
        switch self {
        case .happy: return "😊"
        case .calm: return "🌿"
        case .thoughtful: return "🌧"
        case .missing: return "🌙"
        case .reflective: return "🍂"
        }
    }

    var accentColor: UIColor {
        switch self {
        case .happy: return JournalDesign.amber500
        case .calm: return JournalDesign.sage500
        case .thoughtful: return JournalDesign.mist500
        case .missing: return JournalDesign.rose500
        case .reflective: return JournalDesign.clay500
        }
    }

    var tagTextColor: UIColor {
        switch self {
        case .happy: return JournalDesign.amber600
        case .calm: return UIColor(hex: "#5F7052")
        case .thoughtful: return UIColor(hex: "#5C707C")
        case .missing: return UIColor(hex: "#96604F")
        case .reflective: return UIColor(hex: "#8A3F2E")
        }
    }

    var softColor: UIColor {
        accentColor.withAlphaComponent(0.18)
    }
}
