




import SwiftUI

struct MainTabView: View {
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            OnboardingView(tabSelection: $selectedTab)
                .tabItem {
                    Label("Train", systemImage: "flame.fill")
                }
                .tag(0)
            
            SplitBuilderView()
                .tabItem {
                    Label("Plan", systemImage: "calendar")
                }
                .tag(1)
            
            HistoryView()
                .tabItem {
                    Label("History", systemImage: "clock.fill")
                }
                .tag(2)
        }
        .accentColor(Color(hexString: "FFFFFF"))
    }
}

#Preview {
    MainTabView()
}
