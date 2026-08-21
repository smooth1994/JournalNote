//
//  TimelineViewController.swift
//  JournalNote
//

import UIKit
import SnapKit

final class TimelineViewController: JournalBaseViewController {
    private let repository = JournalRepository.shared
    private var entries: [JournalEntry] = []

    private let summaryCard = UIView()
    private let summaryLabel = UILabel()
    private let summaryNoteLabel = UILabel()
    private let writeButton = JournalActionButton(title: "记下此刻")
    private let inspirationCard = UIView()
    private let inspirationTitleLabel = UILabel()
    private let inspirationTextLabel = UILabel()
    private let inspirationButton = UIButton(type: .system)
    private let tableView = UITableView(frame: .zero, style: .plain)
    private let emptyState = JournalEmptyStateView(
        symbol: "book.closed",
        title: "还没有拾起的时光",
        message: "从今天开始，为一段微小的心情留下一页。"
    )
    private var dataObserver: NSObjectProtocol?

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "时光轴"
        navigationItem.largeTitleDisplayMode = .always
        setupViews()
        dataObserver = NotificationCenter.default.addObserver(
            forName: .journalEntriesDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.reloadData()
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        reloadData()
    }

    private func setupViews() {
        summaryCard.applyJournalSoftCard(cornerRadius: JournalDesign.panelCorner)
        summaryLabel.font = JournalDesign.handwrittenFont(size: 20, textStyle: .title3)
        summaryLabel.textColor = JournalDesign.accent
        summaryLabel.adjustsFontForContentSizeCategory = true
        summaryNoteLabel.font = JournalDesign.serifFont(size: 13, textStyle: .subheadline)
        summaryNoteLabel.textColor = JournalDesign.secondaryText
        summaryNoteLabel.text = "把值得留住的瞬间，慢慢写下来"
        summaryNoteLabel.adjustsFontForContentSizeCategory = true

        inspirationCard.applyJournalSoftCard(cornerRadius: JournalDesign.cardCorner)
        inspirationTitleLabel.text = "今日灵感"
        inspirationTitleLabel.font = JournalDesign.serifFont(size: 14, textStyle: .subheadline, weight: .semibold)
        inspirationTitleLabel.textColor = JournalDesign.accent
        inspirationTextLabel.font = JournalDesign.serifFont(size: 14, textStyle: .subheadline)
        inspirationTextLabel.textColor = JournalDesign.bodyText
        inspirationTextLabel.numberOfLines = 2
        inspirationTextLabel.adjustsFontForContentSizeCategory = true
        var inspirationConfiguration = UIButton.Configuration.plain()
        inspirationConfiguration.title = "引用"
        inspirationConfiguration.baseForegroundColor = JournalDesign.amber600
        inspirationConfiguration.background.backgroundColor = JournalDesign.amber100
        inspirationConfiguration.background.cornerRadius = 15
        inspirationConfiguration.contentInsets = NSDirectionalEdgeInsets(top: 5, leading: 12, bottom: 5, trailing: 12)
        inspirationConfiguration.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
            var outgoing = incoming
            outgoing.font = JournalDesign.serifFont(size: 13, textStyle: .caption1, weight: .semibold)
            return outgoing
        }
        inspirationButton.configuration = inspirationConfiguration
        inspirationButton.addTarget(self, action: #selector(useInspiration), for: .touchUpInside)
        inspirationButton.accessibilityLabel = "引用今日灵感"

        writeButton.addTarget(self, action: #selector(beginWriting), for: .touchUpInside)

        tableView.backgroundColor = .clear
        tableView.separatorStyle = .none
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(JournalCardCell.self, forCellReuseIdentifier: JournalCardCell.reuseIdentifier)
        tableView.estimatedRowHeight = 160
        tableView.rowHeight = UITableView.automaticDimension
        tableView.showsVerticalScrollIndicator = false

        view.addSubview(summaryCard)
        summaryCard.addSubview(summaryLabel)
        summaryCard.addSubview(summaryNoteLabel)
        summaryCard.addSubview(writeButton)
        view.addSubview(inspirationCard)
        inspirationCard.addSubview(inspirationTitleLabel)
        inspirationCard.addSubview(inspirationTextLabel)
        inspirationCard.addSubview(inspirationButton)
        view.addSubview(tableView)
        view.addSubview(emptyState)

        summaryCard.snp.makeConstraints { make in
            make.top.equalTo(view.safeAreaLayoutGuide.snp.top).offset(12)
            make.leading.trailing.equalToSuperview().inset(20)
        }
        summaryLabel.snp.makeConstraints { make in
            make.top.leading.equalToSuperview().inset(18)
            make.trailing.lessThanOrEqualTo(writeButton.snp.leading).offset(-12)
        }
        summaryNoteLabel.snp.makeConstraints { make in
            make.top.equalTo(summaryLabel.snp.bottom).offset(3)
            make.leading.equalTo(summaryLabel)
            make.bottom.equalToSuperview().inset(18)
            make.trailing.lessThanOrEqualTo(writeButton.snp.leading).offset(-12)
        }
        writeButton.snp.makeConstraints { make in
            make.trailing.equalToSuperview().inset(16)
            make.centerY.equalToSuperview()
        }
        inspirationCard.snp.makeConstraints { make in
            make.top.equalTo(summaryCard.snp.bottom).offset(12)
            make.leading.trailing.equalTo(summaryCard)
        }
        inspirationTitleLabel.snp.makeConstraints { make in
            make.top.leading.equalToSuperview().inset(14)
            make.trailing.lessThanOrEqualTo(inspirationButton.snp.leading).offset(-8)
        }
        inspirationTextLabel.snp.makeConstraints { make in
            make.top.equalTo(inspirationTitleLabel.snp.bottom).offset(4)
            make.leading.equalTo(inspirationTitleLabel)
            make.trailing.lessThanOrEqualTo(inspirationButton.snp.leading).offset(-8)
            make.bottom.equalToSuperview().inset(14)
        }
        inspirationButton.snp.makeConstraints { make in
            make.trailing.equalToSuperview().inset(14)
            make.centerY.equalToSuperview()
        }
        tableView.snp.makeConstraints { make in
            make.top.equalTo(inspirationCard.snp.bottom).offset(14)
            make.leading.trailing.bottom.equalToSuperview()
        }
        emptyState.snp.makeConstraints { make in
            make.center.equalTo(tableView)
            make.leading.trailing.equalToSuperview().inset(42)
        }
    }

    private func reloadData() {
        entries = repository.allEntries()
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "M 月"
        let monthlyCount = repository.monthlyEntries(for: Date()).count
        summaryLabel.text = "\(formatter.string(from: Date())) · 拾起 \(monthlyCount) 段时光"
        inspirationTextLabel.text = dailyInspiration()
        emptyState.isHidden = !entries.isEmpty
        tableView.isHidden = entries.isEmpty
        tableView.reloadData()
    }

    @objc private func beginWriting() {
        let composer = ComposeViewController()
        let navigationController = UINavigationController(rootViewController: composer)
        navigationController.modalPresentationStyle = .pageSheet
        present(navigationController, animated: true)
    }

    @objc private func useInspiration() {
        let composer = ComposeViewController()
        composer.suggestedText = inspirationTextLabel.text
        let navigationController = UINavigationController(rootViewController: composer)
        navigationController.modalPresentationStyle = .pageSheet
        present(navigationController, animated: true)
    }

    private func dailyInspiration() -> String {
        let prompts = [
            "描述一下今天闻到的第一种味道。",
            "如果给今天的心情盖一枚印章，它会是什么？",
            "记录一个让你嘴角微微上扬的瞬间。",
            "今天有什么事，比预想中更温柔？",
            "写下此刻窗外的颜色和声音。",
            "给明天的自己留一句轻声提醒。",
            "今天最想感谢的人，为什么？"
        ]
        let day = Calendar.current.ordinality(of: .day, in: .year, for: Date()) ?? 1
        return prompts[(day - 1) % prompts.count]
    }
}

extension TimelineViewController: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        entries.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(
            withIdentifier: JournalCardCell.reuseIdentifier,
            for: indexPath
        ) as? JournalCardCell else {
            return UITableViewCell()
        }
        cell.configure(with: entries[indexPath.row], hidesStem: indexPath.row == entries.count - 1)
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        navigationController?.pushViewController(JournalDetailViewController(entry: entries[indexPath.row]), animated: true)
    }
}
