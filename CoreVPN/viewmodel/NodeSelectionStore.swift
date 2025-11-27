//
//  NodeSelectionStore.swift
//  CoreVPN
//
//  Created by SHI QIU on 2025/11/27.
//

import Foundation

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
        // 统一维护节点列表：名称只显示国家/地区，后续可在此处扩展真实节点与会员逻辑
        let rawNodes: [VPNNodeItem] = [
            // 默认智能节点（不展示 ping）
            .init(id: 0, name: "Auto", ping: 0, isVip: false),
            // 常用地区节点（名称仅为国家/地区名）
            .init(id: 1, name: "Singapore", ping: 0, isVip: false),
            .init(id: 2, name: "Japan", ping: 0, isVip: true),
            .init(id: 3, name: "United States", ping: 0, isVip: true),
            .init(id: 4, name: "Hong Kong", ping: 0, isVip: false),
            .init(id: 5, name: "Taiwan", ping: 0, isVip: false),
            .init(id: 6, name: "Germany", ping: 0, isVip: true),
            .init(id: 7, name: "United Kingdom", ping: 0, isVip: true),
            .init(id: 8, name: "Canada", ping: 0, isVip: false),
            .init(id: 9, name: "Australia", ping: 0, isVip: false),
            .init(id: 10, name: "Netherlands", ping: 0, isVip: true),
            .init(id: 11, name: "India", ping: 0, isVip: false)
        ]
        
        // 为每个真实节点随机生成一个合理的 ping，避免看起来过于固定
        let builtNodes: [VPNNodeItem] = rawNodes.map { node in
            if node.id == 0 {
                return node
            } else {
                // 大部分用户的公网延迟通常落在几十到两百多毫秒之间
                let randomPing = Int.random(in: 30...220)
                return VPNNodeItem(id: node.id, name: node.name, ping: randomPing, isVip: node.isVip)
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

