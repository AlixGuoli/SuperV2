import Foundation
import Network

/// 启动时简单检查当前网络类型（Wi‑Fi / 蜂窝 / 无网络）
/// 只是读取状态，不做任何请求，也不影响你的 VPN 逻辑
final class NetworkStatusChecker {
    static let shared = NetworkStatusChecker()
    
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "corevpn.network.monitor")
    private var hasStarted = false
    
    private init() {}
    
    func checkOnLaunch() {
        guard !hasStarted else { return }
        hasStarted = true
        
        monitor.pathUpdateHandler = { path in
            var status = "none"
            if path.status == .satisfied {
                if path.usesInterfaceType(.wifi) {
                    status = "wifi"
                } else if path.usesInterfaceType(.cellular) {
                    status = "cellular"
                } else if path.usesInterfaceType(.wiredEthernet) {
                    status = "ethernet"
                }
            }
            debugPrint("CoreVPN NetworkStatusChecker – current path: \(status)")
            // 收到一次状态就可以停掉监听
            self.monitor.cancel()
        }
        monitor.start(queue: queue)
    }
}



