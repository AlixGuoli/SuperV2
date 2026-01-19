import SwiftUI
import UIKit

struct AboutView: View {
    @Environment(\.openURL) private var openURL
    
    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "v\(version) (\(build))"
    }
    
    private let websiteURL = URL(string: "https://superv2raytunnel.xyz")!
    
    var body: some View {
        ZStack {
            CoreVPNPlainBackgroundView()
            
            ScrollView {
                VStack(spacing: 20) {
                    VStack(spacing: 12) {
                        Image("logo")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 96, height: 96)
                            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                            .shadow(color: Color.black.opacity(0.6), radius: 12, x: 0, y: 8)
                        
                        Text("about_tagline")
                            .font(.body)
                            .foregroundColor(CoreVPNTheme.textSecondary)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.horizontal, 24)
                    }
                    .padding(.top, 16)
                    
                    VStack(alignment: .leading, spacing: 12) {
                        // 版本信息 item
                        HStack {
                            Text("about_version_prefix")
                                .font(.subheadline)
                                .foregroundColor(CoreVPNTheme.textSecondary)
                            Spacer()
                            Text(appVersion)
                                .foregroundColor(CoreVPNTheme.textPrimary)
                                .font(.body.monospacedDigit())
                        }
                        .padding(.vertical, 12)
                        .padding(.horizontal, 16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(CoreVPNTheme.cardBackground)
                        )
                        
                        // 总体描述 item
                        Text("about_made_by")
                            .font(.body)
                            .foregroundColor(CoreVPNTheme.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.vertical, 12)
                            .padding(.horizontal, 16)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .fill(CoreVPNTheme.cardBackground)
                            )
                        
                        // 特性 item：每条单独一行
                        HStack(spacing: 10) {
                            Image(systemName: "shield.lefthalf.filled")
                                .foregroundColor(CoreVPNTheme.brandOrange)
                            Text("about_feature_security")
                                .font(.subheadline)
                                .foregroundColor(CoreVPNTheme.textSecondary)
                        }
                        .padding(.vertical, 10)
                        .padding(.horizontal, 16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(CoreVPNTheme.cardBackground)
                        )
                        
                        HStack(spacing: 10) {
                            Image(systemName: "globe")
                                .foregroundColor(CoreVPNTheme.brandOrange)
                            Text("about_feature_nodes")
                                .font(.subheadline)
                                .foregroundColor(CoreVPNTheme.textSecondary)
                        }
                        .padding(.vertical, 10)
                        .padding(.horizontal, 16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(CoreVPNTheme.cardBackground)
                        )
                        
                        HStack(spacing: 10) {
                            Image(systemName: "speedometer")
                                .foregroundColor(CoreVPNTheme.brandOrange)
                            Text("about_feature_healthcheck")
                                .font(.subheadline)
                                .foregroundColor(CoreVPNTheme.textSecondary)
                        }
                        .padding(.vertical, 10)
                        .padding(.horizontal, 16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(CoreVPNTheme.cardBackground)
                        )
                        
                        // 官网 item：整行可点
                        Button {
                            openURL(websiteURL)
                        } label: {
                            HStack {
                                HStack(spacing: 10) {
                                    Image(systemName: "safari")
                                        .foregroundColor(CoreVPNTheme.brandOrange)
                                    Text("about_website_button")
                                        .font(.subheadline)
                                        .foregroundColor(CoreVPNTheme.textPrimary)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(CoreVPNTheme.textSecondary)
                            }
                            .padding(.vertical, 12)
                            .padding(.horizontal, 16)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(CoreVPNTheme.cardBackground)
                        )
                    }
                    .padding(.horizontal, 20)
                    
                    // UUID 显示
                    VStack(alignment: .leading, spacing: 8) {
                        Text("UID")
                            .font(.caption)
                            .foregroundColor(CoreVPNTheme.textSecondary)
                        Text(getRequestUID())
                            .font(.caption.monospacedDigit())
                            .foregroundColor(CoreVPNTheme.textPrimary)
                            .textSelection(.enabled)
                    }
                    .padding(.vertical, 12)
                    .padding(.horizontal, 16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(CoreVPNTheme.cardBackground)
                    )
                    .padding(.horizontal, 20)
                    .onLongPressGesture {
                        UIPasteboard.general.string = getRequestUID()
                    }
                    
                    Spacer(minLength: 20)
                }
            }
        }
        .navigationTitle(Text("about_title"))
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private func getRequestUID() -> String {
        return APIRequestExecutor.shared.commonContextProvider().uid
    }
}
