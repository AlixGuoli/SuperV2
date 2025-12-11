import SwiftUI

struct PrivacyConsentView: View {
    let onAccept: () -> Void
    let onDecline: () -> Void
    
    @Environment(\.openURL) private var openURL
    
    private let privacyPolicyURL = URL(string: "https://superv2raytunnel.xyz/p.html")!
    
    var body: some View {
        ZStack {
            CoreVPNPlainBackgroundView()
            
            VStack(spacing: 16) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("privacy_consent_title")
                            .font(.title3.bold())
                            .foregroundColor(CoreVPNTheme.textPrimary)
                            .padding(.top, 8)
                        
                        Text("privacy_consent_preamble")
                            .font(.subheadline)
                            .foregroundColor(CoreVPNTheme.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                        
                        Group {
                            section(titleKey: "privacy_consent_info_title",
                                    bodyKey: "privacy_consent_info_body")
                            section(titleKey: "privacy_consent_records_title",
                                    bodyKey: "privacy_consent_records_body")
                            section(titleKey: "privacy_consent_duration_title",
                                    bodyKey: "privacy_consent_duration_body")
                            section(titleKey: "privacy_consent_ads_title",
                                    bodyKey: "privacy_consent_ads_body")
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("privacy_consent_footer")
                                .font(.caption)
                                .foregroundColor(CoreVPNTheme.textSecondary)
                            
                            Button {
                                openURL(privacyPolicyURL)
                            } label: {
                                Text("privacy_consent_policy_link")
                                    .font(.caption.bold())
                                    .foregroundColor(CoreVPNTheme.brandOrange)
                            }
                        }
                        .padding(.top, 4)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 44)
                }
                
                VStack(spacing: 8) {
                    Text("privacy_consent_agree_statement")
                        .font(.caption)
                        .foregroundColor(CoreVPNTheme.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                    
                    Button(action: onAccept) {
                        Text("privacy_consent_button_accept")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .fill(CoreVPNTheme.brandOrange)
                            )
                    }
                    
                    Button(action: onDecline) {
                        Text("privacy_consent_button_decline")
                            .font(.subheadline)
                            .foregroundColor(CoreVPNTheme.textSecondary)
                            .padding(.vertical, 8)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
            }
        }
    }
    
    private func section(titleKey: String, bodyKey: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(LocalizedStringKey(titleKey))
                .font(.subheadline.bold())
                .foregroundColor(CoreVPNTheme.textPrimary)
            Text(LocalizedStringKey(bodyKey))
                .font(.caption)
                .foregroundColor(CoreVPNTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}


