//
//  CategoryStore.swift
//  CoreVPN
//
//  节点列表缓存（内存 + UserDefaults）
//

import Foundation

final class CategoryStore {
    static let shared = CategoryStore()
    private init() {}
    
    private struct Keys {
        static let cachedCategories = "CategoryStore.CachedCategories"
    }
    
    private var memoryCache: [CategoryGroup]?
    
    /// 读取缓存的节点分类（内存优先，退回 UserDefaults）
    func cachedCategories() -> [CategoryGroup]? {
        if let memoryCache {
            return memoryCache
        }
        guard
            let data = UserDefaults.standard.data(forKey: Keys.cachedCategories),
            let decoded = try? JSONDecoder().decode([CategoryGroup].self, from: data)
        else {
            return nil
        }
        memoryCache = decoded
        return decoded
    }
    
    /// 保存节点分类到内存与 UserDefaults
    func saveCategories(_ categories: [CategoryGroup]) {
        memoryCache = categories
        if let data = try? JSONEncoder().encode(categories) {
            UserDefaults.standard.set(data, forKey: Keys.cachedCategories)
            UserDefaults.standard.synchronize()
        }
    }
}

