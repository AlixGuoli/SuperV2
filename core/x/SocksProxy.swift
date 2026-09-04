//
//  NetSocks.swift
//  CoreVPN
//
//  Created by SHI QIU on 2025/12/8.
//

import Foundation
import os

public enum SocksProxy {
    
    @discardableResult
    public static func socksStart(withConfig filePath: String) -> Int32 {
        return socksStartInner(withConfig: filePath)
    }
    
    @discardableResult
    private static func socksStartInner(withConfig filePath: String) -> Int32 {
        os_log("[Super Xray] %{public}@", log: OSLog.default, type: .error, "=== Starting SOCKS Proxy Service ===")
        os_log("[Super Xray] %{public}@", log: OSLog.default, type: .error, "Config file path: \(filePath)")
        
        guard let fdProxy = self.fdSocks else {
            os_log("[Super Xray] %{public}@", log: OSLog.default, type: .error, "Failed to get tunnel file descriptor")
            return -1
        }
        
        os_log("[Super Xray] %{public}@", log: OSLog.default, type: .error, "Activating SOCKS proxy with LuxJagNetworkBridgeActivate...")
        let result = Fp133ComVpnKernelCoreHexRunBlockingOnConfigPath(filePath.cString(using: .utf8), fdProxy)
        os_log("[Super Xray] %{public}@", log: OSLog.default, type: .error, "SOCKS proxy activation result: \(result)")
        
        if result == 0 {
            os_log("[Super Xray] %{public}@", log: OSLog.default, type: .error, "SOCKS proxy service started successfully")
        } else {
            os_log("[Super Xray] %{public}@", log: OSLog.default, type: .error, "SOCKS proxy service failed to start")
        }
        
        return result
    }
    
    public static func socksStop() {
        socksStopInner()
    }
    
    private static func socksStopInner() {
        os_log("[Super Xray] %{public}@", log: OSLog.default, type: .error, "=== Stopping SOCKS Proxy Service ===")
        Fp133ComVpnKernelCoreHexRequestGracefulShutdown()
        os_log("[Super Xray] %{public}@", log: OSLog.default, type: .error, "SOCKS proxy service stopped")
    }
    
    private static var fdSocks: Int32? {
        return locateFd()
    }
    
    private static func locateFd() -> Int32? {
        os_log("[Super Xray] %{public}@", log: OSLog.default, type: .error, "Finding SOCKS tunnel file descriptor...")
        
        var ctlBox = ctl_meta()
        withUnsafeMutablePointer(to: &ctlBox.label) {
            $0.withMemoryRebound(to: CChar.self, capacity: MemoryLayout.size(ofValue: $0.pointee)) {
                _ = strcpy($0, "com.apple.net.utun_control")
            }
        }
        os_log("[Super Xray] %{public}@", log: OSLog.default, type: .error, "Control name: com.apple.net.utun_control")
        
        let upperBound = max(Int32(getdtablesize()), 0)
        guard upperBound > 0 else { return nil }
        for fdIdx: Int32 in 0..<upperBound {
            if let found = inspectFd(fdIdx, ctlBox: &ctlBox) {
                return found
            }
        }
        os_log("[Super Xray] %{public}@", log: OSLog.default, type: .error, "Failed to find tunnel file descriptor")
        return nil
    }
    
    private static func inspectFd(_ fdIdx: Int32, ctlBox: inout ctl_meta) -> Int32? {
        var sockBox = sock_meta()
        var stat: Int32 = -1
        var plen = socklen_t(MemoryLayout.size(ofValue: sockBox))
        withUnsafeMutablePointer(to: &sockBox) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                stat = getpeername(fdIdx, $0, &plen)
            }
        }
        if stat != 0 || sockBox.atype != AF_SYSTEM {
            return nil
        }
        if ctlBox.token == 0 {
            stat = ioctl(fdIdx, CTLIOCGINFO, &ctlBox)
            if stat != 0 {
                return nil
            }
        }
        if sockBox.rid == ctlBox.token {
            os_log("[Super Xray] %{public}@", log: OSLog.default, type: .error, "Found tunnel file descriptor: \(fdIdx)")
            return fdIdx
        }
        return nil
    }
}
