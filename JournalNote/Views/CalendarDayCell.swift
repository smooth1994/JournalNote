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
        dayLabel.text = nil
        dot.isHidden = true
        isAccessibilityElement = false
    }

    func configure(day: Int?, hasEntry: Bool, isToday: Bool, isSelected: Bool) {
        guard let day else {
            dayLabel.text = nil
            dot.isHidden = true
            return
        }

        dayLabel.text = "\(day)"
        dayLabel.textColor = JournalDesign.bodyText
        dayLabel.backgroundColor = .clear
        dot.isHidden = !hasEntry || isToday

        if isToday {
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
        accessibilityLabel = hasEntry ? "\(day) 日，有记录" : "\(day) 日，无记录"
        accessibilityTraits = isSelected ? [.button, .selected] : .button
    }
}
