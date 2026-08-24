//
//  DataReceiveViewController.swift
//  JournalNote
//

import UIKit
import SnapKit

final class DataReceiveViewController: UIViewController {
    private let service = JournalSyncService.shared
    private let card = UIView()
    private let titleLabel = UILabel()
    private let messageLabel = UILabel()
    private let progressView = UIProgressView(progressViewStyle: .default)
    private let progressLabel = UILabel()
    private let acknowledgeButton = JournalActionButton(title: "我知道了", style: .soft)

    override func viewDidLoad() {
        super.viewDidLoad()
        modalPresentationStyle = .overFullScreen
        modalTransitionStyle = .crossDissolve
        setupViews()
        configureServiceCallbacks()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        service.startReceiving()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        service.stop()
    }

    private func setupViews() {
        view.backgroundColor = UIColor.black.withAlphaComponent(0.42)

        card.applyJournalCard(cornerRadius: JournalDesign.panelCorner)
        titleLabel.text = "接收数据"
        titleLabel.font = JournalDesign.handwrittenFont(size: 24, textStyle: .title2)
        titleLabel.textColor = JournalDesign.accent
        titleLabel.textAlignment = .center

        messageLabel.text = "请不要操作设备\n正在搜索另一台设备…"
        messageLabel.font = JournalDesign.serifFont(size: 16, textStyle: .body)
        messageLabel.textColor = JournalDesign.bodyText
        messageLabel.textAlignment = .center
        messageLabel.numberOfLines = 0

        progressView.progressTintColor = JournalDesign.accent
        progressView.trackTintColor = JournalDesign.separator
        progressView.progress = 0
        progressLabel.text = "0%"
        progressLabel.font = JournalDesign.monoFont(size: 12, textStyle: .caption1)
        progressLabel.textColor = JournalDesign.secondaryText
        progressLabel.textAlignment = .center

        acknowledgeButton.isEnabled = false
        acknowledgeButton.alpha = 0.45
        acknowledgeButton.addTarget(self, action: #selector(acknowledge), for: .touchUpInside)

        view.addSubview(card)
        card.addSubview(titleLabel)
        card.addSubview(messageLabel)
        card.addSubview(progressView)
        card.addSubview(progressLabel)
        card.addSubview(acknowledgeButton)
        card.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(28)
            make.centerY.equalToSuperview()
        }
        titleLabel.snp.makeConstraints { make in
            make.top.leading.trailing.equalToSuperview().inset(22)
        }
        messageLabel.snp.makeConstraints { make in
            make.top.equalTo(titleLabel.snp.bottom).offset(16)
            make.leading.trailing.equalToSuperview().inset(22)
        }
        progressView.snp.makeConstraints { make in
            make.top.equalTo(messageLabel.snp.bottom).offset(20)
            make.leading.trailing.equalToSuperview().inset(26)
        }
        progressLabel.snp.makeConstraints { make in
            make.top.equalTo(progressView.snp.bottom).offset(8)
            make.leading.trailing.equalToSuperview().inset(22)
        }
        acknowledgeButton.snp.makeConstraints { make in
            make.top.equalTo(progressLabel.snp.bottom).offset(16)
            make.centerX.equalToSuperview()
            make.bottom.equalToSuperview().inset(22)
        }
    }

    private func configureServiceCallbacks() {
        service.onStatus = { [weak self] status in
            self?.messageLabel.text = "请不要操作设备\n\(status)"
        }
        service.onProgress = { [weak self] progress in
            guard let self else { return }
            self.progressView.setProgress(Float(progress), animated: true)
            self.progressLabel.text = "\(Int(progress * 100))%"
        }
        service.onReceivingCompleted = { [weak self] result in
            guard let self else { return }
            self.acknowledgeButton.isEnabled = true
            self.acknowledgeButton.alpha = 1
            switch result {
            case .success(let count):
                self.messageLabel.text = "已同步成功\n共接收 \(count) 条日记记录"
                self.progressView.setProgress(1, animated: true)
                self.progressLabel.text = "100%"
            case .failure(let error):
                self.messageLabel.text = "同步失败\n\(error.localizedDescription)"
                self.progressLabel.text = "未完成"
            }
        }
    }

    @objc private func acknowledge() {
        dismiss(animated: true)
    }
}
