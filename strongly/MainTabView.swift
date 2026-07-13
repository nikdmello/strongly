import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct MainTabView: View {
    @State private var selectedTab = 0
    @StateObject private var planStore = SplitPlanStore()

    init() {
        #if canImport(UIKit)
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor(Color.spaceAbyss.opacity(0.96))
        appearance.shadowColor = UIColor(Color.white.opacity(0.06))
        appearance.stackedLayoutAppearance.normal.iconColor = UIColor(Color.white.opacity(0.62))
        appearance.stackedLayoutAppearance.normal.titleTextAttributes = [
            .foregroundColor: UIColor(Color.white.opacity(0.62))
        ]
        appearance.stackedLayoutAppearance.selected.iconColor = UIColor(Color.spaceGlow)
        appearance.stackedLayoutAppearance.selected.titleTextAttributes = [
            .foregroundColor: UIColor(Color.spaceGlow)
        ]
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance

        let navAppearance = UINavigationBarAppearance()
        navAppearance.configureWithTransparentBackground()
        navAppearance.backgroundColor = .clear
        navAppearance.shadowColor = .clear
        navAppearance.largeTitleTextAttributes = [
            .foregroundColor: UIColor(Color.white),
            .font: UIFont.systemFont(ofSize: 32, weight: .bold)
        ]
        navAppearance.titleTextAttributes = [
            .foregroundColor: UIColor(Color.white),
            .font: UIFont.systemFont(ofSize: 17, weight: .semibold)
        ]
        UINavigationBar.appearance().standardAppearance = navAppearance
        UINavigationBar.appearance().scrollEdgeAppearance = navAppearance
        #endif
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            TrainHomeView(tabSelection: $selectedTab)
                .tabItem {
                    Label("Today", systemImage: "checkmark.circle.fill")
                }
                .tag(0)

            HistoryView()
                .tabItem {
                    Label("Progress", systemImage: "chart.line.uptrend.xyaxis")
                }
                .tag(1)

            SplitBuilderView()
                .tabItem {
                    Label("Settings", systemImage: "slider.horizontal.3")
                }
                .tag(2)
        }
        .accentColor(.spaceGlow)
        .preferredColorScheme(.dark)
        .background(StarfieldBackground().ignoresSafeArea())
        .environmentObject(planStore)
    }
}

#Preview {
    MainTabView()
}
