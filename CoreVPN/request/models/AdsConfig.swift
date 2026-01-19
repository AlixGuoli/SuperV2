//
//  AdsConfig.swift
//  CoreVPN
//
//  广告配置数据模型（/graphql/query/ads 接口返回）
//

import Foundation

struct AdsConfig: Codable {
    struct AdConfig: Codable {
        /// 广告混合配置列表
        let adMixed: [AdMixedItem]
        
        enum CodingKeys: String, CodingKey {
            case adMixed = "adMixed"
            // miscConfig 暂时忽略
        }
    }
    
    let adConfig: AdConfig
    
    enum CodingKeys: String, CodingKey {
        case adConfig = "adConfig"
    }
}

struct AdMixedItem: Codable {
    /// 广告 ID（可选，可能为空）
    let adId: String?
    /// 广告样式（可选）
    let adStyle: Int?
    /// 广告类型（可选）
    let adType: String?
    /// 广告 Key（Yandex/AdMob 的 key）- 必需
    let key: String
    /// 类型（可选）
    let type: Int?
    /// 名称（Yandex_Banner_List, Yandex_Int_List, Admob_Int_List）- 必需
    let name: String
    /// Key 列表（可选）
    let keyList: [String]?
    /// 穿透比例（0-100）- 可选（只有 Yandex Banner 需要）
    let penetrate: Int?
    /// 点击延迟穿透（秒）- 可选（只有 Yandex Banner 需要）
    let clickDelayPenet: Int?
    
    enum CodingKeys: String, CodingKey {
        case adId = "adId"
        case adStyle = "adStyle"
        case adType = "adType"
        case key = "key"
        case type = "type"
        case name = "name"
        case keyList = "keyList"
        case penetrate = "penetrate"
        case clickDelayPenet = "clickDelayPenet"
    }
}

