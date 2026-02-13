import SwiftUI

struct LoadingView: View {
    @State private var stars: [Star] = []
    @State private var showMainApp = false
    @State private var transitionProgress: CGFloat = 0
    @State private var promptVisible = false
    @State private var hasHandledTap = false

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
            generateStars()
            animateStars()
            withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                promptVisible = true
            }
        }
        .onTapGesture {
            transitionToMainApp()
        }
    }

    private var welcomeLayer: some View {
        ZStack {
            LinearGradient(
                colors: [Color(hexString: "0a0e27"), Color(hexString: "1a1f3a"), Color(hexString: "0a0e27")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            ForEach(stars) { star in
                Circle()
                    .fill(Color.white.opacity(star.opacity))
                    .frame(width: star.size, height: star.size)
                    .blur(radius: star.blur)
                    .position(star.position)
            }

            VStack {
                Spacer()

                Image("StronglyIcon")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 140, height: 140)
                    .shadow(color: .white.opacity(0.25), radius: 20)
                    .padding(.bottom, 16)

                Text("STRONGLY")
                    .font(.system(size: 48, weight: .black))
                    .foregroundColor(.white)
                    .tracking(6)
                    .shadow(color: .white.opacity(0.5), radius: 20)

                Spacer()

                Text("TAP ANYWHERE")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white.opacity(0.6))
                    .tracking(2)
                    .padding(.bottom, 60)
                    .opacity(promptVisible ? 1 : 0.35)
            }
        }
    }

    private func generateStars() {
        stars = (0..<50).map { _ in
            Star(
                position: CGPoint(
                    x: CGFloat.random(in: 0...400),
                    y: CGFloat.random(in: 0...800)
                ),
                size: CGFloat.random(in: 1...3),
                opacity: Double.random(in: 0.3...0.9),
                blur: CGFloat.random(in: 0...1),
                velocity: CGPoint(
                    x: CGFloat.random(in: -0.5...0.5),
                    y: CGFloat.random(in: -0.5...0.5)
                )
            )
        }
    }

    private func animateStars() {
        Timer.scheduledTimer(withTimeInterval: 0.016, repeats: true) { _ in
            for i in stars.indices {
                stars[i].position.x += stars[i].velocity.x
                stars[i].position.y += stars[i].velocity.y

                if stars[i].position.x < 0 { stars[i].position.x = 400 }
                if stars[i].position.x > 400 { stars[i].position.x = 0 }
                if stars[i].position.y < 0 { stars[i].position.y = 800 }
                if stars[i].position.y > 800 { stars[i].position.y = 0 }
            }
        }
    }

    private func transitionToMainApp() {
        guard !hasHandledTap else { return }
        hasHandledTap = true
        HapticFeedback.heavy.trigger()
        showMainApp = true
        withAnimation(.easeInOut(duration: 0.62)) {
            transitionProgress = 1
        }
    }
}

struct Star: Identifiable {
    let id = UUID()
    var position: CGPoint
    let size: CGFloat
    var opacity: Double
    let blur: CGFloat
    let velocity: CGPoint
}
