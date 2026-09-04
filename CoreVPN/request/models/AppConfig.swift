//
//  AppConfig.swift
//  CoreVPN
//
//  基本配置数据模型（/poplar/config/cambium 接口返回）
//

import Foundation

struct AppConfig: Codable {
    struct CommonConf: Codable {
        /// 广告开关
        let adsOff: Bool
        /// 检测配置
        let detectionConfig: DetectionConfig
        /// Git 版本号
        let git_version: Int
        /// iOS 专业版版本列表
        let ios_professional_versions: [String]
        /// 评价配置
        let rateus: RateusConfig
        /// 广告类型
        let adsType: String
        /// 服务状态码
        let hotcode: String
        /// 动态 Telegram 链接
        let dynamic_tg_link: String
        
        enum CodingKeys: String, CodingKey {
            case adsOff
            case detectionConfig
            case git_version
            case ios_professional_versions
            case rateus
            case adsType
            case hotcode
            case dynamic_tg_link
            // 以下字段忽略（后台可能变更，不影响解析）
            // IPWhiteList, latestClientVersion, upgrade, iosTabblerControl,
            // logURL, forceUpdate, ipinfo, versionInterval, language_enable,
            // pro_enable, pro_day_interval, special_ad_policy, ios_view_professional,
            // client_dns_servers, battery_disable, bv, pv, native_show_rate
        }
    }
    
    let commonConf: CommonConf
    
    enum CodingKeys: String, CodingKey {
        case commonConf
    }
}

struct DetectionConfig: Codable {
    /// 检测服务器列表
    let detectionServers: [String]
    
    enum CodingKeys: String, CodingKey {
        case detectionServers
        // 以下字段忽略（后台可能变更，不影响解析）
        // detectionThreshold, detectionInterval
    }
}

struct RateusConfig: Codable {
    /// 每天最大弹窗次数
    let maxDailyPopups: Int
    /// 冷却天数
    let cooldownDays: Int
}
