//
//  JournalDesign.swift
//  JournalNote
//
//  Shared design tokens for the Shiguang Journal interface.
//

import UIKit

enum JournalThemeMode: String {
    case light
    case night

    var interfaceStyle: UIUserInterfaceStyle {
        switch self {
        case .light: return .light
        case .night: return .dark
        }
    }
}

enum JournalDesign {
    // MARK: Paper

    static let paper50 = UIColor(hex: "#FBF7EF")
    static let paper100 = UIColor(hex: "#F7F1E5")
    static let paper200 = UIColor(hex: "#EFE6D2")
    static let paper300 = UIColor(hex: "#E4D7BC")

    // MARK: Ink

    static let ink900 = UIColor(hex: "#3A3128")
    static let ink700 = UIColor(hex: "#57493C")
    static let ink500 = UIColor(hex: "#8A7B69")
    static let ink300 = UIColor(hex: "#B9AC98")

    // MARK: Accent

    static let amber500 = UIColor(hex: "#B87B4B")
    static let amber600 = UIColor(hex: "#A06636")
    static let amber100 = UIColor(hex: "#F3E3CE")
    static let sage500 = UIColor(hex: "#93A084")
    static let rose500 = UIColor(hex: "#C08879")
    static let mist500 = UIColor(hex: "#8CA0AC")
    static let clay500 = UIColor(hex: "#B5533C")
    static let expiredRed = UIColor(hex: "#C24A34")
    static let expiredBackground = UIColor(hex: "#FBEDE8")
    static let lockedGray = UIColor(hex: "#D8CFBE")
    static let lockedBackground = UIColor(hex: "#F1EDE4")
    static let gold = UIColor(hex: "#D4A056")

    // MARK: Night lamp mode

    static let nightBackground = UIColor(hex: "#221D17")
    static let nightCard = UIColor(hex: "#2E2820")
    static let nightInk = UIColor(hex: "#E8DFD0")
    static let nightAmber = UIColor(hex: "#D29A66")

    static let pageBackground = UIColor { trait in
        trait.userInterfaceStyle == .dark ? nightBackground : paper50
    }
    static let cardBackground = UIColor { trait in
        trait.userInterfaceStyle == .dark ? nightCard : paper100
    }
    static let secondaryBackground = UIColor { trait in
        trait.userInterfaceStyle == .dark ? UIColor(hex: "#383024") : paper200
    }
    static let primaryText = UIColor { trait in
        trait.userInterfaceStyle == .dark ? nightInk : ink900
    }
    static let bodyText = UIColor { trait in
        trait.userInterfaceStyle == .dark ? UIColor(hex: "#C9BDAA") : ink700
    }
    static let secondaryText = UIColor { trait in
        trait.userInterfaceStyle == .dark ? UIColor(hex: "#9A8D7A") : ink500
    }
    static let separator = UIColor { trait in
        trait.userInterfaceStyle == .dark ? UIColor(hex: "#443B2E") : paper300
    }
    static let accent = UIColor { trait in
        trait.userInterfaceStyle == .dark ? nightAmber : amber500
    }

    static let smallCorner: CGFloat = 8
    static let cardCorner: CGFloat = 14
    static let panelCorner: CGFloat = 20

    static func serifFont(size: CGFloat, textStyle: UIFont.TextStyle = .body, weight: UIFont.Weight = .regular) -> UIFont {
        let base = UIFont(name: "Songti SC", size: size) ?? UIFont.systemFont(ofSize: size, weight: weight)
        return UIFontMetrics(forTextStyle: textStyle).scaledFont(for: base)
    }

    static func handwrittenFont(size: CGFloat, textStyle: UIFont.TextStyle = .body) -> UIFont {
        let base = UIFont(name: "STXingkai", size: size) ?? UIFont.italicSystemFont(ofSize: size)
        return UIFontMetrics(forTextStyle: textStyle).scaledFont(for: base)
    }

    static func monoFont(size: CGFloat, textStyle: UIFont.TextStyle = .caption1) -> UIFont {
        let base = UIFont.monospacedSystemFont(ofSize: size, weight: .regular)
        return UIFontMetrics(forTextStyle: textStyle).scaledFont(for: base)
    }

    static func configureNavigationBar() {
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = pageBackground
        appearance.shadowColor = .clear
        appearance.titleTextAttributes = [
            .foregroundColor: primaryText,
            .font: serifFont(size: 18, textStyle: .headline, weight: .semibold)
        ]
        appearance.largeTitleTextAttributes = [
            .foregroundColor: primaryText,
            .font: serifFont(size: 34, textStyle: .largeTitle, weight: .bold)
        ]
        UINavigationBar.appearance().standardAppearance = appearance
        UINavigationBar.appearance().scrollEdgeAppearance = appearance
        UINavigationBar.appearance().compactAppearance = appearance
        UINavigationBar.appearance().tintColor = accent
    }
}

extension UIColor {
    convenience init(hex: String, alpha: CGFloat = 1) {
        var normalized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if normalized.hasPrefix("#") {
            normalized.removeFirst()
        }

        var value: UInt64 = 0
        Scanner(string: normalized).scanHexInt64(&value)
        self.init(
            red: CGFloat((value >> 16) & 0xFF) / 255,
            green: CGFloat((value >> 8) & 0xFF) / 255,
            blue: CGFloat(value & 0xFF) / 255,
            alpha: alpha
        )
    }
}

extension UIView {
    func applyJournalCard(cornerRadius: CGFloat = JournalDesign.cardCorner) {
        backgroundColor = JournalDesign.cardBackground
        layer.cornerRadius = cornerRadius
        layer.cornerCurve = .continuous
        layer.borderWidth = 1
        layer.borderColor = JournalDesign.separator.cgColor
        layer.shadowColor = JournalDesign.ink900.cgColor
        layer.shadowOpacity = 0.08
        layer.shadowOffset = CGSize(width: 0, height: 7)
        layer.shadowRadius = 14
    }

    func applyJournalSoftCard(cornerRadius: CGFloat = JournalDesign.cardCorner) {
        backgroundColor = JournalDesign.cardBackground
        layer.cornerRadius = cornerRadius
        layer.cornerCurve = .continuous
        layer.borderWidth = 1
        layer.borderColor = JournalDesign.separator.cgColor
    }
}

extension Notification.Name {
    static let journalEntriesDidChange = Notification.Name("journalEntriesDidChange")
    static let journalThemeDidChange = Notification.Name("journalThemeDidChange")
    static let checkInDidChange = Notification.Name("checkInDidChange")
    static let badgeUnlocked = Notification.Name("badgeUnlocked")
    static let futureLettersDidChange = Notification.Name("futureLettersDidChange")
    static let planTasksDidChange = Notification.Name("planTasksDidChange")
}
