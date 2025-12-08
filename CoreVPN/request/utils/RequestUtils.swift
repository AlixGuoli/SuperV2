//
//  RequestUtils.swift
//  CoreVPN
//
//  请求工具类
//

import Foundation

enum RequestUtils {
    /// 验证字符串是否是有效的 JSON
    static func validateJsonString(_ jsonString: String) -> Bool {
        guard let data = jsonString.data(using: .utf8) else {
            return false
        }
        do {
            _ = try JSONSerialization.jsonObject(with: data, options: [])
            return true
        } catch {
            return false
        }
    }
}

