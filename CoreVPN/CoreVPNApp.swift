//
//  CoreVPNApp.swift
//  CoreVPN
//
//  Created by SHI QIU on 2025/11/26.
//

import SwiftUI
import UIKit
import AppTrackingTransparency

@main
struct CoreVPNApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    @StateObject private var appLanguage = AppLanguage()
    @StateObject private var nodeStore = NodeSelectionStore()
    @StateObject private var tabSelection = TabSelection()
    @StateObject private var tunnelManager = TunnelStateManager()

    @State private var showSplash = true
    @State private var showPrivacy = false
    @State private var showReturnSplash = false
    @State private var fromBackground = false
    @State private var appReady = false
    @StateObject private var flowRouter = FlowRouter()
    
    @Environment(\.scenePhase) private var scenePhase

    private let privacyAcceptedKey = "CoreVPNPrivacyAccepted_v1"

    var body: some Scene {
        WindowGroup {
            ZStack {
                // 仅 RootTabView 使用 NavigationStack
                NavigationStack(path: $flowRouter.path) {
                    RootTabView()
                        .navigationDestination(for: FlowPage.self) { page in
                            switch page {
                            case .connecting:
                                ConnectingView {
                                    flowRouter.reset()
                                }
                            case .result(let type):
                                ResultView(type: type) {
                                    flowRouter.reset()
                                }
                            case .nodeList:
                                NodeListView()
                            }
                        }
                }
                .environmentObject(appLanguage)
                .environmentObject(nodeStore)
                .environmentObject(tabSelection)
                .environmentObject(tunnelManager)
                .environmentObject(flowRouter)
                .environment(\.locale, appLanguage.locale)
                .preferredColorScheme(.dark)
                
                // 启动页
                if showSplash {
                    SplashView(
                        onFinish: {
                            showSplash = false
                            appReady = true
                            if !UserDefaults.standard.bool(forKey: privacyAcceptedKey) {
                                showPrivacy = true
                            }
                        },
                        onFinishWithAd: {
                            showSplash = false
                            appReady = true
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                                showSplashAd()
                            }
                            if !UserDefaults.standard.bool(forKey: privacyAcceptedKey) {
                                showPrivacy = true
                            }
                        }
                    )
                    .background(Color(UIColor.systemBackground).opacity(1.0))
                    .ignoresSafeArea()
                }
                
                // 隐私页
                if showPrivacy {
                    PrivacyConsentView(
                        onAccept: {
                            UserDefaults.standard.set(true, forKey: privacyAcceptedKey)
                            showPrivacy = false
                        },
                        onDecline: {
                            UIApplication.shared.perform(#selector(NSXPCConnection.suspend))
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                exit(0)
                            }
                        }
                    )
                    .background(Color(UIColor.systemBackground).opacity(1.0))
                    .ignoresSafeArea()
                }
                
                // 后台返回覆盖页
                if showReturnSplash {
                    BackgroundSplashView {
                        showReturnSplash = false
                    }
                    .background(Color(UIColor.systemBackground).opacity(1.0))
                    .ignoresSafeArea()
                    .onAppear {
                        debugPrint("[Ad-Background] 后台启动页显示")
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                            displayReturnAd()
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                            showReturnSplash = false
                        }
                    }
                    .zIndex(9999)
                }
            }
        }
        .onChange(of: scenePhase) { newPhase in
            onScenePhaseChange(newPhase)
        }
    }
    
    private func requestATT() {
        if #available(iOS 14, *) {
            // 延迟一点时间，确保应用完全启动
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                ATTrackingManager.requestTrackingAuthorization { status in
                    
                }
            }
        }
    }
    
    // MARK: - Scene Phase 处理
    
    private func onScenePhaseChange(_ newPhase: ScenePhase) {
        switch newPhase {
        case .active:
            debugPrint("[Ad-Background] App 进入前台")
            requestATT()
            onForeground()
        case .inactive:
            break
        case .background:
            debugPrint("[Ad-Background] App 进入后台")
            onBackground()
        @unknown default:
            break
        }
    }
    
    private func onForeground() {
        // 只有在 App 启动完成后才显示从后台回来的 Splash 页面
        guard fromBackground && appReady else {
            return
        }
        
        let adHub = AdHub.shared
        
        // 返回前台时检查配置是否过期（基础配置6小时，广告配置4小时）
        refreshConfigsIfNeeded()
        
        // 拉广告
        adHub.warmAll(moment: EventAd.foreground)
        
        if canShowReturnSplash(adHub: adHub) {
            debugPrint("[Ad-Background] ✅ 显示后台启动页")
            showReturnOverlay()
        }
        
        fromBackground = false
    }
    
    private func onBackground() {
        fromBackground = true
    }
    
    /// 检查基础配置和广告配置是否过期，过期则后台刷新
    private func refreshConfigsIfNeeded(
        baseTTL: TimeInterval = 6 * 3600,
        adsTTL: TimeInterval = 4 * 3600
    ) {
        let now = Date()
        
        // 基础配置：超过 baseTTL 则重新获取
        if let lastBaseSave = AppConfigStore.shared.getConfigSaveDate() {
            if now.timeIntervalSince(lastBaseSave) >= baseTTL {
                debugPrint("[Config] 基础配置超过阈值，触发刷新")
                Task { AppConfigService.shared.fetchBaseConfig { _ in } }
            }
        } else {
            debugPrint("[Config] 未找到基础配置时间戳，首次拉取")
            Task { AppConfigService.shared.fetchBaseConfig { _ in } }
        }
        
        // 广告配置：超过 adsTTL 则重新获取
        if let lastAdsSave = AdsConfigStore.shared.saveTimestamp() {
            if now.timeIntervalSince(lastAdsSave) >= adsTTL {
                debugPrint("[Config] 广告配置超过阈值，触发刷新")
                Task { AdsService.shared.fetchAdsConfig { _ in } }
            }
        } else {
            debugPrint("[Config] 未找到广告配置时间戳，首次拉取")
            Task { AdsService.shared.fetchAdsConfig { _ in } }
        }
    }
    
    // MARK: - 启动页广告展示
    
    private func showSplashAd() {
        // 检查隐私同意状态
        guard UserDefaults.standard.bool(forKey: privacyAcceptedKey) else {
            debugPrint("[Ad-Splash] ⚠️ 隐私未同意，跳过展示")
            return
        }
        
        let adHub = AdHub.shared
        debugPrint("[Ad-Splash] 🎬 开始展示广告")
        
        if adHub.pingInt() {
            debugPrint("[Ad-Splash] ❤️ 展示 Int")
            adHub.pushInt()
        } else {
            debugPrint("[Ad-Splash] ❌ 无可用广告")
        }
    }
    
    // MARK: - 后台切前台广告展示
    
    private func displayReturnAd() {
        // 检查隐私同意状态
        guard UserDefaults.standard.bool(forKey: privacyAcceptedKey) else {
            debugPrint("[Ad-Background] ⚠️ 隐私未同意，跳过展示")
            return
        }
        
        let adHub = AdHub.shared
        
        if presentBestAd(adHub: adHub) {
            closeReturnOverlay(after: 0.1)
        } else {
            debugPrint("[Ad-Background] ❌ 无可用广告，等待3秒超时关闭")
        }
    }
    
    // MARK: - Helper Methods
    
    private func canShowReturnSplash(adHub: AdHub) -> Bool {
        // 检查隐私状态
        guard UserDefaults.standard.bool(forKey: privacyAcceptedKey) else {
            debugPrint("[Ad-Background] ⚠️ 隐私未同意，跳过展示")
            return false
        }
        
        // 检查UI连接状态（如果UI还在连接中，不显示后台页）
        if tunnelManager.connectionStatus == .connecting {
            debugPrint("[Ad-Background] ⚠️ VPN 正在连接，跳过展示")
            return false
        }
        
        // 检查是否有广告正在展示
        if adHub.showFlag {
            debugPrint("[Ad-Background] ⚠️ 已有广告在展示，跳过")
            return false
        }
        
        // 检查是否有广告可以展示
        if adHub.hasAnyReady() {
            return true
        } else {
            debugPrint("[Ad-Background] ❌ 无可用广告，跳过")
            return false
        }
    }
    
    private func showReturnOverlay() {
        showReturnSplash = true
        // 3秒后自动关闭（展示逻辑由 BackgroundSplashView.onAppear 触发）
        closeReturnOverlay(after: 3.0)
    }
    
    private func closeReturnOverlay(after delay: TimeInterval = 0) {
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            showReturnSplash = false
        }
    }
    
    private func presentBestAd(adHub: AdHub) -> Bool {
        if adHub.pingInt() {
            debugPrint("[Ad-Background] ❤️ 展示 Yandex Int")
            adHub.pushInt()
            return true
        }
        return false
    }
}
