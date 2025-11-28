import SwiftUI

struct HelpView: View {
    var body: some View {
        ZStack {
            CoreVPNPlainBackgroundView()
            
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    FAQItem(titleKey: "help_q1_title", bodyKey: "help_q1_body")
                    FAQItem(titleKey: "help_q2_title", bodyKey: "help_q2_body")
                    FAQItem(titleKey: "help_q3_title", bodyKey: "help_q3_body")
                    FAQItem(titleKey: "help_q4_title", bodyKey: "help_q4_body")
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
        }
        .navigationTitle(Text("help_title"))
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct FAQItem: View {
    let titleKey: String
    let bodyKey: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(LocalizedStringKey(titleKey))
                .font(.headline.bold())
                .foregroundColor(CoreVPNTheme.textPrimary)
            Text(LocalizedStringKey(bodyKey))
                .font(.subheadline)
                .foregroundColor(CoreVPNTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(CoreVPNTheme.cardBackground)
        )
    }
}
