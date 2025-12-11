//
//  CategoryResponse.swift
//  CoreVPN
//
//  节点分类接口返回数据模型
//

import Foundation

struct CategoryResponse: Codable {
    let categories: [CategoryGroup]
}

struct CategoryGroup: Codable {
    let name: String
    let nodes: [CategoryNode]
}

struct CategoryNode: Codable {
    let id: Int
    let name: String
    let country: String
}

