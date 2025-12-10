//
//  YanIntCenter.swift
//  CoreVPN
//
//  Yandex 插屏广告管理
//

import Foundation
import UIKit
import YandexMobileAds

class YanSlotHub: NSObject {
    
    private var cachedAd: InterstitialAd?
    private var showingAd: InterstitialAd?
    private var adUnitList: [String] = []
    private var isLoading = false
    private var loadStartAt: Date?
    private var adUnitIndex = 0
    
    var onAdReady: (() -> Void)?
    var onAdFailed: (() -> Void)?
    var onAdClicked: (() -> Void)?
    var onAdClosed: (() -> Void)?
    
    private lazy var adLoader: InterstitialAdLoader = {
        let loader = InterstitialAdLoader()
        loader.delegate = self
        return loader
    }()
    
    // MARK: - 广告配置和展示
    
    func initKeys() {
        adUnitList = YanEnv.adUnits()
        if !adUnitList.isEmpty {
            debugPrint("[Ad-YanInt] 获取到 keys: \(adUnitList.count) 个 | \(adUnitList)")
        } else {
            debugPrint("[Ad-YanInt] 未找到 keys")
        }
    }
    
    func open(from viewController: UIViewController, moment: String?) {
        guard let activeAd = cachedAd else {
            onAdClosed?()
            return
        }
        
        let adKeyId = activeAd.adInfo?.adUnitId ?? ""
        activeAd.show(from: viewController)
    }
    
    func available() -> Bool {
        return cachedAd != nil
    }
    
    func getCurrentAd() -> InterstitialAd? {
        return available() ? cachedAd : nil
    }
    
    func clearAd() {
        cachedAd = nil
        debugPrint("[Ad-YanInt] 清空广告")
    }
    
    // MARK: - 广告加载管理
    
    func fetch(moment: String? = nil) {
        debugPrint("[Ad-YanInt] 开始加载 | 连接状态: \(YanEnv.connState())")
        
        if canStartFetch() {
            initKeys()
            adUnitIndex = 0
            guard adUnitList.count > adUnitIndex else { return }
            
            debugPrint("[Ad-YanInt] 启动加载流程")
            isLoading = true
            loadStartAt = Date()
            
            Task {
                await loadNext(index: 0, moment: moment)
            }
        }
    }
    
    func reload(moment: String? = nil) {
        clearAd()
        fetch(moment: moment)
    }
    
    // MARK: - 私有方法
    
    private func loadNext(index: Int, moment: String? = nil) async {
        guard index < adUnitList.count else {
            handleLoadFailure()
            return
        }
        
        if let startTime = loadStartAt, Date().timeIntervalSince(startTime) > YanEnv.timeout {
            debugPrint("[Ad-YanInt] 加载超时 (100s)")
            isLoading = false
            handleLoadFailure()
            return
        }
        
        let adKey = adUnitList[index]
        debugPrint("[Ad-YanInt] 尝试加载 key[\(index)]: \(adKey)")
        
        let config = AdRequestConfiguration(adUnitID: adKey)
        adLoader.loadAd(with: config)
    }
    
    private func canStartFetch() -> Bool {
        if available() { return false }
        if isLoading {
            guard let startTime = loadStartAt else { return false }
            let elapsedTime = Date().timeIntervalSince(startTime)
            return elapsedTime > YanEnv.timeout
        }
        return true
    }
    
    private func handleLoadFailure() {
        isLoading = false
        onAdFailed?()
    }
    
    private func loadNextAd() {
        adUnitIndex += 1
        if adUnitIndex < adUnitList.count {
            Task {
                await loadNext(index: adUnitIndex)
            }
        } else {
            handleLoadFailure()
        }
    }
}

// MARK: - 外部依赖封装
private enum YanEnv {
    static func adUnits() -> [String] {
        AdsConfigStore.shared.intKey()
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
    
    static var timeout: TimeInterval { 100 }
}

// MARK: - Yandex Delegate

extension YanSlotHub: InterstitialAdLoaderDelegate, InterstitialAdDelegate {
    
    func interstitialAdLoader(_ adLoader: InterstitialAdLoader, didLoad interstitialAd: InterstitialAd) {
        debugPrint("[Ad-YanInt] ✅ 加载成功 | key: \(interstitialAd.adInfo?.adUnitId ?? "")")
        isLoading = false
        cachedAd = interstitialAd
        cachedAd?.delegate = self
        onAdReady?()
    }
    
    func interstitialAdLoader(_ adLoader: InterstitialAdLoader, didFailToLoadWithError error: AdRequestError) {
        debugPrint("[Ad-YanInt] ❌ 加载失败 | key: \(error.adUnitId ?? "") | error: \(error.error.localizedDescription)")
        loadNextAd()
    }
    
    func interstitialAd(_ interstitialAd: InterstitialAd, didFailToShowWithError error: Error) {
        debugPrint("[Ad-YanInt] ❌ 展示失败 | error: \(error.localizedDescription)")
        reload()
    }
    
    func interstitialAdDidShow(_ interstitialAd: InterstitialAd) {
        YanEnv.isShowing = true
        debugPrint("[Ad-YanInt] 广告已展示 | key: \(interstitialAd.adInfo?.adUnitId ?? "")")
    }
    
    func interstitialAdDidDismiss(_ interstitialAd: InterstitialAd) {
        onAdClosed?()
        reload()
        YanEnv.isShowing = false
    }
    
    func interstitialAdDidClick(_ interstitialAd: InterstitialAd) {
        onAdClicked?()
    }
    
    func interstitialAd(_ interstitialAd: InterstitialAd, didTrackImpressionWith impressionData: ImpressionData?) {
        // Handle impression tracking if needed
    }
}

