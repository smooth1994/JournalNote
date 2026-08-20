//
//  JournalDetailViewController.swift
//  JournalNote
//

import UIKit
import SnapKit

final class JournalDetailViewController: JournalBaseViewController {
    private let entry: JournalEntry
    private let scrollView = UIScrollView()
    private let contentView = UIView()
    private let heroView = UIView()
    private let heroEmojiLabel = UILabel()
    private let heroTitleLabel = UILabel()
    private let timestampLabel = UILabel()
    private let bodyLabel = UILabel()
    private let tagStack = UIStackView()
    private let sealView = JournalSealView()
    private let heroGradient = CAGradientLayer()

    init(entry: JournalEntry) {
        self.entry = entry
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "手账详情"
        navigationItem.largeTitleDisplayMode = .never
        setupViews()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        heroGradient.frame = heroView.bounds
    }

    private func setupViews() {
        scrollView.alwaysBounceVertical = true
        scrollView.showsVerticalScrollIndicator = false

        heroGradient.colors = [
            entry.mood.softColor.cgColor,
            JournalDesign.amber100.withAlphaComponent(0.82).cgColor
        ]
        heroGradient.startPoint = CGPoint(x: 0, y: 0)
        heroGradient.endPoint = CGPoint(x: 1, y: 1)
        heroView.layer.insertSublayer(heroGradient, at: 0)
        heroView.layer.cornerRadius = JournalDesign.panelCorner
        heroView.layer.cornerCurve = .continuous
        heroView.layer.borderWidth = 1
        heroView.layer.borderColor = JournalDesign.separator.cgColor
        heroView.clipsToBounds = true

        heroEmojiLabel.text = entry.mood.emoji
        heroEmojiLabel.font = UIFont.systemFont(ofSize: 44)
        heroEmojiLabel.accessibilityElementsHidden = true
        heroTitleLabel.text = entry.displayTitle
        heroTitleLabel.textColor = JournalDesign.primaryText
        heroTitleLabel.font = JournalDesign.handwrittenFont(size: 28, textStyle: .title1)
        heroTitleLabel.numberOfLines = 2
        heroTitleLabel.textAlignment = .center
        heroTitleLabel.adjustsFontForContentSizeCategory = true

        timestampLabel.text = entry.timestampText
        timestampLabel.textColor = JournalDesign.secondaryText
        timestampLabel.font = JournalDesign.monoFont(size: 12, textStyle: .caption1)
        timestampLabel.textAlignment = .center
        timestampLabel.adjustsFontForContentSizeCategory = true

        bodyLabel.textColor = JournalDesign.bodyText
        bodyLabel.numberOfLines = 0
        bodyLabel.adjustsFontForContentSizeCategory = true
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineSpacing = 10
        paragraph.paragraphSpacing = 10
        bodyLabel.attributedText = NSAttributedString(
            string: entry.body,
            attributes: [
                .font: JournalDesign.serifFont(size: 17, textStyle: .body),
                .foregroundColor: JournalDesign.bodyText,
                .paragraphStyle: paragraph
            ]
        )

        tagStack.axis = .horizontal
        tagStack.alignment = .center
        tagStack.spacing = 8
        tagStack.distribution = .fillProportionally
        tagStack.addArrangedSubview(JournalTagLabel(text: "\(entry.mood.emoji) \(entry.mood.title)", mood: entry.mood))
        entry.tagList.forEach { tag in
            tagStack.addArrangedSubview(JournalTagLabel(text: tag, mood: entry.mood))
        }

        let paperCard = UIView()
        paperCard.applyJournalSoftCard(cornerRadius: JournalDesign.panelCorner)

        view.addSubview(scrollView)
        scrollView.addSubview(contentView)
        contentView.addSubview(heroView)
        heroView.addSubview(heroEmojiLabel)
        heroView.addSubview(heroTitleLabel)
        contentView.addSubview(timestampLabel)
        contentView.addSubview(paperCard)
        paperCard.addSubview(bodyLabel)
        paperCard.addSubview(tagStack)
        paperCard.addSubview(sealView)

        scrollView.snp.makeConstraints { make in
            make.edges.equalTo(view.safeAreaLayoutGuide)
        }
        contentView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
            make.width.equalTo(scrollView.snp.width)
        }
        heroView.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(18)
            make.leading.trailing.equalToSuperview().inset(20)
            make.height.equalTo(188)
        }
        heroEmojiLabel.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.top.equalToSuperview().offset(30)
        }
        heroTitleLabel.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(20)
            make.top.equalTo(heroEmojiLabel.snp.bottom).offset(8)
        }
        timestampLabel.snp.makeConstraints { make in
            make.top.equalTo(heroView.snp.bottom).offset(14)
            make.leading.trailing.equalTo(heroView)
        }
        paperCard.snp.makeConstraints { make in
            make.top.equalTo(timestampLabel.snp.bottom).offset(14)
            make.leading.trailing.equalTo(heroView)
            make.bottom.equalToSuperview().inset(30)
        }
        bodyLabel.snp.makeConstraints { make in
            make.top.leading.trailing.equalToSuperview().inset(20)
        }
        tagStack.snp.makeConstraints { make in
            make.top.equalTo(bodyLabel.snp.bottom).offset(20)
            make.leading.equalTo(bodyLabel)
            make.trailing.lessThanOrEqualToSuperview().inset(20)
            make.bottom.equalToSuperview().inset(20)
        }
        sealView.snp.makeConstraints { make in
            make.trailing.equalToSuperview().inset(16)
            make.bottom.equalToSuperview().inset(12)
            make.width.height.equalTo(54)
        }
    }
}
