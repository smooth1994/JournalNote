//
//  CalendarViewController.swift
//  JournalNote
//

import UIKit
import SnapKit

final class CalendarViewController: JournalBaseViewController {
    private struct DayItem {
        let date: Date?
        let day: Int?
    }

    private let repository = JournalRepository.shared
    private var calendar: Calendar = {
        var calendar = Calendar.current
        calendar.firstWeekday = 2 // Monday, as in the supplied design.
        return calendar
    }()
    private var displayedMonth = Date()
    private var days: [DayItem] = []
    private var monthEntries: [JournalEntry] = []
    private var selectedDate: Date?

    private let scrollView = UIScrollView()
    private let contentView = UIView()
    private let calendarCard = UIView()
    private let monthLabel = UILabel()
    private let previousButton = UIButton(type: .system)
    private let nextButton = UIButton(type: .system)
    private let weekStack = UIStackView()
    private let dayCollectionView: UICollectionView
    private let statisticsCard = UIView()
    private let statisticsTitleLabel = UILabel()
    private let statisticsValueLabel = UILabel()
    private let statisticsDetailLabel = UILabel()
    private var dataObserver: NSObjectProtocol?

    init() {
        let layout = UICollectionViewFlowLayout()
        layout.minimumLineSpacing = 5
        layout.minimumInteritemSpacing = 0
        layout.sectionInset = .zero
        dayCollectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "日历"
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

    deinit {
        if let dataObserver {
            NotificationCenter.default.removeObserver(dataObserver)
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        reloadData()
    }

    private func setupViews() {
        scrollView.alwaysBounceVertical = true
        scrollView.showsVerticalScrollIndicator = false

        calendarCard.applyJournalCard(cornerRadius: JournalDesign.panelCorner)
        monthLabel.font = JournalDesign.serifFont(size: 17, textStyle: .headline, weight: .semibold)
        monthLabel.textColor = JournalDesign.primaryText
        monthLabel.textAlignment = .center
        monthLabel.adjustsFontForContentSizeCategory = true

        configureMonthButton(previousButton, image: "chevron.left", action: #selector(showPreviousMonth))
        configureMonthButton(nextButton, image: "chevron.right", action: #selector(showNextMonth))

        weekStack.axis = .horizontal
        weekStack.distribution = .fillEqually
        ["一", "二", "三", "四", "五", "六", "日"].forEach { title in
            let label = UILabel()
            label.text = title
            label.textColor = JournalDesign.secondaryText
            label.font = JournalDesign.monoFont(size: 11, textStyle: .caption2)
            label.textAlignment = .center
            weekStack.addArrangedSubview(label)
        }

        dayCollectionView.backgroundColor = .clear
        dayCollectionView.dataSource = self
        dayCollectionView.delegate = self
        dayCollectionView.isScrollEnabled = false
        dayCollectionView.register(CalendarDayCell.self, forCellWithReuseIdentifier: CalendarDayCell.reuseIdentifier)

        statisticsCard.applyJournalSoftCard(cornerRadius: JournalDesign.panelCorner)
        statisticsTitleLabel.text = "本月统计"
        statisticsTitleLabel.font = JournalDesign.monoFont(size: 12, textStyle: .caption1)
        statisticsTitleLabel.textColor = JournalDesign.secondaryText
        statisticsValueLabel.font = JournalDesign.serifFont(size: 18, textStyle: .headline, weight: .semibold)
        statisticsValueLabel.textColor = JournalDesign.primaryText
        statisticsValueLabel.adjustsFontForContentSizeCategory = true
        statisticsDetailLabel.font = JournalDesign.serifFont(size: 13, textStyle: .subheadline)
        statisticsDetailLabel.textColor = JournalDesign.secondaryText
        statisticsDetailLabel.numberOfLines = 0
        statisticsDetailLabel.adjustsFontForContentSizeCategory = true

        view.addSubview(scrollView)
        scrollView.addSubview(contentView)
        contentView.addSubview(calendarCard)
        calendarCard.addSubview(monthLabel)
        calendarCard.addSubview(previousButton)
        calendarCard.addSubview(nextButton)
        calendarCard.addSubview(weekStack)
        calendarCard.addSubview(dayCollectionView)
        contentView.addSubview(statisticsCard)
        statisticsCard.addSubview(statisticsTitleLabel)
        statisticsCard.addSubview(statisticsValueLabel)
        statisticsCard.addSubview(statisticsDetailLabel)

        scrollView.snp.makeConstraints { make in
            make.edges.equalTo(view.safeAreaLayoutGuide)
        }
        contentView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
            make.width.equalTo(scrollView.snp.width)
        }
        calendarCard.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(14)
            make.leading.trailing.equalToSuperview().inset(20)
        }
        monthLabel.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(18)
            make.centerX.equalToSuperview()
        }
        previousButton.snp.makeConstraints { make in
            make.centerY.equalTo(monthLabel)
            make.leading.equalToSuperview().offset(14)
        }
        nextButton.snp.makeConstraints { make in
            make.centerY.equalTo(monthLabel)
            make.trailing.equalToSuperview().inset(14)
        }
        weekStack.snp.makeConstraints { make in
            make.top.equalTo(monthLabel.snp.bottom).offset(18)
            make.leading.trailing.equalToSuperview().inset(14)
        }
        dayCollectionView.snp.makeConstraints { make in
            make.top.equalTo(weekStack.snp.bottom).offset(8)
            make.leading.trailing.equalTo(weekStack)
            make.height.equalTo(248)
            make.bottom.equalToSuperview().inset(16)
        }
        statisticsCard.snp.makeConstraints { make in
            make.top.equalTo(calendarCard.snp.bottom).offset(16)
            make.leading.trailing.equalTo(calendarCard)
            make.bottom.equalToSuperview().inset(28)
        }
        statisticsTitleLabel.snp.makeConstraints { make in
            make.top.leading.equalToSuperview().inset(18)
            make.trailing.equalToSuperview().inset(18)
        }
        statisticsValueLabel.snp.makeConstraints { make in
            make.top.equalTo(statisticsTitleLabel.snp.bottom).offset(5)
            make.leading.trailing.equalTo(statisticsTitleLabel)
        }
        statisticsDetailLabel.snp.makeConstraints { make in
            make.top.equalTo(statisticsValueLabel.snp.bottom).offset(5)
            make.leading.trailing.equalTo(statisticsTitleLabel)
            make.bottom.equalToSuperview().inset(18)
        }
    }

    private func configureMonthButton(_ button: UIButton, image: String, action: Selector) {
        button.setImage(UIImage(systemName: image), for: .normal)
        button.tintColor = JournalDesign.accent
        button.backgroundColor = JournalDesign.secondaryBackground
        button.layer.cornerRadius = 18
        button.layer.cornerCurve = .continuous
        button.addTarget(self, action: action, for: .touchUpInside)
        button.snp.makeConstraints { make in
            make.width.height.equalTo(36)
        }
    }

    private func reloadData() {
        monthEntries = repository.monthlyEntries(for: displayedMonth, calendar: calendar)
        days = makeDays(for: displayedMonth)
        updateMonthHeader()
        updateStatistics()
        dayCollectionView.reloadData()
    }

    private func makeDays(for month: Date) -> [DayItem] {
        guard let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: month)),
              let range = calendar.range(of: .day, in: .month, for: month) else {
            return []
        }

        let weekday = calendar.component(.weekday, from: startOfMonth)
        let leadingEmptyDays = (weekday - calendar.firstWeekday + 7) % 7
        var items = Array(repeating: DayItem(date: nil, day: nil), count: leadingEmptyDays)
        for day in range {
            let date = calendar.date(byAdding: .day, value: day - 1, to: startOfMonth)
            items.append(DayItem(date: date, day: day))
        }
        while items.count < 42 {
            items.append(DayItem(date: nil, day: nil))
        }
        return items
    }

    private func updateMonthHeader() {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "yyyy 年 M 月"
        monthLabel.text = formatter.string(from: displayedMonth)
    }

    private func updateStatistics() {
        let dayCount = Set(monthEntries.map { calendar.startOfDay(for: $0.createdAt) }).count
        let consecutive = repository.consecutiveDays(calendar: calendar)
        statisticsValueLabel.text = "已记录 \(dayCount) 天 · 连续 \(consecutive) 天 🔥"

        let total = max(monthEntries.count, 1)
        let moodText = repository.moodCounts(for: monthEntries)
            .sorted { $0.value > $1.value }
            .prefix(3)
            .map { mood, count in "\(mood.title) \(Int((Double(count) / Double(total) * 100).rounded()))%" }
            .joined(separator: " · ")
        statisticsDetailLabel.text = moodText.isEmpty ? "这个月还没有记录，点亮第一天吧。" : "心情占比：\(moodText)"
    }

    @objc private func showPreviousMonth() {
        displayedMonth = calendar.date(byAdding: .month, value: -1, to: displayedMonth) ?? displayedMonth
        selectedDate = nil
        reloadData()
    }

    @objc private func showNextMonth() {
        displayedMonth = calendar.date(byAdding: .month, value: 1, to: displayedMonth) ?? displayedMonth
        selectedDate = nil
        reloadData()
    }
}

extension CalendarViewController: UICollectionViewDataSource, UICollectionViewDelegate, UICollectionViewDelegateFlowLayout {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        days.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let cell = collectionView.dequeueReusableCell(
            withReuseIdentifier: CalendarDayCell.reuseIdentifier,
            for: indexPath
        ) as? CalendarDayCell else {
            return UICollectionViewCell()
        }

        let item = days[indexPath.item]
        let date = item.date
        let hasEntry = date.map { day in monthEntries.contains { calendar.isDate($0.createdAt, inSameDayAs: day) } } ?? false
        let isToday = date.map { calendar.isDateInToday($0) } ?? false
        let isSelected = date.map { selected in selectedDate.map { calendar.isDate($0, inSameDayAs: selected) } ?? false } ?? false
        cell.configure(day: item.day, hasEntry: hasEntry, isToday: isToday, isSelected: isSelected)
        return cell
    }

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        CGSize(width: collectionView.bounds.width / 7, height: 36)
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard let date = days[indexPath.item].date else { return }
        selectedDate = date
        collectionView.reloadData()

        if let entry = monthEntries.first(where: { calendar.isDate($0.createdAt, inSameDayAs: date) }) {
            navigationController?.pushViewController(JournalDetailViewController(entry: entry), animated: true)
        }
    }
}
