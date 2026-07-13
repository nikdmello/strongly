import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

extension Color {

    static let appAccent = Color(hexString: "F7F7F2")
    static let appAccentPressed = Color(hexString: "D8D8D2")
    static let appAccentSoft = Color(hexString: "FFFFFF")
    static let success = Color(hexString: "7CCB8A")
    static let error = Color(hexString: "D86A62")

    static let black = Color(hexString: "000000")
    static let gray900 = Color(hexString: "0D0D0D")
    static let gray700 = Color(hexString: "585858")
    static let gray400 = Color(hexString: "B8B8B8")
    static let gray100 = Color(hexString: "F7F7F2")
    static let white = Color(hexString: "FFFFFF")

    static let spaceAbyss = Color(hexString: "000000")
    static let spaceNavy = Color(hexString: "090909")
    static let spaceMidnight = Color(hexString: "030303")
    static let spaceNebula = Color(hexString: "121212")
    static let themedCard = Color(hexString: "0E0E0E")
    static let spaceStroke = Color(hexString: "2A2A2A")
    static let spaceGlow = appAccent
    static let spaceGlowSecondary = Color(hexString: "FFFFFF")
    static let spacePanelTop = Color(hexString: "171717")
    static let spacePanelBottom = Color(hexString: "080808")
    static let spacePanelEdge = Color(hexString: "353535")
    static let spacePanelInner = Color(hexString: "181818")
    static let spacePulse = Color(hexString: "FFFFFF")
    static let chestColor = Color(hexString: "FF3B6B")
    static let backColor = Color(hexString: "00D084")
    static let shoulderColor = Color(hexString: "8B5CF6")
    static let legColor = Color(hexString: "FACC15")
    static let armColor = Color(hexString: "38BDF8")
    static let coreColor = Color(hexString: "FB7185")

    static let text = Color(hexString: "F7F7F2")
    static let textSecondary = Color(hexString: "B8B8B2")
    static let textTertiary = Color(hexString: "787872")
    static let background = spaceAbyss
    static let surface = themedCard

    static let ink = white
    static let ash = textSecondary
    static let graphite = textTertiary
    static let ghost = themedCard
    static let paper = background
    static let separator = Color(hexString: "2A2A2A")

    init(hexString: String) {
        let hex = hexString.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default: (a, r, g, b) = (1, 1, 1, 0)
        }
        self.init(.sRGB, red: Double(r) / 255, green: Double(g) / 255, blue: Double(b) / 255, opacity: Double(a) / 255)
    }
}

extension LinearGradient {
    static var rainbowRoad: LinearGradient {
        LinearGradient(
            colors: RainbowRoad.colors,
            startPoint: .leading,
            endPoint: .trailing
        )
    }
}

enum RainbowRoad {
    static let colors = [
        Color(hexString: "FF3B6B"),
        Color(hexString: "FF8A00"),
        Color(hexString: "FACC15"),
        Color(hexString: "00D084"),
        Color(hexString: "38BDF8"),
        Color(hexString: "8B5CF6")
    ]

    static let loopDuration: TimeInterval = 4.8

    static func phase(at date: Date) -> CGFloat {
        CGFloat(date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: loopDuration) / loopDuration)
    }
}

extension MuscleGroup {
    var symbolName: String {
        switch self {
        case .chestUpper, .chestLower:
            return "figure.strengthtraining.traditional"
        case .backWidth, .backThickness:
            return "figure.rower"
        case .shoulderFront, .shoulderSide, .shoulderRear:
            return "figure.strengthtraining.functional"
        case .quads, .hamstrings, .glutes, .calves:
            return "figure.walk.motion"
        case .biceps, .triceps:
            return "dumbbell.fill"
        case .abs:
            return "square.grid.3x2.fill"
        }
    }

    var shortName: String {
        switch self {
        case .chestUpper: return "Chest"
        case .chestLower: return "Chest"
        case .backWidth: return "Back"
        case .backThickness: return "Back"
        case .shoulderFront: return "Shoulders"
        case .shoulderSide: return "Shoulders"
        case .shoulderRear: return "Shoulders"
        case .quads: return "Quads"
        case .hamstrings: return "Hamstrings"
        case .glutes: return "Glutes"
        case .calves: return "Calves"
        case .biceps: return "Biceps"
        case .triceps: return "Triceps"
        case .abs: return "Abs"
        }
    }

    var subtypeTag: String? {
        switch self {
        case .chestUpper: return "U"
        case .chestLower: return "L"
        case .backWidth: return "W"
        case .backThickness: return "T"
        case .shoulderFront: return "F"
        case .shoulderSide: return "S"
        case .shoulderRear: return "R"
        default: return nil
        }
    }

    var tint: Color {
        switch self {
        case .chestUpper, .chestLower:
            return .chestColor
        case .backWidth, .backThickness:
            return .backColor
        case .shoulderFront, .shoulderSide, .shoulderRear:
            return .shoulderColor
        case .quads, .hamstrings, .glutes, .calves:
            return .legColor
        case .biceps, .triceps:
            return .armColor
        case .abs:
            return .coreColor
        }
    }

    var iconAssetName: String {
        "muscle_\(rawValue)"
    }
}

extension DayType {
    var symbolName: String {
        switch self {
        case .push:
            return "arrow.up.right.circle.fill"
        case .pull:
            return "arrow.down.left.circle.fill"
        case .legs:
            return "figure.walk"
        case .upper:
            return "figure.strengthtraining.traditional"
        case .lower:
            return "figure.walk.motion"
        case .full:
            return "figure.mixed.cardio"
        case .rest:
            return "bed.double.fill"
        }
    }

    var tint: Color {
        switch self {
        case .push:
            return .chestColor
        case .pull:
            return .backColor
        case .legs:
            return .legColor
        case .upper:
            return .shoulderColor
        case .lower:
            return .legColor
        case .full:
            return .spaceGlow
        case .rest:
            return .white.opacity(0.6)
        }
    }
}

extension Font {

    static let display = Font.system(size: 56, weight: .heavy)
    static let title = Font.system(size: 32, weight: .bold)
    static let body = Font.system(size: 17, weight: .semibold)
    static let detail = Font.system(size: 15, weight: .medium)
    static let label = Font.system(size: 13, weight: .semibold)

    static let micro = label
    static let caption = label
    static let mega = display

    static func display(_ size: CGFloat) -> Font {
        Font.system(size: size, weight: .heavy)
    }

    static func title(_ size: CGFloat) -> Font {
        Font.system(size: size, weight: .bold)
    }
}

enum Space {
    static let xs: CGFloat = 8
    static let s: CGFloat = 12
    static let m: CGFloat = 16
    static let l: CGFloat = 24
    static let xl: CGFloat = 32
    static let xxl: CGFloat = 48
    static let xxxl: CGFloat = 64
}

enum Spacing {
    static let xs = Space.xs
    static let s = Space.s
    static let m = Space.m
    static let l = Space.l
    static let xl = Space.xl
}

enum Radius {
    static let s: CGFloat = 10
    static let m: CGFloat = 14
    static let l: CGFloat = 18
    static let xl: CGFloat = 22
}

enum Layout {
    static let screenHorizontal: CGFloat = 20
}

enum PremiumLayout {
    static let sectionSpacing: CGFloat = 18
    static let sectionPadding: CGFloat = 18
    static let sectionRadius: CGFloat = 22
    static let sectionTitleSpacing: CGFloat = 6
}

enum Motion {
    static let quick = Animation.easeOut(duration: 0.18)
    static let normal = Animation.spring(response: 0.28, dampingFraction: 0.86)
    static let slow = Animation.spring(response: 0.52, dampingFraction: 0.82)

    static let snap = normal
    static let slide = slow
}

enum HapticFeedback {
    case light, medium, heavy, success, warning, error

    func trigger() {
        switch self {
        case .light:
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        case .medium:
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        case .heavy:
            UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        case .success:
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        case .warning:
            UINotificationFeedbackGenerator().notificationOccurred(.warning)
        case .error:
            UINotificationFeedbackGenerator().notificationOccurred(.error)
        }
    }
}

struct AnimatedRainbowStroke: View {
    var cornerRadius: CGFloat
    var lineWidth: CGFloat = 1.5

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { context in
            let phase = RainbowRoad.phase(at: context.date)
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .strokeBorder(
                    AngularGradient(
                        colors: RainbowRoad.colors + [RainbowRoad.colors[0]],
                        center: .center,
                        angle: .degrees(Double(phase) * 360)
                    ),
                    lineWidth: lineWidth
                )
                .shadow(color: Color(hexString: "38BDF8").opacity(0.18), radius: 10, y: 4)
        }
    }
}

struct AnimatedRainbowRail: View {
    var height: CGFloat = 2

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { context in
            GeometryReader { geometry in
                let phase = RainbowRoad.phase(at: context.date)
                ZStack {
                    LinearGradient.rainbowRoad

                    RainbowWaveTexture(phase: phase)
                        .blendMode(.screen)
                        .opacity(0.42)

                    RainbowWaveTexture(phase: phase + 0.33)
                        .blendMode(.overlay)
                        .opacity(0.24)
                }
                .frame(width: geometry.size.width, height: height)
                .clipShape(Capsule(style: .continuous))
                .shadow(color: Color(hexString: "38BDF8").opacity(0.24), radius: 8, y: 2)
            }
            .frame(height: height)
        }
    }
}

private struct RainbowWaveTexture: View {
    let phase: Double

    var body: some View {
        Canvas { context, size in
            guard size.width > 0, size.height > 0 else { return }

            let waveCount = 2.7
            let pulse = sin(phase * .pi * 2)
            let amplitude = max(1.1, size.height * (0.22 + 0.08 * pulse))
            let midY = size.height * (0.5 + 0.08 * cos(phase * .pi * 2))
            let lineWidth = max(1.4, size.height * 0.34)

            var highlight = Path()
            highlight.move(to: CGPoint(x: 0, y: midY))

            let steps = max(16, Int(size.width / 4))
            for index in 0...steps {
                let progress = Double(index) / Double(steps)
                let x = size.width * progress
                let y = midY + sin(progress * .pi * 2 * waveCount + phase * .pi * 0.45) * amplitude
                highlight.addLine(to: CGPoint(x: x, y: y))
            }

            context.stroke(
                highlight,
                with: .linearGradient(
                    Gradient(colors: [
                        .white.opacity(0.12),
                        .white.opacity(0.62),
                        .white.opacity(0.16)
                    ]),
                    startPoint: CGPoint(x: 0, y: 0),
                    endPoint: CGPoint(x: size.width, y: size.height)
                ),
                lineWidth: lineWidth
            )

            var shadow = highlight
            shadow = shadow.applying(CGAffineTransform(translationX: 0, y: size.height * 0.22))
            context.stroke(
                shadow,
                with: .color(.black.opacity(0.16)),
                lineWidth: max(1, lineWidth * 0.7)
            )
        }
    }
}

struct AnimatedRainbowCircleStroke: View {
    var lineWidth: CGFloat = 1.2

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { context in
            let phase = RainbowRoad.phase(at: context.date)
            Circle()
                .strokeBorder(
                    AngularGradient(
                        colors: RainbowRoad.colors + [RainbowRoad.colors[0]],
                        center: .center,
                        angle: .degrees(Double(phase) * 360)
                    ),
                    lineWidth: lineWidth
                )
                .shadow(color: Color(hexString: "38BDF8").opacity(0.18), radius: 8, y: 3)
        }
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body)
            .fontWeight(.semibold)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(configuration.isPressed ? Color.spacePanelTop : Color.spacePanelInner)
            .cornerRadius(Radius.l, antialiased: true)
            .overlay(
                AnimatedRainbowStroke(cornerRadius: Radius.l, lineWidth: 1.4)
            )
            .shadow(color: Color.black.opacity(0.28), radius: 16, y: 8)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(Motion.quick, value: configuration.isPressed)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body)
            .fontWeight(.semibold)
            .foregroundColor(.white.opacity(0.88))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(Color.white.opacity(configuration.isPressed ? 0.16 : 0.1))
            .cornerRadius(Radius.m)
            .overlay(
                RoundedRectangle(cornerRadius: Radius.m)
                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
            )
            .scaleEffect(configuration.isPressed ? 0.985 : 1.0)
            .animation(Motion.quick, value: configuration.isPressed)
    }
}

struct GhostButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .semibold))
            .foregroundColor(.white.opacity(0.76))
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.white.opacity(configuration.isPressed ? 0.16 : 0.1))
            .clipShape(Capsule(style: .continuous))
            .animation(Motion.quick, value: configuration.isPressed)
    }
}

struct InputFieldStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(Color.white.opacity(0.06))
            .overlay(
                RoundedRectangle(cornerRadius: Radius.m)
                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
            )
            .cornerRadius(Radius.m)
    }
}

struct ListRowShellStyle: ViewModifier {
    var cornerRadius: CGFloat = Radius.l

    func body(content: Content) -> some View {
        content
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(Color.white.opacity(0.06))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(Color.white.opacity(0.09), lineWidth: 1)
            )
            .cornerRadius(cornerRadius)
    }
}

struct SkeletonBlock: View {
    var height: CGFloat = 16
    var cornerRadius: CGFloat = Radius.s
    @State private var phase: CGFloat = -1

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(Color.white.opacity(0.08))
            .overlay(alignment: .leading) {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.0),
                                Color.white.opacity(0.22),
                                Color.white.opacity(0.0)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: 90)
                    .offset(x: phase * 220)
            }
            .frame(height: height)
            .onAppear {
                withAnimation(.linear(duration: 1.2).repeatForever(autoreverses: false)) {
                    phase = 1.2
                }
            }
    }
}

struct CardStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(Space.l)
            .background(Color.themedCard.opacity(0.98))
            .cornerRadius(Radius.xl)
            .overlay(
                RoundedRectangle(cornerRadius: Radius.xl)
                    .stroke(Color.spaceStroke.opacity(0.95), lineWidth: 1)
                    .allowsHitTesting(false)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Radius.xl)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.045),
                                Color.clear
                            ],
                            startPoint: .top,
                            endPoint: .center
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: Radius.xl, style: .continuous))
                    .allowsHitTesting(false)
            )
            .shadow(color: .black.opacity(0.34), radius: 18, y: 10)
    }
}

struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(Motion.quick, value: configuration.isPressed)
    }
}

struct StarfieldBackground: View {
    var body: some View {
        GeometryReader { _ in
            ZStack {
                LinearGradient(
                    colors: [
                        Color.spaceAbyss,
                        Color.spaceNavy,
                        Color.spaceAbyss
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottom
                )

                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.035),
                                Color.clear,
                                Color.black.opacity(0.34)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )

                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.clear,
                                Color.white.opacity(0.08),
                                Color.clear
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                Rectangle()
                    .fill(Color.black.opacity(0.18))
            }
            .ignoresSafeArea()
            .allowsHitTesting(false)
        }
    }
}

struct DayTypeBadge: View {
    let dayType: DayType

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: dayType.symbolName)
                .font(.system(size: 11, weight: .semibold))
            Text(dayType.rawValue)
                .font(.system(size: 12, weight: .semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.9)
        }
        .fixedSize(horizontal: true, vertical: false)
        .foregroundColor(dayType == .rest ? .white.opacity(0.75) : dayType.tint)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(dayType.tint.opacity(dayType == .rest ? 0.12 : 0.2))
        .clipShape(Capsule())
        .overlay(
            Capsule()
                .stroke(dayType.tint.opacity(0.5), lineWidth: 1)
        )
    }
}

struct MuscleBadge: View {
    let muscle: MuscleGroup
    var valueText: String?
    var compact = false

    var body: some View {
        HStack(spacing: compact ? 6 : 8) {
            iconBadge
            Text(compact ? muscle.shortName : muscle.displayName)
                .font(.system(size: compact ? 11 : 13, weight: .semibold))
                .foregroundColor(.white)
                .lineLimit(compact ? 1 : 2)
                .fixedSize(horizontal: false, vertical: true)
            if let valueText {
                Text(valueText)
                    .font(.system(size: compact ? 10 : 11, weight: .bold))
                    .foregroundColor(.black.opacity(0.88))
                    .padding(.horizontal, compact ? 6 : 8)
                    .padding(.vertical, 4)
                    .background(muscle.tint)
                    .clipShape(Capsule())
            }
        }
        .padding(.horizontal, compact ? 8 : 10)
        .padding(.vertical, compact ? 6 : 8)
        .background(Color.white.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: compact ? 14 : 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: compact ? 14 : 12, style: .continuous)
                .stroke(muscle.tint.opacity(0.5), lineWidth: 1)
        )
    }

    private var iconBadge: some View {
        let baseSize: CGFloat = compact ? 20 : 24

        return ZStack {
            Circle()
                .fill(muscle.tint.opacity(0.18))
                .frame(width: baseSize, height: baseSize)
            MuscleIcon(muscle: muscle, compact: compact)
        }
        .frame(width: baseSize, height: baseSize, alignment: .center)
        .overlay(alignment: .topTrailing) {
            if let subtypeTag = muscle.subtypeTag {
                Text(subtypeTag)
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(.black.opacity(0.88))
                    .padding(.horizontal, 3)
                    .padding(.vertical, 1)
                    .background(muscle.tint)
                    .clipShape(Capsule())
                    .offset(x: 4, y: -4)
            }
        }
    }
}

struct MuscleIcon: View {
    let muscle: MuscleGroup
    var compact: Bool

    var body: some View {
        ZStack {
            silhouette(backView: usesBackSilhouette)
            highlightLayer
        }
        .frame(width: iconSize, height: iconSize)
    }

    private var iconSize: CGFloat { compact ? 12 : 14 }
    private var baseColor: Color { .white.opacity(0.24) }
    private var accentColor: Color { .spaceGlow }

    private var usesBackSilhouette: Bool {
        switch muscle {
        case .backWidth, .backThickness, .shoulderRear, .triceps, .hamstrings, .glutes, .calves:
            return true
        default:
            return false
        }
    }

    private func silhouette(backView: Bool) -> some View {
        let head = compact ? 2.0 : 2.3
        let torsoW = compact ? 4.4 : 5.0
        let torsoH = compact ? 5.0 : 5.8
        let armW = compact ? 1.2 : 1.4
        let armH = compact ? 4.6 : 5.2
        let legW = compact ? 1.8 : 2.0
        let legH = compact ? 5.0 : 5.8

        return ZStack {
            Circle()
                .fill(baseColor)
                .frame(width: head, height: head)
                .offset(y: compact ? -4.6 : -5.2)

            RoundedRectangle(cornerRadius: compact ? 1.4 : 1.7, style: .continuous)
                .fill(baseColor)
                .frame(width: torsoW, height: torsoH)
                .offset(y: compact ? -0.8 : -0.9)

            Capsule(style: .continuous)
                .fill(baseColor)
                .frame(width: armW, height: armH)
                .offset(x: compact ? -3.1 : -3.6, y: compact ? -0.2 : -0.1)

            Capsule(style: .continuous)
                .fill(baseColor)
                .frame(width: armW, height: armH)
                .offset(x: compact ? 3.1 : 3.6, y: compact ? -0.2 : -0.1)

            Capsule(style: .continuous)
                .fill(baseColor)
                .frame(width: legW, height: legH)
                .offset(x: compact ? -1.3 : -1.5, y: compact ? 4.1 : 4.7)

            Capsule(style: .continuous)
                .fill(baseColor)
                .frame(width: legW, height: legH)
                .offset(x: compact ? 1.3 : 1.5, y: compact ? 4.1 : 4.7)

            if backView {
                Capsule(style: .continuous)
                    .fill(baseColor.opacity(0.9))
                    .frame(width: compact ? 0.75 : 0.85, height: compact ? 4.2 : 4.8)
                    .offset(y: compact ? -0.7 : -0.8)
            }
        }
    }

    @ViewBuilder
    private var highlightLayer: some View {
        switch muscle {
        case .chestUpper:
            highlightCapsules(y: compact ? -1.7 : -2.0, width: compact ? 2.3 : 2.6, height: compact ? 1.2 : 1.4, spacing: compact ? 1.3 : 1.5)
        case .chestLower:
            highlightCapsules(y: compact ? -0.4 : -0.5, width: compact ? 2.2 : 2.5, height: compact ? 1.2 : 1.4, spacing: compact ? 1.2 : 1.4)
        case .backWidth:
            highlightCapsules(y: compact ? -0.8 : -0.9, width: compact ? 1.5 : 1.7, height: compact ? 3.6 : 4.1, spacing: compact ? 2.5 : 2.9)
        case .backThickness:
            Capsule(style: .continuous)
                .fill(accentColor)
                .frame(width: compact ? 1.2 : 1.4, height: compact ? 3.8 : 4.4)
                .offset(y: compact ? -0.8 : -0.9)
        case .shoulderFront, .shoulderSide, .shoulderRear:
            highlightCapsules(y: compact ? -2.2 : -2.6, width: compact ? 1.8 : 2.0, height: compact ? 1.8 : 2.0, spacing: compact ? 6.0 : 7.0)
        case .quads:
            highlightCapsules(y: compact ? 3.0 : 3.4, width: compact ? 1.8 : 2.0, height: compact ? 2.8 : 3.1, spacing: compact ? 2.6 : 3.0)
        case .hamstrings:
            highlightCapsules(y: compact ? 3.6 : 4.1, width: compact ? 1.6 : 1.8, height: compact ? 2.4 : 2.7, spacing: compact ? 2.6 : 3.0)
        case .glutes:
            highlightCapsules(y: compact ? 1.6 : 1.9, width: compact ? 2.0 : 2.3, height: compact ? 1.6 : 1.8, spacing: compact ? 2.0 : 2.3)
        case .calves:
            highlightCapsules(y: compact ? 6.0 : 6.8, width: compact ? 1.5 : 1.7, height: compact ? 2.0 : 2.3, spacing: compact ? 2.6 : 3.0)
        case .biceps, .triceps:
            highlightCapsules(y: compact ? -0.6 : -0.6, width: compact ? 1.1 : 1.3, height: compact ? 2.2 : 2.5, spacing: compact ? 6.1 : 7.1)
        case .abs:
            absHighlight
        }
    }

    private func highlightCapsules(y: CGFloat, width: CGFloat, height: CGFloat, spacing: CGFloat) -> some View {
        HStack(spacing: spacing) {
            Capsule(style: .continuous)
                .fill(accentColor)
                .frame(width: width, height: height)
            Capsule(style: .continuous)
                .fill(accentColor)
                .frame(width: width, height: height)
        }
        .offset(y: y)
    }

    private var absHighlight: some View {
        let blockW = compact ? 1.5 : 1.7
        let blockH = compact ? 1.1 : 1.25
        let colSpacing = compact ? 1.1 : 1.3
        let rowSpacing = compact ? 0.9 : 1.0

        return ZStack {
            HStack(spacing: colSpacing) {
                VStack(spacing: rowSpacing) {
                    absBlock(width: blockW, height: blockH)
                    absBlock(width: blockW, height: blockH)
                    absBlock(width: blockW, height: blockH)
                }
                VStack(spacing: rowSpacing) {
                    absBlock(width: blockW, height: blockH)
                    absBlock(width: blockW, height: blockH)
                    absBlock(width: blockW, height: blockH)
                }
            }
            .offset(y: compact ? 1.0 : 1.2)
        }
    }

    private func absBlock(width: CGFloat, height: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: compact ? 0.55 : 0.65, style: .continuous)
            .fill(accentColor)
            .frame(width: width, height: height)
    }
}

struct TrainingGroupIcon: View {
    let group: MuscleTrainingGroup
    var compact = false

    var body: some View {
        MuscleIcon(muscle: representativeMuscle, compact: compact)
    }

    private var representativeMuscle: MuscleGroup {
        switch group {
        case .chest:
            return .chestUpper
        case .back:
            return .backWidth
        case .shoulders:
            return .shoulderSide
        case .quads:
            return .quads
        case .hamstrings:
            return .hamstrings
        case .glutes:
            return .glutes
        case .calves:
            return .calves
        case .biceps:
            return .biceps
        case .triceps:
            return .triceps
        case .abs:
            return .abs
        }
    }
}

struct MuscleTargetRow: View {
    let muscle: MuscleGroup
    let setsText: String

    var body: some View {
        HStack(spacing: 12) {
            MuscleBadge(muscle: muscle, compact: true)
                .frame(maxWidth: .infinity, alignment: .leading)

            Text("\(setsText) sets")
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(.white.opacity(0.85))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.white.opacity(0.12))
                .clipShape(Capsule())
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color.white.opacity(0.09), lineWidth: 1)
        )
    }
}

struct SectionLead: View {
    let title: String
    var subtitle: String?

    var body: some View {
        VStack(alignment: .leading, spacing: PremiumLayout.sectionTitleSpacing) {
            Text(title)
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.white)
            if let subtitle, !subtitle.isEmpty {
                Text(subtitle)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white.opacity(0.67))
            }
        }
    }
}

extension View {
    func appInputField() -> some View {
        modifier(InputFieldStyle())
    }

    func appListRow(cornerRadius: CGFloat = Radius.l) -> some View {
        modifier(ListRowShellStyle(cornerRadius: cornerRadius))
    }

    func themedCard(cornerRadius: CGFloat = 16) -> some View {
        self
            .background(Color.themedCard.opacity(0.98))
            .cornerRadius(cornerRadius)
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(
                        Color.spaceStroke.opacity(0.95),
                        lineWidth: 1
                    )
                    .allowsHitTesting(false)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.055),
                                Color.clear
                            ],
                            startPoint: .top,
                            endPoint: .center
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                    .allowsHitTesting(false)
            )
            .shadow(color: .black.opacity(0.34), radius: 18, y: 10)
    }

    func premiumSectionCard(
        padding: CGFloat = PremiumLayout.sectionPadding,
        cornerRadius: CGFloat = PremiumLayout.sectionRadius
    ) -> some View {
        self
            .padding(padding)
            .themedCard(cornerRadius: cornerRadius)
    }
}
