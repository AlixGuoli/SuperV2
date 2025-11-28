import SwiftUI

struct NodeListView: View {
    @EnvironmentObject private var nodeStore: NodeSelectionStore
    
    var body: some View {
        ZStack {
            CoreVPNPlainBackgroundView()
            
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

/// 节点卡片样式
private struct NodeCardView: View {
    let node: VPNNodeItem
    let isSelected: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // 顶部：节点名称 + 选中状态
            HStack(spacing: 8) {
                Text(node.name)
                    .font(.headline)
                    .foregroundColor(CoreVPNTheme.textPrimary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(CoreVPNTheme.brandOrange)
                        .font(.system(size: 18, weight: .semibold))
                }
            }
            
            // 中部：标签行（地区代码 / 推荐）
            HStack(spacing: 6) {
                // 地区代码标签
                Text(node.regionCode)
                    .font(.caption2.bold())
                    .foregroundColor(CoreVPNTheme.brandOrange)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(
                        Capsule().fill(CoreVPNTheme.brandOrange.opacity(0.15))
                    )
                
                // 推荐标签（Auto 固定显示，其他节点根据 isRecommended）
                if node.id == 0 || node.isRecommended {
                    Text("nodes_recommended")
                        .font(.caption2.bold())
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(
                            Capsule().fill(CoreVPNTheme.successGreen.opacity(0.15))
                        )
                        .foregroundColor(CoreVPNTheme.successGreen)
                }
            }
            
            // 底部：延迟 + 负载指示器
            HStack(spacing: 12) {
                if node.ping > 0 {
                    // 延迟信息
                    HStack(spacing: 4) {
                        Circle()
                            .fill(colorForPing(node.ping))
                            .frame(width: 6, height: 6)
                        Text("\(node.ping) ms")
                            .font(.caption)
                            .foregroundColor(CoreVPNTheme.textSecondary)
                    }
                }
                
                if node.id != 0 {
                    // 负载指示器
                    HStack(spacing: 4) {
                        Text("nodes_load")
                            .font(.caption)
                            .foregroundColor(CoreVPNTheme.textSecondary)
                        Text("\(node.loadLevel)%")
                            .font(.caption.monospacedDigit())
                            .foregroundColor(colorForLoad(node.loadLevel))
                    }
                }
            }
        }
        .padding(14)
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
    
    /// 根据负载等级返回颜色：绿（低负载）/ 黄（中负载）/ 红（高负载）
    private func colorForLoad(_ load: Int) -> Color {
        switch load {
        case ..<30:
            return CoreVPNTheme.successGreen
        case 30..<70:
            return CoreVPNTheme.brandOrange
        default:
            return Color.red.opacity(0.8)
        }
    }
}

