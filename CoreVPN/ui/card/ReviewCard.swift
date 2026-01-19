//
//  ReviewCard.swift
//  CoreVPN
//
//  评价引导卡片（连接页 / 结果页复用）
//

import SwiftUI

struct ReviewCard: View {
    private let title = LocalizedStringKey("ReviewPrompt_Title")
    private let subtitle = LocalizedStringKey("ReviewPrompt_Body")
    private let reviewURL = URL(string: "https://apps.apple.com/app/id6755873784?action=write-review")!
    
    @State private var currentRating: Int = 4
    @State private var animateStars: Bool = false
    
    var body: some View {
        Button(action: openReview) {
            VStack(spacing: 16) {
                VStack(spacing: 8) {
                    Text(title)
                        .font(.headline)
                        .foregroundColor(CoreVPNTheme.textPrimary)
                        .multilineTextAlignment(.center)
                    Text(subtitle)
                        .font(.footnote)
                        .foregroundColor(CoreVPNTheme.textSecondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
                HStack(spacing: 14) {
                    ForEach(1...5, id: \.self) { idx in
                        Image(systemName: idx <= currentRating ? "star.fill" : "star")
                            .font(.system(size: 28, weight: .semibold))
                            .foregroundColor(CoreVPNTheme.brandOrange)
                            .scaleEffect(animateStars ? 1.0 : 0.3)
                            .opacity(animateStars ? 1.0 : 0.0)
                            .animation(
                                .spring(response: 0.5, dampingFraction: 0.6)
                                .delay(Double(idx - 1) * 0.1),
                                value: animateStars
                            )
                            .onTapGesture {
                                currentRating = idx
                                openReview()
                            }
                    }
                }
                .frame(maxWidth: .infinity)
            }
            .onAppear {
                animateStars = true
            }
            .padding(20)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                CoreVPNTheme.cardBackground.opacity(0.96),
                                CoreVPNTheme.cardBackground.opacity(0.9),
                                CoreVPNTheme.brandOrangeSoft.opacity(0.08)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(
                        AngularGradient(
                            gradient: Gradient(colors: [
                                CoreVPNTheme.brandOrange,
                                CoreVPNTheme.brandOrangeSoft,
                                CoreVPNTheme.brandOrange
                            ]),
                            center: .center
                        ),
                        lineWidth: 1.5
                    )
                    .shadow(color: CoreVPNTheme.brandOrange.opacity(0.6), radius: 12)
            )
        }
        .buttonStyle(.plain)
    }
    
    private func openReview() {
        UIApplication.shared.open(reviewURL, options: [:], completionHandler: nil)
    }
}

