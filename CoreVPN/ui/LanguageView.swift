//
//  LanguageView.swift
//  CoreVPN
//
//  Created by SHI QIU on 2025/11/27.
//

import SwiftUI

private struct AppLanguageOption: Identifiable {
    let id: String      // 语言代码，例如 "en", "ru"
    let name: String    // 展示名称
}

struct LanguageView: View {
    @EnvironmentObject private var appLanguage: AppLanguage
    @State private var isSwitching: Bool = false
    @State private var pendingCode: String?
    
    // 正式版语言选项（已移除中文，仅保留非中文语言）
    private let options: [AppLanguageOption] = [
        .init(id: "en",     name: "English"),
        .init(id: "ru",     name: "Русский"),
        .init(id: "es",     name: "Español"),
        .init(id: "de",     name: "Deutsch"),
        .init(id: "fr",     name: "Français"),
        .init(id: "ja",     name: "日本語"),
        .init(id: "ko",     name: "한국어"),
        .init(id: "tr",     name: "Türkçe")
    ]
    
    private var currentCode: String {
        let id = appLanguage.locale.identifier
        if id.hasPrefix("ru") { return "ru" }
        if id.hasPrefix("es") { return "es" }
        if id.hasPrefix("de") { return "de" }
        if id.hasPrefix("fr") { return "fr" }
        if id.hasPrefix("ja") { return "ja" }
        if id.hasPrefix("ko") { return "ko" }
        if id.hasPrefix("tr") { return "tr" }
        return "en"
    }
    
    var body: some View {
        ZStack {
            CoreVPNPlainBackgroundView()
            
            ScrollView {
                VStack(spacing: 12) {
                    ForEach(options) { option in
                        LanguageRow(
                            option: option,
                            isSelected: option.id == currentCode
                        )
                        .onTapGesture {
                            guard !isSwitching, option.id != currentCode else { return }
                            // 先显示一个轻量 loading，再稍微延迟切换语言，避免界面瞬间闪变
                            pendingCode = option.id
                            isSwitching = true
                            
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                                if let code = pendingCode {
                                    appLanguage.setLanguage(code: code)
                                }
                                // 再延迟一点点让用户看到 loading 过渡
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                    isSwitching = false
                                    pendingCode = nil
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
            }
            
            if isSwitching {
                Color.black.opacity(0.25)
                    .ignoresSafeArea()
                
                VStack(spacing: 8) {
                    ProgressView()
                        .tint(CoreVPNTheme.brandOrange)
                    Text("settings_language_loading")
                        .font(.caption)
                        .foregroundColor(CoreVPNTheme.textSecondary)
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(CoreVPNTheme.cardBackground)
                )
            }
        }
        .navigationTitle(Text("settings_language"))
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct LanguageRow: View {
    let option: AppLanguageOption
    let isSelected: Bool
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(option.name)
                    .font(.headline)
                    .foregroundColor(CoreVPNTheme.textPrimary)
                Text("settings_language_subtitle")
                    .font(.caption)
                    .foregroundColor(CoreVPNTheme.textSecondary)
            }
            Spacer()
            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(CoreVPNTheme.brandOrange)
                    .font(.system(size: 18, weight: .semibold))
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(CoreVPNTheme.cardBackground)
        )
    }
}


