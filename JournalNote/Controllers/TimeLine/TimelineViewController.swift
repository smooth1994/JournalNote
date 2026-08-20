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
        tableView.snp.makeConstraints { make in
            make.top.equalTo(summaryCard.snp.bottom).offset(14)
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
