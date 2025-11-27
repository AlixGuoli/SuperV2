//
//  CoreVPNApp.swift
//  CoreVPN
//
//  Created by SHI QIU on 2025/11/26.
//

import SwiftUI

@main
struct CoreVPNApp: App {
    @StateObject private var appLanguage = AppLanguage()
    @StateObject private var nodeStore = NodeSelectionStore()
    @StateObject private var tabSelection = TabSelection()
    
    var body: some Scene {
        WindowGroup {
            RootTabView()
                .environmentObject(appLanguage)
                .environmentObject(nodeStore)
                .environmentObject(tabSelection)
                .environment(\.locale, appLanguage.locale)
        }
    }
}
