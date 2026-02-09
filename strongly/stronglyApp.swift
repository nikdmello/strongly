import SwiftUI

@main
struct stronglyApp: App {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    var body: some Scene {
        WindowGroup {
            LoadingView()
        }
    }
}
