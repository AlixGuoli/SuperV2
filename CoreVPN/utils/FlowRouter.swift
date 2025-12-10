//
//  FlowRouter.swift
//  CoreVPN
//
//  连接流程导航路由（连接中 / 结果页）
//

import Foundation
import SwiftUI

enum FlowPage: Hashable {
    case connecting
    case result(ResultType)
}

enum ResultType: Hashable {
    case connectSuccess
    case connectFail
    case disconnectSuccess
}

final class FlowRouter: ObservableObject {
    @Published var path: [FlowPage] = []
    
    func showConnecting() {
        // 若已有 result，先清空
        path.removeAll()
        path.append(.connecting)
    }
    
    func showResult(_ type: ResultType) {
        // 移除连接中，直接推结果
        path.removeAll()
        path.append(.result(type))
    }
    
    func reset() {
        path.removeAll()
    }
}

