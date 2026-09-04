//
//  AdsConfig.swift
//  CoreVPN
//
//  广告配置数据模型（/poplar/ads/shade 接口返回）
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
    /// Yandex 广告 Key
    let key: String
    /// 类型（可选）
    let type: Int?
    /// 名称（Yandex_Int_List / Yandex_EMInt_List）
    let name: String
    /// Key 列表（可选）
    let keyList: [String]?
    
    enum CodingKeys: String, CodingKey {
        case adId = "adId"
        case adStyle = "adStyle"
        case adType = "adType"
        case key = "key"
        case type = "type"
        case name = "name"
        case keyList = "keyList"
    }
}
