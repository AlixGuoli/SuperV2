//
//  NetManager.swift
//  CoreVPN
//
//  Created by SHI QIU on 2025/12/8.
//

import Foundation
import NetworkExtension
import os

var globalConfigPath: URL? = nil

class TConn {
    
    private static let tunRemoteAddr = "254.1.1.1"
    private static let tunMtu: NSNumber = 9000
    private static let tunIpAddr = "198.18.0.1"
    private static let tunSubnet = "255.255.0.0"
    private static let dnsPrimary = "8.8.8.8"
    private static let dnsSecondary = "114.114.114.114"

    private let lifecycleLock = NSLock()
    private var stopping = false
    private var ownsRunningCore = false
    
    var applyNetworkSettings: ((NEPacketTunnelNetworkSettings, @escaping (Error?) -> Void) -> Void)?
    
    func bootNet(xrayJSON: String) async throws {
        try await bootNetInner(xrayJSON: xrayJSON)
    }
    
    private func bootNetInner(xrayJSON: String) async throws {
        os_log("[Super Xray] %{public}@", log: OSLog.default, type: .error, "=== Starting Tunnel Connection ===")
        do {
            try ensureActive()
            try startXray(json: xrayJSON)
            try ensureActive()
            try await prepInfra()
            try ensureActive()
            try bootSocks()
            os_log("[Super Xray] %{public}@", log: OSLog.default, type: .error, "=== Tunnel Connection Completed ===")
        } catch {
            stopXray()
            throw error
        }
    }
    
    private func prepInfra() async throws {
        let tunCfg = netCfg()
        try await applyNet(tunCfg)
    }
    
    private func netCfg() -> NEPacketTunnelNetworkSettings {
        let tunCfg = NEPacketTunnelNetworkSettings(tunnelRemoteAddress: Self.tunRemoteAddr)
        tunCfg.mtu = Self.tunMtu
        tunCfg.ipv4Settings = ipv4Cfg()
        tunCfg.dnsSettings = dnsCfg()
        return tunCfg
    }
    
    private func ipv4Cfg() -> NEIPv4Settings {
        let ip4Cfg = NEIPv4Settings(addresses: [Self.tunIpAddr], subnetMasks: [Self.tunSubnet])
        ip4Cfg.includedRoutes = [NEIPv4Route.default()]
        return ip4Cfg
    }
    
    private func dnsCfg() -> NEDNSSettings {
        return NEDNSSettings(servers: [Self.dnsPrimary, Self.dnsSecondary])
    }
    
    private func applyNet(_ tunCfg: NEPacketTunnelNetworkSettings) async throws {
        guard let applyNetworkSettings else {
            throw NSError(domain: "TConn", code: 2, userInfo: [NSLocalizedDescriptionKey: "Missing network settings handler"])
        }
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            applyNetworkSettings(tunCfg) { error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    os_log("[Super Xray] %{public}@", log: OSLog.default, type: .error, "Network settings applied successfully")
                    continuation.resume()
                }
            }
        }
    }

    private func startXray(json: String) throws {
        _ = try XrayCommandClient.execute(method: "runXray", payload: ["xrayJson": json])

        lifecycleLock.lock()
        ownsRunningCore = true
        let wasCancelled = stopping
        lifecycleLock.unlock()

        if wasCancelled {
            stopXray()
            throw cancellationError()
        }
        os_log("[Super Xray] %{public}@", log: OSLog.default, type: .error, "Xray service started successfully")
    }

    private func stopXray() {
        lifecycleLock.lock()
        guard ownsRunningCore else {
            lifecycleLock.unlock()
            return
        }
        ownsRunningCore = false
        lifecycleLock.unlock()

        do {
            _ = try XrayCommandClient.execute(method: "stopXray", payload: [:])
        } catch {
            os_log("[Super Xray] %{public}@", log: OSLog.default, type: .error, "Xray stop failed: \(error.localizedDescription)")
        }
    }
    
    private func bootSocks() throws {
        let socksPath = CProc.mkSocksPath()
        os_log("[Super Xray] %{public}@", log: OSLog.default, type: .error, "SOCKS config path: \(socksPath)")
        
        DispatchQueue.global(qos: .userInitiated).async {
            SocksProxy.socksStart(withConfig: socksPath)
            os_log("[Super Xray] %{public}@", log: OSLog.default, type: .error, "SOCKS proxy activated")
        }
    }
    
    func haltNet() {
        haltNetInner()
    }
    
    private func haltNetInner() {
        os_log("[Super Xray] %{public}@", log: OSLog.default, type: .error, "=== Terminating Tunnel Connection ===")
        lifecycleLock.lock()
        stopping = true
        lifecycleLock.unlock()
        SocksProxy.socksStop()
        stopXray()
        os_log("[Super Xray] %{public}@", log: OSLog.default, type: .error, "Xray service stopped")
    }

    private func ensureActive() throws {
        lifecycleLock.lock()
        let isStopping = stopping
        lifecycleLock.unlock()
        if isStopping {
            throw cancellationError()
        }
    }

    private func cancellationError() -> Error {
        NSError(domain: "TConn", code: 3, userInfo: [NSLocalizedDescriptionKey: "Tunnel start cancelled"])
    }
}
