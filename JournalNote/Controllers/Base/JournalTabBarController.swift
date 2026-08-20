//
//  JournalTabBarController.swift
//  JournalNote
//

import UIKit

final class JournalTabBarController: UITabBarController {
    private var observers: [NSObjectProtocol] = []

    override func viewDidLoad() {
        super.viewDidLoad()
        JournalDesign.configureNavigationBar()
        configureControllers()
        applyPersistedTheme()
        observeApplicationChanges()
    }

    deinit {
        observers.forEach(NotificationCenter.default.removeObserver)
    }

    private func configureControllers() {
        let timeline = makeNavigationController(
            root: TimelineViewController(),
            title: "时光轴",
            image: "book.closed",
            selectedImage: "book.closed.fill"
        )
        let calendar = makeNavigationController(
            root: CalendarViewController(),
            title: "日历",
            image: "calendar",
            selectedImage: "calendar"
        )
        let badges = makeNavigationController(
            root: BadgeViewController(),
            title: "徽章",
            image: "medal",
            selectedImage: "medal.fill"
        )
        let profile = makeNavigationController(
            root: ProfileViewController(),
            title: "我的",
            image: "flame",
            selectedImage: "flame.fill"
        )
        viewControllers = [timeline, calendar, badges, profile]
    }

    private func makeNavigationController(
        root: UIViewController,
        title: String,
        image: String,
        selectedImage: String
    ) -> UINavigationController {
        root.tabBarItem = UITabBarItem(
            title: title,
            image: UIImage(systemName: image),
            selectedImage: UIImage(systemName: selectedImage)
        )
        let navigationController = UINavigationController(rootViewController: root)
        navigationController.navigationBar.prefersLargeTitles = true
        return navigationController
    }

    private func applyPersistedTheme() {
        overrideUserInterfaceStyle = JournalRepository.shared.themeMode().interfaceStyle
        configureTabBarAppearance()
    }

    private func configureTabBarAppearance() {
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = JournalDesign.cardBackground
        appearance.shadowColor = JournalDesign.separator

        let itemAppearance = appearance.stackedLayoutAppearance
        itemAppearance.normal.iconColor = JournalDesign.secondaryText
        itemAppearance.normal.titleTextAttributes = [
            .foregroundColor: JournalDesign.secondaryText,
            .font: JournalDesign.serifFont(size: 11, textStyle: .caption2)
        ]
        itemAppearance.selected.iconColor = JournalDesign.accent
        itemAppearance.selected.titleTextAttributes = [
            .foregroundColor: JournalDesign.accent,
            .font: JournalDesign.serifFont(size: 11, textStyle: .caption2, weight: .semibold)
        ]

        tabBar.standardAppearance = appearance
        tabBar.scrollEdgeAppearance = appearance
        tabBar.tintColor = JournalDesign.accent
        tabBar.unselectedItemTintColor = JournalDesign.secondaryText
    }

    private func observeApplicationChanges() {
        let themeObserver = NotificationCenter.default.addObserver(
            forName: .journalThemeDidChange,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self else { return }
            let mode = (notification.object as? JournalThemeMode) ?? JournalRepository.shared.themeMode()
            self.overrideUserInterfaceStyle = mode.interfaceStyle
            JournalDesign.configureNavigationBar()
            self.configureTabBarAppearance()
            self.view.setNeedsLayout()
        }
        observers.append(themeObserver)
    }
}
