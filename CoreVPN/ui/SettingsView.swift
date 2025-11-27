import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var appLanguage: AppLanguage
    @EnvironmentObject private var nodeStore: NodeSelectionStore
    
    var body: some View {
        NavigationView {
            ZStack {
                CoreVPNTheme.background.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 16) {
                        generalCard
                        aboutCard
                        legalCard
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                }
            }
            .navigationTitle(Text("tab_settings"))
            .navigationBarTitleDisplayMode(.inline)
            .id(appLanguage.locale.identifier)
        }
    }
    
    // MARK: - Cards
    
    private var generalCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("settings_section_general")
                .font(.caption)
                .foregroundColor(CoreVPNTheme.textSecondary)
            
            NavigationLink {
                LanguageView()
            } label: {
                SettingsRow(
                    titleKey: "settings_language",
                    subtitleKey: "settings_language_subtitle",
                    trailing: {
                        HStack(spacing: 6) {
                            Text(currentLanguageName)
                                .font(.subheadline)
                                .foregroundColor(CoreVPNTheme.textSecondary)
                            Image(systemName: "chevron.right")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(CoreVPNTheme.textSecondary)
                        }
                    }
                )
            }
            .buttonStyle(.plain)
            
            Divider()
                .overlay(CoreVPNTheme.cardBackground)
            
            SettingsRow(
                titleKey: "settings_remember_last_node",
                subtitleKey: nil,
                trailing: {
                    Toggle("", isOn: $nodeStore.rememberLastNode)
                        .labelsHidden()
                        .toggleStyle(SwitchToggleStyle(tint: CoreVPNTheme.brandOrange))
                }
            )
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(CoreVPNTheme.cardBackground)
        )
    }
    
    private var aboutCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("settings_section_about")
                .font(.caption)
                .foregroundColor(CoreVPNTheme.textSecondary)
            
            VStack(alignment: .leading, spacing: 4) {
                Text("CoreVPN")
                    .font(.headline)
                    .foregroundColor(CoreVPNTheme.textPrimary)
                Text("Secure VPN connection for everyday use.")
                    .font(.caption)
                    .foregroundColor(CoreVPNTheme.textSecondary)
            }
            
            Divider()
                .overlay(CoreVPNTheme.cardBackground)
            
            HStack {
                Text("settings_version")
                    .foregroundColor(CoreVPNTheme.textPrimary)
                Spacer()
                Text("1.0.0")
                    .foregroundColor(CoreVPNTheme.textSecondary)
            }
            .font(.subheadline)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(CoreVPNTheme.cardBackground)
        )
    }
    
    private var legalCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("settings_section_legal")
                .font(.caption)
                .foregroundColor(CoreVPNTheme.textSecondary)
            
            Button {
                // TODO: open privacy policy
            } label: {
                SettingsRow(
                    titleKey: "settings_privacy_policy",
                    subtitleKey: nil,
                    trailing: {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(CoreVPNTheme.textSecondary)
                    }
                )
            }
            .buttonStyle(.plain)
            
            Divider()
                .overlay(CoreVPNTheme.cardBackground)
            
            Button {
                // TODO: open terms of service
            } label: {
                SettingsRow(
                    titleKey: "settings_terms_of_service",
                    subtitleKey: nil,
                    trailing: {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(CoreVPNTheme.textSecondary)
                    }
                )
            }
            .buttonStyle(.plain)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(CoreVPNTheme.cardBackground)
        )
    }
    
    // MARK: - Helpers
    
    private var currentLanguageName: String {
        let id = appLanguage.locale.identifier
        if id.hasPrefix("zh") {
            return "简体中文"
        }
        return "English"
    }
}

private struct SettingsRow<Trailing: View>: View {
    let titleKey: String
    let subtitleKey: String?
    @ViewBuilder let trailing: () -> Trailing
    
    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(LocalizedStringKey(titleKey))
                    .font(.subheadline)
                    .foregroundColor(CoreVPNTheme.textPrimary)
                if let subtitleKey = subtitleKey {
                    Text(LocalizedStringKey(subtitleKey))
                        .font(.caption)
                        .foregroundColor(CoreVPNTheme.textSecondary)
                }
            }
            Spacer()
            trailing()
        }
        .padding(.vertical, 4)
    }
}
