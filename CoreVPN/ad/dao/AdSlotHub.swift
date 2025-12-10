//
//  AdmobCenter.swift
//  CoreVPN
//
//  AdMob 插屏广告管理
//

import Foundation
import UIKit
import GoogleMobileAds

class AdSlotHub: NSObject {
    
    private var cachedAd: InterstitialAd?
    private var showingAd: InterstitialAd?
    private var isLoading = false
    private var adUnitList: [String] = []
    private var adUnitIndex = 0
    private var loadStartAt: Date?
    
    var onAdReady: (() -> Void)?
    var onAdFailed: (() -> Void)?
    var onAdClicked: (() -> Void)?
    var onAdClosed: (() -> Void)?
    
    // MARK: - 广告配置和展示
    
    func initKeys() {
        adUnitList = AdDeps.adUnits()
        if !adUnitList.isEmpty {
            debugPrint("[Ad-Admob] 获取到 keys: \(adUnitList.count) 个 | \(adUnitList)")
        } else {
            debugPrint("[Ad-Admob] 未找到 keys")
        }
    }
    
    func open(from viewController: UIViewController, moment: String?) {
        guard let activeAd = cachedAd else {
            return
        }
        
        let adKeyId = activeAd.adUnitID
        activeAd.present(from: viewController)
        
        // 上报展示事件
        AdDeps.report(event: EventReporter.evtAdShow, key: adKeyId, moment: moment)
    }
    
    func available() -> Bool {
        return cachedAd != nil
    }
    
    func getCurrentAd() -> InterstitialAd? {
        return available() ? cachedAd : nil
    }
    
    func clearAd() {
        cachedAd = nil
        debugPrint("[Ad-Admob] 清空广告")
    }
    
    // MARK: - 广告加载管理
    
    func fetch(moment: String? = nil) {
        debugPrint("[Ad-Admob] 开始加载 | 连接状态: \(AdDeps.connState())")
        
        if canStartFetch() {
            initKeys()
            adUnitIndex = 0
            guard adUnitList.count > adUnitIndex else { return }
            
            debugPrint("[Ad-Admob] 启动加载流程")
            isLoading = true
            loadStartAt = Date()
            
            Task {
                await loadNext(moment: moment)
            }
        }
    }
    
    func reload(moment: String? = nil) {
        clearAd()
        fetch(moment: moment)
    }
    
    // MARK: - 私有方法
    
    private func loadNext(moment: String? = nil) async {
        guard adUnitIndex < adUnitList.count else {
            handleLoadFailure()
            return
        }
        
        if let startTime = loadStartAt, Date().timeIntervalSince(startTime) > AdDeps.timeout {
            debugPrint("[Ad-Admob] 加载超时 (120s)")
            isLoading = false
            handleLoadFailure()
            return
        }
        
        let adKey = adUnitList[adUnitIndex]
        debugPrint("[Ad-Admob] 尝试加载 key[\(adUnitIndex)]: \(adKey)")
        
        // 上报开始加载事件
        AdDeps.report(event: EventReporter.evtAdStart, key: adKey, moment: moment)
        
        do {
            let ad = try await InterstitialAd.load(with: adKey, request: Request())
            
            debugPrint("[Ad-Admob] ✅ 加载成功 | key: \(ad.adUnitID)")
            isLoading = false
            cachedAd = ad
            cachedAd?.fullScreenContentDelegate = self
            
            // 上报加载成功事件
            AdDeps.report(event: EventReporter.evtAdSuccess, key: ad.adUnitID, moment: moment)
            
            onAdReady?()
        } catch {
            debugPrint("[Ad-Admob] ❌ 加载失败 | key: \(adKey) | error: \(error.localizedDescription)")
            adUnitIndex += 1
            await loadNext(moment: moment)
        }
    }
    
    private func canStartFetch() -> Bool {
        if available() { return false }
        if isLoading {
            guard let startTime = loadStartAt else { return false }
            let elapsedTime = Date().timeIntervalSince(startTime)
            return elapsedTime > AdDeps.timeout
        }
        return true
    }
    
    private func handleLoadFailure() {
        isLoading = false
        onAdFailed?()
    }
}

// MARK: - GADFullScreenContentDelegate

extension AdSlotHub: FullScreenContentDelegate {
    
    func adWillPresentFullScreenContent(_ ad: FullScreenPresentingAd) {
        debugPrint("[Ad-Admob] 广告将展示")
        AdDeps.isShowing = true
        showingAd = cachedAd
        cachedAd = nil
        reload(moment: EventAd.closead)
    }
    
    func adDidRecordImpression(_ ad: FullScreenPresentingAd) {
        debugPrint("[Ad-Admob] 广告已展示")
    }
    
    func adDidRecordClick(_ ad: FullScreenPresentingAd) {
        debugPrint("[Ad-Admob] 广告点击")
        onAdClicked?()
    }
    
    func ad(_ ad: FullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: Error) {
        debugPrint("[Ad-Admob] ❌ 展示失败 | error: \(error.localizedDescription)")
        reload()
    }
    
    func adWillDismissFullScreenContent(_ ad: FullScreenPresentingAd) {
        AdDeps.isShowing = false
    }
    
    func adDidDismissFullScreenContent(_ ad: any FullScreenPresentingAd) {
        debugPrint("[Ad-Admob] 广告关闭")
    }

}

// MARK: - 外部依赖封装
private enum AdDeps {
    static func adUnits() -> [String] {
        AdsConfigStore.shared.admobKey()
            .components(separatedBy: ";")
            .filter { !$0.isEmpty }
    }
    
    static func connState() -> TunnelState {
        AppGlobalStatus.shared.connectStatus
    }
    
    static var isShowing: Bool {
        get { AdHub.shared.showFlag }
        set { AdHub.shared.showFlag = newValue }
    }
    
    static func report(event: String, key: String, moment: String?) {
        EventReporter.shared.sendAdEvent(event: event, key: key, eventAd: moment)
    }
    
    static var timeout: TimeInterval { 120 }
}

