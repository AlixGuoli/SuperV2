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
        return yIntUnit.available()
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
            yBanUnit.fetch()
            yIntUnit.fetch()
        }
        
        if gaOn {
            gUnit.fetch(moment: moment)
        }
    }
    
    func warmBan(onAdReady: (() -> Void)? = nil, onAdFailed: (() -> Void)? = nil) {
        debugPrint("[Ad-Center] 加载 Yandex Banner")
        
        if adsToggle && yaOn {
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
        debugPrint("[Ad-Center] 加载 Yandex Int")
        
        if adsToggle && yaOn {
            if pingInt() {
                onAdReady?()
            } else {
                yIntUnit.onAdReady = onAdReady
                yIntUnit.onAdFailed = onAdFailed
                yIntUnit.fetch()
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

