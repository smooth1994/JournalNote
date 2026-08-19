//
//  ComposeViewController.swift
//  JournalNote
//

import UIKit
import SnapKit

final class ComposeViewController: JournalBaseViewController {
    private let repository = JournalRepository.shared
    private let scrollView = UIScrollView()
    private let contentView = UIView()
    private let headlineLabel = UILabel()
    private let dateLabel = UILabel()
    private let titleField = UITextField()
    private let moodPicker = MoodPickerView()
    private let bodyTextView = JournalLinedTextView()
    private let bodyPlaceholderLabel = UILabel()
    private let tagStack = UIStackView()
    private let saveButton = JournalActionButton(title: "记下此刻")
    private var selectedTags = Set(["日常"])
    private var tagButtons: [String: UIButton] = [:]

    private let tagOptions = ["日常", "旅行", "灵感", "美食"]

    override func viewDidLoad() {
        super.viewDidLoad()
        setupViews()
        refreshDate()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: animated)
        refreshDate()
    }

    private func setupViews() {
        scrollView.alwaysBounceVertical = true
        scrollView.keyboardDismissMode = .interactive
        scrollView.showsVerticalScrollIndicator = false

        headlineLabel.text = "此刻"
        headlineLabel.textColor = JournalDesign.primaryText
        headlineLabel.font = JournalDesign.serifFont(size: 34, textStyle: .largeTitle, weight: .bold)
        headlineLabel.adjustsFontForContentSizeCategory = true

        dateLabel.textColor = JournalDesign.accent
        dateLabel.font = JournalDesign.handwrittenFont(size: 16, textStyle: .subheadline)
        dateLabel.adjustsFontForContentSizeCategory = true

        titleField.placeholder = "给这段时光起个名字…"
        titleField.font = JournalDesign.serifFont(size: 18, textStyle: .headline, weight: .semibold)
        titleField.textColor = JournalDesign.primaryText
        titleField.adjustsFontForContentSizeCategory = true
        titleField.backgroundColor = JournalDesign.cardBackground
        titleField.layer.cornerRadius = JournalDesign.cardCorner
        titleField.layer.cornerCurve = .continuous
        titleField.layer.borderWidth = 1.5
        titleField.layer.borderColor = JournalDesign.separator.cgColor
        titleField.leftView = UIView(frame: CGRect(x: 0, y: 0, width: 16, height: 1))
        titleField.leftViewMode = .always
        titleField.rightView = UIView(frame: CGRect(x: 0, y: 0, width: 16, height: 1))
        titleField.rightViewMode = .always
        titleField.tintColor = JournalDesign.accent
        titleField.accessibilityLabel = "手账标题"

        bodyTextView.delegate = self
        bodyPlaceholderLabel.text = "给今天：\n\n写下此刻想留住的一句话、一个画面，或一份心情。"
        bodyPlaceholderLabel.font = JournalDesign.handwrittenFont(size: 18, textStyle: .body)
        bodyPlaceholderLabel.textColor = JournalDesign.ink300
        bodyPlaceholderLabel.numberOfLines = 0
        bodyPlaceholderLabel.isUserInteractionEnabled = false

        let moodTitle = makeSectionTitle("此刻的心情")
        let tagsTitle = makeSectionTitle("给这页贴上标签")
        let tools = makeWritingTools()

        tagStack.axis = .horizontal
        tagStack.alignment = .center
        tagStack.spacing = 8
        tagStack.distribution = .fillEqually
        for tag in tagOptions {
            let button = UIButton(type: .system)
            button.setTitle(tag, for: .normal)
            button.titleLabel?.font = JournalDesign.serifFont(size: 13, textStyle: .caption1, weight: .medium)
            button.layer.cornerRadius = 17
            button.layer.cornerCurve = .continuous
            button.snp.makeConstraints { make in
                make.height.equalTo(34)
            }
            button.accessibilityLabel = "标签：\(tag)"
            button.addTarget(self, action: #selector(toggleTag(_:)), for: .touchUpInside)
            tagButtons[tag] = button
            tagStack.addArrangedSubview(button)
        }
        updateTagSelection()

        saveButton.addTarget(self, action: #selector(saveEntry), for: .touchUpInside)

        view.addSubview(scrollView)
        scrollView.addSubview(contentView)
        [headlineLabel, dateLabel, moodTitle, moodPicker, titleField, bodyTextView, bodyPlaceholderLabel, tools, tagsTitle, tagStack, saveButton].forEach {
            contentView.addSubview($0)
        }

        scrollView.snp.makeConstraints { make in
            make.edges.equalTo(view.safeAreaLayoutGuide)
        }
        contentView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
            make.width.equalTo(scrollView.snp.width)
        }
        headlineLabel.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(18)
            make.leading.trailing.equalToSuperview().inset(20)
        }
        dateLabel.snp.makeConstraints { make in
            make.top.equalTo(headlineLabel.snp.bottom).offset(2)
            make.leading.trailing.equalTo(headlineLabel)
        }
        moodTitle.snp.makeConstraints { make in
            make.top.equalTo(dateLabel.snp.bottom).offset(24)
            make.leading.trailing.equalTo(headlineLabel)
        }
        moodPicker.snp.makeConstraints { make in
            make.top.equalTo(moodTitle.snp.bottom).offset(12)
            make.leading.equalTo(headlineLabel)
            make.trailing.lessThanOrEqualToSuperview().inset(20)
        }
        titleField.snp.makeConstraints { make in
            make.top.equalTo(moodPicker.snp.bottom).offset(24)
            make.leading.trailing.equalTo(headlineLabel)
            make.height.greaterThanOrEqualTo(52)
        }
        bodyTextView.snp.makeConstraints { make in
            make.top.equalTo(titleField.snp.bottom).offset(12)
            make.leading.trailing.equalTo(headlineLabel)
            make.height.greaterThanOrEqualTo(254)
        }
        bodyPlaceholderLabel.snp.makeConstraints { make in
            make.top.equalTo(bodyTextView).offset(18)
            make.leading.equalTo(bodyTextView).offset(20)
            make.trailing.equalTo(bodyTextView).inset(20)
        }
        tools.snp.makeConstraints { make in
            make.top.equalTo(bodyTextView.snp.bottom).offset(14)
            make.centerX.equalToSuperview()
        }
        tagsTitle.snp.makeConstraints { make in
            make.top.equalTo(tools.snp.bottom).offset(20)
            make.leading.trailing.equalTo(headlineLabel)
        }
        tagStack.snp.makeConstraints { make in
            make.top.equalTo(tagsTitle.snp.bottom).offset(10)
            make.leading.trailing.equalTo(headlineLabel)
        }
        saveButton.snp.makeConstraints { make in
            make.top.equalTo(tagStack.snp.bottom).offset(26)
            make.centerX.equalToSuperview()
            make.bottom.equalToSuperview().inset(28)
        }
    }

    private func makeSectionTitle(_ text: String) -> UILabel {
        let label = UILabel()
        label.text = text
        label.textColor = JournalDesign.bodyText
        label.font = JournalDesign.serifFont(size: 14, textStyle: .subheadline, weight: .semibold)
        label.adjustsFontForContentSizeCategory = true
        return label
    }

    private func makeWritingTools() -> UIStackView {
        let symbols = [("pencil.tip", "笔"), ("photo", "图片"), ("face.smiling", "贴纸"), ("music.note", "音乐"), ("tag", "标签")]
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.spacing = 10
        stack.alignment = .center

        for (symbol, label) in symbols {
            let button = UIButton(type: .system)
            button.setImage(UIImage(systemName: symbol), for: .normal)
            button.tintColor = JournalDesign.bodyText
            button.backgroundColor = JournalDesign.secondaryBackground
            button.layer.cornerRadius = 19
            button.layer.cornerCurve = .continuous
            button.accessibilityLabel = label
            button.accessibilityHint = "第一版仅展示书写工具"
            button.snp.makeConstraints { make in
                make.width.height.equalTo(38)
            }
            stack.addArrangedSubview(button)
        }
        return stack
    }

    private func refreshDate() {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "yyyy.MM.dd · EEE · 窗外有光"
        dateLabel.text = formatter.string(from: Date()).uppercased()
    }

    @objc private func toggleTag(_ sender: UIButton) {
        guard let tag = tagButtons.first(where: { $0.value === sender })?.key else { return }
        if selectedTags.contains(tag), selectedTags.count > 1 {
            selectedTags.remove(tag)
        } else {
            selectedTags.insert(tag)
        }
        updateTagSelection()
    }

    private func updateTagSelection() {
        for (tag, button) in tagButtons {
            let isSelected = selectedTags.contains(tag)
            button.backgroundColor = isSelected ? JournalDesign.amber100 : JournalDesign.secondaryBackground
            button.setTitleColor(isSelected ? JournalDesign.amber600 : JournalDesign.secondaryText, for: .normal)
            button.layer.borderWidth = isSelected ? 1 : 0
            button.layer.borderColor = isSelected ? JournalDesign.amber500.cgColor : UIColor.clear.cgColor
            button.accessibilityTraits = isSelected ? [.button, .selected] : .button
        }
    }

    @objc private func saveEntry() {
        let body = bodyTextView.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !body.isEmpty else {
            presentValidationAlert()
            return
        }

        let entry = JournalEntry(
            title: titleField.text ?? "",
            body: body,
            mood: moodPicker.selectedMood,
            tags: tagOptions.filter(selectedTags.contains)
        )

        do {
            try repository.save(entry)
            clearComposer()
            let alert = UIAlertController(title: "这一刻已被拾起", message: "它会安静地留在你的时光轴里。", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "继续写", style: .cancel))
            alert.addAction(UIAlertAction(title: "查看时光轴", style: .default) { [weak self] _ in
                (self?.tabBarController as? JournalTabBarController)?.selectTimeline()
            })
            present(alert, animated: true)
        } catch {
            let alert = UIAlertController(title: "保存失败", message: error.localizedDescription, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "知道了", style: .default))
            present(alert, animated: true)
        }
    }

    private func clearComposer() {
        titleField.text = nil
        bodyTextView.text = nil
        bodyPlaceholderLabel.isHidden = false
        moodPicker.setSelectedMood(.happy)
        selectedTags = ["日常"]
        updateTagSelection()
        view.endEditing(true)
    }

    private func presentValidationAlert() {
        let alert = UIAlertController(title: "留一句话给今天吧", message: "写下至少一段心情后，才能把它放进时光轴。", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "继续写", style: .default))
        present(alert, animated: true)
    }
}

extension ComposeViewController: UITextViewDelegate {
    func textViewDidChange(_ textView: UITextView) {
        bodyPlaceholderLabel.isHidden = !textView.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}
