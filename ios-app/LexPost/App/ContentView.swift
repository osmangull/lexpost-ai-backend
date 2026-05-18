import SwiftUI

struct ContentView: View {
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false

    var body: some View {
        if hasSeenOnboarding {
            mainTabs
        } else {
            OnboardingView {
                withAnimation(.easeInOut(duration: 0.4)) {
                    hasSeenOnboarding = true
                }
            }
        }
    }

    private var mainTabs: some View {
        TabView {
            DashboardViewNew()
                .tabItem { Label("Gazete", systemImage: "newspaper") }

            SettingsView()
                .tabItem { Label("Ayarlar", systemImage: "gear") }
        }
    }
}
