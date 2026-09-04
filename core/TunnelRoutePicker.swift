import Foundation
import os

struct RunningRoute { let position: Int; let group: Int; let serverAddress: String }

enum TunnelRouteFailure: LocalizedError {
    case staleInput, invalidProbeReply, stopped, exhausted
    var errorDescription: String? {
        switch self {
        case .staleInput: return "Tunnel route input is invalid or expired"
        case .invalidProbeReply: return "Core returned an invalid probe reply"
        case .stopped: return "Tunnel startup was stopped"
        case .exhausted: return "No server could start the tunnel"
        }
    }
}

final class TunnelRoutePicker {
    private struct Server {
        let position: Int, group: Int
        let outerAddress: String, coreAddress: String
        let corePort: Int?
        let config: String
    }

    private let connection: TConn
    private let isCurrent: () -> Bool

    init(connection: TConn, isCurrent: @escaping () -> Bool) {
        self.connection = connection
        self.isCurrent = isCurrent
    }

    func openFirstAvailableRoute() async throws -> RunningRoute {
        let input = try loadInput()
        let servers = try readServers(input.config)
        try ensureCurrent()
        TunnelRunRecords.note("pingBatch START count=\(servers.count) timeout=10 url=\(input.url)")
        for server in servers {
            let port = server.corePort.map(String.init) ?? "unknown"
            TunnelRunRecords.note(
                "ITEM index=\(server.position) groupID=\(server.group) " +
                "address=\(server.outerAddress) xray=\(server.coreAddress):\(port)"
            )
        }

        let probes: [[String: Any]]
        let probeStartedAt = Date()
        do {
            let configs = servers.map { ["xrayJson": probeConfig($0), "outboundTag": "proxy"] }
            let reply = try XrayCommandClient.execute(
                method: "pingBatch",
                payload: ["configs": configs, "url": input.url, "timeout": 10]
            )
            probes = (reply["data"] as? [String: Any])?["results"] as? [[String: Any]] ?? []
            TunnelRunRecords.note(
                "pingBatch END duration=\(milliseconds(since: probeStartedAt))ms resultCount=\(probes.count)"
            )
        } catch {
            TunnelRunRecords.note(
                "pingBatch FAILED duration=\(milliseconds(since: probeStartedAt))ms error=\(error.localizedDescription)"
            )
            let failed = servers.map { _ in ["success": false, "delay": -1, "error": error.localizedDescription] as [String: Any] }
            let task = sendReports(servers, failed)
            TunnelRunRecords.save(servers: reportRows(servers), probes: failed, route: nil, connected: false, error: error.localizedDescription)
            await task?.value
            throw error
        }

        guard probes.count == servers.count else {
            let aligned: [[String: Any]] = servers.indices.map { position in
                if position < probes.count { return probes[position] }
                return [
                    "success": false,
                    "delay": -1,
                    "error": TunnelRouteFailure.invalidProbeReply.localizedDescription
                ]
            }
            let task = sendReports(servers, aligned)
            TunnelRunRecords.save(servers: reportRows(servers), probes: aligned, route: nil, connected: false, error: TunnelRouteFailure.invalidProbeReply.localizedDescription)
            await task?.value
            throw TunnelRouteFailure.invalidProbeReply
        }

        let reportTask = sendReports(servers, probes)
        try ensureCurrent()
        for server in servers {
            let passed = probes[server.position]["success"] as? Bool == true
            let delay = (probes[server.position]["delay"] as? NSNumber)?.intValue ?? -1
            let error = probes[server.position]["error"] as? String ?? ""
            let port = server.corePort.map(String.init) ?? "unknown"
            TunnelRunRecords.note(
                "RESULT index=\(server.position) groupID=\(server.group) " +
                "xray=\(server.coreAddress):\(port) success=\(passed) delay=\(delay) error=\(error)"
            )
        }

        for server in servers {
            guard probes[server.position]["success"] as? Bool == true else { continue }
            try ensureCurrent()
            let port = server.corePort.map(String.init) ?? "unknown"
            TunnelRunRecords.note(
                "SELECT index=\(server.position) groupID=\(server.group) " +
                "xray=\(server.coreAddress):\(port)"
            )
            TunnelRunRecords.note("testXray")
            do {
                try connection.validateXray(server.config)
            }
            catch { TunnelRunRecords.note("testXray failed"); continue }
            try ensureCurrent()
            TunnelRunRecords.note("runXray")
            do {
                try connection.activateXray(server.config)
            }
            catch { TunnelRunRecords.note("runXray failed"); continue }
            guard isCurrent() else { connection.haltNet(); throw TunnelRouteFailure.stopped }
            let route = RunningRoute(position: server.position, group: server.group, serverAddress: server.coreAddress)
            TunnelRunRecords.save(servers: reportRows(servers), probes: probes, route: route, connected: false, error: "")
            return route
        }
        TunnelRunRecords.note("selection failed reason=no-available-server")
        TunnelRunRecords.save(servers: reportRows(servers), probes: probes, route: nil, connected: false, error: TunnelRouteFailure.exhausted.localizedDescription)
        await reportTask?.value
        throw TunnelRouteFailure.exhausted
    }

    private func ensureCurrent() throws { if !isCurrent() { throw TunnelRouteFailure.stopped } }

    private func milliseconds(since start: Date) -> Int {
        Int(Date().timeIntervalSince(start) * 1_000)
    }

    private func loadInput() throws -> (config: String, url: String) {
        guard let d = UserDefaults(suiteName: SharedConfig.storageGroup),
              let date = d.object(forKey: SharedConfig.timeKey) as? Date,
              (0...30).contains(Date().timeIntervalSince(date)),
              let config = d.string(forKey: SharedConfig.batchDataKey), !config.isEmpty,
              let probe = d.string(forKey: SharedConfig.probeURLKey),
              let url = URL(string: probe), ["http", "https"].contains(url.scheme?.lowercased() ?? ""),
              url.host?.isEmpty == false else { throw TunnelRouteFailure.staleInput }
        return (config, probe)
    }

    private func readServers(_ text: String) throws -> [Server] {
        guard let data = text.data(using: .utf8),
              let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let rows = root["res"] as? [[String: Any]], (1...5).contains(rows.count) else { throw TunnelRouteFailure.staleInput }
        return try rows.enumerated().map { position, row in
            guard let group = (row["groupID"] as? NSNumber)?.intValue,
                  let outer = clean(row["address"] as? String),
                  let object = row["conf"] as? [String: Any], JSONSerialization.isValidJSONObject(object),
                  let data = try? JSONSerialization.data(withJSONObject: object),
                  let config = String(data: data, encoding: .utf8) else { throw TunnelRouteFailure.staleInput }
            let endpoint = endpointOf(object)
            return Server(position: position, group: group, outerAddress: outer, coreAddress: endpoint?.0 ?? outer, corePort: endpoint?.1, config: config)
        }
    }

    private func probeConfig(_ server: Server) -> String {
        guard ProbeTestOptions.unreachableNodePositions.contains(server.position),
              let data = server.config.data(using: .utf8),
              var root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              var outbounds = root["outbounds"] as? [[String: Any]],
              let i = outbounds.firstIndex(where: { $0["tag"] as? String == "proxy" }),
              var settings = outbounds[i]["settings"] as? [String: Any] else { return server.config }
        if var vnext = settings["vnext"] as? [[String: Any]], !vnext.isEmpty { vnext[0]["port"] = 1; settings["vnext"] = vnext }
        else if settings["address"] != nil { settings["port"] = 1 }
        else { return server.config }
        outbounds[i]["settings"] = settings; root["outbounds"] = outbounds
        guard let changed = try? JSONSerialization.data(withJSONObject: root), let text = String(data: changed, encoding: .utf8) else { return server.config }
        TunnelRunRecords.note("test override enabled position=\(server.position) ip=\(server.coreAddress) probePort=1")
        return text
    }

    private func endpointOf(_ root: [String: Any]) -> (String, Int?)? {
        guard let outbounds = root["outbounds"] as? [[String: Any]], let proxy = outbounds.first(where: { $0["tag"] as? String == "proxy" }), let settings = proxy["settings"] as? [String: Any] else { return nil }
        if let first = (settings["vnext"] as? [[String: Any]])?.first, let address = clean(first["address"] as? String) { return (address, (first["port"] as? NSNumber)?.intValue) }
        guard let address = clean(settings["address"] as? String) else { return nil }
        return (address, (settings["port"] as? NSNumber)?.intValue)
    }

    private func clean(_ value: String?) -> String? { guard let v = value?.trimmingCharacters(in: .whitespacesAndNewlines), !v.isEmpty else { return nil }; return v }
    private func reportRows(_ values: [Server]) -> [[String: Any]] { values.map { ["index": $0.position, "groupID": $0.group, "address": $0.outerAddress, "xrayAddress": $0.coreAddress, "xrayPort": $0.corePort ?? -1] } }

    private func sendReports(_ servers: [Server], _ probes: [[String: Any]]) -> Task<Void, Never>? {
        guard let d = UserDefaults(suiteName: SharedConfig.storageGroup), let data = d.data(forKey: SharedConfig.reportContextKey), let context = try? JSONDecoder().decode(ConnectionReportSeed.self, from: data) else { return nil }
        return Task.detached { await withTaskGroup(of: Void.self) { jobs in for server in servers { let passed = server.position < probes.count && probes[server.position]["success"] as? Bool == true; jobs.addTask { await Self.send(passed, server.coreAddress, context) } } } }
    }

    private static func send(_ passed: Bool, _ ip: String, _ context: ConnectionReportSeed) async {
        guard var parts = URLComponents(string: context.endpoint) else { return }
        let f = DateFormatter(); f.locale = Locale(identifier: "en_US_POSIX"); f.dateFormat = "MMddHHmmss"
        let event = passed ? "connect_success" : "connect_failed", stamp = f.string(from: Date()) + "-" + context.sessionID
        let info = passed ? "\(event),0,\(stamp),\(ip)" : "\(event),\(stamp),\(ip)"
        parts.queryItems = [URLQueryItem(name: "imei", value: context.uid), URLQueryItem(name: "country", value: context.country), URLQueryItem(name: "lang", value: context.language), URLQueryItem(name: "mobile", value: "iPhone"), URLQueryItem(name: "pk", value: context.packageName), URLQueryItem(name: "version", value: context.version), URLQueryItem(name: "info", value: info)]
        guard let url = parts.url else { return }; var request = URLRequest(url: url); request.timeoutInterval = 10; _ = try? await URLSession.shared.data(for: request)
    }
}

enum TunnelRunRecords {
    private static let lock = NSLock(); private static var sequence: UInt64 = 0
    static func note(_ text: String) { os_log("[Tunnel Route] %{public}@", log: .default, type: .error, text)
#if DEBUG
        guard let d = UserDefaults(suiteName: SharedConfig.storageGroup) else { return }; lock.lock(); defer { lock.unlock() }; sequence &+= 1
        var rows = d.array(forKey: SharedConfig.extensionLogKey) as? [[String: Any]] ?? []; rows.append(["sequence": NSNumber(value: sequence), "message": text, "time": Date().timeIntervalSince1970]); if rows.count > 200 { rows.removeFirst(rows.count - 200) }; d.set(rows, forKey: SharedConfig.extensionLogKey)
#endif
    }
    static func save(servers: [[String: Any]], probes: [[String: Any]], route: RunningRoute?, connected: Bool, error: String) { var safe = probes; for i in safe.indices { safe[i] = safe[i].filter { !($0.value is NSNull) } }; let value: [String: Any] = ["success": connected, "candidates": servers, "results": safe, "selectedIndex": route?.position ?? -1, "selectedGroupID": route?.group ?? -1, "selectedAddress": route?.serverAddress ?? "", "error": error, "finishedAt": Date().timeIntervalSince1970]; UserDefaults(suiteName: SharedConfig.storageGroup)?.set(value, forKey: SharedConfig.reportKey) }
    static func complete(_ route: RunningRoute?, success: Bool, error: String) { var value = current() ?? [:]; value["success"] = success; value["selectedIndex"] = route?.position ?? -1; value["selectedGroupID"] = route?.group ?? -1; value["selectedAddress"] = route?.serverAddress ?? ""; value["error"] = error; value["finishedAt"] = Date().timeIntervalSince1970; UserDefaults(suiteName: SharedConfig.storageGroup)?.set(value, forKey: SharedConfig.reportKey) }
    static func current() -> [String: Any]? { UserDefaults(suiteName: SharedConfig.storageGroup)?.dictionary(forKey: SharedConfig.reportKey) }
}
