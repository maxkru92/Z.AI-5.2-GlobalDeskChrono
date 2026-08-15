//
//  NTPClockSync.swift
//  Global Desk Chrono — Powered by KruppCapital
//
//  Lightweight NTPv4 client using Apple's Network framework.
//  No external dependencies. RFC 5905 compliant.
//

import Foundation
import Network
import Observation

@Observable
final class NTPClockSync {

    private(set) var offset: TimeInterval = 0
    private(set) var lastSync: Date?
    private(set) var isSyncing = false
    private(set) var syncError: String?
    private(set) var syncCount: Int = 0
    private(set) var roundTripDelay: TimeInterval = 0

    private let ntpServers = ["pool.ntp.org", "time.apple.com", "time.cloudflare.com"]
    private let ntpPort: NWEndpoint.Port = 123
    private let ntpEpochOffset: TimeInterval = 2_208_988_800.0
    private let resyncInterval: TimeInterval = 300
    private let queryTimeout: TimeInterval = 5.0
    private var resyncTask: Task<Void, Never>?

    var correctedNow: Date { Date().addingTimeInterval(offset) }

    func startPeriodicSync() {
        resyncTask?.cancel()
        resyncTask = Task { [weak self] in
            guard let self = self else { return }
            while !Task.isCancelled {
                await self.sync()
                try? await Task.sleep(for: .seconds(self.resyncInterval))
            }
        }
    }

    func stopPeriodicSync() { resyncTask?.cancel(); resyncTask = nil }

    func sync() async {
        guard !isSyncing else { return }
        isSyncing = true; syncError = nil
        for server in ntpServers {
            let result = await queryServer(server)
            if let result = result {
                self.offset = result.offset
                self.roundTripDelay = result.delay
                self.lastSync = Date(); self.syncCount += 1; self.syncError = nil
                self.isSyncing = false; return
            }
        }
        self.syncError = "All NTP servers unreachable"; self.isSyncing = false
    }

    private struct NTPResult { let offset: TimeInterval; let delay: TimeInterval }

    private func queryServer(_ server: String) async -> NTPResult? {
        await withCheckedContinuation { (continuation: CheckedContinuation<NTPResult?, Never>) in
            let connection = NWConnection(host: NWEndpoint.Host(server), port: ntpPort, using: .udp)
            var packet = [UInt8](repeating: 0, count: 48)
            packet[0] = 0x1B
            let sendBox = TimeBox()
            var hasCompleted = false
            let lock = NSLock()
            func complete(_ result: NTPResult?) {
                lock.lock(); defer { lock.unlock() }
                guard !hasCompleted else { return }; hasCompleted = true
                connection.cancel(); continuation.resume(returning: result)
            }
            connection.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    sendBox.t1 = Date()
                    connection.send(content: Data(packet)) { error in
                        if error != nil { complete(nil) }
                    }
                case .failed: complete(nil)
                case .cancelled: complete(nil)
                default: break
                }
            }
            connection.receive(minimumIncompleteLength: 48, maximumLength: 48) { data, _, _, error in
                let t4 = Date()
                if error != nil { complete(nil); return }
                guard let data = data, data.count >= 48 else { complete(nil); return }
                let t1 = sendBox.t1.timeIntervalSince1970
                let t2 = self.readNTPTimestamp(data, offset: 32)
                let t3 = self.readNTPTimestamp(data, offset: 40)
                let t4Sec = t4.timeIntervalSince1970
                let offset = ((t2 - t1) + (t3 - t4Sec)) / 2.0
                let delay = (t4Sec - t1) - (t3 - t2)
                complete(NTPResult(offset: offset, delay: max(0, delay)))
            }
            connection.start(queue: .global(qos: .utility))
            DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + queryTimeout) { complete(nil) }
        }
    }

    private func readNTPTimestamp(_ data: Data, offset: Int) -> TimeInterval {
        let bytes = [UInt8](data)
        let seconds = (UInt32(bytes[offset]) << 24) | (UInt32(bytes[offset+1]) << 16) | (UInt32(bytes[offset+2]) << 8) | UInt32(bytes[offset+3])
        let fraction = (UInt32(bytes[offset+4]) << 24) | (UInt32(bytes[offset+5]) << 16) | (UInt32(bytes[offset+6]) << 8) | UInt32(bytes[offset+7])
        return TimeInterval(seconds) - ntpEpochOffset + TimeInterval(fraction) / 4_294_967_296.0
    }
}

private final class TimeBox { var t1: Date = Date() }
