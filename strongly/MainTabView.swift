import SwiftUI

struct MainTabView: View {
    @State private var selectedTab = 0
    @StateObject private var planStore = SplitPlanStore()

    var body: some View {
        TabView(selection: $selectedTab) {
            TrainHomeView(tabSelection: $selectedTab)
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
        .accentColor(.spaceGlow)
        .preferredColorScheme(.dark)
        .environmentObject(planStore)
    }
}

#Preview {
    MainTabView()
}
