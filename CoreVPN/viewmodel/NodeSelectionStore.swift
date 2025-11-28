//
//  NodeSelectionStore.swift
//  CoreVPN
//
//  Created by SHI QIU on 2025/11/27.
//

import Foundation

enum NodeType {
    case standard
    case gaming
    case streaming
}

struct VPNNodeItem: Identifiable {
    let id: Int
    let name: String
    let ping: Int
    let isVip: Bool
    let regionCode: String        // 地区代码，如 "SG", "JP", "US"
    let isRecommended: Bool       // 是否推荐节点
    let loadLevel: Int            // 负载等级 0-100
    let nodeType: NodeType        // 节点类型
}

/// 节点选择共享状态（目前节点全开放，后续可在此处做会员控制）
final class NodeSelectionStore: ObservableObject {
    /// 所有可用节点
    @Published var nodes: [VPNNodeItem]
    
    /// 是否记住上次选择的节点（决定是否持久化 selectedId），默认 true
    @Published var rememberLastNode: Bool = true {
        didSet {
            UserDefaults.standard.set(rememberLastNode, forKey: rememberKey)
        }
    }
    
    /// 当前选中的节点 ID（默认 0，会在 init 中根据配置覆盖）
    @Published var selectedId: Int = 0 {
        didSet {
            guard oldValue != selectedId else { return }
            if rememberLastNode {
                UserDefaults.standard.set(selectedId, forKey: selectedIdKey)
            }
        }
    }
    
    private let selectedIdKey = "NodeSelectedId"
    private let rememberKey   = "NodeRememberLast"
    
    init() {
        // 地区代码映射
        func regionCode(for name: String) -> String {
            let mapping: [String: String] = [
                "Auto": "🌐",
                "Singapore": "SG",
                "Japan": "JP",
                "United States": "US",
                "Germany": "DE",
                "United Kingdom": "UK",
                "Canada": "CA",
                "Australia": "AU",
                "Netherlands": "NL",
                "India": "IN"
            ]
            return mapping[name] ?? "🌐"
        }
        
        // 统一维护节点列表：名称只显示国家/地区，后续可在此处扩展真实节点与会员逻辑
        let rawNodes: [(id: Int, name: String, isVip: Bool)] = [
            // 默认智能节点（不展示 ping）
            (0, "Auto", false),
            // 常用地区节点（名称仅为国家/地区名）
            (1, "Singapore", false),
            (2, "Japan", true),
            (3, "United States", true),
            (4, "Germany", true),
            (5, "United Kingdom", true),
            (6, "Canada", false),
            (7, "Australia", false),
            (8, "Netherlands", true),
            (9, "India", false)
        ]
        
        // 为每个真实节点生成完整数据（先不标记推荐）
        var builtNodes: [VPNNodeItem] = rawNodes.map { raw in
            if raw.id == 0 {
                // Auto 节点特殊处理，固定标记为推荐
                return VPNNodeItem(
                    id: raw.id,
                    name: raw.name,
                    ping: 0,
                    isVip: raw.isVip,
                    regionCode: regionCode(for: raw.name),
                    isRecommended: true, // Auto 固定推荐
                    loadLevel: 0,
                    nodeType: .standard
                )
            } else {
                // 按比例生成延迟：60% 绿色、35% 橙色、5% 红色
                let randomPing: Int = {
                    let rand = Int.random(in: 1...100)
                    if rand <= 60 {
                        // 60% 绿色：35-59ms
                        return Int.random(in: 35...59)
                    } else if rand <= 95 {
                        // 35% 橙色：60-140ms
                        return Int.random(in: 60...140)
                    } else {
                        // 5% 红色：140-150ms
                        return Int.random(in: 140...150)
                    }
                }()
                // 负载等级：20-80 之间，避免极端值
                let loadLevel = Int.random(in: 20...80)
                // 节点类型：大部分 standard，少量 gaming/streaming
                let nodeType: NodeType = {
                    let rand = Int.random(in: 1...10)
                    if rand <= 7 {
                        return .standard
                    } else if rand <= 9 {
                        return .gaming
                    } else {
                        return .streaming
                    }
                }()
                
                return VPNNodeItem(
                    id: raw.id,
                    name: raw.name,
                    ping: randomPing,
                    isVip: raw.isVip,
                    regionCode: regionCode(for: raw.name),
                    isRecommended: false, // 先设为 false，后面根据延迟排序后再标记
                    loadLevel: loadLevel,
                    nodeType: nodeType
                )
            }
        }
        
        // 根据延迟排序，选择延迟最低的 2-3 个节点标记为推荐（排除 Auto）
        let recommendedCount = Int.random(in: 2...3)
        let sortedByPing = builtNodes
            .filter { $0.id != 0 }
            .sorted { $0.ping < $1.ping }
            .prefix(recommendedCount)
        
        let recommendedIds = Set(sortedByPing.map { $0.id })
        
        // 更新推荐状态
        builtNodes = builtNodes.map { node in
            if recommendedIds.contains(node.id) {
                return VPNNodeItem(
                    id: node.id,
                    name: node.name,
                    ping: node.ping,
                    isVip: node.isVip,
                    regionCode: node.regionCode,
                    isRecommended: true,
                    loadLevel: node.loadLevel,
                    nodeType: node.nodeType
                )
            } else {
                return node
            }
        }
        
        self.nodes = builtNodes
        
        // 从配置中恢复“是否记住节点”开关状态，默认 true
        let storedRemember = UserDefaults.standard.object(forKey: rememberKey) as? Bool
        let shouldRemember = storedRemember ?? true
        
        // 根据开关状态与已保存的 selectedId 决定初始节点
        let initialSelectedId: Int
        if shouldRemember,
           let saved = UserDefaults.standard.object(forKey: selectedIdKey) as? Int,
           builtNodes.contains(where: { $0.id == saved }) {
            initialSelectedId = saved
        } else {
            initialSelectedId = builtNodes.first?.id ?? 0
        }
        
        // 最后统一赋值给属性，避免在属性完全初始化前访问 self
        self.rememberLastNode = shouldRemember
        self.selectedId = initialSelectedId
    }
    
    var selectedNode: VPNNodeItem? {
        nodes.first(where: { $0.id == selectedId })
    }
}

