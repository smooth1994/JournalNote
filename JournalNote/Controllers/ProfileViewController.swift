//
//  ProfileViewController.swift
//  JournalNote
//

import UIKit
import SnapKit

final class ProfileViewController: JournalBaseViewController {
    private let repository = JournalRepository.shared
    private let scrollView = UIScrollView()
    private let contentView = UIView()
    private let greetingLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let moodCard = UIView()
    private let moodYearView = MoodYearView()
    private let moodSummaryLabel = UILabel()
    private let sealCard = UIView()
    private let sealStack = UIStackView()
    private let themeCard = UIView()
    private let nightSwitch = UISwitch()
    private let exportButton = JournalActionButton(title: "导出 PDF 手账册", style: .ghost)
    private var observers: [NSObjectProtocol] = []

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "我的"
        navigationItem.largeTitleDisplayMode = .always
        setupViews()
        observeChanges()
        reloadData()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        reloadData()
    }

    deinit {
        observers.forEach(NotificationCenter.default.removeObserver)
    }

    private func setupViews() {
        scrollView.alwaysBounceVertical = true
        scrollView.showsVerticalScrollIndicator = false

        greetingLabel.text = "把日子，慢慢收好"
        greetingLabel.font = JournalDesign.handwrittenFont(size: 25, textStyle: .title2)
        greetingLabel.textColor = JournalDesign.accent
        greetingLabel.adjustsFontForContentSizeCategory = true
        subtitleLabel.font = JournalDesign.serifFont(size: 14, textStyle: .subheadline)
        subtitleLabel.textColor = JournalDesign.secondaryText
        subtitleLabel.adjustsFontForContentSizeCategory = true

        moodCard.applyJournalCard(cornerRadius: JournalDesign.panelCorner)
        let moodTitle = makeCardEyebrow("心情年轮")
        moodSummaryLabel.font = JournalDesign.serifFont(size: 14, textStyle: .subheadline)
        moodSummaryLabel.textColor = JournalDesign.secondaryText
        moodSummaryLabel.numberOfLines = 0
        moodSummaryLabel.textAlignment = .center
        moodSummaryLabel.adjustsFontForContentSizeCategory = true

        sealCard.applyJournalSoftCard(cornerRadius: JournalDesign.panelCorner)
        let sealTitle = makeCardEyebrow("印章墙")
        let sealNote = UILabel()
        sealNote.text = "每一次落笔，都是给自己的一枚小小印记。"
        sealNote.font = JournalDesign.serifFont(size: 13, textStyle: .subheadline)
        sealNote.textColor = JournalDesign.secondaryText
        sealNote.numberOfLines = 0
        sealNote.adjustsFontForContentSizeCategory = true
        sealStack.axis = .horizontal
        sealStack.alignment = .center
        sealStack.distribution = .equalSpacing
        sealStack.spacing = 18

        themeCard.applyJournalSoftCard(cornerRadius: JournalDesign.panelCorner)
        let lampIcon = UIImageView(image: UIImage(systemName: "lamp.desk.fill"))
        lampIcon.tintColor = JournalDesign.amber500
        lampIcon.preferredSymbolConfiguration = .init(pointSize: 20, weight: .medium)
        let themeTitle = UILabel()
        themeTitle.text = "今夜台灯模式"
        themeTitle.font = JournalDesign.serifFont(size: 16, textStyle: .headline, weight: .semibold)
        themeTitle.textColor = JournalDesign.primaryText
        themeTitle.adjustsFontForContentSizeCategory = true
        let themeNote = UILabel()
        themeNote.text = "深夜台灯下的暖棕纸张"
        themeNote.font = JournalDesign.serifFont(size: 13, textStyle: .subheadline)
        themeNote.textColor = JournalDesign.secondaryText
        themeNote.adjustsFontForContentSizeCategory = true
        nightSwitch.onTintColor = JournalDesign.accent
        nightSwitch.addTarget(self, action: #selector(changeTheme), for: .valueChanged)
        nightSwitch.accessibilityLabel = "今夜台灯模式"

        exportButton.addTarget(self, action: #selector(exportJournal), for: .touchUpInside)

        view.addSubview(scrollView)
        scrollView.addSubview(contentView)
        [greetingLabel, subtitleLabel, moodCard, sealCard, themeCard, exportButton].forEach { contentView.addSubview($0) }
        moodCard.addSubview(moodTitle)
        moodCard.addSubview(moodYearView)
        moodCard.addSubview(moodSummaryLabel)
        sealCard.addSubview(sealTitle)
        sealCard.addSubview(sealNote)
        sealCard.addSubview(sealStack)
        themeCard.addSubview(lampIcon)
        themeCard.addSubview(themeTitle)
        themeCard.addSubview(themeNote)
        themeCard.addSubview(nightSwitch)

        scrollView.snp.makeConstraints { make in
            make.edges.equalTo(view.safeAreaLayoutGuide)
        }
        contentView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
            make.width.equalTo(scrollView.snp.width)
        }
        greetingLabel.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(16)
            make.leading.trailing.equalToSuperview().inset(20)
        }
        subtitleLabel.snp.makeConstraints { make in
            make.top.equalTo(greetingLabel.snp.bottom).offset(2)
            make.leading.trailing.equalTo(greetingLabel)
        }
        moodCard.snp.makeConstraints { make in
            make.top.equalTo(subtitleLabel.snp.bottom).offset(20)
            make.leading.trailing.equalToSuperview().inset(20)
        }
        moodTitle.snp.makeConstraints { make in
            make.top.leading.equalToSuperview().inset(18)
            make.trailing.equalToSuperview().inset(18)
        }
        moodYearView.snp.makeConstraints { make in
            make.top.equalTo(moodTitle.snp.bottom).offset(12)
            make.centerX.equalToSuperview()
            make.width.height.equalTo(190)
        }
        moodSummaryLabel.snp.makeConstraints { make in
            make.top.equalTo(moodYearView.snp.bottom).offset(8)
            make.leading.trailing.equalToSuperview().inset(18)
            make.bottom.equalToSuperview().inset(18)
        }
        sealCard.snp.makeConstraints { make in
            make.top.equalTo(moodCard.snp.bottom).offset(16)
            make.leading.trailing.equalTo(moodCard)
        }
        sealTitle.snp.makeConstraints { make in
            make.top.leading.trailing.equalToSuperview().inset(18)
        }
        sealNote.snp.makeConstraints { make in
            make.top.equalTo(sealTitle.snp.bottom).offset(5)
            make.leading.trailing.equalTo(sealTitle)
        }
        sealStack.snp.makeConstraints { make in
            make.top.equalTo(sealNote.snp.bottom).offset(18)
            make.leading.trailing.equalToSuperview().inset(26)
            make.height.equalTo(68)
            make.bottom.equalToSuperview().inset(18)
        }
        themeCard.snp.makeConstraints { make in
            make.top.equalTo(sealCard.snp.bottom).offset(16)
            make.leading.trailing.equalTo(moodCard)
            make.height.greaterThanOrEqualTo(76)
        }
        lampIcon.snp.makeConstraints { make in
            make.leading.equalToSuperview().inset(18)
            make.centerY.equalToSuperview()
            make.width.height.equalTo(24)
        }
        themeTitle.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(16)
            make.leading.equalTo(lampIcon.snp.trailing).offset(12)
            make.trailing.lessThanOrEqualTo(nightSwitch.snp.leading).offset(-12)
        }
        themeNote.snp.makeConstraints { make in
            make.top.equalTo(themeTitle.snp.bottom).offset(2)
            make.leading.equalTo(themeTitle)
            make.bottom.equalToSuperview().inset(16)
            make.trailing.lessThanOrEqualTo(nightSwitch.snp.leading).offset(-12)
        }
        nightSwitch.snp.makeConstraints { make in
            make.trailing.equalToSuperview().inset(18)
            make.centerY.equalToSuperview()
        }
        exportButton.snp.makeConstraints { make in
            make.top.equalTo(themeCard.snp.bottom).offset(22)
            make.centerX.equalToSuperview()
            make.bottom.equalToSuperview().inset(30)
        }
    }

    private func makeCardEyebrow(_ title: String) -> UILabel {
        let label = UILabel()
        label.text = title
        label.font = JournalDesign.monoFont(size: 12, textStyle: .caption1)
        label.textColor = JournalDesign.secondaryText
        label.adjustsFontForContentSizeCategory = true
        return label
    }

    private func observeChanges() {
        let entriesObserver = NotificationCenter.default.addObserver(
            forName: .journalEntriesDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.reloadData()
        }
        let themeObserver = NotificationCenter.default.addObserver(
            forName: .journalThemeDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.reloadData()
        }
        observers = [entriesObserver, themeObserver]
    }

    private func reloadData() {
        let entries = repository.allEntries()
        subtitleLabel.text = "你已经拾起 \(entries.count) 段时光"
        moodYearView.entries = entries
        nightSwitch.setOn(repository.themeMode() == .night, animated: false)

        let counts = repository.moodCounts(for: entries)
            .sorted { $0.value > $1.value }
            .prefix(2)
            .map { "\($0.key.emoji) \($0.key.title) \($0.value) 次" }
            .joined(separator: "  ·  ")
        moodSummaryLabel.text = counts.isEmpty ? "你的心情会在这里慢慢长成一圈年轮。" : counts
        updateSealWall(entryCount: entries.count, streak: repository.consecutiveDays())
    }

    private func updateSealWall(entryCount: Int, streak: Int) {
        sealStack.arrangedSubviews.forEach {
            sealStack.removeArrangedSubview($0)
            $0.removeFromSuperview()
        }

        var seals = ["初次\n落笔"]
        seals.append(streak >= 7 ? "七日\n不辍" : "慢慢\n记录")
        seals.append(entryCount >= 10 ? "拾光\n十页" : "未完\n待续")

        for text in seals {
            let seal = JournalSealView(text: text)
            seal.snp.makeConstraints { make in
                make.width.height.equalTo(58)
            }
            sealStack.addArrangedSubview(seal)
        }
    }

    @objc private func changeTheme() {
        let mode: JournalThemeMode = nightSwitch.isOn ? .night : .light
        do {
            try repository.saveThemeMode(mode)
        } catch {
            nightSwitch.setOn(!nightSwitch.isOn, animated: true)
            let alert = UIAlertController(title: "设置未保存", message: error.localizedDescription, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "知道了", style: .default))
            present(alert, animated: true)
        }
    }

    @objc private func exportJournal() {
        let entries = repository.allEntries()
        guard !entries.isEmpty else { return }

        let pageBounds = CGRect(x: 0, y: 0, width: 595, height: 842)
        let renderer = UIGraphicsPDFRenderer(bounds: pageBounds)
        let data = renderer.pdfData { context in
            var y: CGFloat = 54
            context.beginPage()
            drawPDFTitle(at: &y)

            for entry in entries.reversed() {
                let neededHeight = heightForPDFEntry(entry, width: pageBounds.width - 80)
                if y + neededHeight > pageBounds.height - 50 {
                    context.beginPage()
                    y = 54
                    drawPDFTitle(at: &y)
                }
                drawPDFEntry(entry, at: &y, width: pageBounds.width - 80)
            }
        }

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmm"
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("拾光手账-\(formatter.string(from: Date())).pdf")

        do {
            try data.write(to: url, options: .atomic)
            let activity = UIActivityViewController(activityItems: [url], applicationActivities: nil)
            if let popover = activity.popoverPresentationController {
                popover.sourceView = exportButton
                popover.sourceRect = exportButton.bounds
            }
            present(activity, animated: true)
        } catch {
            let alert = UIAlertController(title: "导出失败", message: error.localizedDescription, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "知道了", style: .default))
            present(alert, animated: true)
        }
    }

    private func drawPDFTitle(at y: inout CGFloat) {
        let title = "拾光手账"
        let subtitle = "把时光，一页一页捡起来"
        title.draw(at: CGPoint(x: 42, y: y), withAttributes: [
            .font: JournalDesign.serifFont(size: 28, textStyle: .title1, weight: .bold),
            .foregroundColor: JournalDesign.ink900
        ])
        y += 38
        subtitle.draw(at: CGPoint(x: 42, y: y), withAttributes: [
            .font: JournalDesign.handwrittenFont(size: 16, textStyle: .subheadline),
            .foregroundColor: JournalDesign.amber600
        ])
        y += 34
    }

    private func heightForPDFEntry(_ entry: JournalEntry, width: CGFloat) -> CGFloat {
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineSpacing = 6
        let attributes: [NSAttributedString.Key: Any] = [
            .font: JournalDesign.serifFont(size: 14, textStyle: .body),
            .paragraphStyle: paragraph
        ]
        let bodyHeight = (entry.body as NSString).boundingRect(
            with: CGSize(width: width, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: attributes,
            context: nil
        ).height
        return 48 + bodyHeight + 32
    }

    private func drawPDFEntry(_ entry: JournalEntry, at y: inout CGFloat, width: CGFloat) {
        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: JournalDesign.serifFont(size: 17, textStyle: .headline, weight: .semibold),
            .foregroundColor: JournalDesign.ink900
        ]
        let metadataAttributes: [NSAttributedString.Key: Any] = [
            .font: JournalDesign.monoFont(size: 10, textStyle: .caption2),
            .foregroundColor: JournalDesign.ink500
        ]
        let bodyParagraph = NSMutableParagraphStyle()
        bodyParagraph.lineSpacing = 6
        let bodyAttributes: [NSAttributedString.Key: Any] = [
            .font: JournalDesign.serifFont(size: 14, textStyle: .body),
            .foregroundColor: JournalDesign.ink700,
            .paragraphStyle: bodyParagraph
        ]

        "\(entry.mood.emoji)  \(entry.displayTitle)".draw(at: CGPoint(x: 42, y: y), withAttributes: titleAttributes)
        y += 25
        entry.timestampText.draw(at: CGPoint(x: 42, y: y), withAttributes: metadataAttributes)
        y += 18
        let rect = (entry.body as NSString).boundingRect(
            with: CGSize(width: width, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: bodyAttributes,
            context: nil
        )
        (entry.body as NSString).draw(in: CGRect(x: 42, y: y, width: width, height: rect.height), withAttributes: bodyAttributes)
        y += rect.height + 20
    }
}
