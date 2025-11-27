//
//  VPNConnectionStatus.swift
//  CoreVPN
//
//  Created by SHI QIU on 2025/11/27.
//

import Foundation

enum VPNConnectionStatus {
    case disconnected    // 未连接
    case connecting      // 处理中（连接中/断开中，按钮禁用）
    case connected       // 已连接
    case failed          // 连接失败
}

