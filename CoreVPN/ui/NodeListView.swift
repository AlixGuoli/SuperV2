import SwiftUI

struct NodeListView: View {
    @EnvironmentObject private var nodeStore: NodeSelectionStore
    
    var body: some View {
        ZStack {
            CoreVPNTheme.background.ignoresSafeArea()
            
            VStack(alignment: .leading, spacing: 16) {
                Text("nodes_title")
                    .font(.title2.bold())
                    .foregroundColor(CoreVPNTheme.textPrimary)
                    .padding(.top, 8)
                
                ScrollView {
                    let columns = [
                        GridItem(.flexible(), spacing: 12),
                        GridItem(.flexible(), spacing: 12)
                    ]
                    
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(nodeStore.nodes) { node in
                            NodeCardView(
                                node: node,
                                isSelected: node.id == nodeStore.selectedId
                            )
                            .onTapGesture {
                                nodeStore.selectedId = node.id
                            }
                        }
                    }
                    .padding(.vertical, 8)
                }
            }
            .padding(.horizontal, 16)
        }
    }
}

struct VPNNodeItem: Identifiable {
    let id: Int
    let name: String
    let ping: Int
    let isVip: Bool
}

/// 节点卡片样式
private struct NodeCardView: View {
    let node: VPNNodeItem
    let isSelected: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(node.name)
                    .font(.headline)
                    .foregroundColor(CoreVPNTheme.textPrimary)
                    .lineLimit(1)
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(CoreVPNTheme.brandOrange)
                        .font(.system(size: 16, weight: .semibold))
                }
            }
            
            HStack(spacing: 6) {
                if node.id == 0 {
                    // 默认自动节点标签
                    Text("AUTO")
                        .font(.caption2.bold())
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            Capsule().fill(CoreVPNTheme.brandOrange.opacity(0.15))
                        )
                        .foregroundColor(CoreVPNTheme.brandOrange)
                }
                
                if node.ping > 0 {
                    // 用颜色点+ping值表现线路质量
                    Circle()
                        .fill(colorForPing(node.ping))
                        .frame(width: 6, height: 6)
                    Text("\(node.ping) ms")
                        .font(.caption2)
                        .foregroundColor(CoreVPNTheme.textSecondary)
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(CoreVPNTheme.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(
                            isSelected ? CoreVPNTheme.brandOrange : Color.clear,
                            lineWidth: 1.5
                        )
                )
        )
    }
    
    /// 根据 ping 粗略映射线路质量：绿 / 黄 / 红
    private func colorForPing(_ ping: Int) -> Color {
        switch ping {
        case ..<60:
            return CoreVPNTheme.successGreen
        case 60..<140:
            return CoreVPNTheme.brandOrange
        default:
            return Color.red.opacity(0.8)
        }
    }
}

