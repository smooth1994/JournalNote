//
//  DataExportViewController.swift
//  JournalNote
//

import UIKit
import SnapKit

final class DataExportViewController: JournalBaseViewController {
    private let repository = JournalRepository.shared
    private let statusLabel = UILabel()
    private let progressView = UIProgressView(progressViewStyle: .default)
    private let service = JournalSyncService.shared
    private var started = false

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "导出数据"
        navigationItem.largeTitleDisplayMode = .never
        setupViews()
        configureServiceCallbacks()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        startExportIfNeeded()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        service.stop()
        started = false
    }

    private func setupViews() {
        let instructionCard = UIView()
        instructionCard.applyJournalCard(cornerRadius: JournalDesign.panelCorner)

        let titleLabel = UILabel()
        titleLabel.text = "如何在另一台设备接收？"
        titleLabel.font = JournalDesign.handwrittenFont(size: 22, textStyle: .title3)
        titleLabel.textColor = JournalDesign.accent
        titleLabel.textAlignment = .center

        let instructionLabel = UILabel()
        instructionLabel.text = "1. 确认两台设备连接同一个 Wi-Fi\n2. 在另一台设备打开拾光手账\n3. 进入「我的」→「接收数据」\n4. 保持两台设备停留在当前页面，等待同步完成"
        instructionLabel.font = JournalDesign.serifFont(size: 16, textStyle: .body)
        instructionLabel.textColor = JournalDesign.bodyText
        instructionLabel.numberOfLines = 0
        instructionLabel.adjustsFontForContentSizeCategory = true

        statusLabel.font = JournalDesign.serifFont(size: 15, textStyle: .subheadline)
        statusLabel.textColor = JournalDesign.secondaryText
        statusLabel.textAlignment = .center
        statusLabel.numberOfLines = 0
        statusLabel.text = "正在准备数据…"

        progressView.progressTintColor = JournalDesign.accent
        progressView.trackTintColor = JournalDesign.separator
        progressView.progress = 0

        instructionCard.addSubview(titleLabel)
        instructionCard.addSubview(instructionLabel)
        titleLabel.snp.makeConstraints { make in
            make.top.leading.trailing.equalToSuperview().inset(20)
        }
        instructionLabel.snp.makeConstraints { make in
            make.top.equalTo(titleLabel.snp.bottom).offset(16)
            make.leading.trailing.bottom.equalToSuperview().inset(20)
        }

        view.addSubview(instructionCard)
        view.addSubview(statusLabel)
        view.addSubview(progressView)
        instructionCard.snp.makeConstraints { make in
            make.top.equalTo(view.safeAreaLayoutGuide).offset(24)
            make.leading.trailing.equalToSuperview().inset(20)
        }
        statusLabel.snp.makeConstraints { make in
            make.top.equalTo(instructionCard.snp.bottom).offset(24)
            make.leading.trailing.equalTo(instructionCard)
        }
        progressView.snp.makeConstraints { make in
            make.top.equalTo(statusLabel.snp.bottom).offset(14)
            make.leading.trailing.equalTo(instructionCard)
        }
    }

    private func configureServiceCallbacks() {
        service.onStatus = { [weak self] status in
            self?.statusLabel.text = status
        }
        service.onProgress = { [weak self] progress in
            self?.progressView.setProgress(Float(progress), animated: true)
        }
        service.onSendingCompleted = { [weak self] result in
            guard let self else { return }
            switch result {
            case .success:
                self.statusLabel.text = "数据已发送，请在另一台设备完成接收。"
                self.progressView.setProgress(1, animated: true)
            case .failure(let error):
                self.statusLabel.text = "发送失败：\(error.localizedDescription)"
            }
        }
    }

    private func startExportIfNeeded() {
        guard !started else { return }
        started = true
        do {
            let payload = try repository.makeSyncPayload()
            statusLabel.text = "正在等待另一台设备接收…"
            service.startSending(payload)
        } catch {
            statusLabel.text = "数据准备失败：\(error.localizedDescription)"
        }
    }
}
