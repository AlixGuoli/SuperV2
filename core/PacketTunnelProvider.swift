import Foundation
import NetworkExtension
import os

final class PacketTunnelProvider: NEPacketTunnelProvider {
    private static let errorDomain = "com.vpn.kernel.core.hex"

    private let stateLock = NSLock()
    private var generation: UInt64 = 0
    private var connection: TConn?

    override func startTunnel(options: [String: NSObject]?, completionHandler: @escaping (Error?) -> Void) {
        let current = TConn()
        current.applyNetworkSettings = { [weak self] settings, done in
            self?.setTunnelNetworkSettings(settings, completionHandler: done)
        }
        let token = beginStart(current)

        Task.detached(priority: .userInitiated) { [weak self, weak current] in
            guard let self, let current else {
                completionHandler(NSError(domain: Self.errorDomain, code: 1))
                return
            }
            var route: RunningRoute?
            do {
                let picker = TunnelRoutePicker(connection: current) {
                    self.isActive(token, connection: current)
                }
                route = try await picker.openFirstAvailableRoute()
                guard self.isActive(token, connection: current) else { throw TunnelRouteFailure.stopped }
                try await current.finishTunnelSetup()
                guard self.isActive(token, connection: current) else {
                    current.haltNet()
                    throw TunnelRouteFailure.stopped
                }
                TunnelRunRecords.note("network ready")
                TunnelRunRecords.complete(route, success: true, error: "")
                completionHandler(nil)
            } catch {
                current.haltNet()
                self.release(current, token: token)
                TunnelRunRecords.note("tunnel failed error=\(error.localizedDescription)")
                TunnelRunRecords.complete(route, success: false, error: error.localizedDescription)
                os_log("[Batch] tunnel start failed: %{public}@", log: OSLog.default, type: .error, error.localizedDescription)
                completionHandler(error)
            }
        }
    }

    override func stopTunnel(with reason: NEProviderStopReason, completionHandler: @escaping () -> Void) {
        stateLock.lock()
        generation &+= 1
        let current = connection
        connection = nil
        stateLock.unlock()

        DispatchQueue.global(qos: .userInitiated).async {
            current?.haltNet()
            completionHandler()
        }
    }

    override func handleAppMessage(_ messageData: Data, completionHandler: ((Data?) -> Void)?) {
        guard let object = try? JSONSerialization.jsonObject(with: messageData) as? [String: Any],
              object["action"] as? String == "batchReport",
              let report = TunnelRunRecords.current(),
              let data = try? JSONSerialization.data(withJSONObject: report) else {
            completionHandler?(nil)
            return
        }
        completionHandler?(data)
    }

    override func sleep(completionHandler: @escaping () -> Void) { completionHandler() }
    override func wake() {}

    private func beginStart(_ current: TConn) -> UInt64 {
        stateLock.lock()
        generation &+= 1
        let token = generation
        connection = current
        stateLock.unlock()
        return token
    }

    private func isActive(_ token: UInt64, connection current: TConn) -> Bool {
        stateLock.lock()
        defer { stateLock.unlock() }
        return generation == token && connection === current
    }

    private func release(_ current: TConn, token: UInt64) {
        stateLock.lock()
        if generation == token, connection === current { connection = nil }
        stateLock.unlock()
    }
}
