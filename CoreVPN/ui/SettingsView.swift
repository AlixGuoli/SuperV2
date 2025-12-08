import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var appLanguage: AppLanguage
    @EnvironmentObject private var nodeStore: NodeSelectionStore
    @Environment(\.openURL) private var openURL
    
    var body: some View {
        NavigationView {
            ZStack {
                CoreVPNPlainBackgroundView()
                
                ScrollView {
                    VStack(spacing: 16) {
                        generalCard
                        helpCard
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
                    iconSystemName: "globe",
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
                iconSystemName: "location.circle",
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
            
            NavigationLink {
                AboutView()
            } label: {
                SettingsRow(
                    titleKey: "settings_about_entry",
                    subtitleKey: "settings_about_description",
                    iconSystemName: "info.circle",
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
    
    private var helpCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("settings_section_help")
                .font(.caption)
                .foregroundColor(CoreVPNTheme.textSecondary)
            
            NavigationLink {
                HelpView()
            } label: {
                SettingsRow(
                    titleKey: "settings_help_center",
                    subtitleKey: nil,
                    iconSystemName: "questionmark.circle",
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
    
    private var legalCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("settings_section_legal")
                .font(.caption)
                .foregroundColor(CoreVPNTheme.textSecondary)
            
            Button {
                if let url = URL(string: "https://superv2raytunnel.xyz/p.html") {
                    openURL(url)
                }
            } label: {
                SettingsRow(
                    titleKey: "settings_privacy_policy",
                    subtitleKey: nil,
                    iconSystemName: "lock.shield",
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
                if let url = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/") {
                    openURL(url)
                }
            } label: {
                SettingsRow(
                    titleKey: "settings_terms_of_service",
                    subtitleKey: nil,
                    iconSystemName: "doc.text",
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
        if id.hasPrefix("ru") { return "Русский" }
        if id.hasPrefix("es") { return "Español" }
        if id.hasPrefix("de") { return "Deutsch" }
        if id.hasPrefix("fr") { return "Français" }
        if id.hasPrefix("ja") { return "日本語" }
        if id.hasPrefix("ko") { return "한국어" }
        if id.hasPrefix("tr") { return "Türkçe" }
        return "English"
    }
}

private struct SettingsRow<Trailing: View>: View {
    let titleKey: String
    let subtitleKey: String?
    let iconSystemName: String?
    @ViewBuilder let trailing: () -> Trailing
    
    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            HStack(spacing: 10) {
                if let icon = iconSystemName {
                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(CoreVPNTheme.brandOrange)
                        .frame(width: 20, height: 20)
                }
                
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
            }
            Spacer()
            trailing()
        }
        .padding(.vertical, 10)
        .contentShape(Rectangle())
    }
}
