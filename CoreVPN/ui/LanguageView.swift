//
//  LanguageView.swift
//  CoreVPN
//
//  Created by SHI QIU on 2025/11/27.
//

import SwiftUI

private struct AppLanguageOption: Identifiable {
    let id: String      // 语言代码，例如 "en", "zh-Hans"
    let name: String    // 展示名称
}

struct LanguageView: View {
    @EnvironmentObject private var appLanguage: AppLanguage
    
    // 目前只放 EN / ZH，占位，后续你可以在这里加更多语言
    private let options: [AppLanguageOption] = [
        .init(id: "en", name: "English"),
        .init(id: "zh-Hans", name: "简体中文")
    ]
    
    private var currentCode: String {
        let id = appLanguage.locale.identifier
        if id.hasPrefix("zh") { return "zh-Hans" }
        return "en"
    }
    
    var body: some View {
        ZStack {
            CoreVPNTheme.background.ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 12) {
                    ForEach(options) { option in
                        LanguageRow(
                            option: option,
                            isSelected: option.id == currentCode
                        )
                        .onTapGesture {
                            appLanguage.setLanguage(code: option.id)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
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


