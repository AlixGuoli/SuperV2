//
//  APIEndpoint.swift
//  CoreVPN
//
//  通用接口描述与基础参数
//

import Foundation

struct APIEndpoint {
    static let serviceBatchPath = "/poplar/service/batch"

    /// 例如："/poplar/config/cambium"、"/poplar/ads/shade" 等
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

    /// Poplar 业务接口和上报统一使用带新库标识的包名。
    var apiPackageName: String {
        "fp133.\(pk)"
    }
}
