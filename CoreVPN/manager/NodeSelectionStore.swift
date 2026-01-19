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
    let isPlaceholder: Bool       // 是否占位假节点（用于兜底展示）
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
    
    /// 当前选中的节点 ID（默认 -1: Auto，会在 init 中根据配置覆盖）
    @Published var selectedId: Int = -1 {
        didSet {
            guard oldValue != selectedId else { return }
            if rememberLastNode {
                UserDefaults.standard.set(selectedId, forKey: selectedIdKey)
            }
        }
    }
    
    private let selectedIdKey = "NodeSelectedId"
    private let rememberKey   = "NodeRememberLast"
    
    private var isFetching = false
    
    init() {
        // 先尝试加载缓存的真实节点
        if let cached = CategoryStore.shared.cachedCategories(), !cached.isEmpty {
            self.nodes = Self.buildNodes(from: cached)
        } else {
            // 兜底假节点
            self.nodes = Self.buildPlaceholderNodes()
        }
        
        // 从配置中恢复“是否记住节点”开关状态，默认 true
        let storedRemember = UserDefaults.standard.object(forKey: rememberKey) as? Bool
        let shouldRemember = storedRemember ?? true
        
        // 根据开关状态与已保存的 selectedId 决定初始节点
        let initialSelectedId: Int
        if shouldRemember,
           let saved = UserDefaults.standard.object(forKey: selectedIdKey) as? Int,
           nodes.contains(where: { $0.id == saved }) {
            initialSelectedId = saved
        } else {
            initialSelectedId = nodes.first?.id ?? -1
        }
        
        // 最后统一赋值给属性，避免在属性完全初始化前访问 self
        self.rememberLastNode = shouldRemember
        self.selectedId = initialSelectedId
    }
    
    var selectedNode: VPNNodeItem? {
        nodes.first(where: { $0.id == selectedId })
    }
    
    /// 返回服务请求使用的节点 ID（占位节点视作 Auto）
    var serviceGroupId: Int {
        if selectedNode?.isPlaceholder == true {
            return -1
        }
        return selectedId
    }
    
    /// 刷新真实节点列表（有缓存先展示，成功后更新）
    func refreshCategories() {
        guard !isFetching else { return }
        isFetching = true
        CategoryService.shared.fetchCategories { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.isFetching = false
                switch result {
                case .success(let categories):
                    CategoryStore.shared.saveCategories(categories)
                    self.applyCategories(categories)
                case .failure:
                    break
                }
            }
        }
    }
    
    // MARK: - Private helpers
    
    private func applyCategories(_ categories: [CategoryGroup]) {
        let newNodes = Self.buildNodes(from: categories)
        let oldSelected = selectedId
        self.nodes = newNodes
        // 如果新列表里找不到旧选中，则回退到 Auto(-1)
        if newNodes.contains(where: { $0.id == oldSelected }) {
            self.selectedId = oldSelected
        } else {
            self.selectedId = -1
        }
    }
    
    private static func buildNodes(from categories: [CategoryGroup]) -> [VPNNodeItem] {
        var results: [VPNNodeItem] = []
        // Auto 节点固定在最前
        results.append(
            VPNNodeItem(
                id: -1,
                name: "Auto",
                ping: 0,
                isVip: false,
                regionCode: "🌐",
                isRecommended: true,
                loadLevel: 0,
                nodeType: .standard,
                isPlaceholder: false
            )
        )
        
        var addedIds = Set<Int>()
        for group in categories {
            for node in group.nodes {
                guard !addedIds.contains(node.id) else { continue }
                addedIds.insert(node.id)
                let regionCode = node.country.isEmpty ? "🌐" : node.country
                let randomPing: Int = {
                    let rand = Int.random(in: 1...100)
                    if rand <= 60 {
                        return Int.random(in: 35...59)
                    } else if rand <= 95 {
                        return Int.random(in: 60...140)
                    } else {
                        return Int.random(in: 140...150)
                    }
                }()
                let loadLevel = Int.random(in: 20...80)
                let item = VPNNodeItem(
                    id: node.id,
                    name: node.name,
                    ping: randomPing,
                    isVip: false,
                    regionCode: regionCode,
                    isRecommended: false,
                    loadLevel: loadLevel,
                    nodeType: .standard,
                    isPlaceholder: false
                )
                results.append(item)
            }
        }
        return results
    }
    
    private static func buildPlaceholderNodes() -> [VPNNodeItem] {
        // 简化的假节点列表，供接口未拉到数据时展示
        let raw: [(Int, String, String)] = [
            (-1, "Auto", "🌐"),
            (-2, "Singapore", "SG"),
            (-3, "Japan", "JP"),
            (-4, "United States", "US"),
            (-5, "Germany", "DE"),
            (-6, "United Kingdom", "UK"),
            (-7, "Canada", "CA"),
            (-8, "Australia", "AU"),
            (-9, "Netherlands", "NL"),
            (-10, "India", "IN")
        ]
        return raw.map { (id, name, code) in
            let randomPing: Int = {
                let rand = Int.random(in: 1...100)
                if rand <= 60 {
                    return Int.random(in: 35...59)
                } else if rand <= 95 {
                    return Int.random(in: 60...140)
                } else {
                    return Int.random(in: 140...150)
                }
            }()
            let loadLevel = Int.random(in: 20...80)
            return VPNNodeItem(
                id: id,
                name: name,
                ping: id == -1 ? 0 : randomPing,
                isVip: false,
                regionCode: code,
                isRecommended: id == -1,
                loadLevel: id == -1 ? 0 : loadLevel,
                nodeType: .standard,
                isPlaceholder: id != -1 // Auto 视为有效，其他为占位
            )
        }
    }
}

