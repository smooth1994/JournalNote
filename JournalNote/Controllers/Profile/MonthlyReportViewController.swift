//
//  MonthlyReportViewController.swift
//  JournalNote
//

import UIKit
import SnapKit

final class MonthlyReportViewController: JournalBaseViewController {
    private let repository = JournalRepository.shared
    private let reportCard = UIView()
    private let shareButton = JournalActionButton(title: "生成分享卡片")
    private let exportButton = JournalActionButton(title: "导出 PDF", style: .ghost)

    override func viewDidLoad() {
        super.viewDidLoad()
        title = monthTitle
        navigationItem.largeTitleDisplayMode = .never
        setupViews()
    }

    private var monthTitle: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "M 月手账报告"
        return formatter.string(from: Date())
    }

    private func setupViews() {
        let subtitle = UILabel()
        subtitle.text = "把一个月的时光，折成一页纸"
        subtitle.font = JournalDesign.handwrittenFont(size: 19, textStyle: .title3)
        subtitle.textColor = JournalDesign.accent
        subtitle.textAlignment = .center

        reportCard.applyJournalCard(cornerRadius: JournalDesign.panelCorner)
        let cardStack = UIStackView()
        cardStack.axis = .vertical
        cardStack.alignment = .fill
        cardStack.spacing = 16
        reportCard.addSubview(cardStack)
        cardStack.snp.makeConstraints { make in make.edges.equalToSuperview().inset(24) }

        let cardTitle = UILabel()
        cardTitle.text = monthTitle.replacingOccurrences(of: "手账报告", with: "· 拾光手记")
        cardTitle.font = JournalDesign.handwrittenFont(size: 23, textStyle: .title2)
        cardTitle.textColor = JournalDesign.accent
        cardTitle.textAlignment = .center
        cardStack.addArrangedSubview(cardTitle)

        let entries = repository.monthlyEntries(for: Date())
        let stats = UIStackView()
        stats.axis = .horizontal
        stats.distribution = .fillEqually
        stats.spacing = 8
        stats.addArrangedSubview(makeStat(value: repository.checkInCount(in: Date()), label: "记录天数"))
        stats.addArrangedSubview(makeStat(value: repository.longestCheckInStreak(in: Date()), label: "最长连续"))
        stats.addArrangedSubview(makeStat(value: BadgeManager.shared.unlockedBadges().count, label: "解锁徽章"))
        cardStack.addArrangedSubview(stats)

        let detail = UILabel()
        detail.font = JournalDesign.serifFont(size: 14, textStyle: .subheadline)
        detail.textColor = JournalDesign.secondaryText
        detail.textAlignment = .center
        detail.numberOfLines = 0
        detail.text = detailText(entries: entries)
        cardStack.addArrangedSubview(detail)

        let closing = UILabel()
        closing.text = "每一页都在证明：你认真生活过。"
        closing.font = JournalDesign.handwrittenFont(size: 17, textStyle: .body)
        closing.textColor = JournalDesign.bodyText
        closing.textAlignment = .center
        cardStack.addArrangedSubview(closing)

        shareButton.addTarget(self, action: #selector(shareCard), for: .touchUpInside)
        exportButton.addTarget(self, action: #selector(exportPDF), for: .touchUpInside)
        view.addSubview(subtitle)
        view.addSubview(reportCard)
        view.addSubview(shareButton)
        view.addSubview(exportButton)
        subtitle.snp.makeConstraints { make in
            make.top.equalTo(view.safeAreaLayoutGuide).offset(22)
            make.leading.trailing.equalToSuperview().inset(20)
        }
        reportCard.snp.makeConstraints { make in
            make.top.equalTo(subtitle.snp.bottom).offset(18)
            make.leading.trailing.equalToSuperview().inset(20)
        }
        shareButton.snp.makeConstraints { make in
            make.top.equalTo(reportCard.snp.bottom).offset(18)
            make.leading.trailing.equalTo(reportCard)
        }
        exportButton.snp.makeConstraints { make in
            make.top.equalTo(shareButton.snp.bottom).offset(10)
            make.leading.trailing.equalTo(reportCard)
            make.bottom.lessThanOrEqualTo(view.safeAreaLayoutGuide).inset(20)
        }
    }

    private func makeStat(value: Int, label: String) -> UIView {
        let numberLabel = UILabel()
        numberLabel.text = "\(value)"
        numberLabel.font = JournalDesign.handwrittenFont(size: 28, textStyle: .title1)
        numberLabel.textColor = JournalDesign.accent
        numberLabel.textAlignment = .center
        let titleLabel = UILabel()
        titleLabel.text = label
        titleLabel.font = JournalDesign.monoFont(size: 11, textStyle: .caption2)
        titleLabel.textColor = JournalDesign.secondaryText
        titleLabel.textAlignment = .center
        let stack = UIStackView(arrangedSubviews: [numberLabel, titleLabel])
        stack.axis = .vertical
        stack.spacing = 3
        stack.backgroundColor = JournalDesign.secondaryBackground
        stack.layer.cornerRadius = 12
        stack.layer.cornerCurve = .continuous
        stack.isLayoutMarginsRelativeArrangement = true
        stack.layoutMargins = UIEdgeInsets(top: 12, left: 4, bottom: 12, right: 4)
        return stack
    }

    private func detailText(entries: [JournalEntry]) -> String {
        let counts = repository.moodCounts(for: entries).sorted { $0.value > $1.value }
        let moodText: String
        if let first = counts.first, !entries.isEmpty {
            let percent = Int((Double(first.value) / Double(entries.count) * 100).rounded())
            moodText = "最常出现的心情：\(first.key.emoji) \(first.key.title) \(percent)%"
        } else {
            moodText = "最常出现的心情：等待你的下一次落笔"
        }
        let latestTime = entries.max(by: { $0.createdAt < $1.createdAt }).map { entry -> String in
            let formatter = DateFormatter()
            formatter.dateFormat = "HH:mm"
            return formatter.string(from: entry.createdAt)
        } ?? "--:--"
        return "\(moodText)\n最晚记录时间：\(latestTime)"
    }

    @objc private func shareCard() {
        reportCard.layoutIfNeeded()
        let renderer = UIGraphicsImageRenderer(bounds: reportCard.bounds)
        let image = renderer.image { context in
            reportCard.layer.render(in: context.cgContext)
        }
        presentActivity(items: [image], sourceView: shareButton)
    }

    @objc private func exportPDF() {
        reportCard.layoutIfNeeded()
        let page = CGRect(x: 0, y: 0, width: 595, height: 842)
        let renderer = UIGraphicsPDFRenderer(bounds: page)
        let data = renderer.pdfData { context in
            context.beginPage()
            let scale = min((page.width - 80) / reportCard.bounds.width, (page.height - 120) / reportCard.bounds.height)
            context.cgContext.saveGState()
            context.cgContext.translateBy(x: 40, y: 60)
            context.cgContext.scaleBy(x: scale, y: scale)
            reportCard.layer.render(in: context.cgContext)
            context.cgContext.restoreGState()
        }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(monthTitle).pdf")
        do {
            try data.write(to: url, options: .atomic)
            presentActivity(items: [url], sourceView: exportButton)
        } catch {
            let alert = UIAlertController(title: "导出失败", message: error.localizedDescription, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "知道了", style: .default))
            present(alert, animated: true)
        }
    }

    private func presentActivity(items: [Any], sourceView: UIView) {
        let activity = UIActivityViewController(activityItems: items, applicationActivities: nil)
        if let popover = activity.popoverPresentationController {
            popover.sourceView = sourceView
            popover.sourceRect = sourceView.bounds
        }
        present(activity, animated: true)
    }
}
