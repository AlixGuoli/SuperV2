//
//  AppGlobalStatus.swift
//  CoreVPN
//
//  全局状态管理（用于广告等全局访问）
//

import Foundation

class AppGlobalStatus {
    
    static let shared = AppGlobalStatus()
    
    private init() {}
    
    /// 全局当前连接状态
    var connectStatus: TunnelState = .disconnected
}

