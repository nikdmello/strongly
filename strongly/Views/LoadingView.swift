import SwiftUI

struct LoadingView: View {
    @State private var stars: [Star] = []
    @State private var showOnboarding = false

    var body: some View {
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
                    .opacity(pulseOpacity)
            }
        }
        .onAppear {
            generateStars()
            animateStars()
        }
        .onTapGesture {
            explodeStars()
            HapticFeedback.heavy.trigger()
            showOnboarding = true
        }
        .fullScreenCover(isPresented: $showOnboarding) {
            MainTabView()
        }
    }

    private var pulseOpacity: Double {
        let animation = Animation.easeInOut(duration: 1.5).repeatForever(autoreverses: true)
        return withAnimation(animation) { 0.3 }
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

    private func explodeStars() {
        let center = CGPoint(x: 200, y: 400)

        withAnimation(.easeOut(duration: 0.6)) {
            for i in stars.indices {
                let dx = stars[i].position.x - center.x
                let dy = stars[i].position.y - center.y
                let distance = sqrt(dx * dx + dy * dy)
                let normalized = CGPoint(x: dx / distance, y: dy / distance)

                stars[i].position.x += normalized.x * 2000
                stars[i].position.y += normalized.y * 2000
                stars[i].opacity = 0
            }
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
