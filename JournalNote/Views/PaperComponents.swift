//
//  PaperComponents.swift
//  JournalNote
//

import UIKit
import SnapKit

final class JournalActionButton: UIButton {
    enum Style {
        case primary
        case ghost
        case soft
    }

    private let style: Style

    init(title: String, style: Style = .primary) {
        self.style = style
        super.init(frame: .zero)
        setTitle(title, for: .normal)
        titleLabel?.font = JournalDesign.serifFont(size: 16, textStyle: .headline, weight: .semibold)
        titleLabel?.adjustsFontForContentSizeCategory = true
        titleLabel?.numberOfLines = 1
        layer.cornerRadius = 22
        layer.cornerCurve = .continuous
        contentEdgeInsets = UIEdgeInsets(top: 11, left: 24, bottom: 11, right: 24)
        accessibilityTraits = .button
        applyStyle()
        snp.makeConstraints { make in
            make.height.greaterThanOrEqualTo(44)
        }
    }

    required init?(coder: NSCoder) {
        nil
    }

    override var isHighlighted: Bool {
        didSet {
            UIView.animate(withDuration: 0.16) {
                self.transform = self.isHighlighted ? CGAffineTransform(scaleX: 0.97, y: 0.97) : .identity
                self.alpha = self.isHighlighted ? 0.86 : 1
            }
        }
    }

    private func applyStyle() {
        switch style {
        case .primary:
            backgroundColor = JournalDesign.accent
            setTitleColor(JournalDesign.paper50, for: .normal)
            layer.shadowColor = JournalDesign.amber500.cgColor
            layer.shadowOpacity = 0.28
            layer.shadowOffset = CGSize(width: 0, height: 5)
            layer.shadowRadius = 10
        case .ghost:
            backgroundColor = .clear
            setTitleColor(JournalDesign.accent, for: .normal)
            layer.borderWidth = 1.5
            layer.borderColor = JournalDesign.accent.cgColor
        case .soft:
            backgroundColor = JournalDesign.secondaryBackground
            setTitleColor(JournalDesign.bodyText, for: .normal)
        }
    }
}

final class JournalTagLabel: UILabel {
    init(text: String, mood: JournalMood? = nil) {
        super.init(frame: .zero)
        self.text = text
        font = JournalDesign.serifFont(size: 12, textStyle: .caption1, weight: .medium)
        adjustsFontForContentSizeCategory = true
        textAlignment = .center
        textColor = mood?.tagTextColor ?? JournalDesign.amber600
        backgroundColor = mood?.softColor ?? JournalDesign.amber100
        layer.cornerRadius = 12
        layer.cornerCurve = .continuous
        clipsToBounds = true
        contentEdgeInsets = UIEdgeInsets(top: 3, left: 10, bottom: 3, right: 10)
        accessibilityLabel = text
    }

    required init?(coder: NSCoder) {
        nil
    }

    override var intrinsicContentSize: CGSize {
        let size = super.intrinsicContentSize
        return CGSize(width: size.width + contentEdgeInsets.left + contentEdgeInsets.right,
                      height: max(24, size.height + contentEdgeInsets.top + contentEdgeInsets.bottom))
    }

    private var contentEdgeInsets: UIEdgeInsets = .zero
}

final class JournalLinedTextView: UITextView {
    private let lineHeight: CGFloat = 32

    init() {
        super.init(frame: .zero, textContainer: nil)
        backgroundColor = JournalDesign.cardBackground
        textColor = JournalDesign.bodyText
        font = JournalDesign.serifFont(size: 17, textStyle: .body)
        adjustsFontForContentSizeCategory = true
        textContainerInset = UIEdgeInsets(top: 14, left: 16, bottom: 14, right: 16)
        textContainer.lineFragmentPadding = 0
        layer.cornerRadius = JournalDesign.cardCorner
        layer.cornerCurve = .continuous
        layer.borderWidth = 1
        layer.borderColor = JournalDesign.separator.cgColor
        tintColor = JournalDesign.accent
        accessibilityLabel = "手账正文"
        accessibilityHint = "输入想留给今天的话"
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func draw(_ rect: CGRect) {
        super.draw(rect)
        guard let context = UIGraphicsGetCurrentContext() else { return }
        context.saveGState()
        context.setStrokeColor(JournalDesign.separator.withAlphaComponent(0.72).cgColor)
        context.setLineWidth(0.75)

        var y = textContainerInset.top + lineHeight
        while y < bounds.height - textContainerInset.bottom / 2 {
            context.move(to: CGPoint(x: textContainerInset.left, y: y))
            context.addLine(to: CGPoint(x: bounds.width - textContainerInset.right, y: y))
            y += lineHeight
        }
        context.strokePath()
        context.restoreGState()
    }

    override var contentSize: CGSize {
        didSet { setNeedsDisplay() }
    }
}

final class JournalSealView: UIView {
    private let label = UILabel()

    init(text: String = "拾光") {
        super.init(frame: .zero)
        layer.cornerRadius = 9
        layer.borderWidth = 1.6
        layer.borderColor = JournalDesign.clay500.cgColor
        transform = CGAffineTransform(rotationAngle: .pi / 30)
        alpha = 0.84

        label.text = text
        label.numberOfLines = 2
        label.textAlignment = .center
        label.textColor = JournalDesign.clay500
        label.font = JournalDesign.handwrittenFont(size: 16, textStyle: .caption1)
        label.adjustsFontForContentSizeCategory = true
        addSubview(label)
        label.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(5)
        }
        accessibilityLabel = "印章：\(text)"
    }

    required init?(coder: NSCoder) {
        nil
    }
}

final class JournalEmptyStateView: UIView {
    init(symbol: String, title: String, message: String) {
        super.init(frame: .zero)
        let imageView = UIImageView(image: UIImage(systemName: symbol))
        imageView.tintColor = JournalDesign.amber500
        imageView.preferredSymbolConfiguration = .init(pointSize: 30, weight: .regular)

        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.textColor = JournalDesign.primaryText
        titleLabel.font = JournalDesign.handwrittenFont(size: 22, textStyle: .title3)
        titleLabel.textAlignment = .center

        let messageLabel = UILabel()
        messageLabel.text = message
        messageLabel.textColor = JournalDesign.secondaryText
        messageLabel.font = JournalDesign.serifFont(size: 14, textStyle: .subheadline)
        messageLabel.numberOfLines = 0
        messageLabel.textAlignment = .center

        let stack = UIStackView(arrangedSubviews: [imageView, titleLabel, messageLabel])
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = 10
        addSubview(stack)
        stack.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(24)
        }
        accessibilityLabel = "\(title)，\(message)"
    }

    required init?(coder: NSCoder) {
        nil
    }
}

/// A lightweight, Canvas-drawn annual mood ring. It avoids image assets while
/// preserving the visual language from the supplied design.
final class MoodYearView: UIView {
    var entries: [JournalEntry] = [] {
        didSet {
            accessibilityLabel = "心情年轮，本年度记录 \(entries.count) 次"
            setNeedsDisplay()
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        isOpaque = false
        isAccessibilityElement = true
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func draw(_ rect: CGRect) {
        guard let context = UIGraphicsGetCurrentContext() else { return }
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let maxRadius = min(rect.width, rect.height) / 2 - 18

        context.setLineWidth(1)
        context.setStrokeColor(JournalDesign.separator.withAlphaComponent(0.9).cgColor)
        for ratio: CGFloat in [0.34, 0.58, 0.82] {
            context.addEllipse(in: CGRect(
                x: center.x - maxRadius * ratio,
                y: center.y - maxRadius * ratio,
                width: maxRadius * ratio * 2,
                height: maxRadius * ratio * 2
            ))
        }
        context.strokePath()

        let calendar = Calendar.current
        let referenceYear = calendar.component(.year, from: Date())
        let visibleEntries = entries.filter { calendar.component(.year, from: $0.createdAt) == referenceYear }
        for entry in visibleEntries {
            let day = calendar.ordinality(of: .day, in: .year, for: entry.createdAt) ?? 1
            let angle = (CGFloat(day) / 365.0) * .pi * 2 - .pi / 2
            let ring = CGFloat((day % 3) + 1) / 4
            let radius = maxRadius * (0.22 + ring * 0.68)
            let point = CGPoint(x: center.x + cos(angle) * radius, y: center.y + sin(angle) * radius)
            context.setFillColor(entry.mood.accentColor.cgColor)
            context.fillEllipse(in: CGRect(x: point.x - 4, y: point.y - 4, width: 8, height: 8))
        }

        let centerText = "\(visibleEntries.count)\n段时光"
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        let attributes: [NSAttributedString.Key: Any] = [
            .font: JournalDesign.serifFont(size: 14, textStyle: .subheadline, weight: .semibold),
            .foregroundColor: JournalDesign.primaryText,
            .paragraphStyle: paragraph
        ]
        let size = (centerText as NSString).boundingRect(
            with: CGSize(width: 100, height: 60),
            options: .usesLineFragmentOrigin,
            attributes: attributes,
            context: nil
        ).size
        (centerText as NSString).draw(
            in: CGRect(x: center.x - 50, y: center.y - size.height / 2, width: 100, height: size.height),
            withAttributes: attributes
        )
    }
}
