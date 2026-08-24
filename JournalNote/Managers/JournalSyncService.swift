//
//  JournalSyncService.swift
//  JournalNote
//

import Foundation
import UIKit
import MultipeerConnectivity

enum JournalSyncError: LocalizedError {
    case unsupportedPayloadVersion
    case invalidData
    case noSession
    case peerDisconnected

    var errorDescription: String? {
        switch self {
        case .unsupportedPayloadVersion:
            return "数据版本不兼容，请先更新两台设备上的拾光手账。"
        case .invalidData:
            return "接收到的数据不完整，无法同步。"
        case .noSession:
            return "局域网连接尚未建立。"
        case .peerDisconnected:
            return "另一台设备已断开连接。"
        }
    }
}

/// Handles discovery and encrypted transport over the same local network.
/// MCSession uses its required encryption mode; the payload itself is only
/// decoded and persisted after every chunk has arrived.
final class JournalSyncService: NSObject {
    static let shared = JournalSyncService()

    private static let serviceType = "journal-sync"
    private static let headerLength = 8
    private static let chunkSize = 24 * 1024

    private let peerID: MCPeerID
    private var session: MCSession!
    private var advertiser: MCNearbyServiceAdvertiser?
    private var browser: MCNearbyServiceBrowser?
    private var outgoingData: Data?
    private var hasSentPayload = false
    private var expectedChunkCount = 0
    private var receivedChunks: [Int: Data] = [:]
    private var isReceiving = false

    var onStatus: ((String) -> Void)?
    var onProgress: ((Double) -> Void)?
    var onSendingCompleted: ((Result<Void, Error>) -> Void)?
    var onReceivingCompleted: ((Result<Int, Error>) -> Void)?

    private override init() {
        let suffix = String(UUID().uuidString.prefix(4))
        peerID = MCPeerID(displayName: "拾光-\(UIDevice.current.name)-\(suffix)")
        super.init()
        makeSession()
    }

    func startSending(_ payload: JournalSyncPayload) {
        stop()
        makeSession()
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            outgoingData = try encoder.encode(payload)
        } catch {
            notifySending(.failure(error))
            return
        }

        advertiser = MCNearbyServiceAdvertiser(
            peer: peerID,
            discoveryInfo: ["version": "\(JournalSyncPayload.currentVersion)"],
            serviceType: Self.serviceType
        )
        advertiser?.delegate = self
        advertiser?.startAdvertisingPeer()
        notifyStatus("正在等待另一台设备接收…")
    }

    func startReceiving() {
        stop()
        makeSession()
        isReceiving = true
        browser = MCNearbyServiceBrowser(peer: peerID, serviceType: Self.serviceType)
        browser?.delegate = self
        browser?.startBrowsingForPeers()
        notifyProgress(0)
        notifyStatus("正在搜索同一局域网内的设备…")
    }

    func stop() {
        advertiser?.stopAdvertisingPeer()
        browser?.stopBrowsingForPeers()
        advertiser = nil
        browser = nil
        session?.disconnect()
        outgoingData = nil
        hasSentPayload = false
        expectedChunkCount = 0
        receivedChunks.removeAll()
        isReceiving = false
        onStatus = nil
        onProgress = nil
        onSendingCompleted = nil
        onReceivingCompleted = nil
    }

    private func makeSession() {
        session = MCSession(peer: peerID, securityIdentity: nil, encryptionPreference: .required)
        session.delegate = self
    }

    private func sendPayload(to peer: MCPeerID) {
        guard !hasSentPayload, let outgoingData else { return }
        hasSentPayload = true

        let count = max(1, Int(ceil(Double(outgoingData.count) / Double(Self.chunkSize))))
        notifyStatus("正在发送数据…")
        notifyProgress(0)

        do {
            for index in 0..<count {
                let start = index * Self.chunkSize
                let end = min(start + Self.chunkSize, outgoingData.count)
                var frame = Data()
                appendUInt32(UInt32(index), to: &frame)
                appendUInt32(UInt32(count), to: &frame)
                if start < end {
                    frame.append(outgoingData[start..<end])
                }
                try session.send(frame, toPeers: [peer], with: .reliable)
                notifyProgress(Double(index + 1) / Double(count) * 0.9)
            }
            notifySending(.success(()))
        } catch {
            notifySending(.failure(error))
        }
    }

    private func receive(_ frame: Data) {
        guard frame.count >= Self.headerLength else {
            notifyReceiving(.failure(JournalSyncError.invalidData))
            return
        }
        let index = Int(readUInt32(from: frame, offset: 0))
        let count = Int(readUInt32(from: frame, offset: 4))
        guard count > 0, index >= 0, index < count else {
            notifyReceiving(.failure(JournalSyncError.invalidData))
            return
        }
        if expectedChunkCount == 0 {
            expectedChunkCount = count
        }
        guard expectedChunkCount == count else {
            notifyReceiving(.failure(JournalSyncError.invalidData))
            return
        }
        receivedChunks[index] = Data(frame.dropFirst(Self.headerLength))
        notifyProgress(Double(receivedChunks.count) / Double(count) * 0.9)
        guard receivedChunks.count == count else { return }

        let data = (0..<count).reduce(into: Data()) { result, chunkIndex in
            guard let chunk = receivedChunks[chunkIndex] else { return }
            result.append(chunk)
        }
        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let payload = try decoder.decode(JournalSyncPayload.self, from: data)
            guard payload.version == JournalSyncPayload.currentVersion else {
                throw JournalSyncError.unsupportedPayloadVersion
            }
            try JournalRepository.shared.mergeSyncPayload(payload)
            notifyProgress(1)
            notifyReceiving(.success(payload.entries.count))
        } catch {
            notifyReceiving(.failure(error))
        }
    }

    private func appendUInt32(_ value: UInt32, to data: inout Data) {
        var bigEndianValue = value.bigEndian
        withUnsafeBytes(of: &bigEndianValue) { data.append(contentsOf: $0) }
    }

    private func readUInt32(from data: Data, offset: Int) -> UInt32 {
        data[offset..<offset + 4].reduce(UInt32(0)) { ($0 << 8) | UInt32($1) }
    }

    private func notifyStatus(_ status: String) {
        DispatchQueue.main.async { [weak self] in self?.onStatus?(status) }
    }

    private func notifyProgress(_ progress: Double) {
        DispatchQueue.main.async { [weak self] in self?.onProgress?(progress) }
    }

    private func notifySending(_ result: Result<Void, Error>) {
        DispatchQueue.main.async { [weak self] in self?.onSendingCompleted?(result) }
    }

    private func notifyReceiving(_ result: Result<Int, Error>) {
        DispatchQueue.main.async { [weak self] in self?.onReceivingCompleted?(result) }
    }
}

extension JournalSyncService: MCSessionDelegate {
    func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            switch state {
            case .connecting:
                self.onStatus?("正在连接另一台设备…")
            case .connected:
                self.onStatus?(self.isReceiving ? "设备已连接，正在接收数据…" : "设备已连接，正在发送数据…")
                if !self.isReceiving { self.sendPayload(to: peerID) }
            case .notConnected:
                if self.isReceiving && self.receivedChunks.isEmpty {
                    self.onReceivingCompleted?(.failure(JournalSyncError.peerDisconnected))
                }
            @unknown default:
                break
            }
        }
    }

    func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        receive(data)
    }

    func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {}

    func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {}

    func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {}
}

extension JournalSyncService: MCNearbyServiceAdvertiserDelegate {
    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didReceiveInvitationFromPeer peerID: MCPeerID, withContext context: Data?, invitationHandler: @escaping (Bool, MCSession?) -> Void) {
        invitationHandler(true, session)
    }

    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didNotStartAdvertisingPeer error: Error) {
        notifySending(.failure(error))
    }
}

extension JournalSyncService: MCNearbyServiceBrowserDelegate {
    func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String: String]?) {
        notifyStatus("已找到设备，正在连接…")
        browser.invitePeer(peerID, to: session, withContext: nil, timeout: 30)
    }

    func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {}

    func browser(_ browser: MCNearbyServiceBrowser, didNotStartBrowsingForPeers error: Error) {
        notifyReceiving(.failure(error))
    }
}
