//
//  FutureMailboxViewController.swift
//  JournalNote
//

import UIKit
import SnapKit
import UserNotifications

final class FutureMailboxViewController: JournalBaseViewController, UITextViewDelegate {
    private let repository = JournalRepository.shared
    private let scrollView = UIScrollView()
    private let contentStack = UIStackView()
    private let textView = JournalLinedTextView()
    private let placeholderLabel = UILabel()
    private let dateOptions = UISegmentedControl(items: ["1 个月后", "3 个月后", "1 年后", "自定义"])
    private let datePicker = UIDatePicker()
    private let saveButton = JournalActionButton(title: "✉️ 封存这封信")
    private let listCard = UIView()
    private let listStack = UIStackView()
    private var letters: [FutureLetter] = []
    private var observer: NSObjectProtocol?

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "未来信箱"
        navigationItem.largeTitleDisplayMode = .never
        setupViews()
        observer = NotificationCenter.default.addObserver(
            forName: .futureLettersDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.reloadLetters()
        }
        reloadLetters()
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        if isMovingFromParent, let observer {
            NotificationCenter.default.removeObserver(observer)
            self.observer = nil
        }
    }

    private func setupViews() {
        let subtitle = UILabel()
        subtitle.text = "把此刻寄给未来的自己"
        subtitle.font = JournalDesign.handwrittenFont(size: 20, textStyle: .title3)
        subtitle.textColor = JournalDesign.accent
        subtitle.textAlignment = .center

        let formCard = UIView()
        formCard.applyJournalCard(cornerRadius: JournalDesign.panelCorner)
        let receiveTitle = UILabel()
        receiveTitle.text = "收信时间"
        receiveTitle.font = JournalDesign.serifFont(size: 15, textStyle: .headline, weight: .semibold)
        receiveTitle.textColor = JournalDesign.primaryText

        dateOptions.selectedSegmentIndex = 0
        dateOptions.selectedSegmentTintColor = JournalDesign.amber100
        dateOptions.setTitleTextAttributes([.foregroundColor: JournalDesign.accent], for: .selected)
        dateOptions.setTitleTextAttributes([.foregroundColor: JournalDesign.secondaryText], for: .normal)
        dateOptions.addTarget(self, action: #selector(dateOptionChanged), for: .valueChanged)

        datePicker.datePickerMode = .date
        datePicker.preferredDatePickerStyle = .compact
        datePicker.minimumDate = Calendar.current.date(byAdding: .day, value: 1, to: Date())
        datePicker.tintColor = JournalDesign.accent
        setRelativeDate(months: 1)

        textView.delegate = self
        textView.accessibilityLabel = "写给未来的信"
        placeholderLabel.text = "写一封信，给未来的自己…"
        placeholderLabel.font = JournalDesign.serifFont(size: 17, textStyle: .body)
        placeholderLabel.textColor = JournalDesign.secondaryText.withAlphaComponent(0.65)
        placeholderLabel.isUserInteractionEnabled = false
        textView.addSubview(placeholderLabel)

        formCard.addSubview(receiveTitle)
        formCard.addSubview(dateOptions)
        formCard.addSubview(datePicker)
        formCard.addSubview(textView)
        receiveTitle.snp.makeConstraints { make in
            make.top.leading.trailing.equalToSuperview().inset(18)
        }
        dateOptions.snp.makeConstraints { make in
            make.top.equalTo(receiveTitle.snp.bottom).offset(12)
            make.leading.trailing.equalToSuperview().inset(18)
        }
        datePicker.snp.makeConstraints { make in
            make.top.equalTo(dateOptions.snp.bottom).offset(12)
            make.leading.equalToSuperview().inset(18)
        }
        textView.snp.makeConstraints { make in
            make.top.equalTo(datePicker.snp.bottom).offset(12)
            make.leading.trailing.bottom.equalToSuperview().inset(18)
            make.height.greaterThanOrEqualTo(180)
        }
        placeholderLabel.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(14)
            make.leading.equalToSuperview().offset(16)
            make.trailing.lessThanOrEqualToSuperview().inset(16)
        }

        saveButton.addTarget(self, action: #selector(saveLetter), for: .touchUpInside)

        listCard.applyJournalSoftCard(cornerRadius: JournalDesign.panelCorner)
        listStack.axis = .vertical
        listStack.spacing = 10
        listCard.addSubview(listStack)
        listStack.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(18)
        }

        contentStack.axis = .vertical
        contentStack.spacing = 16
        contentStack.addArrangedSubview(subtitle)
        contentStack.addArrangedSubview(formCard)
        contentStack.addArrangedSubview(saveButton)
        contentStack.addArrangedSubview(listCard)

        view.addSubview(scrollView)
        scrollView.addSubview(contentStack)
        scrollView.alwaysBounceVertical = true
        scrollView.keyboardDismissMode = .interactive
        scrollView.snp.makeConstraints { make in
            make.edges.equalTo(view.safeAreaLayoutGuide)
        }
        contentStack.snp.makeConstraints { make in
            make.top.bottom.equalToSuperview().inset(22)
            make.leading.trailing.equalToSuperview().inset(20)
            make.width.equalTo(scrollView.snp.width).offset(-40)
        }
    }

    func textViewDidChange(_ textView: UITextView) {
        placeholderLabel.isHidden = !textView.text.isEmpty
    }

    @objc private func dateOptionChanged() {
        switch dateOptions.selectedSegmentIndex {
        case 0: setRelativeDate(months: 1)
        case 1: setRelativeDate(months: 3)
        case 2: setRelativeDate(years: 1)
        default: break
        }
    }

    private func setRelativeDate(months: Int = 0, years: Int = 0) {
        var components = DateComponents()
        components.month = months
        components.year = years
        datePicker.setDate(Calendar.current.date(byAdding: components, to: Date()) ?? Date(), animated: true)
    }

    @objc private func saveLetter() {
        let body = textView.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !body.isEmpty else {
            showAlert(title: "还没有写信", message: "先写下一些想对未来自己说的话吧。")
            return
        }
        let openAt = Calendar.current.startOfDay(for: datePicker.date)
        guard openAt > Calendar.current.startOfDay(for: Date()) else {
            showAlert(title: "请选择未来日期", message: "收信时间至少需要是明天。")
            return
        }

        let letter = FutureLetter(body: body, openAt: openAt)
        do {
            try repository.saveFutureLetter(letter)
            scheduleNotification(for: letter)
            textView.text = nil
            placeholderLabel.isHidden = false
            showAlert(title: "已封存", message: "到期后，这封信会在未来信箱里等你。")
        } catch {
            showAlert(title: "封存失败", message: error.localizedDescription)
        }
    }

    private func scheduleNotification(for letter: FutureLetter) {
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            guard granted else { return }
            let content = UNMutableNotificationContent()
            content.title = "未来的信已送达"
            content.body = "你曾经写给自己的那封信，今天可以开启了。"
            content.sound = .default
            var components = Calendar.current.dateComponents([.year, .month, .day], from: letter.openAt)
            components.hour = 9
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            center.add(UNNotificationRequest(
                identifier: "future-letter-\(letter.id)",
                content: content,
                trigger: trigger
            ))
        }
    }

    private func reloadLetters() {
        letters = repository.futureLetters()
        listStack.arrangedSubviews.forEach {
            listStack.removeArrangedSubview($0)
            $0.removeFromSuperview()
        }

        let header = UILabel()
        header.text = letters.isEmpty ? "还没有封存的信" : "已封存 \(letters.count) 封"
        header.font = JournalDesign.monoFont(size: 12, textStyle: .caption1)
        header.textColor = JournalDesign.secondaryText
        listStack.addArrangedSubview(header)

        for letter in letters {
            listStack.addArrangedSubview(makeLetterRow(letter))
        }
    }

    private func makeLetterRow(_ letter: FutureLetter) -> UIView {
        let row = UIControl()
        row.backgroundColor = JournalDesign.secondaryBackground
        row.layer.cornerRadius = 12
        row.layer.cornerCurve = .continuous
        row.accessibilityIdentifier = letter.id
        row.addTarget(self, action: #selector(openLetter(_:)), for: .touchUpInside)

        let isAvailable = letter.openAt <= Date()
        let icon = UIImageView(image: UIImage(systemName: isAvailable ? "envelope.open.fill" : "envelope.fill"))
        icon.tintColor = isAvailable ? JournalDesign.accent : JournalDesign.secondaryText
        let label = UILabel()
        label.font = JournalDesign.serifFont(size: 14, textStyle: .subheadline)
        label.textColor = JournalDesign.bodyText
        label.numberOfLines = 2
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy.MM.dd"
        if isAvailable {
            label.text = letter.isOpened ? "已开启 · \(formatter.string(from: letter.openAt))\n再次读一读这封信" : "可以开启 · \(formatter.string(from: letter.openAt))"
        } else {
            let days = max(1, Calendar.current.dateComponents([.day], from: Date(), to: letter.openAt).day ?? 1)
            label.text = "\(formatter.string(from: letter.openAt)) 开启\n还有 \(days) 天"
        }
        row.addSubview(icon)
        row.addSubview(label)
        icon.snp.makeConstraints { make in
            make.leading.equalToSuperview().inset(14)
            make.centerY.equalToSuperview()
            make.width.height.equalTo(22)
        }
        label.snp.makeConstraints { make in
            make.top.bottom.trailing.equalToSuperview().inset(12)
            make.leading.equalTo(icon.snp.trailing).offset(12)
        }
        row.snp.makeConstraints { make in make.height.greaterThanOrEqualTo(58) }
        row.accessibilityLabel = label.text
        return row
    }

    @objc private func openLetter(_ sender: UIControl) {
        guard let id = sender.accessibilityIdentifier,
              let letter = letters.first(where: { $0.id == id }) else { return }
        guard letter.openAt <= Date() else {
            let days = max(1, Calendar.current.dateComponents([.day], from: Date(), to: letter.openAt).day ?? 1)
            showAlert(title: "信件还在路上", message: "还有 \(days) 天才能开启。")
            return
        }
        let body: String
        do {
            body = try FutureLetterCipher.decrypt(letter.body)
        } catch {
            showAlert(title: "暂时无法开启", message: "信件内容解密失败，请稍后再试。")
            return
        }
        if !letter.isOpened {
            letter.isOpened = true
            do {
                try repository.saveFutureLetter(letter)
            } catch {
                showAlert(title: "开启状态未保存", message: error.localizedDescription)
                return
            }
        }
        showAlert(title: "写给未来的你", message: body)
    }

    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "知道了", style: .default))
        present(alert, animated: true)
    }
}
