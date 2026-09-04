import Foundation

struct TunnelConfigPackage {
    let text: String
    let firstServerAddress: String?
}

enum TunnelConfigPackageError: Error {
    case malformedResponse
    case unsupportedServerCount
    case malformedServer(Int)
}

final class CFGPipeline {
    static let shared = CFGPipeline()

    private let directHosts = [
        "mradx.net", "yandex.ru", "yandexadexchange.net", "ads.adfox.ru",
        "appmetrica.yandex.ru", "raw.githubusercontent.com", "vk.ru", "vk.me",
        "mail.ru", "vk.com", "target.my.com"
    ]

    private init() {}

    func makeTunnelPackage(from response: String) throws -> TunnelConfigPackage {
        guard let data = response.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data),
              var envelope = object as? [String: Any],
              var servers = envelope["res"] as? [[String: Any]] else {
            throw TunnelConfigPackageError.malformedResponse
        }
        guard (1...5).contains(servers.count) else {
            throw TunnelConfigPackageError.unsupportedServerCount
        }

        var firstAddress: String?
        for position in servers.indices {
            guard number(servers[position]["groupID"]) != nil,
                  let outerAddress = trimmed(servers[position]["address"] as? String),
                  let receivedConfig = servers[position]["conf"] as? [String: Any],
                  JSONSerialization.isValidJSONObject(receivedConfig) else {
                throw TunnelConfigPackageError.malformedServer(position)
            }
            if firstAddress == nil {
                firstAddress = proxyAddress(in: receivedConfig) ?? outerAddress
            }
            var usableConfig = receivedConfig
            setLocalSocksAddress(in: &usableConfig)
            mergeDirectRouting(into: &usableConfig)
            servers[position]["conf"] = usableConfig
        }

        envelope["res"] = servers
        guard JSONSerialization.isValidJSONObject(envelope),
              let finalData = try? JSONSerialization.data(
                withJSONObject: envelope,
                options: [.prettyPrinted, .sortedKeys]
              ),
              let finalText = String(data: finalData, encoding: .utf8) else {
            throw TunnelConfigPackageError.malformedResponse
        }
        return TunnelConfigPackage(text: finalText, firstServerAddress: firstAddress)
    }

    private func setLocalSocksAddress(in config: inout [String: Any]) {
        guard var inbounds = config["inbounds"] as? [[String: Any]],
              let socksPosition = inbounds.firstIndex(where: {
                  $0["tag"] as? String == "socks" || $0["protocol"] as? String == "socks"
              }) else { return }
        inbounds[socksPosition]["listen"] = "[::1]"
        inbounds[socksPosition]["port"] = "8080"
        config["inbounds"] = inbounds
    }

    private func mergeDirectRouting(into config: inout [String: Any]) {
        var routing = config["routing"] as? [String: Any] ?? [:]
        let runtimeHosts = reportHostRules()
        let ours = Set((directHosts + runtimeHosts).map { normalized($0) })
        let receivedRules = routing["rules"] as? [[String: Any]] ?? []
        var serverRules: [[String: Any]] = []

        for receivedRule in receivedRules {
            guard let domains = receivedRule["domain"] as? [String] else {
                serverRules.append(receivedRule)
                continue
            }
            if domains.contains(where: { normalized($0) == "geosite:category-ads-all" }) {
                continue
            }

            var rule = receivedRule
            if receivedRule["outboundTag"] as? String == "direct" {
                rule["domain"] = domains.filter { !ours.contains(normalized($0)) }
                if (rule["domain"] as? [String])?.isEmpty != false { continue }
            }
            serverRules.append(rule)
        }

        serverRules.append([
            "outboundTag": "direct",
            "type": "field",
            "domain": directHosts
        ])
        if !runtimeHosts.isEmpty {
            serverRules.append([
                "outboundTag": "direct",
                "domain": runtimeHosts
            ])
        }
        routing["rules"] = serverRules
        if routing["domainStrategy"] == nil { routing["domainStrategy"] = "AsIs" }
        config["routing"] = routing
    }

    private func reportHostRules() -> [String] {
        guard let api = DomainConfigStore.shared.loadActiveConfig()?.api else { return [] }
        let addresses = api.hosts + [api.connectReportURL, api.generalReportURL]
        var unique = Set<String>()
        return addresses.compactMap { address in
            guard let host = URL(string: address)?.host?.lowercased() else { return nil }
            let labels = host.split(separator: ".", omittingEmptySubsequences: true)
            guard labels.count >= 2 else { return nil }
            let value = "domain:" + labels.suffix(2).joined(separator: ".")
            return unique.insert(value).inserted ? value : nil
        }
    }

    private func proxyAddress(in config: [String: Any]) -> String? {
        guard let outbounds = config["outbounds"] as? [[String: Any]],
              let proxy = outbounds.first(where: { $0["tag"] as? String == "proxy" }),
              let settings = proxy["settings"] as? [String: Any] else { return nil }
        if let first = (settings["vnext"] as? [[String: Any]])?.first {
            return trimmed(first["address"] as? String)
        }
        return trimmed(settings["address"] as? String)
    }

    private func normalized(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private func number(_ value: Any?) -> Int? { (value as? NSNumber)?.intValue }

    private func trimmed(_ value: String?) -> String? {
        guard let value = value?.trimmingCharacters(in: .whitespacesAndNewlines),
              !value.isEmpty else { return nil }
        return value
    }
}
