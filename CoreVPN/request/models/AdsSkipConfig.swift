//
//  AdsSkipConfig.swift
//  CoreVPN
//
//  广告跳过按钮配置数据模型
//

import Foundation

struct AdsSkipConfig: Codable {
    let location: Int  // 0-5
    let x: Int
    let y: Int
    
    // 默认值
    static let `default` = AdsSkipConfig(location: 0, x: 20, y: 100)
    
    // Location 枚举（用于代码可读性）
    enum Location: Int {
        case topLeft = 0
        case topRight = 1
        case centerLeft = 2
        case centerRight = 3
        case bottomLeft = 4
        case bottomRight = 5
    }
}

