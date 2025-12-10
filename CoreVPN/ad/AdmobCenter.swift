//
//  AdmobCenter.swift
//  CoreVPN
//
//  AdMob 插屏广告管理
//

import Foundation
import UIKit
import GoogleMobileAds

class AdmobCenter: NSObject {
    
    private var activeAd: InterstitialAd?
    private var displayingAd: InterstitialAd?
    private var fetching = false
    private var keyPool: [String] = []
    private var keyPos = 0
    private var loadStartTime: Date?
    
    var onAdReady: (() -> Void)?
    var onAdFailed: (() -> Void)?
    var onAdClicked: (() -> Void)?
    var onAdClosed: (() -> Void)?
    
    // MARK: - 广告配置和展示
    
    func initKeys() {
        let admobKey = AdsConfigStore.shared.admobKey()
        if !admobKey.isEmpty {
            self.keyPool = admobKey.components(separatedBy: ";").filter { !$0.isEmpty }
            debugPrint("[Ad-Admob] 获取到 keys: \(keyPool.count) 个 | \(keyPool)")
        } else {
            self.keyPool = []
            debugPrint("[Ad-Admob] 未找到 keys")
        }
    }
    
    func open(from viewController: UIViewController, moment: String?) {
        guard let activeAd = activeAd else {
            return
        }
        
        let adKeyId = activeAd.adUnitID
        activeAd.present(from: viewController)
        
        // 上报展示事件
        EventReporter.shared.sendAdEvent(event: EventReporter.evtAdShow, key: adKeyId, eventAd: moment)
    }
    
    func available() -> Bool {
        return activeAd != nil
    }
    
    func getCurrentAd() -> InterstitialAd? {
        return available() ? activeAd : nil
    }
    
    func clearAd() {
        activeAd = nil
        debugPrint("[Ad-Admob] 清空广告")
    }
    
    // MARK: - 广告加载管理
    
    func fetch(moment: String? = nil) {
        debugPrint("[Ad-Admob] 开始加载 | 连接状态: \(AppGlobalStatus.shared.connectStatus)")
        
        if canStartFetch() {
            initKeys()
            keyPos = 0
            guard keyPool.count > keyPos else { return }
            
            debugPrint("[Ad-Admob] 启动加载流程")
            fetching = true
            loadStartTime = Date()
            
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
        guard keyPos < keyPool.count else {
            handleLoadFailure()
            return
        }
        
        if let startTime = loadStartTime, Date().timeIntervalSince(startTime) > 120 {
            debugPrint("[Ad-Admob] 加载超时 (120s)")
            fetching = false
            handleLoadFailure()
            return
        }
        
        let adKey = keyPool[keyPos]
        debugPrint("[Ad-Admob] 尝试加载 key[\(keyPos)]: \(adKey)")
        
        // 上报开始加载事件
        EventReporter.shared.sendAdEvent(event: EventReporter.evtAdStart, key: adKey, eventAd: moment)
        
        do {
            let ad = try await InterstitialAd.load(with: adKey, request: Request())
            
            debugPrint("[Ad-Admob] ✅ 加载成功 | key: \(ad.adUnitID)")
            fetching = false
            activeAd = ad
            activeAd?.fullScreenContentDelegate = self
            
            // 上报加载成功事件
            EventReporter.shared.sendAdEvent(event: EventReporter.evtAdSuccess, key: ad.adUnitID, eventAd: moment)
            
            onAdReady?()
        } catch {
            debugPrint("[Ad-Admob] ❌ 加载失败 | key: \(adKey) | error: \(error.localizedDescription)")
            keyPos += 1
            await loadNext(moment: moment)
        }
    }
    
    private func canStartFetch() -> Bool {
        if available() { return false }
        if fetching {
            guard let startTime = loadStartTime else { return false }
            let elapsedTime = Date().timeIntervalSince(startTime)
            return elapsedTime > 120
        }
        return true
    }
    
    private func handleLoadFailure() {
        fetching = false
        onAdFailed?()
    }
}

// MARK: - GADFullScreenContentDelegate

extension AdmobCenter: FullScreenContentDelegate {
    
    func adWillPresentFullScreenContent(_ ad: FullScreenPresentingAd) {
        debugPrint("[Ad-Admob] 广告将展示")
        AdCenter.shared.isShowingAd = true
        displayingAd = activeAd
        activeAd = nil
        reload(moment: AdMoment.closead)
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
        AdCenter.shared.isShowingAd = false
    }
    
    func adDidDismissFullScreenContent(_ ad: any FullScreenPresentingAd) {
        debugPrint("[Ad-Admob] 广告关闭")
    }

}

