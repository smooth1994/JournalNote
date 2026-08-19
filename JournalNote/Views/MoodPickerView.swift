//
//  MoodPickerView.swift
//  JournalNote
//

import UIKit
import SnapKit

final class MoodPickerView: UIView {
    var onMoodChanged: ((JournalMood) -> Void)?

    private(set) var selectedMood: JournalMood {
        didSet { updateSelection() }
    }
    private var buttons: [JournalMood: UIButton] = [:]

    init(selectedMood: JournalMood = .happy) {
        self.selectedMood = selectedMood
        super.init(frame: .zero)
        setupViews()
        updateSelection()
    }

    required init?(coder: NSCoder) {
        nil
    }

    func setSelectedMood(_ mood: JournalMood, notify: Bool = false) {
        selectedMood = mood
        if notify {
            onMoodChanged?(mood)
        }
    }

    private func setupViews() {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.alignment = .center
        stack.distribution = .equalSpacing
        stack.spacing = 8
        addSubview(stack)
        stack.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        for mood in JournalMood.allCases {
            let button = UIButton(type: .system)
            button.setTitle(mood.emoji, for: .normal)
            button.titleLabel?.font = UIFont.systemFont(ofSize: 23)
            button.backgroundColor = JournalDesign.secondaryBackground
            button.layer.cornerRadius = 26
            button.layer.cornerCurve = .continuous
            button.accessibilityLabel = mood.title
            button.accessibilityHint = "选择\(mood.title)心情"
            button.addTarget(self, action: #selector(selectMood(_:)), for: .touchUpInside)
            button.snp.makeConstraints { make in
                make.width.height.equalTo(52)
            }
            buttons[mood] = button
            stack.addArrangedSubview(button)
        }
    }

    @objc private func selectMood(_ sender: UIButton) {
        guard let mood = buttons.first(where: { $0.value === sender })?.key else { return }
        setSelectedMood(mood, notify: true)
    }

    private func updateSelection() {
        for (mood, button) in buttons {
            let isSelected = mood == selectedMood
            button.layer.borderWidth = isSelected ? 2 : 0
            button.layer.borderColor = isSelected ? JournalDesign.accent.cgColor : UIColor.clear.cgColor
            button.backgroundColor = isSelected ? JournalDesign.amber100 : JournalDesign.secondaryBackground
            button.transform = isSelected ? CGAffineTransform(scaleX: 1.12, y: 1.12) : .identity
            button.accessibilityTraits = isSelected ? [.button, .selected] : .button
        }
    }
}
