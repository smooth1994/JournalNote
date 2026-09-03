//
//  RecurringPlanListViewController.swift
//  JournalNote
//

import UIKit
import SnapKit

final class RecurringPlanListViewController: JournalBaseViewController {
    private let repository = JournalRepository.shared
    private let tableView = UITableView(frame: .zero, style: .insetGrouped)
    private let emptyLabel = UILabel()
    private var observer: NSObjectProtocol?

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "重复计划"
        navigationItem.largeTitleDisplayMode = .never
        setupViews()
        observer = NotificationCenter.default.addObserver(
            forName: .planTasksDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in self?.reloadData() }
        reloadData()
    }

    private func setupViews() {
        tableView.backgroundColor = JournalDesign.pageBackground
        tableView.separatorColor = JournalDesign.separator
        tableView.rowHeight = 76
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(RecurringPlanCell.self, forCellReuseIdentifier: RecurringPlanCell.reuseIdentifier)
        tableView.accessibilityIdentifier = "recurringPlansTableView"

        emptyLabel.text = "还没有重复计划\n每天、工作日、每周末或自定义周几，都可以从计划页新增。"
        emptyLabel.font = JournalDesign.serifFont(size: 15, textStyle: .subheadline)
        emptyLabel.textColor = JournalDesign.secondaryText
        emptyLabel.numberOfLines = 0
        emptyLabel.textAlignment = .center
        emptyLabel.isHidden = true

        view.addSubview(tableView)
        view.addSubview(emptyLabel)
        tableView.snp.makeConstraints { make in make.edges.equalTo(view.safeAreaLayoutGuide) }
        emptyLabel.snp.makeConstraints { make in make.center.equalToSuperview(); make.leading.trailing.equalToSuperview().inset(32) }
    }

    private var recurringTasks: [PlanTask] {
        repository.allPlanTasks(includePaused: true).filter { task in
            task.rule != .once && task.endDate == nil
        }
    }

    private func reloadData() {
        guard isViewLoaded else { return }
        let tasks = recurringTasks
        emptyLabel.isHidden = !tasks.isEmpty
        tableView.isHidden = tasks.isEmpty
        tableView.reloadData()
    }
}

extension RecurringPlanListViewController: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        recurringTasks.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: RecurringPlanCell.reuseIdentifier, for: indexPath) as! RecurringPlanCell
        cell.configure(task: recurringTasks[indexPath.row])
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        navigationController?.pushViewController(RecurringPlanDetailViewController(task: recurringTasks[indexPath.row]), animated: true)
    }
}

private final class RecurringPlanCell: UITableViewCell {
    static let reuseIdentifier = "RecurringPlanCell"
    private let titleLabel = UILabel()
    private let detailLabel = UILabel()
    private let tagLabel = UILabel()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        backgroundColor = JournalDesign.cardBackground
        contentView.backgroundColor = JournalDesign.cardBackground
        accessoryType = .disclosureIndicator
        titleLabel.font = JournalDesign.serifFont(size: 16, textStyle: .subheadline, weight: .semibold)
        titleLabel.textColor = JournalDesign.primaryText
        detailLabel.font = JournalDesign.monoFont(size: 11, textStyle: .caption1)
        detailLabel.textColor = JournalDesign.secondaryText
        detailLabel.numberOfLines = 1
        tagLabel.font = JournalDesign.monoFont(size: 10, textStyle: .caption2)
        tagLabel.textAlignment = .center
        tagLabel.layer.cornerRadius = 6
        tagLabel.clipsToBounds = true

        contentView.addSubview(titleLabel)
        contentView.addSubview(detailLabel)
        contentView.addSubview(tagLabel)
        titleLabel.snp.makeConstraints { make in
            make.top.equalToSuperview().inset(13)
            make.leading.equalToSuperview().inset(16)
            make.trailing.lessThanOrEqualTo(tagLabel.snp.leading).offset(-10)
        }
        detailLabel.snp.makeConstraints { make in
            make.top.equalTo(titleLabel.snp.bottom).offset(4)
            make.leading.equalTo(titleLabel)
            make.trailing.lessThanOrEqualTo(tagLabel.snp.leading).offset(-10)
        }
        tagLabel.snp.makeConstraints { make in
            make.trailing.equalToSuperview().inset(34)
            make.centerY.equalToSuperview()
            make.width.greaterThanOrEqualTo(48)
            make.height.equalTo(24)
        }
    }

    required init?(coder: NSCoder) { nil }

    func configure(task: PlanTask) {
        titleLabel.text = task.title
        let start = format(task.anchorDate, format: "yyyy.MM.dd")
        var detail = "从 \(start) 开始"
        if task.reminderEnabled, let hour = task.reminderHour, let minute = task.reminderMinute {
            detail += " · 提醒 \(String(format: "%02d:%02d", hour, minute))"
        }
        if task.isPaused { detail += " · 已暂停" }
        detailLabel.text = detail
        tagLabel.text = task.displayRule
        tagLabel.textColor = task.isPaused ? JournalDesign.secondaryText : UIColor(hex: task.rule.tagColor.text)
        tagLabel.backgroundColor = task.isPaused ? JournalDesign.lockedBackground : UIColor(hex: task.rule.tagColor.background)
        accessibilityLabel = "\(task.title)，\(task.displayRule)，\(task.isPaused ? "已暂停" : "进行中")，点击查看详情"
    }

    private func format(_ date: Date, format: String) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = format
        return formatter.string(from: date)
    }
}

final class RecurringPlanDetailViewController: JournalBaseViewController {
    private let repository = JournalRepository.shared
    private var task: PlanTask
    private let scrollView = UIScrollView()
    private let contentView = UIView()
    private let statusLabel = UILabel()
    private let titleValueLabel = UILabel()
    private let ruleValueLabel = UILabel()
    private let dateValueLabel = UILabel()
    private let reminderValueLabel = UILabel()
    private let statusButton = JournalActionButton(title: "暂停计划", style: .soft)
    private let editButton = JournalActionButton(title: "编辑计划")
    private let deleteButton = JournalActionButton(title: "删除计划", style: .ghost)
    private var observer: NSObjectProtocol?

    init(task: PlanTask) {
        self.task = task
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { nil }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "计划详情"
        navigationItem.largeTitleDisplayMode = .never
        setupViews()
        observer = NotificationCenter.default.addObserver(
            forName: .planTasksDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in self?.reloadData() }
        reloadData()
    }

    private func setupViews() {
        view.backgroundColor = JournalDesign.pageBackground
        let card = UIView()
        card.applyJournalCard(cornerRadius: JournalDesign.panelCorner)
        let heading = UILabel()
        heading.text = "重复计划"
        heading.font = JournalDesign.monoFont(size: 12, textStyle: .caption1)
        heading.textColor = JournalDesign.secondaryText
        statusLabel.font = JournalDesign.serifFont(size: 14, textStyle: .subheadline)
        statusLabel.numberOfLines = 0
        statusLabel.textColor = JournalDesign.secondaryText

        let rows: [(String, UILabel)] = [("计划名称", titleValueLabel), ("重复规则", ruleValueLabel), ("开始日期", dateValueLabel), ("提醒", reminderValueLabel)]
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 15
        stack.addArrangedSubview(heading)
        stack.addArrangedSubview(statusLabel)
        for (labelText, valueLabel) in rows {
            let row = UIStackView()
            row.axis = .horizontal
            row.spacing = 12
            let label = UILabel()
            label.text = labelText
            label.font = JournalDesign.monoFont(size: 11, textStyle: .caption1)
            label.textColor = JournalDesign.secondaryText
            label.setContentHuggingPriority(.required, for: .horizontal)
            valueLabel.font = JournalDesign.serifFont(size: 15, textStyle: .body, weight: .medium)
            valueLabel.textColor = JournalDesign.primaryText
            valueLabel.numberOfLines = 0
            row.addArrangedSubview(label)
            row.addArrangedSubview(valueLabel)
            stack.addArrangedSubview(row)
        }
        card.addSubview(stack)
        stack.snp.makeConstraints { make in make.edges.equalToSuperview().inset(18) }

        statusButton.addTarget(self, action: #selector(togglePaused), for: .touchUpInside)
        editButton.addTarget(self, action: #selector(editTask), for: .touchUpInside)
        deleteButton.addTarget(self, action: #selector(deleteTask), for: .touchUpInside)

        let actions = UIStackView(arrangedSubviews: [statusButton, editButton, deleteButton])
        actions.axis = .vertical
        actions.spacing = 12

        contentView.addSubview(card)
        contentView.addSubview(actions)
        scrollView.addSubview(contentView)
        view.addSubview(scrollView)
        scrollView.alwaysBounceVertical = true
        scrollView.showsVerticalScrollIndicator = false
        scrollView.snp.makeConstraints { make in make.edges.equalTo(view.safeAreaLayoutGuide) }
        contentView.snp.makeConstraints { make in make.edges.equalToSuperview(); make.width.equalTo(scrollView.snp.width) }
        card.snp.makeConstraints { make in make.top.leading.trailing.equalToSuperview().inset(20) }
        actions.snp.makeConstraints { make in make.top.equalTo(card.snp.bottom).offset(18); make.leading.trailing.equalTo(card); make.bottom.equalToSuperview().inset(28) }
    }

    private func reloadData() {
        guard isViewLoaded else { return }
        task = repository.planTask(id: task.id) ?? task
        titleValueLabel.text = task.title
        ruleValueLabel.text = task.displayRule
        dateValueLabel.text = format(task.anchorDate, format: "yyyy.MM.dd")
        if task.reminderEnabled, let hour = task.reminderHour, let minute = task.reminderMinute {
            reminderValueLabel.text = "每天 \(String(format: "%02d:%02d", hour, minute))"
        } else {
            reminderValueLabel.text = "不提醒"
        }
        statusLabel.text = task.isPaused ? "已暂停：之后的日期不会生成新的任务实例。" : "进行中：会按重复规则出现在计划日历中。"
        statusButton.setTitle(task.isPaused ? "恢复计划" : "暂停计划", for: .normal)
        statusButton.setImage(UIImage(systemName: task.isPaused ? "play.fill" : "pause.fill"), for: .normal)
        editButton.setImage(UIImage(systemName: "pencil"), for: .normal)
        deleteButton.setImage(UIImage(systemName: "trash"), for: .normal)
    }

    @objc private func togglePaused() {
        do {
            try repository.setPlanTaskPaused(task, paused: !task.isPaused)
        } catch {
            presentError(error)
        }
    }

    @objc private func editTask() {
        let editor = PlanTaskEditorViewController(task: task, date: Date())
        editor.onSave = { [weak self] updated in
            do { try self?.repository.replacePlanTask(updated, effectiveFrom: Date()) }
            catch { self?.presentError(error) }
        }
        let navigation = UINavigationController(rootViewController: editor)
        navigation.modalPresentationStyle = .pageSheet
        if let sheet = navigation.sheetPresentationController { sheet.detents = [.medium(), .large()]; sheet.prefersGrabberVisible = true }
        present(navigation, animated: true)
    }

    @objc private func deleteTask() {
        let alert = UIAlertController(title: "删除重复计划？", message: "历史记录会保留，今天之后将不再生成这项计划。", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        alert.addAction(UIAlertAction(title: "删除", style: .destructive) { [weak self] _ in
            guard let self else { return }
            do {
                try self.repository.deletePlanTask(self.task, from: Date())
                self.navigationController?.popViewController(animated: true)
            } catch {
                self.presentError(error)
            }
        })
        present(alert, animated: true)
    }

    private func presentError(_ error: Error) {
        let alert = UIAlertController(title: "操作未完成", message: error.localizedDescription, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "知道了", style: .default))
        present(alert, animated: true)
    }

    private func format(_ date: Date, format: String) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = format
        return formatter.string(from: date)
    }
}
