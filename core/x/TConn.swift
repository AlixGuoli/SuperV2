import Foundation
import NetworkExtension
import os

private enum XrayCoreLease {
    private static let lock = NSLock()
    private static var serial: UInt64 = 0
    private static var owner: UInt64 = 0

    static func test(_ json: String) throws {
        lock.lock()
        defer { lock.unlock() }
        _ = try XrayCommandClient.execute(method: "testXray", payload: ["xrayJson": json])
    }

    static func start(_ json: String) throws -> UInt64 {
        lock.lock()
        defer { lock.unlock() }
        serial &+= 1
        let token = serial
        do {
            _ = try XrayCommandClient.execute(method: "runXray", payload: ["xrayJson": json])
            owner = token
            return token
        } catch {
            _ = try? XrayCommandClient.execute(method: "stopXray", payload: [:])
            owner = 0
            throw error
        }
    }

    static func stop(_ token: UInt64) {
        lock.lock()
        defer { lock.unlock() }
        guard token != 0, owner == token else { return }
        _ = try? XrayCommandClient.execute(method: "stopXray", payload: [:])
        owner = 0
    }
}

final class TConn {
    private static let tunRemoteAddr = "254.1.1.1"
    private static let tunMtu: NSNumber = 9000
    private static let tunIpAddr = "198.18.0.1"
    private static let tunSubnet = "255.255.0.0"
    private static let dnsPrimary = "8.8.8.8"
    private static let dnsSecondary = "114.114.114.114"

    private let lifecycleLock = NSLock()
    private var stopping = false
    private var coreToken: UInt64 = 0
    private var socksStarted = false

    var applyNetworkSettings: ((NEPacketTunnelNetworkSettings, @escaping (Error?) -> Void) -> Void)?

    func validateXray(_ json: String) throws {
        try ensureActive()
        try XrayCoreLease.test(json)
        try ensureActive()
    }

    func activateXray(_ json: String) throws {
        try ensureActive()
        let token = try XrayCoreLease.start(json)
        lifecycleLock.lock()
        let cancelled = stopping
        if !cancelled { coreToken = token }
        lifecycleLock.unlock()
        guard !cancelled else {
            XrayCoreLease.stop(token)
            throw cancellationError()
        }
    }

    func finishTunnelSetup() async throws {
        do {
            try ensureActive()
            try await applyNet(netCfg())
            try ensureActive()
            startSocks()
            try ensureActive()
        } catch {
            haltNet()
            throw error
        }
    }

    func haltNet() {
        lifecycleLock.lock()
        stopping = true
        let token = coreToken
        coreToken = 0
        let shouldStopSocks = socksStarted
        socksStarted = false
        lifecycleLock.unlock()

        if shouldStopSocks { SocksProxy.socksStop() }
        XrayCoreLease.stop(token)
    }

    private func netCfg() -> NEPacketTunnelNetworkSettings {
        let settings = NEPacketTunnelNetworkSettings(tunnelRemoteAddress: Self.tunRemoteAddr)
        settings.mtu = Self.tunMtu
        let ipv4 = NEIPv4Settings(addresses: [Self.tunIpAddr], subnetMasks: [Self.tunSubnet])
        ipv4.includedRoutes = [NEIPv4Route.default()]
        settings.ipv4Settings = ipv4
        settings.dnsSettings = NEDNSSettings(servers: [Self.dnsPrimary, Self.dnsSecondary])
        return settings
    }

    private func applyNet(_ settings: NEPacketTunnelNetworkSettings) async throws {
        guard let applyNetworkSettings else {
            throw NSError(domain: "TConn", code: 2, userInfo: [NSLocalizedDescriptionKey: "Missing network settings handler"])
        }
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            applyNetworkSettings(settings) { error in
                if let error { continuation.resume(throwing: error) }
                else { continuation.resume() }
            }
        }
    }

    private func startSocks() {
        let path = CProc.mkSocksPath()
        lifecycleLock.lock()
        socksStarted = true
        lifecycleLock.unlock()
        DispatchQueue.global(qos: .userInitiated).async {
            let result = SocksProxy.socksStart(withConfig: path)
            os_log("[Super Xray] tun2socks exited: %{public}d", log: OSLog.default, type: .error, result)
        }
    }

    private func ensureActive() throws {
        lifecycleLock.lock()
        let cancelled = stopping
        lifecycleLock.unlock()
        if cancelled { throw cancellationError() }
    }

    private func cancellationError() -> Error {
        NSError(domain: "TConn", code: NSUserCancelledError, userInfo: [NSLocalizedDescriptionKey: "Tunnel start cancelled"])
    }
}
