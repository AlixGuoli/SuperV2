//
//  TabSelection.swift
//  CoreVPN
//
//  Created by SHI QIU on 2025/11/27.
//

import Foundation

/// 全局 Tab 选择状态，便于在子页面间切换 Tab
final class TabSelection: ObservableObject {
    /// 当前选中的 Tab 索引：0=Home, 1=Nodes, 2=Settings
    @Published var selectedIndex: Int = 0
}


