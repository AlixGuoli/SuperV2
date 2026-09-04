//
//  AdCenter.swift
//  CoreVPN
//
//  广告中心（统一入口 + 配置管理）
//

import Foundation
import UIKit
import YandexMobileAds

class AdHub {
    
    static var shared = AdHub()
    
    let yIntUnit = YanSlotHub()
    let yEMIntUnit = YanEMSlotHub()
    
    var showFlag = false
    var vipFlag = false
    
    // MARK: - 外部依赖封装
    private enum Env {
        static var cfg: AppConfigStore { AppConfigStore.shared }
    }
    
    private var adsToggle: Bool {
        
        if vipFlag {
            debugPrint("[Ad-Center] 广告关闭 | 原因: VIP用户")
            return false
        }
        
        let isAdsOff = Env.cfg.getSavedAdsOff()!
        let adType = Env.cfg.getSavedAdsType()!.components(separatedBy: ";")
        
        debugPrint("[Ad-Center] 广告开关: \(isAdsOff ? "关闭" : "开启")")
        debugPrint("[Ad-Center] 广告类型: \(adType)")
        
        return !isAdsOff
    }

    /// 当前版本只识别 EM 和普通 Yandex；旧缓存中的 `a` 不再生效。
    private var adTypeTokens: Set<String> {
        let raw = Env.cfg.getSavedAdsType() ?? ""
        return Set(raw.split(separator: ";").map { String($0) })
    }
    
    private var yaOn: Bool {
        if adTypeTokens.contains("y") {
            return true
        }
        debugPrint("[Ad-Center] Yandex 关闭")
        return false
    }
    
    /// e 独立：有 "e" 就是 EM，不管有没有 "y"
    private var emOn: Bool {
        return adTypeTokens.contains("e")
    }
    
    private init() {
        vipFlag = UserPrefs.isPremium
    }
    
    // MARK: - 状态检查方法
    
    func pingInt() -> Bool {
        if emOn {
            return yEMIntUnit.available()
        }
        return yIntUnit.available()
    }
    
    func hasYanReady() -> Bool {
        guard adsToggle else { return false }
        return pingInt()
    }
    
    func hasAnyReady() -> Bool {
        guard adsToggle else { return false }
        return hasYanReady()
    }
    
    // MARK: - 广告加载管理
    
    func warmAll(moment: String? = nil) {
        debugPrint("[Ad-Center] 加载所有广告 | moment: \(moment ?? "nil")")
        
        guard adsToggle else {
            debugPrint("[Ad-Center] 广告已禁用，跳过加载")
            return
        }
        
        // 有 e 就是 EM：只加载 EM Int，不依赖 y
        if emOn {
            debugPrint("[Ad-Center] 加载 Yandex EM Int")
            yEMIntUnit.fetch()
        }
        // 有 y 且无 e：加载原版 Yandex Int（不再加载 Banner）
        else if yaOn {
            debugPrint("[Ad-Center] 加载 Yandex 原版 Int")
            yIntUnit.fetch()
        }
        
    }
    
    func warmInt(onAdReady: (() -> Void)? = nil, onAdFailed: (() -> Void)? = nil) {
        guard adsToggle, emOn || yaOn else {
            onAdReady?()
            return
        }
        if emOn {
            debugPrint("[Ad-Center] 加载 Yandex EM Int")
            if pingInt() {
                onAdReady?()
            } else {
                yEMIntUnit.onAdReady = onAdReady
                yEMIntUnit.onAdFailed = onAdFailed
                yEMIntUnit.fetch()
            }
        } else {
            debugPrint("[Ad-Center] 加载 Yandex 原版 Int")
            if pingInt() {
                onAdReady?()
            } else {
                yIntUnit.onAdReady = onAdReady
                yIntUnit.onAdFailed = onAdFailed
                yIntUnit.fetch()
            }
        }
    }
    
    // MARK: - 便捷展示方法
    
    func pushInt(onClose: (() -> Void)? = nil) {
        AdShow.shared.showFromRoot(type: .yandexInt, onClose: onClose)
    }
    
}
