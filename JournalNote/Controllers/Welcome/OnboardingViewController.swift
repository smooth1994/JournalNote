//
//  OnboardingViewController.swift
//  JournalNote
//

import UIKit
import SnapKit

final class OnboardingViewController: UIViewController {
    var onFinished: (() -> Void)?

    private struct Page {
        let imageName: String
        let title: String
        let detail: String
    }

    private let pages: [Page] = [
        Page(imageName: "OnboardingRecord", title: "随手记下此刻", detail: "钢笔落在纸上的瞬间，每一刻都值得被写下来。"),
        Page(imageName: "OnboardingMood", title: "给心情留个记号", detail: "用五种心情为一页手账盖上专属的小印章。"),
        Page(imageName: "OnboardingTimeline", title: "把日子串成轴", detail: "所有写下的日子，串成一条只属于你的时光长河。"),
        Page(imageName: "OnboardingCalendar", title: "回看每一天的光", detail: "被点亮的那一天，都是你认真生活过的证据。"),
        Page(imageName: "OnboardingImmersive", title: "开始拾起时光", detail: "零干扰书写，年终一键导出属于你的纸质手账册。")
    ]

    private let scrollView = UIScrollView()
    private let pageControl = UIPageControl()
    private let skipButton = UIButton(type: .system)
    private let actionButton = UIButton(type: .system)
    private let bottomButtonStack = UIStackView()
    private var pageViews: [UIView] = []

    override func viewDidLoad() {
        super.viewDidLoad()
        recordOnboardingShown()
        configureView()
        buildPages()
        configureControls()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        UIAccessibility.post(notification: .screenChanged, argument: pageViews.first)
    }

    private func configureView() {
        view.backgroundColor = JournalDesign.pageBackground
        view.accessibilityViewIsModal = true

        scrollView.isPagingEnabled = true
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.alwaysBounceVertical = false
        scrollView.delegate = self
        scrollView.accessibilityLabel = "拾光手账功能介绍"
        view.addSubview(scrollView)
        scrollView.snp.makeConstraints { make in
            make.top.equalTo(view.safeAreaLayoutGuide).offset(8)
            make.leading.trailing.equalToSuperview()
            make.bottom.equalTo(view.safeAreaLayoutGuide).offset(-112)
        }
    }

    private func buildPages() {
        var previousPage: UIView?
        for (index, page) in pages.enumerated() {
            let pageView = UIView()
            pageView.accessibilityViewIsModal = true
            scrollView.addSubview(pageView)
            pageViews.append(pageView)

            pageView.snp.makeConstraints { make in
                make.top.bottom.equalToSuperview()
                make.width.equalTo(scrollView.snp.width)
                if let previousPage {
                    make.leading.equalTo(previousPage.snp.trailing)
                } else {
                    make.leading.equalToSuperview()
                }
                if index == pages.count - 1 {
                    make.trailing.equalToSuperview()
                }
            }

            let imageView = UIImageView(image: UIImage(named: page.imageName))
            imageView.contentMode = .scaleAspectFit
            imageView.clipsToBounds = true
            imageView.accessibilityLabel = page.title
            imageView.isAccessibilityElement = true
            pageView.addSubview(imageView)
            imageView.snp.makeConstraints { make in
                make.top.equalToSuperview().offset(12)
                make.leading.trailing.equalToSuperview().inset(24)
                make.height.lessThanOrEqualTo(scrollView.snp.height).multipliedBy(0.57)
                make.height.greaterThanOrEqualTo(220)
            }

            let titleLabel = UILabel()
            titleLabel.text = page.title
            titleLabel.textColor = JournalDesign.primaryText
            titleLabel.font = JournalDesign.serifFont(size: 27, textStyle: .title2, weight: .bold)
            titleLabel.textAlignment = .center
            titleLabel.numberOfLines = 0
            titleLabel.adjustsFontForContentSizeCategory = true
            pageView.addSubview(titleLabel)
            titleLabel.snp.makeConstraints { make in
                make.top.equalTo(imageView.snp.bottom).offset(10)
                make.leading.trailing.equalToSuperview().inset(28)
            }

            let detailLabel = UILabel()
            detailLabel.text = page.detail
            detailLabel.textColor = JournalDesign.bodyText
            detailLabel.font = JournalDesign.serifFont(size: 16, textStyle: .body)
            detailLabel.textAlignment = .center
            detailLabel.numberOfLines = 0
            detailLabel.adjustsFontForContentSizeCategory = true
            pageView.addSubview(detailLabel)
            detailLabel.snp.makeConstraints { make in
                make.top.equalTo(titleLabel.snp.bottom).offset(8)
                make.leading.trailing.equalToSuperview().inset(36)
            }
            previousPage = pageView
        }
    }

    private func configureControls() {
        pageControl.numberOfPages = pages.count
        pageControl.currentPage = 0
        pageControl.pageIndicatorTintColor = JournalDesign.paper300
        pageControl.currentPageIndicatorTintColor = JournalDesign.amber500
        pageControl.accessibilityLabel = "引导页进度"
        pageControl.addTarget(self, action: #selector(pageControlChanged), for: .valueChanged)
        view.addSubview(pageControl)
        pageControl.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.bottom.equalTo(view.safeAreaLayoutGuide).offset(-82)
            make.height.equalTo(24)
        }

        skipButton.setTitle("跳过", for: .normal)
        skipButton.setTitleColor(JournalDesign.secondaryText, for: .normal)
        skipButton.titleLabel?.font = JournalDesign.serifFont(size: 15, textStyle: .subheadline)
        skipButton.accessibilityLabel = "跳过引导"
        skipButton.addTarget(self, action: #selector(skipTapped), for: .touchUpInside)
        skipButton.setContentHuggingPriority(.required, for: .horizontal)
        skipButton.setContentCompressionResistancePriority(.required, for: .horizontal)

        actionButton.setTitle("下一页", for: .normal)
        actionButton.setTitleColor(.white, for: .normal)
        actionButton.titleLabel?.font = JournalDesign.serifFont(size: 16, textStyle: .headline, weight: .semibold)
        actionButton.backgroundColor = JournalDesign.amber500
        actionButton.layer.cornerRadius = 22
        actionButton.layer.cornerCurve = .continuous
        actionButton.layer.shadowColor = JournalDesign.amber600.cgColor
        actionButton.layer.shadowOpacity = 0.22
        actionButton.layer.shadowOffset = CGSize(width: 0, height: 5)
        actionButton.layer.shadowRadius = 10
        actionButton.accessibilityLabel = "下一页"
        actionButton.addTarget(self, action: #selector(actionTapped), for: .touchUpInside)
        actionButton.setContentHuggingPriority(.required, for: .horizontal)
        actionButton.setContentCompressionResistancePriority(.required, for: .horizontal)

        // Use the stack as a full-width positioning container. The primary
        // action is centered on the screen; skip follows it on the right.
        view.addSubview(bottomButtonStack)
        bottomButtonStack.snp.makeConstraints { make in
            make.top.equalTo(pageControl.snp.bottom).offset(10)
            make.leading.trailing.equalToSuperview().inset(20)
            make.height.equalTo(44)
            make.bottom.lessThanOrEqualTo(view.safeAreaLayoutGuide).offset(-16)
        }
        bottomButtonStack.addSubview(actionButton)
        bottomButtonStack.addSubview(skipButton)
        actionButton.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.top.bottom.equalToSuperview()
            make.width.equalTo(132)
        }
        skipButton.snp.makeConstraints { make in
            make.leading.equalTo(actionButton.snp.trailing).offset(12)
            make.centerY.equalTo(actionButton)
            make.width.equalTo(68)
            make.height.equalTo(44)
        }
    }

    @objc private func pageControlChanged() {
        let page = pageControl.currentPage
        scrollToPage(page, animated: true)
    }

    @objc private func skipTapped() {
        finish()
    }

    @objc private func actionTapped() {
        if pageControl.currentPage == pages.count - 1 {
            finish()
        } else {
            scrollToPage(pageControl.currentPage + 1, animated: true)
        }
    }

    private func scrollToPage(_ page: Int, animated: Bool) {
        let clampedPage = max(0, min(page, pages.count - 1))
        let offset = CGPoint(x: CGFloat(clampedPage) * scrollView.bounds.width, y: 0)
        scrollView.setContentOffset(offset, animated: animated)
        updateControls(for: clampedPage)
    }

    private func updateControls(for page: Int) {
        pageControl.currentPage = page
        let isLastPage = page == pages.count - 1
        actionButton.setTitle(isLastPage ? "开始拾光" : "下一页", for: .normal)
        actionButton.accessibilityLabel = isLastPage ? "开始拾光" : "下一页"
        skipButton.isHidden = isLastPage
    }

    private func finish() {
        do {
            try JournalRepository.shared.markOnboardingCompleted()
        } catch {
            assertionFailure("WCDB onboarding write error: \(error)")
        }
        onFinished?()
    }

    private func recordOnboardingShown() {
        do {
            try JournalRepository.shared.markOnboardingShown()
        } catch {
            assertionFailure("WCDB onboarding schedule write error: \(error)")
        }
    }
}

extension OnboardingViewController: UIScrollViewDelegate {
    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        updateControls(for: Int(round(scrollView.contentOffset.x / max(scrollView.bounds.width, 1))))
    }

    func scrollViewDidEndScrollingAnimation(_ scrollView: UIScrollView) {
        updateControls(for: Int(round(scrollView.contentOffset.x / max(scrollView.bounds.width, 1))))
        UIAccessibility.post(notification: .screenChanged, argument: pageViews[pageControl.currentPage])
    }
}
