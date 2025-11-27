import SwiftUI

struct RootTabView: View {
    @EnvironmentObject private var appLanguage: AppLanguage
    @EnvironmentObject private var tabSelection: TabSelection
    
    var body: some View {
        TabView(selection: $tabSelection.selectedIndex) {
            HomeConnectView()
                .tabItem {
                    Image(systemName: "power.circle.fill")
                    Text("tab_home")
                }
                .tag(0)

            NodeListView()
                .tabItem {
                    Image(systemName: "globe")
                    Text("tab_nodes")
                }
                .tag(1)

            SettingsView()
                .tabItem {
                    Image(systemName: "gearshape.fill")
                    Text("tab_settings")
                }
                .tag(2)
        }
        .tint(CoreVPNTheme.brandOrange)
        // 语言变化时强制刷新 TabView，避免标题偶尔不更新
        .id(appLanguage.locale.identifier)
    }
}
