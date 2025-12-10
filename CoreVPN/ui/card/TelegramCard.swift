//
//  TelegramCard.swift
//  CoreVPN
//
//  Telegram 卡片组件
//

import SwiftUI

struct TelegramCard: View {
    private let telegramURL: URL
    
    init() {
        /// 测试服
        let link = ""
        //let link = AppConfigStore.shared.telegramLink()
        self.telegramURL = URL(string: link) ?? URL(string: "https://t.me/+B47jOSvMu0I4MmY9")!
    }
    
    var body: some View {
        Button(action: openTelegram) {
            HStack(spacing: 16) {
                // Telegram 图标
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.2, green: 0.6, blue: 0.9),
                                    Color(red: 0.1, green: 0.5, blue: 0.8)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 48, height: 48)
                    
                    Image(systemName: "paperplane.fill")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundColor(.white)
                }
                
                // 文本内容
                VStack(alignment: .leading, spacing: 4) {
                    Text("result_telegram_title")
                        .font(.headline)
                        .foregroundColor(CoreVPNTheme.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                        .lineLimit(2)
                    Text("result_telegram_subtitle")
                        .font(.subheadline)
                        .foregroundColor(CoreVPNTheme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .lineLimit(2)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                Spacer(minLength: 8)
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(CoreVPNTheme.textSecondary)
            }
            .padding(16)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(CoreVPNTheme.cardBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(CoreVPNTheme.brandOrange.opacity(0.15), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
    
    private func openTelegram() {
        UIApplication.shared.open(telegramURL, options: [:], completionHandler: nil)
    }
}

