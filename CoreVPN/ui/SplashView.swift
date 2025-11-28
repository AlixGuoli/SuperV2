import SwiftUI

struct SplashView: View {
    let onFinish: () -> Void
    
    @State private var progress: Double = 0
    
    var body: some View {
        ZStack {
            CoreVPNBackgroundView()
            
            VStack(spacing: 32) {
                Spacer()
                
                VStack(spacing: 12) {
                    Image("logo")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 88, height: 88)
                        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                        .shadow(color: Color.black.opacity(0.6), radius: 12, x: 0, y: 8)
                    
                    Text("splash_title")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(CoreVPNTheme.textPrimary)
                    Text("splash_subtitle")
                        .font(.subheadline)
                        .foregroundColor(CoreVPNTheme.textSecondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, 32)
                }
                
                Spacer()
                
                VStack(spacing: 8) {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 999)
                                .fill(CoreVPNTheme.cardBackground.opacity(0.9))
                            RoundedRectangle(cornerRadius: 999)
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            CoreVPNTheme.brandOrange,
                                            CoreVPNTheme.brandOrangeSoft
                                        ],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(width: geo.size.width * progress)
                        }
                    }
                    .frame(height: 6)
                    
                    Text("splash_loading")
                        .font(.caption2)
                        .foregroundColor(CoreVPNTheme.textSecondary)
                }
                .padding(.horizontal, 40)
                .padding(.bottom, 40)
            }
        }
        .onAppear {
            NetworkStatusChecker.shared.checkOnLaunch()
            withAnimation(.linear(duration: 3.0)) {
                progress = 1.0
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                onFinish()
            }
        }
    }
}


