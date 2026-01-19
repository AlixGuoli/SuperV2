//
//  ShareAppCard.swift
//  CoreVPN
//
//  分享 App 卡片组件
//

import SwiftUI

struct ShareAppCard: View {
    @State private var showShareSheet = false
    
    private let appStoreURL = URL(string: "https://apps.apple.com/app/id6755873784")!
    
    var body: some View {
        Button(action: showShare) {
            HStack(spacing: 16) {
                // 分享图标
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    CoreVPNTheme.brandOrange,
                                    CoreVPNTheme.brandOrangeSoft
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 48, height: 48)
                    
                    Image(systemName: "square.and.arrow.up.fill")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundColor(.white)
                }
                
                // 文本内容
                VStack(alignment: .leading, spacing: 4) {
                    Text("result_share_title")
                        .font(.headline)
                        .foregroundColor(CoreVPNTheme.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                        .lineLimit(2)
                    Text("result_share_subtitle")
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
        .sheet(isPresented: $showShareSheet) {
            ShareSheet(activityItems: [appStoreURL])
        }
    }
    
    private func showShare() {
        showShareSheet = true
    }
}

// 分享 Sheet 包装器
struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(
            activityItems: activityItems,
            applicationActivities: nil
        )
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

