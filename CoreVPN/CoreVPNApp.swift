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
    @StateObject private var appLanguage = AppLanguage()
    @StateObject private var nodeStore = NodeSelectionStore()
    @StateObject private var tabSelection = TabSelection()

    @State private var showSplash = true
    @State private var showPrivacy = false

    private let privacyAcceptedKey = "CoreVPNPrivacyAccepted_v1"

    var body: some Scene {
        WindowGroup {
            Group {
                if showSplash {
                    SplashView {
                        showSplash = false
                        // 启动页结束后，如果还没同意隐私，就进隐私页
                        if !UserDefaults.standard.bool(forKey: privacyAcceptedKey) {
                            showPrivacy = true
                        }
                    }
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
                    RootTabView()
                }
            }
            .preferredColorScheme(.dark)
            .environmentObject(appLanguage)
            .environmentObject(nodeStore)
            .environmentObject(tabSelection)
            .environment(\.locale, appLanguage.locale)
        }
    }
}
