//
//  CoreVPNApp.swift
//  CoreVPN
//
//  Created by SHI QIU on 2025/11/26.
//

import SwiftUI
import UIKit

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
            NavigationStack(path: $flowRouter.path) {
                Group {
                    if showSplash {
                        SplashView(
                            onFinish: {
                                showSplash = false
                                appReady = true
                                // 启动页结束后，如果还没同意隐私，就进隐私页
                                if !UserDefaults.standard.bool(forKey: privacyAcceptedKey) {
                                    showPrivacy = true
                                }
                            },
                            onFinishWithAd: {
                                showSplash = false
                                appReady = true
                                // 延迟展示广告，避免与切换动画竞争
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                                    showSplashAd()
                                }
                                // 启动页结束后，如果还没同意隐私，就进隐私页
                                if !UserDefaults.standard.bool(forKey: privacyAcceptedKey) {
                                    showPrivacy = true
                                }
                            }
                        )
                    } else if showPrivacy {
                        PrivacyConsentView(
                            onAccept: {
                                UserDefaults.standard.set(true, forKey: privacyAcceptedKey)
                                showPrivacy = false
                            },
                            onDecline: {
                                // 不同意，直接退出 App（iOS 常见做法）
                                UIApplication.shared.perform(#selector(NSXPCConnection.suspend))
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                    exit(0)
                                }
                            }
                        )
                    } else {
                        ZStack {
                            RootTabView()
                            
                            // 后台切前台的启动页
                            if showReturnSplash {
                                BackgroundSplashView {
                                    showReturnSplash = false
                                }
                                .background(Color(UIColor.systemBackground).opacity(1.0))
                                .onAppear {
                                    debugPrint("[Ad-Background] 后台启动页显示")
                                    // 2秒后展示广告
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                                        displayReturnAd()
                                    }
                                    // 3秒后自动关闭
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                                        showReturnSplash = false
                                    }
                                }
                            }
                        }
                    }
                }
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
                    }
                }
            }
            .preferredColorScheme(.dark)
            .environmentObject(appLanguage)
            .environmentObject(nodeStore)
            .environmentObject(tabSelection)
            .environmentObject(tunnelManager)
            .environmentObject(flowRouter)
            .environment(\.locale, appLanguage.locale)
        }
        .onChange(of: scenePhase) { newPhase in
            onScenePhaseChange(newPhase)
        }
    }
    
    // MARK: - Scene Phase 处理
    
    private func onScenePhaseChange(_ newPhase: ScenePhase) {
        switch newPhase {
        case .active:
            debugPrint("[Ad-Background] App 进入前台")
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
        
        let adCenter = AdCenter.shared
        
        // 拉广告
        adCenter.loadAllAdvertisements(moment: AdMoment.foreground)
        
        if canShowReturnSplash(adCenter: adCenter) {
            debugPrint("[Ad-Background] ✅ 显示后台启动页")
            showReturnOverlay()
        }
        
        fromBackground = false
    }
    
    private func onBackground() {
        fromBackground = true
    }
    
    // MARK: - 启动页广告展示
    
    private func showSplashAd() {
        // 检查隐私同意状态
        guard UserDefaults.standard.bool(forKey: privacyAcceptedKey) else {
            debugPrint("[Ad-Splash] ⚠️ 隐私未同意，跳过展示")
            return
        }
        
        let adCenter = AdCenter.shared
        debugPrint("[Ad-Splash] 🎬 开始展示广告")
        
        if adCenter.checkBannerStatus() {
            debugPrint("[Ad-Splash] ✅ 展示 Banner")
            adCenter.showYanBannerFromRoot()
        } else if adCenter.checkIntStatus() {
            debugPrint("[Ad-Splash] ✅ 展示 Int")
            adCenter.showYanIntFromRoot()
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
        
        let adCenter = AdCenter.shared
        
        if presentBestAd(adCenter: adCenter) {
            closeReturnOverlay(after: 0.1)
        } else {
            debugPrint("[Ad-Background] ❌ 无可用广告，等待3秒超时关闭")
        }
    }
    
    // MARK: - Helper Methods
    
    private func canShowReturnSplash(adCenter: AdCenter) -> Bool {
        // 检查隐私状态
        guard UserDefaults.standard.bool(forKey: privacyAcceptedKey) else {
            debugPrint("[Ad-Background] ⚠️ 隐私未同意，跳过展示")
            return false
        }
        
        // 检查连接状态
        if AppGlobalStatus.shared.connectStatus == .connecting {
            debugPrint("[Ad-Background] ⚠️ VPN 正在连接，跳过展示")
            return false
        }
        
        // 检查是否有广告正在展示
        if adCenter.isShowingAd {
            debugPrint("[Ad-Background] ⚠️ 已有广告在展示，跳过")
            return false
        }
        
        // 检查是否有广告可以展示
        if adCenter.checkOverallAvailability() {
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
    
    private func presentBestAd(adCenter: AdCenter) -> Bool {
        // 优先级顺序：Admob > Yandex Banner > Yandex Int
        if adCenter.checkAdmobStatus() {
            debugPrint("[Ad-Background] ✅ 展示 Admob")
            adCenter.showAdmobIntFromRoot(moment: AdMoment.foreground)
            return true
        } else if adCenter.checkBannerStatus() {
            debugPrint("[Ad-Background] ✅ 展示 Yandex Banner")
            adCenter.showYanBannerFromRoot()
            return true
        } else if adCenter.checkIntStatus() {
            debugPrint("[Ad-Background] ✅ 展示 Yandex Int")
            adCenter.showYanIntFromRoot()
            return true
        }
        return false
    }
}
