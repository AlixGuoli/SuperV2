//
//  VPNManager.swift
//  CoreVPN
//
//  Created by SHI QIU on 2025/11/27.
//

import Foundation
import NetworkExtension

class VPNManager {
    
    public var coreMgr: NETunnelProviderManager
    
    private static var sharedInstance: VPNManager = {
        return VPNManager()
    }()
    
    public class func shared() -> VPNManager {
        return sharedInstance
    }
    
    public init() {
        self.coreMgr = NETunnelProviderManager()
    }
    
    /// 只读取已有配置，不创建（用于恢复状态，避免触发权限）
    public func loadExistingPreferences(completion: @escaping (Bool, Error?) -> Void) {
        NETunnelProviderManager.loadAllFromPreferences { [weak self] managers, error in
            guard let self = self else { return }
            
            if let error = error {
                completion(false, error)
                return
            }
            
            guard let managers = managers, !managers.isEmpty else {
                // 没有配置，返回false但不报错
                completion(false, nil)
                return
            }
            
            // 有配置，加载它
            self.coreMgr = managers[0]
            self.coreMgr.loadFromPreferences { error in
                completion(true, error)
            }
        }
    }
    
    /// 加载VPN配置，如果不存在则创建（用于用户主动连接）
    public func loadFromPreferences(completion: @escaping (Error?) -> Void) {
        NETunnelProviderManager.loadAllFromPreferences { [weak self] managers, error in
            guard let self = self else { return }
            
            guard let managers = managers, error == nil else {
                completion(error)
                return
            }
            
            if managers.isEmpty {
                // 创建新的配置
                let providerManager = NETunnelProviderManager()
                let protocolConfig = NETunnelProviderProtocol()
                protocolConfig.serverAddress = "Core VPN"
                providerManager.protocolConfiguration = protocolConfig
                providerManager.localizedDescription = "Core VPN"
                providerManager.isEnabled = true
                
                providerManager.saveToPreferences { error in
                    guard error == nil else {
                        completion(error)
                        return
                    }
                    providerManager.loadFromPreferences { error in
                        self.coreMgr = providerManager
                        completion(error)
                    }
                }
            } else {
                // 使用已存在的配置
                self.coreMgr = managers[0]
                self.coreMgr.loadFromPreferences { error in
                    completion(error)
                }
            }
        }
    }
    
    /// 启用并保存VPN配置
    public func enableAndConfigure(completion: @escaping (Error?) -> Void) {
        coreMgr.isEnabled = true
        coreMgr.saveToPreferences { [weak self] error in
            guard let self = self else { return }
            guard error == nil else {
                completion(error)
                return
            }
            self.coreMgr.loadFromPreferences { error in
                completion(error)
            }
        }
    }
    
    /// 启动VPN连接
    public func startConnection(completion: @escaping (Error?) -> Void) {
        if coreMgr.connection.status == .disconnected || coreMgr.connection.status == .invalid {
            do {
                debugPrint("VPNManager: 启动VPN连接")
                try coreMgr.connection.startVPNTunnel()
                completion(nil)
            } catch {
                debugPrint("VPNManager: 启动连接失败 - \(error)")
                completion(error)
            }
        } else {
            completion(nil)
        }
    }
    
    /// 停止VPN连接
    public func stopConnection() {
        if coreMgr.connection.status == .connected || coreMgr.connection.status == .connecting {
            debugPrint("VPNManager: 停止VPN连接")
            coreMgr.connection.stopVPNTunnel()
        }
    }
}

