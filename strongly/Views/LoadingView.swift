import SwiftUI

struct LoadingView: View {
    var onComplete: () -> Void = {}
    @State private var showMainApp = false
    @State private var transitionProgress: CGFloat = 0
    @State private var promptVisible = false
    @State private var hasHandledTap = false
    @State private var logoPulse = false
    @State private var heroRise = false

    var body: some View {
        ZStack {
            if showMainApp {
                MainTabView()
                    .opacity(transitionProgress)
                    .transition(.opacity)
            }

            welcomeLayer
                .opacity(1 - transitionProgress)
                .blur(radius: 4 * transitionProgress)
                .allowsHitTesting(!showMainApp)
                .transition(.opacity)
        }
        .animation(.easeInOut(duration: 0.55), value: transitionProgress)
        .onAppear {
            withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                promptVisible = true
            }
            withAnimation(.easeInOut(duration: 2.1).repeatForever(autoreverses: true)) {
                logoPulse = true
            }
            withAnimation(.spring(response: 0.75, dampingFraction: 0.86)) {
                heroRise = true
            }
        }
    }

    private var welcomeLayer: some View {
        ZStack {
            StarfieldBackground()
                .ignoresSafeArea()

            Button {
                transitionToMainApp()
            } label: {
                Color.clear
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(showMainApp)
            .accessibilityLabel("Begin")
            .ignoresSafeArea()

            VStack {
                Spacer()

                VStack(spacing: 14) {
                    Image("StronglyIcon")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 122, height: 122)
                        .shadow(color: .black.opacity(0.34), radius: 18, y: 10)
                        .scaleEffect(logoPulse ? 1.03 : 0.985)

                    Text("STRONGLY")
                        .font(.system(size: 44, weight: .black))
                        .foregroundColor(.white)
                        .tracking(3)
                }
                .offset(y: heroRise ? 0 : 18)
                .opacity(heroRise ? 1 : 0.5)

                Spacer()

                Button {
                    transitionToMainApp()
                } label: {
                    Text("Tap anywhere to begin")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white.opacity(0.7))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Color.white.opacity(0.1))
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .disabled(showMainApp)
                .padding(.bottom, 54)
                .opacity(promptVisible ? 1 : 0.35)
            }
            .padding(.horizontal, 28)
            .allowsHitTesting(!showMainApp)
        }
        .contentShape(Rectangle())
        .simultaneousGesture(
            TapGesture().onEnded {
                transitionToMainApp()
            }
        )
    }

    private func transitionToMainApp() {
        guard !hasHandledTap else { return }
        hasHandledTap = true
        HapticFeedback.heavy.trigger()
        showMainApp = true
        withAnimation(.easeInOut(duration: 0.52)) {
            transitionProgress = 1
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.52) {
            onComplete()
        }
    }
}
