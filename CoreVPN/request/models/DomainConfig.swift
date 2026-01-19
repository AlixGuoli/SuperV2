//
//  DomainConfig.swift
//  CoreVPN
//
//  域名与上报配置模型（从 core.tun 或 git 解密得到）
//

import Foundation

struct DomainConfig: Codable {
    struct APISection: Codable {
        /// 业务接口域名列表，对应 JSON 的 api.host
        let hosts: [String]
        /// 更新配置用的 git 源列表，对应 JSON 的 api.git
        let gitSources: [String]
        /// 连接上报地址，对应 JSON 的 api.connreport
        let connectReportURL: String
        /// 通用上报地址，对应 JSON 的 api.greport
        let generalReportURL: String

        enum CodingKeys: String, CodingKey {
            case hosts = "host"
            case gitSources = "git"
            case connectReportURL = "connreport"
            case generalReportURL = "greport"
        }
    }

    let api: APISection
}


