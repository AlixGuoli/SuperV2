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
    
    let gUnit = AdSlotHub()
    let yIntUnit = YanSlotHub()
    let yEMIntUnit = YanEMSlotHub()
    let yBanUnit = YanBannerHub()
    
    var showFlag = false
    var vipFlag = false
    
    // MARK: - 外部依赖封装
    private enum Env {
        static var cfg: AppConfigStore { AppConfigStore.shared }
        static var status: AppGlobalStatus { AppGlobalStatus.shared }
        static var connectState: TunnelState { status.connectStatus }
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
    
    private var yaOn: Bool {
        let adType = Env.cfg.getSavedAdsType()!.components(separatedBy: ";")
        if adType.contains("y") {
            return true
        }
        debugPrint("[Ad-Center] Yandex 关闭")
        return false
    }
    
    private var gaOn: Bool {
        let adType = Env.cfg.getSavedAdsType()!.components(separatedBy: ";")
        if adType.contains("a") {
            if Env.connectState == .connected {
                return true
            }
        }
        debugPrint("[Ad-Center] Admob 关闭 | 原因: 未连接或类型不匹配")
        return false
    }
    
    private init() {
        vipFlag = UserPrefs.isPremium
    }
    
    // MARK: - 状态检查方法
    
    func pingBan() -> Bool {
        return yBanUnit.available()
    }
    
    func pingInt() -> Bool {
        let adsType = Env.cfg.getSavedAdsType()!.components(separatedBy: ";")
        if adsType.contains("e") {
            return yEMIntUnit.available()
        } else {
            return yIntUnit.available()
        }
    }
    
    func pingG() -> Bool {
        if Env.connectState == .connected {
            return gUnit.available()
        } else {
            gUnit.clearAd()
            return false
        }
    }
    
    func hasYanReady() -> Bool {
        guard adsToggle else { return false }
        return pingBan() || pingInt()
    }
    
    func hasAnyReady() -> Bool {
        guard adsToggle else { return false }
        return hasYanReady() || pingG()
    }
    
    // MARK: - 广告加载管理
    
    func warmAll(moment: String? = nil) {
        debugPrint("[Ad-Center] 加载所有广告 | moment: \(moment ?? "nil")")
        
        guard adsToggle else {
            debugPrint("[Ad-Center] 广告已禁用，跳过加载")
            return
        }
        
        if yaOn {
            let adsType = Env.cfg.getSavedAdsType()!.components(separatedBy: ";")
            let isEMMode = adsType.contains("e")
            
            // 没有 "e" 才加载 Banner（有 "e" 就是 EM 模式，不加载 Banner）
            if !isEMMode {
                yBanUnit.fetch()
            } else {
                debugPrint("[Ad-Center] EM 模式，跳过 Banner 加载")
            }
            
            // 根据是否是 EM 模式，加载对应的 Int
            if isEMMode {
                debugPrint("[Ad-Center] 加载 Yandex EM Int")
                yEMIntUnit.fetch()
            } else {
                debugPrint("[Ad-Center] 加载 Yandex 原版 Int")
                yIntUnit.fetch()
            }
        }
        
        // Admob 根据后台配置决定是否加载（有 "a" 就加载，没 "a" 就不加载）
        if gaOn {
            gUnit.fetch(moment: moment)
        }
    }
    
    func warmBan(onAdReady: (() -> Void)? = nil, onAdFailed: (() -> Void)? = nil) {
        debugPrint("[Ad-Center] 加载 Yandex Banner")
        
        if adsToggle && yaOn {
            let adsType = Env.cfg.getSavedAdsType()!.components(separatedBy: ";")
            
            // 有 "e" 就不加载 Banner，直接回调成功
            if adsType.contains("e") {
                debugPrint("[Ad-Center] EM 模式，跳过 Banner 加载")
                onAdReady?()
                return
            }
            
            // 原逻辑保持不变
            if pingBan() {
                onAdReady?()
            } else {
                yBanUnit.onAdReady = onAdReady
                yBanUnit.onAdFailed = onAdFailed
                yBanUnit.fetch()
            }
        } else {
            onAdReady?()
        }
    }
    
    func warmInt(onAdReady: (() -> Void)? = nil, onAdFailed: (() -> Void)? = nil) {
        if adsToggle && yaOn {
            let adsType = Env.cfg.getSavedAdsType()!.components(separatedBy: ";")
            let isEMMode = adsType.contains("e")
            
            if isEMMode {
                debugPrint("[Ad-Center] 加载 Yandex EM Int")
            } else {
                debugPrint("[Ad-Center] 加载 Yandex 原版 Int")
            }
            
            if pingInt() {
                onAdReady?()
            } else {
                if isEMMode {
                    yEMIntUnit.onAdReady = onAdReady
                    yEMIntUnit.onAdFailed = onAdFailed
                    yEMIntUnit.fetch()
                } else {
                    yIntUnit.onAdReady = onAdReady
                    yIntUnit.onAdFailed = onAdFailed
                    yIntUnit.fetch()
                }
            }
        } else {
            onAdReady?()
        }
    }
    
    func warmG(moment: String? = nil, onAdReady: (() -> Void)? = nil, onAdFailed: (() -> Void)? = nil) {
        debugPrint("[Ad-Center] 加载 Admob Int")
        
        if adsToggle && gaOn {
            gUnit.onAdReady = onAdReady
            gUnit.onAdFailed = onAdFailed
            gUnit.fetch(moment: moment)
        } else {
            onAdReady?()
        }
    }
    
    // MARK: - 便捷展示方法
    
    func pushBan() {
        AdShow.shared.showFromRoot(type: .yandexBanner)
    }
    
    func pushInt(onClose: (() -> Void)? = nil) {
        AdShow.shared.showFromRoot(type: .yandexInt, onClose: onClose)
    }
    
    func pushG(moment: String?) {
        AdShow.shared.showFromRoot(type: .admobInt, moment: moment)
    }
    
    // MARK: - 获取方法
    
    func getBan() -> AdView? {
        return AdShow.shared.fetchBan()
    }
}

