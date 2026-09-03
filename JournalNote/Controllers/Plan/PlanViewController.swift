//
//  PlanViewController.swift
//  JournalNote
//

import UIKit
import SnapKit

final class PlanViewController: JournalBaseViewController {
    private let repository = JournalRepository.shared
    private var calendar: Calendar = {
        var value = Calendar.current
        value.locale = Locale(identifier: "zh_CN")
        value.firstWeekday = 2
        return value
    }()
    private var displayedDate: Date
    private let scrollView = UIScrollView()
    private let contentView = UIView()
    private let dateLabel = UILabel()
    private let previousButton = UIButton(type: .system)
    private let nextButton = UIButton(type: .system)
    private let pagerTitleLabel = UILabel()
    private let pagerDetailLabel = UILabel()
    private let progressCard = UIView()
    private let progressRing = PlanProgressRing()
    private let progressTitleLabel = UILabel()
    private let progressDetailLabel = UILabel()
    private let completionSeal = JournalSealView(text: "今日\n完成")
    private let taskStack = UIStackView()
    private let banner = UIView()
    private let bannerLabel = UILabel()
    private let addButton = JournalActionButton(title: "＋ 新增当日任务")
    private var observers: [NSObjectProtocol] = []
    private var isAnimatingDateChange = false

    init(date: Date = Date()) {
        displayedDate = calendar.startOfDay(for: date)
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { nil }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "计划"
        navigationItem.largeTitleDisplayMode = .never
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            image: UIImage(systemName: "ellipsis.circle"),
            style: .plain,
            target: self,
            action: #selector(showPausedTasks)
        )
        navigationItem.rightBarButtonItem?.accessibilityLabel = "管理已暂停任务"
        setupViews()
        let planObserver = NotificationCenter.default.addObserver(
            forName: .planTasksDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in self?.reloadData() }
        let dayObserver = NotificationCenter.default.addObserver(
            forName: .NSCalendarDayChanged,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            self.displayedDate = self.calendar.startOfDay(for: Date())
            self.reloadData()
        }
        observers = [planObserver, dayObserver]
        reloadData()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        displayedDate = calendar.startOfDay(for: displayedDate)
        reloadData()
    }

    private func setupViews() {
        view.backgroundColor = JournalDesign.pageBackground
        dateLabel.font = JournalDesign.monoFont(size: 12, textStyle: .caption1)
        dateLabel.textColor = JournalDesign.secondaryText
        dateLabel.textAlignment = .right

        configureArrow(previousButton, image: "chevron.left", action: #selector(showPreviousDay))
        configureArrow(nextButton, image: "chevron.right", action: #selector(showNextDay))
        pagerTitleLabel.font = JournalDesign.serifFont(size: 16, textStyle: .headline, weight: .semibold)
        pagerTitleLabel.textColor = JournalDesign.primaryText
        pagerTitleLabel.textAlignment = .center
        pagerDetailLabel.font = JournalDesign.monoFont(size: 11, textStyle: .caption2)
        pagerDetailLabel.textColor = JournalDesign.secondaryText
        pagerDetailLabel.textAlignment = .center

        let pager = UIView()
        pager.applyJournalSoftCard(cornerRadius: JournalDesign.cardCorner)
        pager.addSubview(previousButton)
        pager.addSubview(nextButton)
        pager.addSubview(pagerTitleLabel)
        pager.addSubview(pagerDetailLabel)

        progressCard.applyJournalSoftCard(cornerRadius: JournalDesign.panelCorner)
        progressCard.addSubview(progressRing)
        progressCard.addSubview(progressTitleLabel)
        progressCard.addSubview(progressDetailLabel)
        progressCard.addSubview(completionSeal)
        completionSeal.isHidden = true
        progressTitleLabel.font = JournalDesign.serifFont(size: 16, textStyle: .headline, weight: .semibold)
        progressTitleLabel.textColor = JournalDesign.primaryText
        progressDetailLabel.font = JournalDesign.serifFont(size: 13, textStyle: .subheadline)
        progressDetailLabel.textColor = JournalDesign.secondaryText
        progressDetailLabel.numberOfLines = 0

        taskStack.axis = .vertical
        taskStack.spacing = 18
        taskStack.alignment = .fill

        banner.layer.cornerRadius = 12
        banner.layer.cornerCurve = .continuous
        bannerLabel.font = JournalDesign.serifFont(size: 12, textStyle: .caption1)
        bannerLabel.textColor = JournalDesign.bodyText
        bannerLabel.numberOfLines = 0
        banner.addSubview(bannerLabel)

        addButton.addTarget(self, action: #selector(addTask), for: .touchUpInside)
        addButton.accessibilityIdentifier = "addPlanTaskButton"

        let header = UIView()
        header.addSubview(dateLabel)
        header.snp.makeConstraints { make in make.height.equalTo(24) }
        dateLabel.snp.makeConstraints { make in make.edges.equalToSuperview() }

        contentView.addSubview(header)
        contentView.addSubview(pager)
        contentView.addSubview(progressCard)
        contentView.addSubview(taskStack)
        contentView.addSubview(banner)
        contentView.addSubview(addButton)
        scrollView.addSubview(contentView)
        view.addSubview(scrollView)

        scrollView.alwaysBounceVertical = true
        scrollView.showsVerticalScrollIndicator = false
        scrollView.snp.makeConstraints { make in make.edges.equalTo(view.safeAreaLayoutGuide) }
        contentView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
            make.width.equalTo(scrollView.snp.width)
        }
        header.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(8)
            make.leading.trailing.equalToSuperview().inset(20)
        }
        pager.snp.makeConstraints { make in
            make.top.equalTo(header.snp.bottom).offset(6)
            make.leading.trailing.equalToSuperview().inset(20)
            make.height.equalTo(70)
        }
        previousButton.snp.makeConstraints { make in
            make.leading.equalToSuperview().inset(12)
            make.centerY.equalToSuperview()
            make.width.height.equalTo(38)
        }
        nextButton.snp.makeConstraints { make in
            make.trailing.equalToSuperview().inset(12)
            make.centerY.equalToSuperview()
            make.width.height.equalTo(38)
        }
        pagerTitleLabel.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(13)
            make.leading.equalTo(previousButton.snp.trailing).offset(10)
            make.trailing.equalTo(nextButton.snp.leading).offset(-10)
        }
        pagerDetailLabel.snp.makeConstraints { make in
            make.top.equalTo(pagerTitleLabel.snp.bottom).offset(3)
            make.leading.trailing.equalTo(pagerTitleLabel)
        }
        progressCard.snp.makeConstraints { make in
            make.top.equalTo(pager.snp.bottom).offset(14)
            make.leading.trailing.equalTo(pager)
            make.height.greaterThanOrEqualTo(92)
        }
        progressRing.snp.makeConstraints { make in
            make.leading.equalToSuperview().inset(16)
            make.centerY.equalToSuperview()
            make.width.height.equalTo(64)
        }
        progressTitleLabel.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(20)
            make.leading.equalTo(progressRing.snp.trailing).offset(14)
            make.trailing.lessThanOrEqualTo(completionSeal.snp.leading).offset(-8)
        }
        progressDetailLabel.snp.makeConstraints { make in
            make.top.equalTo(progressTitleLabel.snp.bottom).offset(4)
            make.leading.equalTo(progressTitleLabel)
            make.trailing.lessThanOrEqualTo(completionSeal.snp.leading).offset(-8)
            make.bottom.lessThanOrEqualToSuperview().inset(17)
        }
        completionSeal.snp.makeConstraints { make in
            make.trailing.equalToSuperview().inset(14)
            make.centerY.equalToSuperview()
            make.width.height.equalTo(50)
        }
        taskStack.snp.makeConstraints { make in
            make.top.equalTo(progressCard.snp.bottom).offset(16)
            make.leading.trailing.equalTo(pager)
        }
        banner.snp.makeConstraints { make in
            make.top.equalTo(taskStack.snp.bottom).offset(16)
            make.leading.trailing.equalTo(pager)
        }
        bannerLabel.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(UIEdgeInsets(top: 11, left: 13, bottom: 11, right: 13))
        }
        addButton.snp.makeConstraints { make in
            make.top.equalTo(banner.snp.bottom).offset(16)
            make.leading.trailing.equalTo(pager)
            make.bottom.equalToSuperview().inset(28)
        }

        let swipeLeft = UISwipeGestureRecognizer(target: self, action: #selector(showNextDay))
        swipeLeft.direction = .left
        let swipeRight = UISwipeGestureRecognizer(target: self, action: #selector(showPreviousDay))
        swipeRight.direction = .right
        view.addGestureRecognizer(swipeLeft)
        view.addGestureRecognizer(swipeRight)
    }

    private func configureArrow(_ button: UIButton, image: String, action: Selector) {
        button.setImage(UIImage(systemName: image), for: .normal)
        button.tintColor = JournalDesign.accent
        button.backgroundColor = JournalDesign.secondaryBackground
        button.layer.cornerRadius = 19
        button.addTarget(self, action: action, for: .touchUpInside)
        button.accessibilityLabel = image == "chevron.left" ? "前一天" : "后一天"
    }

    private var dayOffset: Int {
        calendar.dateComponents([.day], from: calendar.startOfDay(for: Date()), to: displayedDate).day ?? 0
    }

    private func reloadData() {
        guard isViewLoaded else { return }
        let completion = repository.planCompletion(for: displayedDate, calendar: calendar)
        let instances = repository.planTaskInstances(for: displayedDate, calendar: calendar)
        let today = calendar.startOfDay(for: Date())
        let isPast = displayedDate < today
        let isFuture = displayedDate > today

        dateLabel.text = formattedDate(displayedDate, format: "yyyy.MM.dd · EEEE")
        pagerTitleLabel.text = calendar.isDateInToday(displayedDate) ? "今天" : (isPast ? "昨天" : "明天")
        if abs(dayOffset) > 1 { pagerTitleLabel.text = formattedDate(displayedDate, format: "MM.dd · EEEE") }
        pagerDetailLabel.text = "\(formattedDate(displayedDate, format: "MM.dd EEEE")) · \(completion.completed) / \(completion.total) 已完成"
        progressRing.progress = completion.total == 0 ? 0 : CGFloat(completion.completed) / CGFloat(completion.total)
        progressRing.centerText = "\(completion.completed)/\(completion.total)"
        progressTitleLabel.text = isPast ? "昨日完成 \(completion.completed) / \(completion.total)" : (isFuture ? "明日预览 \(completion.completed) / \(completion.total)" : "今日完成 \(completion.completed) / \(completion.total)")
        progressDetailLabel.text = completion.total == 0 ? "给今天安排一件小事，计划就开始生长了。" : (completion.completed == completion.total ? "今日计划 · 已完成  🎉" : (isPast ? "已封存的记录，留给未来的自己。" : (isFuture ? "先预览，到了当天再完成。" : "别急，剩下的留给今晚的台灯 🕯")))
        let shouldShowSeal = !isPast && !isFuture && completion.total > 0 && completion.completed == completion.total
        if shouldShowSeal && completionSeal.isHidden {
            completionSeal.isHidden = false
            completionSeal.transform = CGAffineTransform(scaleX: 1.5, y: 1.5).rotated(by: .pi / 20)
            completionSeal.alpha = 0
            UIView.animate(withDuration: UIAccessibility.isReduceMotionEnabled ? 0 : 0.34, delay: 0, usingSpringWithDamping: 0.62, initialSpringVelocity: 0.5) {
                self.completionSeal.transform = CGAffineTransform(rotationAngle: .pi / 30)
                self.completionSeal.alpha = 0.84
            }
        } else if !shouldShowSeal {
            completionSeal.isHidden = true
        }
        renderTasks(instances: instances, isPast: isPast, isFuture: isFuture)

        banner.isHidden = !(isPast || isFuture)
        if isPast {
            banner.backgroundColor = JournalDesign.expiredBackground
            banner.layer.borderWidth = 1
            banner.layer.borderColor = JournalDesign.expiredRed.withAlphaComponent(0.3).cgColor
            bannerLabel.text = "🔖  昨日已封存，记录只读保留。过期未完成的项目不再可编辑或补勾。"
            bannerLabel.textColor = JournalDesign.expiredRed
        } else if isFuture {
            banner.backgroundColor = JournalDesign.lockedBackground
            banner.layer.borderWidth = 1
            banner.layer.borderColor = JournalDesign.lockedGray.cgColor
            bannerLabel.text = "🔒  未来计划仅供预览，到达当天即可完成。"
            bannerLabel.textColor = JournalDesign.secondaryText
        }
        addButton.isHidden = isPast
        previousButton.isEnabled = dayOffset > -30
        nextButton.isEnabled = dayOffset < 30
        previousButton.alpha = previousButton.isEnabled ? 1 : 0.4
        nextButton.alpha = nextButton.isEnabled ? 1 : 0.4
    }

    private func renderTasks(instances: [PlanTaskInstance], isPast: Bool, isFuture: Bool) {
        taskStack.arrangedSubviews.forEach { taskStack.removeArrangedSubview($0); $0.removeFromSuperview() }
        let groups: [(String, [PlanTaskRule])] = [
            ("每日循环", [.daily]),
            ("工作日循环", [.weekdays, .weekends, .custom]),
            (calendar.isDateInToday(displayedDate) ? "今日新增" : "当天新增", [.once])
        ]
        for (title, rules) in groups {
            let values = instances.compactMap { instance -> (PlanTaskInstance, PlanTask)? in
                guard let task = repository.planTask(id: instance.taskID), rules.contains(task.rule) else { return nil }
                return (instance, task)
            }
            guard !values.isEmpty else { continue }
            let header = UILabel()
            header.text = "\(title)  ·  \(values.count) 项"
            header.font = JournalDesign.monoFont(size: 12, textStyle: .caption1)
            header.textColor = JournalDesign.secondaryText
            header.accessibilityTraits = .header
            taskStack.addArrangedSubview(header)
            for (instance, task) in values {
                let cell = PlanTaskCell()
                cell.configure(task: task, instance: instance, isPast: isPast, isFuture: isFuture)
                cell.onToggle = { [weak self] in self?.toggle(instance: instance, task: task) }
                cell.onEdit = { [weak self] in self?.showTaskActions(for: task) }
                taskStack.addArrangedSubview(cell)
            }
        }
        if taskStack.arrangedSubviews.isEmpty {
            let empty = UILabel()
            empty.text = isPast ? "这一天没有安排任务。" : "还没有任务，给今天留一件小事吧。"
            empty.font = JournalDesign.serifFont(size: 14, textStyle: .subheadline)
            empty.textColor = JournalDesign.secondaryText
            empty.textAlignment = .center
            empty.numberOfLines = 0
            empty.backgroundColor = JournalDesign.cardBackground
            empty.layer.cornerRadius = JournalDesign.cardCorner
            empty.clipsToBounds = true
            empty.snp.makeConstraints { make in make.height.greaterThanOrEqualTo(64) }
            taskStack.addArrangedSubview(empty)
        }
    }

    private func toggle(instance: PlanTaskInstance, task: PlanTask) {
        guard calendar.isDateInToday(displayedDate) else { return }
        do {
            let done = !instance.done
            _ = try repository.setPlanTaskDone(taskID: task.id, on: displayedDate, done: done, calendar: calendar)
            UIView.animate(withDuration: 0.2, animations: { self.view.layoutIfNeeded() }) { _ in
                self.reloadData()
                if done && task.title.trimmingCharacters(in: .whitespacesAndNewlines) == "睡前写手账" {
                    self.offerJournalComposer()
                }
            }
        } catch {
            presentError(error)
        }
    }

    @objc private func showPreviousDay() {
        guard dayOffset > -30 else { return }
        shiftDay(by: -1)
    }

    @objc private func showNextDay() {
        guard dayOffset < 30 else { return }
        shiftDay(by: 1)
    }

    private func shiftDay(by value: Int) {
        guard !isAnimatingDateChange, let next = calendar.date(byAdding: .day, value: value, to: displayedDate) else { return }
        isAnimatingDateChange = true
        displayedDate = calendar.startOfDay(for: next)
        UIView.transition(with: contentView, duration: UIAccessibility.isReduceMotionEnabled ? 0 : 0.28, options: [.transitionCrossDissolve, .allowAnimatedContent]) {
            self.reloadData()
        } completion: { _ in self.isAnimatingDateChange = false }
    }

    @objc private func addTask() {
        presentEditor(for: nil)
    }

    private func presentEditor(for task: PlanTask?) {
        let editor = PlanTaskEditorViewController(task: task, date: displayedDate)
        let isEditingExistingTask = task != nil
        editor.onSave = { [weak self] task in
            do {
                if isEditingExistingTask {
                    try self?.repository.replacePlanTask(task, effectiveFrom: self?.displayedDate ?? Date())
                } else {
                    _ = try self?.repository.savePlanTask(task)
                }
            }
            catch { self?.presentError(error) }
        }
        editor.onDelete = { [weak self] task in
            do { try self?.repository.deletePlanTask(task, from: self?.displayedDate ?? Date()) }
            catch { self?.presentError(error) }
        }
        let navigation = UINavigationController(rootViewController: editor)
        navigation.modalPresentationStyle = .pageSheet
        if let sheet = navigation.sheetPresentationController { sheet.detents = [.medium(), .large()]; sheet.prefersGrabberVisible = true }
        present(navigation, animated: true)
    }

    private func showTaskActions(for task: PlanTask) {
        let alert = UIAlertController(title: task.title, message: task.rule == .once ? "修改或删除这个任务。" : "以下操作作用于之后所有天。", preferredStyle: .actionSheet)
        alert.addAction(UIAlertAction(title: "修改", style: .default) { [weak self] _ in self?.presentEditor(for: task) })
        if task.rule != .once {
            let pauseTitle = task.isPaused ? "恢复" : "暂停"
            alert.addAction(UIAlertAction(title: pauseTitle, style: .default) { [weak self] _ in
                do { try self?.repository.setPlanTaskPaused(task, paused: !task.isPaused, from: self?.displayedDate ?? Date()) }
                catch { self?.presentError(error) }
            })
        }
        alert.addAction(UIAlertAction(title: "删除", style: .destructive) { [weak self] _ in
            let confirmation = UIAlertController(title: "删除任务？", message: task.rule == .once ? "这项任务会被删除。" : "这会删除之后所有天的重复任务。", preferredStyle: .alert)
            confirmation.addAction(UIAlertAction(title: "取消", style: .cancel))
            confirmation.addAction(UIAlertAction(title: "删除", style: .destructive) { _ in
                do { try self?.repository.deletePlanTask(task, from: self?.displayedDate ?? Date()) }
                catch { self?.presentError(error) }
            })
            self?.present(confirmation, animated: true)
        })
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        if let popover = alert.popoverPresentationController { popover.sourceView = view; popover.sourceRect = view.bounds }
        present(alert, animated: true)
    }

    @objc private func showPausedTasks() {
        let paused = repository.allPlanTasks(includePaused: true).filter { $0.isPaused && $0.endDate == nil }
        let alert = UIAlertController(
            title: "已暂停任务",
            message: paused.isEmpty ? "当前没有暂停的重复任务。" : "选择任务即可恢复之后的计划。",
            preferredStyle: .actionSheet
        )
        for task in paused {
            alert.addAction(UIAlertAction(title: "恢复 · \(task.title)", style: .default) { [weak self] _ in
                do { try self?.repository.setPlanTaskPaused(task, paused: false) }
                catch { self?.presentError(error) }
            })
        }
        alert.addAction(UIAlertAction(title: "关闭", style: .cancel))
        if let popover = alert.popoverPresentationController {
            popover.barButtonItem = navigationItem.rightBarButtonItem
        }
        present(alert, animated: true)
    }

    private func offerJournalComposer() {
        let alert = UIAlertController(title: "计划完成", message: "要把今晚的这一刻写进手账吗？", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "稍后", style: .cancel))
        alert.addAction(UIAlertAction(title: "去写手账", style: .default) { [weak self] _ in
            let composer = ComposeViewController()
            let navigation = UINavigationController(rootViewController: composer)
            navigation.modalPresentationStyle = .pageSheet
            self?.present(navigation, animated: true)
        })
        present(alert, animated: true)
    }

    private func presentError(_ error: Error) {
        let alert = UIAlertController(title: "操作未完成", message: error.localizedDescription, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "知道了", style: .default))
        present(alert, animated: true)
    }

    private func formattedDate(_ date: Date, format: String) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = format
        return formatter.string(from: date)
    }
}

private final class PlanProgressRing: UIView {
    var progress: CGFloat = 0 { didSet { setNeedsDisplay() } }
    var centerText = "0/0" { didSet { setNeedsDisplay() } }
    override init(frame: CGRect) { super.init(frame: frame); isOpaque = false; accessibilityTraits = .updatesFrequently }
    required init?(coder: NSCoder) { nil }

    override func draw(_ rect: CGRect) {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2 - 6
        let track = UIBezierPath(arcCenter: center, radius: radius, startAngle: -.pi / 2, endAngle: .pi * 1.5, clockwise: true)
        track.lineWidth = 8
        JournalDesign.secondaryBackground.setStroke()
        track.stroke()
        guard progress > 0 else { drawText(center: center); return }
        let value = UIBezierPath(arcCenter: center, radius: radius, startAngle: -.pi / 2, endAngle: -.pi / 2 + .pi * 2 * min(progress, 1), clockwise: true)
        value.lineWidth = 8
        value.lineCapStyle = .round
        JournalDesign.accent.setStroke()
        value.stroke()
        drawText(center: center)
    }

    private func drawText(center: CGPoint) {
        let attributes: [NSAttributedString.Key: Any] = [.font: JournalDesign.monoFont(size: 11, textStyle: .caption2), .foregroundColor: JournalDesign.accent]
        let size = centerText.size(withAttributes: attributes)
        centerText.draw(at: CGPoint(x: center.x - size.width / 2, y: center.y - size.height / 2), withAttributes: attributes)
    }
}

private final class PlanTaskCell: UIView {
    private let checkButton = UIButton(type: .system)
    private let titleLabel = UILabel()
    private let detailLabel = UILabel()
    private let tagLabel = UILabel()
    private var task: PlanTask?
    var onToggle: (() -> Void)?
    var onEdit: (() -> Void)?

    override init(frame: CGRect) {
        super.init(frame: frame)
        applyJournalSoftCard(cornerRadius: 13)
        let longPress = UILongPressGestureRecognizer(target: self, action: #selector(longPressed))
        addGestureRecognizer(longPress)
        addSubview(checkButton); addSubview(titleLabel); addSubview(detailLabel); addSubview(tagLabel)
        checkButton.addTarget(self, action: #selector(toggle), for: .touchUpInside)
        checkButton.snp.makeConstraints { make in make.leading.equalToSuperview().inset(12); make.centerY.equalToSuperview(); make.width.height.equalTo(26) }
        titleLabel.snp.makeConstraints { make in make.top.equalToSuperview().inset(11); make.leading.equalTo(checkButton.snp.trailing).offset(10); make.trailing.lessThanOrEqualTo(tagLabel.snp.leading).offset(-8) }
        detailLabel.snp.makeConstraints { make in make.top.equalTo(titleLabel.snp.bottom).offset(3); make.leading.equalTo(titleLabel); make.trailing.lessThanOrEqualTo(tagLabel.snp.leading).offset(-8); make.bottom.equalToSuperview().inset(11) }
        tagLabel.snp.makeConstraints { make in make.trailing.equalToSuperview().inset(12); make.centerY.equalToSuperview() }
        titleLabel.font = JournalDesign.serifFont(size: 15, textStyle: .subheadline, weight: .semibold)
        titleLabel.textColor = JournalDesign.primaryText
        detailLabel.font = JournalDesign.monoFont(size: 10, textStyle: .caption2)
        detailLabel.textColor = JournalDesign.secondaryText
        tagLabel.font = JournalDesign.monoFont(size: 10, textStyle: .caption2)
        tagLabel.textAlignment = .center
        tagLabel.layer.cornerRadius = 6
        tagLabel.clipsToBounds = true
        accessibilityTraits = .button
        snp.makeConstraints { make in make.height.greaterThanOrEqualTo(62) }
    }

    required init?(coder: NSCoder) { nil }

    func configure(task: PlanTask, instance: PlanTaskInstance, isPast: Bool, isFuture: Bool) {
        self.task = task
        let overdue = isPast && !instance.done
        backgroundColor = overdue ? JournalDesign.expiredBackground : JournalDesign.cardBackground
        layer.borderColor = (overdue ? JournalDesign.expiredRed : JournalDesign.separator).cgColor
        alpha = isPast || isFuture ? 0.58 : 1
        titleLabel.text = task.title.isEmpty ? "未命名任务" : task.title
        titleLabel.textColor = overdue ? JournalDesign.expiredRed : JournalDesign.primaryText
        titleLabel.attributedText = instance.done ? NSAttributedString(string: titleLabel.text ?? "", attributes: [.strikethroughStyle: NSUnderlineStyle.single.rawValue, .foregroundColor: JournalDesign.secondaryText]) : nil
        if !instance.done { titleLabel.text = task.title }
        let streak = JournalRepository.shared.consecutivePlanCompletion(upTo: Date())
        detailLabel.text = "\(task.displayRule) · \(streak) 天连续完成 🔥"
        tagLabel.text = overdue ? "未完成" : task.rule.shortTitle
        tagLabel.textColor = overdue ? .white : UIColor(hex: task.rule.tagColor.text)
        tagLabel.backgroundColor = overdue ? JournalDesign.expiredRed : UIColor(hex: task.rule.tagColor.background)
        if isFuture {
            checkButton.setTitle("🔒", for: .normal)
            checkButton.setTitleColor(JournalDesign.secondaryText, for: .normal)
            accessibilityLabel = "未来任务，\(task.title)，到达当天可完成"
        } else if overdue {
            checkButton.setTitle("×", for: .normal)
            checkButton.setTitleColor(JournalDesign.expiredRed, for: .normal)
            accessibilityLabel = "\(task.title)，已过期，不可编辑"
        } else if instance.done {
            checkButton.setTitle("✓", for: .normal)
            checkButton.setTitleColor(JournalDesign.sage500, for: .normal)
            accessibilityLabel = "\(task.title)，已完成"
        } else {
            checkButton.setTitle("○", for: .normal)
            checkButton.setTitleColor(JournalDesign.accent, for: .normal)
            accessibilityLabel = "\(task.title)，未完成"
        }
        checkButton.titleLabel?.font = .systemFont(ofSize: 22, weight: .medium)
        checkButton.isEnabled = !isPast && !isFuture
        isUserInteractionEnabled = !isPast || isFuture
        accessibilityHint = isFuture ? "到达当天可完成，长按可编辑" : (isPast ? "已过期，不可编辑" : "轻点完成，长按编辑")
    }

    @objc private func toggle() { onToggle?() }

    @objc private func longPressed(_ gesture: UILongPressGestureRecognizer) {
        guard gesture.state == .began else { return }
        onEdit?()
    }
}

final class PlanTaskEditorViewController: JournalBaseViewController {
    private let existingTask: PlanTask?
    private let initialDate: Date
    private let titleField = UITextField()
    private let ruleControl = UISegmentedControl(items: PlanTaskRule.allCases.map(\.rawValue))
    private let weekdayStack = UIStackView()
    private let datePicker = UIDatePicker()
    private let reminderSwitch = UISwitch()
    private let reminderTimePicker = UIDatePicker()
    private var selectedWeekdays: Set<Int> = []
    var onSave: ((PlanTask) -> Void)?
    var onDelete: ((PlanTask) -> Void)?

    init(task: PlanTask?, date: Date) {
        existingTask = task
        initialDate = date
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { nil }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = existingTask == nil ? "新增计划" : "修改计划"
        navigationItem.largeTitleDisplayMode = .never
        navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(close))
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "保存", style: .done, target: self, action: #selector(save))
        if existingTask != nil {
            navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .close, target: self, action: #selector(close))
            navigationItem.rightBarButtonItem = UIBarButtonItem(title: "完成", style: .done, target: self, action: #selector(save))
        }
        setupViews()
        loadValues()
    }

    private func setupViews() {
        view.backgroundColor = JournalDesign.pageBackground
        let scroll = UIScrollView()
        let content = UIView()
        view.addSubview(scroll); scroll.addSubview(content)
        scroll.snp.makeConstraints { make in make.edges.equalTo(view.safeAreaLayoutGuide) }
        content.snp.makeConstraints { make in make.edges.equalToSuperview(); make.width.equalTo(scroll.snp.width) }

        let titleLabel = makeLabel("标题")
        titleField.placeholder = "写下要完成的事"
        titleField.font = JournalDesign.serifFont(size: 17, textStyle: .body)
        titleField.textColor = JournalDesign.primaryText
        titleField.backgroundColor = JournalDesign.cardBackground
        titleField.layer.cornerRadius = 11
        titleField.layer.borderWidth = 1
        titleField.layer.borderColor = JournalDesign.separator.cgColor
        titleField.leftView = UIView(frame: CGRect(x: 0, y: 0, width: 12, height: 1)); titleField.leftViewMode = .always
        titleField.snp.makeConstraints { make in make.height.equalTo(48) }

        let ruleLabel = makeLabel("重复规则")
        ruleControl.selectedSegmentTintColor = JournalDesign.accent
        ruleControl.selectedSegmentIndex = 0
        ruleControl.setTitleTextAttributes([.foregroundColor: JournalDesign.bodyText], for: .normal)
        ruleControl.setTitleTextAttributes([.foregroundColor: JournalDesign.paper50], for: .selected)
        ruleControl.addTarget(self, action: #selector(ruleChanged), for: .valueChanged)

        let weekdaysLabel = makeLabel("自定义周几")
        weekdayStack.axis = .horizontal; weekdayStack.distribution = .fillEqually; weekdayStack.spacing = 6
        ["日", "一", "二", "三", "四", "五", "六"].enumerated().forEach { index, text in
            let button = UIButton(type: .system)
            button.tag = index + 1
            button.setTitle(text, for: .normal)
            button.titleLabel?.font = JournalDesign.monoFont(size: 12, textStyle: .caption1)
            button.layer.cornerRadius = 15
            button.layer.borderWidth = 1
            button.layer.borderColor = JournalDesign.separator.cgColor
            button.backgroundColor = JournalDesign.cardBackground
            button.setTitleColor(JournalDesign.secondaryText, for: .normal)
            button.addTarget(self, action: #selector(toggleWeekday(_:)), for: .touchUpInside)
            weekdayStack.addArrangedSubview(button)
        }

        let dateLabel = makeLabel("归属日期")
        datePicker.datePickerMode = .date
        datePicker.preferredDatePickerStyle = .wheels
        datePicker.locale = Locale(identifier: "zh_CN")
        datePicker.tintColor = JournalDesign.accent
        datePicker.minimumDate = Calendar.current.startOfDay(for: Date())
        datePicker.snp.makeConstraints { make in make.height.equalTo(130) }

        let reminderLabel = makeLabel("提醒")
        reminderSwitch.onTintColor = JournalDesign.accent
        reminderSwitch.addTarget(self, action: #selector(reminderChanged), for: .valueChanged)
        let reminderRow = UIView()
        let reminderText = UILabel()
        reminderText.text = "在任务日提醒我"
        reminderText.font = JournalDesign.serifFont(size: 15, textStyle: .body)
        reminderText.textColor = JournalDesign.primaryText
        reminderRow.addSubview(reminderText); reminderRow.addSubview(reminderSwitch)
        reminderText.snp.makeConstraints { make in make.leading.centerY.equalToSuperview() }
        reminderSwitch.snp.makeConstraints { make in make.trailing.centerY.equalToSuperview() }
        reminderRow.snp.makeConstraints { make in make.height.equalTo(44) }

        reminderTimePicker.datePickerMode = .time
        reminderTimePicker.preferredDatePickerStyle = .compact
        reminderTimePicker.locale = Locale(identifier: "zh_CN")
        reminderTimePicker.tintColor = JournalDesign.accent
        reminderTimePicker.minuteInterval = 5

        let stack = UIStackView(arrangedSubviews: [titleLabel, titleField, ruleLabel, ruleControl, weekdaysLabel, weekdayStack, dateLabel, datePicker, reminderLabel, reminderRow, reminderTimePicker])
        stack.axis = .vertical; stack.spacing = 10
        content.addSubview(stack)
        stack.snp.makeConstraints { make in make.top.leading.trailing.equalToSuperview().inset(20); make.bottom.equalToSuperview().inset(28) }
        ruleControl.snp.makeConstraints { make in make.height.equalTo(36) }
        weekdayStack.snp.makeConstraints { make in make.height.equalTo(32) }
        updateWeekdayVisibility()
        updateReminderVisibility()
        if Calendar.current.startOfDay(for: initialDate) > Calendar.current.startOfDay(for: Date()), existingTask != nil {
            reminderSwitch.isEnabled = false
            reminderTimePicker.isEnabled = false
        }
    }

    private func makeLabel(_ text: String) -> UILabel {
        let label = UILabel(); label.text = text; label.font = JournalDesign.monoFont(size: 12, textStyle: .caption1); label.textColor = JournalDesign.secondaryText; return label
    }

    private func loadValues() {
        guard let task = existingTask else { datePicker.date = initialDate; ruleControl.selectedSegmentIndex = 0; return }
        titleField.text = task.title
        ruleControl.selectedSegmentIndex = PlanTaskRule.allCases.firstIndex(of: task.rule) ?? 0
        selectedWeekdays = Set(task.weekdays)
        datePicker.date = task.anchorDate
        reminderSwitch.isOn = task.reminderEnabled
        if let hour = task.reminderHour, let minute = task.reminderMinute,
           let date = Calendar.current.date(from: DateComponents(hour: hour, minute: minute)) {
            reminderTimePicker.date = date
        }
        datePicker.isEnabled = false
        updateWeekdayButtons(); updateWeekdayVisibility()
        updateReminderVisibility()
    }

    @objc private func ruleChanged() { updateWeekdayVisibility() }

    private func updateWeekdayVisibility() {
        weekdayStack.isHidden = PlanTaskRule.allCases[ruleControl.selectedSegmentIndex] != .custom
    }

    @objc private func reminderChanged() { updateReminderVisibility() }

    private func updateReminderVisibility() {
        reminderTimePicker.isHidden = !reminderSwitch.isOn
    }

    @objc private func toggleWeekday(_ sender: UIButton) {
        if selectedWeekdays.contains(sender.tag) { selectedWeekdays.remove(sender.tag) } else { selectedWeekdays.insert(sender.tag) }
        updateWeekdayButtons()
    }

    private func updateWeekdayButtons() {
        weekdayStack.arrangedSubviews.compactMap { $0 as? UIButton }.forEach { button in
            let selected = selectedWeekdays.contains(button.tag)
            button.backgroundColor = selected ? JournalDesign.accent : JournalDesign.cardBackground
            button.setTitleColor(selected ? JournalDesign.paper50 : JournalDesign.secondaryText, for: .normal)
            button.layer.borderColor = (selected ? JournalDesign.accent : JournalDesign.separator).cgColor
        }
    }

    @objc private func save() {
        let title = titleField.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !title.isEmpty else { titleField.becomeFirstResponder(); return }
        let rule = PlanTaskRule.allCases[ruleControl.selectedSegmentIndex]
        if rule == .custom && selectedWeekdays.isEmpty { return }
        let old = existingTask
        let reminder = reminderSwitch.isOn
        let reminderComponents = Calendar.current.dateComponents([.hour, .minute], from: reminderTimePicker.date)
        let task = PlanTask(
            id: old?.id ?? UUID().uuidString,
            title: title,
            rule: rule,
            weekdays: rule == .custom ? Array(selectedWeekdays) : [],
            anchorDate: old?.anchorDate ?? datePicker.date,
            reminderEnabled: reminder,
            reminderHour: reminder ? reminderComponents.hour : nil,
            reminderMinute: reminder ? reminderComponents.minute : nil,
            createdAt: old?.createdAt ?? Date(),
            isPaused: old?.isPaused ?? false,
            endDate: old?.endDate
        )
        onSave?(task)
        dismiss(animated: true)
    }

    @objc private func close() { dismiss(animated: true) }
}
