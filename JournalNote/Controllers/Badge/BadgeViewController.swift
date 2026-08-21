//
//  BadgeViewController.swift
//  JournalNote
//

import UIKit
import SnapKit

final class BadgeViewController: JournalBaseViewController {
    private let manager = BadgeManager.shared
    private let scrollView = UIScrollView()
    private let contentView = UIView()
    private let summaryLabel = UILabel()
    private let seriesControl = UISegmentedControl(items: BadgeSeries.allCases.map(\.rawValue))
    private let gridView = UICollectionView(frame: .zero, collectionViewLayout: UICollectionViewFlowLayout())
    private var gridHeightConstraint: Constraint?
    private var selectedSeries: BadgeSeries = .persistence

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "徽章"
        navigationItem.largeTitleDisplayMode = .always
        setupViews()
        reloadData()
        NotificationCenter.default.addObserver(self, selector: #selector(reloadData), name: .badgeUnlocked, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(reloadData), name: .journalEntriesDidChange, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(reloadData), name: .checkInDidChange, object: nil)
    }

    private func setupViews() {
        summaryLabel.font = JournalDesign.serifFont(size: 15, textStyle: .subheadline)
        summaryLabel.textColor = JournalDesign.secondaryText
        summaryLabel.textAlignment = .center
        summaryLabel.adjustsFontForContentSizeCategory = true

        seriesControl.selectedSegmentIndex = 0
        seriesControl.selectedSegmentTintColor = JournalDesign.accent
        seriesControl.setTitleTextAttributes([.foregroundColor: JournalDesign.bodyText], for: .normal)
        seriesControl.setTitleTextAttributes([.foregroundColor: JournalDesign.paper50], for: .selected)
        seriesControl.addTarget(self, action: #selector(seriesChanged), for: .valueChanged)
        seriesControl.accessibilityLabel = "徽章系列"

        let layout = gridView.collectionViewLayout as? UICollectionViewFlowLayout
        layout?.minimumLineSpacing = 18
        layout?.minimumInteritemSpacing = 8
        gridView.backgroundColor = .clear
        gridView.isScrollEnabled = false
        gridView.dataSource = self
        gridView.delegate = self
        gridView.register(BadgeCell.self, forCellWithReuseIdentifier: BadgeCell.reuseIdentifier)

        view.addSubview(scrollView)
        scrollView.addSubview(contentView)
        [summaryLabel, seriesControl, gridView].forEach { contentView.addSubview($0) }
        scrollView.snp.makeConstraints { make in make.edges.equalTo(view.safeAreaLayoutGuide) }
        contentView.snp.makeConstraints { make in make.edges.equalToSuperview(); make.width.equalTo(scrollView.snp.width) }
        summaryLabel.snp.makeConstraints { make in make.top.equalToSuperview().offset(14); make.leading.trailing.equalToSuperview().inset(20) }
        seriesControl.snp.makeConstraints { make in make.top.equalTo(summaryLabel.snp.bottom).offset(16); make.leading.trailing.equalToSuperview().inset(20); make.height.equalTo(34) }
        gridView.snp.makeConstraints { make in
            make.top.equalTo(seriesControl.snp.bottom).offset(22)
            make.leading.trailing.equalToSuperview().inset(20)
            gridHeightConstraint = make.height.equalTo(360).constraint
            make.bottom.equalToSuperview().inset(24)
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        gridView.layoutIfNeeded()
        let contentHeight = gridView.collectionViewLayout.collectionViewContentSize.height
        guard contentHeight > 0 else { return }
        let height = max(360, contentHeight)
        let currentHeight = gridHeightConstraint?.layoutConstraints.first?.constant ?? 0
        if abs(currentHeight - height) > 0.5 {
            gridHeightConstraint?.update(offset: height)
        }
    }

    @objc private func seriesChanged() {
        selectedSeries = BadgeSeries.allCases[seriesControl.selectedSegmentIndex]
        reloadData()
    }

    @objc private func reloadData() {
        let unlockedCount = manager.unlockedBadges().count
        summaryLabel.text = "已点亮 \(unlockedCount) 枚 · 共 \(manager.allBadges().count) 枚"
        gridView.reloadData()
        gridView.collectionViewLayout.invalidateLayout()
    }
}

extension BadgeViewController: UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    private var visibleBadges: [Badge] { manager.badges(forSeries: selectedSeries) }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int { visibleBadges.count }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: BadgeCell.reuseIdentifier, for: indexPath) as! BadgeCell
        let badge = visibleBadges[indexPath.item]
        let progress = manager.progressForBadge(badge)
        cell.configure(badge: badge, unlocked: manager.isUnlocked(badge.id), progress: progress)
        return cell
    }

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        let width = (collectionView.bounds.width - 16) / 3
        return CGSize(width: width, height: 132)
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let badge = visibleBadges[indexPath.item]
        let progress = manager.progressForBadge(badge)
        let unlocked = manager.isUnlocked(badge.id)
        let sourceCell = collectionView.cellForItem(at: indexPath)
        let detail = unlocked ? "已点亮 · 进度 \(progress.current)/\(progress.target)" : "进度 \(min(progress.current, progress.target))/\(progress.target)"
        let alert = UIAlertController(title: "\(badge.emoji)  \(badge.name)", message: "\(badge.description)\n\n\(detail)", preferredStyle: .actionSheet)
        if unlocked {
            alert.addAction(UIAlertAction(title: "分享徽章", style: .default) { [weak self] _ in
                let activity = UIActivityViewController(activityItems: ["我在拾光手账点亮了「\(badge.name)」徽章：\(badge.description)"], applicationActivities: nil)
                if let popover = activity.popoverPresentationController {
                    popover.sourceView = sourceCell ?? collectionView
                    popover.sourceRect = sourceCell?.bounds ?? collectionView.bounds
                }
                self?.present(activity, animated: true)
            })
        }
        alert.addAction(UIAlertAction(title: "知道了", style: .cancel))
        if let popover = alert.popoverPresentationController { popover.sourceView = collectionView; popover.sourceRect = sourceCell?.frame ?? .zero }
        present(alert, animated: true)
    }
}

private final class BadgeCell: UICollectionViewCell {
    static let reuseIdentifier = "BadgeCell"
    private let badgeView = UIView()
    private let emojiLabel = UILabel()
    private let lockLabel = UILabel()
    private let nameLabel = UILabel()
    private let progressLabel = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        contentView.addSubview(badgeView); badgeView.addSubview(emojiLabel); badgeView.addSubview(lockLabel); contentView.addSubview(nameLabel); contentView.addSubview(progressLabel)
        badgeView.snp.makeConstraints { make in make.top.centerX.equalToSuperview(); make.width.height.equalTo(72) }
        emojiLabel.snp.makeConstraints { make in make.edges.equalToSuperview() }
        lockLabel.snp.makeConstraints { make in make.trailing.bottom.equalToSuperview().inset(-2) }
        nameLabel.snp.makeConstraints { make in make.top.equalTo(badgeView.snp.bottom).offset(8); make.leading.trailing.equalToSuperview() }
        progressLabel.snp.makeConstraints { make in make.top.equalTo(nameLabel.snp.bottom).offset(2); make.leading.trailing.equalToSuperview() }
        emojiLabel.font = .systemFont(ofSize: 35); emojiLabel.textAlignment = .center
        nameLabel.font = JournalDesign.serifFont(size: 13, textStyle: .caption1, weight: .semibold); nameLabel.textColor = JournalDesign.primaryText; nameLabel.textAlignment = .center; nameLabel.adjustsFontForContentSizeCategory = true
        progressLabel.font = JournalDesign.monoFont(size: 10, textStyle: .caption2); progressLabel.textColor = JournalDesign.secondaryText; progressLabel.textAlignment = .center
    }
    required init?(coder: NSCoder) { nil }

    func configure(badge: Badge, unlocked: Bool, progress: (current: Int, target: Int)) {
        emojiLabel.text = unlocked ? badge.emoji : "🔒"
        lockLabel.text = unlocked ? "" : "🔒"
        badgeView.backgroundColor = unlocked ? JournalDesign.amber100 : JournalDesign.secondaryBackground
        badgeView.layer.cornerRadius = 36; badgeView.layer.cornerCurve = .continuous; badgeView.layer.borderWidth = unlocked ? 2.5 : 1; badgeView.layer.borderColor = (unlocked ? UIColor(hex: "#D4A056") : JournalDesign.separator).cgColor
        badgeView.layer.shadowColor = UIColor(hex: "#D4A056").cgColor; badgeView.layer.shadowOpacity = unlocked ? 0.24 : 0; badgeView.layer.shadowRadius = 7; badgeView.layer.shadowOffset = CGSize(width: 0, height: 3)
        nameLabel.text = badge.name
        progressLabel.text = unlocked ? "已点亮" : "\(min(progress.current, progress.target))/\(progress.target)"
        accessibilityLabel = unlocked ? "\(badge.name)，已点亮" : "\(badge.name)，未解锁，\(badge.description)"
    }
}
