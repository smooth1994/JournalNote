//
//  JournalCardCell.swift
//  JournalNote
//

import UIKit
import SnapKit

final class JournalCardCell: UITableViewCell {
    static let reuseIdentifier = "JournalCardCell"

    private let timeline = UIView()
    private let dot = UIView()
    private let stem = UIView()
    private let card = UIView()
    private let accentStrip = UIView()
    private let tape = UIView()
    private let dateLabel = UILabel()
    private let titleLabel = UILabel()
    private let excerptLabel = UILabel()
    private let metadataStack = UIStackView()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        selectionStyle = .none
        backgroundColor = .clear
        contentView.backgroundColor = .clear
        setupViews()
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        metadataStack.arrangedSubviews.forEach {
            metadataStack.removeArrangedSubview($0)
            $0.removeFromSuperview()
        }
    }

    func configure(with entry: JournalEntry, hidesStem: Bool) {
        dot.backgroundColor = entry.mood.accentColor
        accentStrip.backgroundColor = entry.mood.accentColor
        stem.isHidden = hidesStem
        dateLabel.text = entry.shortDateText
        titleLabel.text = entry.displayTitle
        excerptLabel.text = entry.excerpt
        accessibilityLabel = "\(entry.shortDateText)，\(entry.displayTitle)，\(entry.mood.title)"

        let moodTag = JournalTagLabel(text: "\(entry.mood.emoji) \(entry.mood.title)", mood: entry.mood)
        metadataStack.addArrangedSubview(moodTag)
        for tag in entry.tagList.prefix(2) {
            metadataStack.addArrangedSubview(JournalTagLabel(text: tag, mood: entry.mood))
        }
    }

    private func setupViews() {
        contentView.addSubview(timeline)
        timeline.addSubview(dot)
        timeline.addSubview(stem)
        contentView.addSubview(card)
        card.addSubview(accentStrip)
        card.addSubview(tape)
        card.addSubview(dateLabel)
        card.addSubview(titleLabel)
        card.addSubview(excerptLabel)
        card.addSubview(metadataStack)

        dot.layer.cornerRadius = 6
        dot.layer.borderWidth = 2
        dot.layer.borderColor = JournalDesign.pageBackground.cgColor
        dot.layer.shadowColor = JournalDesign.amber500.cgColor
        dot.layer.shadowOpacity = 0.24
        dot.layer.shadowRadius = 3

        stem.backgroundColor = JournalDesign.separator
        card.applyJournalCard()
        card.clipsToBounds = false
        accentStrip.layer.cornerRadius = 2
        accentStrip.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        tape.backgroundColor = JournalDesign.amber500.withAlphaComponent(0.26)
        tape.layer.cornerRadius = 2
        tape.transform = CGAffineTransform(rotationAngle: -.pi / 90)

        dateLabel.font = JournalDesign.monoFont(size: 12, textStyle: .caption1)
        dateLabel.textColor = JournalDesign.secondaryText
        titleLabel.font = JournalDesign.serifFont(size: 19, textStyle: .headline, weight: .semibold)
        titleLabel.textColor = JournalDesign.primaryText
        titleLabel.numberOfLines = 2
        titleLabel.adjustsFontForContentSizeCategory = true
        excerptLabel.font = JournalDesign.serifFont(size: 14, textStyle: .subheadline)
        excerptLabel.textColor = JournalDesign.secondaryText
        excerptLabel.numberOfLines = 2
        excerptLabel.adjustsFontForContentSizeCategory = true

        metadataStack.axis = .horizontal
        metadataStack.alignment = .center
        metadataStack.spacing = 6
        metadataStack.distribution = .fillProportionally

        timeline.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(12)
            make.top.bottom.equalToSuperview()
            make.width.equalTo(16)
        }
        dot.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(26)
            make.centerX.equalToSuperview()
            make.width.height.equalTo(12)
        }
        stem.snp.makeConstraints { make in
            make.top.equalTo(dot.snp.bottom).offset(4)
            make.centerX.equalToSuperview()
            make.bottom.equalToSuperview().offset(8)
            make.width.equalTo(1.5)
        }
        card.snp.makeConstraints { make in
            make.leading.equalTo(timeline.snp.trailing).offset(10)
            make.trailing.equalToSuperview().inset(16)
            make.top.equalToSuperview().offset(12)
            make.bottom.equalToSuperview().inset(8)
        }
        accentStrip.snp.makeConstraints { make in
            make.top.leading.trailing.equalToSuperview()
            make.height.equalTo(4)
        }
        tape.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(-8)
            make.centerX.equalToSuperview()
            make.width.equalTo(64)
            make.height.equalTo(20)
        }
        dateLabel.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(22)
            make.leading.trailing.equalToSuperview().inset(16)
        }
        titleLabel.snp.makeConstraints { make in
            make.top.equalTo(dateLabel.snp.bottom).offset(4)
            make.leading.trailing.equalTo(dateLabel)
        }
        excerptLabel.snp.makeConstraints { make in
            make.top.equalTo(titleLabel.snp.bottom).offset(5)
            make.leading.trailing.equalTo(dateLabel)
        }
        metadataStack.snp.makeConstraints { make in
            make.top.equalTo(excerptLabel.snp.bottom).offset(12)
            make.leading.equalTo(dateLabel)
            make.trailing.lessThanOrEqualTo(dateLabel)
            make.bottom.equalToSuperview().inset(16)
        }
    }
}
