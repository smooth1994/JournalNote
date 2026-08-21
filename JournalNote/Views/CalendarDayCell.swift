//
//  CalendarDayCell.swift
//  JournalNote
//

import UIKit
import SnapKit

final class CalendarDayCell: UICollectionViewCell {
    static let reuseIdentifier = "CalendarDayCell"

    private let dayLabel = UILabel()
    private let dot = UIView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        contentView.addSubview(dayLabel)
        contentView.addSubview(dot)

        dayLabel.textAlignment = .center
        dayLabel.font = JournalDesign.serifFont(size: 14, textStyle: .subheadline, weight: .medium)
        dayLabel.adjustsFontForContentSizeCategory = true
        dayLabel.layer.cornerRadius = 18
        dayLabel.layer.cornerCurve = .continuous
        dayLabel.clipsToBounds = true

        dot.layer.cornerRadius = 2
        dot.backgroundColor = JournalDesign.clay500

        dayLabel.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.width.height.equalTo(36)
        }
        dot.snp.makeConstraints { make in
            make.centerX.equalTo(dayLabel)
            make.bottom.equalTo(dayLabel.snp.bottom).offset(-4)
            make.width.height.equalTo(4)
        }
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        resetVisualState()
    }

    func configure(day: Int?, hasEntry: Bool, isCheckedIn: Bool, isFuture: Bool, isToday: Bool, isSelected: Bool) {
        resetVisualState()

        guard let day else {
            return
        }

        dayLabel.text = "\(day)"
        dot.isHidden = !isCheckedIn || isToday
        dot.backgroundColor = JournalDesign.sage500

        if isFuture {
            dayLabel.textColor = JournalDesign.ink300
        } else if isToday {
            dayLabel.backgroundColor = JournalDesign.accent
            dayLabel.textColor = JournalDesign.paper50
        } else if isSelected {
            dayLabel.backgroundColor = JournalDesign.amber100
            dayLabel.textColor = JournalDesign.amber600
        } else if hasEntry {
            dayLabel.backgroundColor = JournalDesign.amber100.withAlphaComponent(0.78)
            dayLabel.textColor = JournalDesign.amber600
        }

        isAccessibilityElement = true
        let status = isCheckedIn ? "已打卡" : (hasEntry ? "有记录" : (isFuture ? "未来日期" : "无记录"))
        accessibilityLabel = "\(day) 日，\(status)"
        accessibilityTraits = isSelected ? [.button, .selected] : .button
    }

    private func resetVisualState() {
        dayLabel.text = nil
        dayLabel.textColor = JournalDesign.bodyText
        dayLabel.backgroundColor = .clear
        dot.isHidden = true
        dot.backgroundColor = JournalDesign.sage500
        accessibilityLabel = nil
        accessibilityTraits = []
        isAccessibilityElement = false
    }
}
