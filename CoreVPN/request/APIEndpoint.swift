//
//  APIEndpoint.swift
//  CoreVPN
//
//  通用接口描述与基础参数
//

import Foundation

struct APIEndpoint {
    /// 例如："/graphql/query/config"、"/graphql/query/ads" 等
    let path: String

    /// 额外业务参数（会在通用参数之上 merge）
    let extraParams: [String: Any]

    enum Method {
        case get
        case post
    }

    let method: Method

    init(path: String,
         method: Method = .get,
         extraParams: [String: Any] = [:]) {
        self.path = path
        self.method = method
        self.extraParams = extraParams
    }
}

struct CommonRequestContext {
    let uid: String
    let country: String
    let language: String
    let pk: String
    let version: String
}


