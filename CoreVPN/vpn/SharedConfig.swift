//
//  SharedConfig.swift
//  CoreVPN
//
//  Created by SHI QIU on 2025/12/8.
//

import Foundation

class SharedConfig {
    
    public static let storageGroup = "group.com.vpn.kernel.core.hex"
    
    public static let dataKey = "configData"
    
    public static let timeKey = "lastSyncTime"
    
    public static let syncKey = "syncToken"
    
    public static let backupKey = "backupData"

    public static let batchDataKey = "batchConfigData.v2"
    public static let probeURLKey = "batchProbeURL.v2"
    public static let sourceKey = "batchConfigSource.v2"
    public static let reportKey = "batchProbeReport.v2"
    public static let reportContextKey = "batchReportContext.v2"
    public static let extensionLogKey = "batchExtensionLog.v2"
    
}

struct ConnectionReportSeed: Codable {
    let endpoint: String
    let uid: String
    let country: String
    let language: String
    let packageName: String
    let version: String
    let sessionID: String
    let usesCache: Bool
}
