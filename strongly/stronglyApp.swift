import SwiftUI

@main
struct stronglyApp: App {
    @AppStorage("strongly_has_seen_launch_screen") private var hasSeenLaunchScreen = false
    @AppStorage("strongly_product_onboarding_complete") private var onboardingComplete = false

    var body: some Scene {
        WindowGroup {
            if hasSeenLaunchScreen || onboardingComplete {
                MainTabView()
            } else {
                LoadingView {
                    hasSeenLaunchScreen = true
                }
            }
        }
    }
}
