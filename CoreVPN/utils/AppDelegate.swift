//
//  AppDelegate.swift
//  CoreVPN
//
//  Created by SHI QIU on 2025/11/26.
//

import UIKit
import YandexMobileAds

class AppDelegate: NSObject, UIApplicationDelegate {
    
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil
    ) -> Bool {
        // 初始化语言
        _ = AppLanguage()
        
        pushYandex()
        pushGameAnalytics()
        return true
    }
    
    func pushYandex() {
        MobileAds.initializeSDK {
            debugPrint("[Init] Yandex 初始化成功")
        }
    }
    
    func pushGameAnalytics() {
        let gameKey = "964444f7e096a92a0029fe014f0fbe56"
        let secretKey = "c60786c57eb1934da67f5033bc3152241d27277a"
        
        #if DEBUG
        debugPrint("[Init] 初始化 GameAnalytics")
        #endif
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
       
        #if DEBUG
        GameAnalytics.setEnabledInfoLog(true)
        GameAnalytics.setEnabledVerboseLog(true)
        #else
        GameAnalytics.setEnabledInfoLog(false)
        GameAnalytics.setEnabledVerboseLog(false)
        #endif
        GameAnalytics.configureAutoDetectAppVersion(true)
        GameAnalytics.configureBuild(version)
        GameAnalytics.initialize(withGameKey: gameKey, gameSecret: secretKey)
    }
}
