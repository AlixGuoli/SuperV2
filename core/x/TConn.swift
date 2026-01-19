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
    
    var applyNetworkSettings: ((NEPacketTunnelNetworkSettings, @escaping (Error?) -> Void) -> Void)?
    
    func bootNet() async throws {
        try await bootNetInner()
    }
    
    private func bootNetInner() async throws {
        os_log("[Super Xray] %{public}@", log: OSLog.default, type: .error, "=== Starting Tunnel Connection ===")
        
        try await prepInfra()
        try bootProxy()
        
        os_log("[Super Xray] %{public}@", log: OSLog.default, type: .error, "=== Tunnel Connection Completed ===")
    }
    
    private func prepInfra() async throws {
        let tunCfg = netCfg()
        applyNet(tunCfg)
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
    
    private func applyNet(_ tunCfg: NEPacketTunnelNetworkSettings) {
        self.applyNetworkSettings?(tunCfg) { error in
            if error != nil {
                os_log("[Super Xray] %{public}@", log: OSLog.default, type: .error, "Network settings application failed: \(error?.localizedDescription ?? "Unknown error")")
            } else {
                os_log("[Super Xray] %{public}@", log: OSLog.default, type: .error, "Network settings applied successfully")
            }
        }
    }
    
    private func bootProxy() throws {
        try bootSocks()
        try bootXray()
    }
    
    private func bootXray() throws {
        let b64Cfg = mkXrayCfg()
        try runXray(with: b64Cfg)
    }
    
    private func mkXrayCfg() -> String {
        let dirCfg = CProc.mkDirCfg()
        let b64Cfg = Data(dirCfg.utf8).base64EncodedString()
        os_log("[Super Xray] %{public}@", log: OSLog.default, type: .error, "Configuration encoded, length: \(b64Cfg.count) chars")
        return b64Cfg
    }
    
    private func runXray(with config: String) throws {
        guard let cfgStr = strdup(config) else {
            os_log("[Super Xray] %{public}@", log: OSLog.default, type: .error, "Failed to allocate memory for configuration")
            throw NSError(domain: "TConn", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to allocate memory"])
        }
        defer { free(cfgStr) }
        
        CGoRunGaffield(UnsafeMutablePointer(mutating: cfgStr))
        os_log("[Super Xray] %{public}@", log: OSLog.default, type: .error, "Xray service started successfully")
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
        CGoStopGaffield()
        os_log("[Super Xray] %{public}@", log: OSLog.default, type: .error, "Xray service stopped")
    }
}
