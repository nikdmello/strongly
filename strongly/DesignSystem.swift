import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

extension Color {

    static let appAccent = Color(hexString: "86F3CB")

    static let black = Color(hexString: "000000")
    static let gray900 = Color(hexString: "0D1220")
    static let gray700 = Color(hexString: "52617D")
    static let gray400 = Color(hexString: "9AAAC8")
    static let gray100 = Color(hexString: "E8EEFA")
    static let white = Color(hexString: "FFFFFF")
    static let spaceAbyss = Color(hexString: "030711")
    static let spaceNavy = Color(hexString: "061024")
    static let spaceMidnight = Color(hexString: "0C1B36")
    static let spaceNebula = Color(hexString: "12324A")
    static let themedCard = Color(hexString: "111E38")
    static let spaceStroke = Color(hexString: "2D4B75")
    static let spaceGlow = Color(hexString: "86F3CB")
    static let spaceGlowSecondary = Color(hexString: "69C8FF")
    static let chestColor = Color(hexString: "FF8F6A")
    static let backColor = Color(hexString: "5CD3FF")
    static let shoulderColor = Color(hexString: "FFD37A")
    static let legColor = Color(hexString: "83E2A4")
    static let armColor = Color(hexString: "FFBCD0")
    static let coreColor = Color(hexString: "9CC8FF")

    static let text = white
    static let textSecondary = Color(hexString: "B7C6E4")
    static let textTertiary = Color(hexString: "93A5C8")
    static let background = spaceAbyss
    static let surface = themedCard

    static let ink = white
    static let ash = textSecondary
    static let graphite = textTertiary
    static let ghost = themedCard
    static let paper = background
    static let separator = Color(hexString: "E5E5E7")

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

extension MuscleGroup {
    var symbolName: String {
        switch self {
        case .chestUpper, .chestLower:
            return "lungs.fill"
        case .backWidth, .backThickness:
            return "figure.rower"
        case .shoulderFront, .shoulderSide, .shoulderRear:
            return "figure.strengthtraining.functional"
        case .quads, .hamstrings, .glutes, .calves:
            return "figure.walk.motion"
        case .biceps, .triceps:
            return "dumbbell.fill"
        case .abs:
            return "square.grid.2x3.fill"
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
            return "figure.upper.body"
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

    static let display = Font.system(size: 56, weight: .heavy, design: .rounded)
    static let title = Font.system(size: 32, weight: .bold, design: .rounded)
    static let body = Font.system(size: 17, weight: .semibold, design: .rounded)
    static let detail = Font.system(size: 15, weight: .medium, design: .rounded)
    static let label = Font.system(size: 13, weight: .semibold, design: .rounded)

    static let micro = label
    static let caption = label
    static let mega = display

    static func display(_ size: CGFloat) -> Font {
        Font.system(size: size, weight: .heavy, design: .rounded)
    }

    static func title(_ size: CGFloat) -> Font {
        Font.system(size: size, weight: .bold, design: .rounded)
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

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body)
            .fontWeight(.semibold)
            .foregroundColor(.spaceNavy)
            .frame(maxWidth: .infinity)
            .padding(.vertical, Space.m)
            .background(
                LinearGradient(
                    colors: [.spaceGlow, .spaceGlowSecondary],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.white.opacity(0.28), lineWidth: 0.9)
            )
            .shadow(color: .spaceGlow.opacity(0.28), radius: 12, y: 6)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(Motion.quick, value: configuration.isPressed)
    }
}

struct CardStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(Space.l)
            .background(
                LinearGradient(
                    colors: [
                        Color.themedCard.opacity(0.95),
                        Color.spaceMidnight.opacity(0.86)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .cornerRadius(20)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color.spaceGlow.opacity(0.35),
                                Color.spaceStroke.opacity(0.55)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
            .shadow(color: .black.opacity(0.52), radius: 16, y: 10)
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
    private let starCount = 76

    var body: some View {
        GeometryReader { geo in
            TimelineView(.animation(minimumInterval: 1.0 / 24.0)) { context in
                let time = context.date.timeIntervalSinceReferenceDate
                let renderSize = stabilizedRenderSize(for: geo.size)

                ZStack {
                    LinearGradient(
                        colors: [.spaceAbyss, .spaceNavy, .spaceMidnight],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    Circle()
                        .fill(Color.spaceNebula.opacity(0.33))
                        .frame(width: renderSize.width * 0.95)
                        .blur(radius: 66)
                        .offset(x: -renderSize.width * 0.35, y: -renderSize.height * 0.35)
                    Circle()
                        .fill(Color.spaceGlowSecondary.opacity(0.14))
                        .frame(width: renderSize.width * 0.75)
                        .blur(radius: 74)
                        .offset(x: renderSize.width * 0.32, y: renderSize.height * 0.42)
                    Circle()
                        .fill(Color.spaceGlow.opacity(0.08))
                        .frame(width: renderSize.width * 0.62)
                        .blur(radius: 84)
                        .offset(x: renderSize.width * 0.22, y: -renderSize.height * 0.2)
                    ForEach(0..<starCount, id: \.self) { index in
                        Circle()
                            .fill(Color.white.opacity(animatedStarOpacity(for: index, time: time)))
                            .frame(width: starSize(for: index), height: starSize(for: index))
                            .position(
                                x: animatedStarX(for: index, width: renderSize.width, time: time),
                                y: animatedStarY(for: index, height: renderSize.height, time: time)
                            )
                    }
                }
                .ignoresSafeArea()
            }
        }
    }

    private func stabilizedRenderSize(for current: CGSize) -> CGSize {
        CGSize(width: max(current.width, 1), height: max(current.height, 1))
    }

    private func starX(for index: Int, width: CGFloat) -> CGFloat {
        CGFloat((index * 73) % 1000) / 1000 * width
    }

    private func starY(for index: Int, height: CGFloat) -> CGFloat {
        CGFloat((index * 131) % 1000) / 1000 * height
    }

    private func starSize(for index: Int) -> CGFloat {
        CGFloat((index % 3) + 1)
    }

    private func starOpacity(for index: Int) -> Double {
        0.25 + (Double((index * 29) % 70) / 100)
    }

    private func animatedStarX(for index: Int, width: CGFloat, time: TimeInterval) -> CGFloat {
        let base = starX(for: index, width: width)
        let phase = Double(index) * 0.37
        let drift = CGFloat(sin(time * (0.24 + Double(index % 5) * 0.024) + phase) * 5.8)
        return base + drift
    }

    private func animatedStarY(for index: Int, height: CGFloat, time: TimeInterval) -> CGFloat {
        let base = starY(for: index, height: height)
        let phase = Double(index) * 0.51
        let drift = CGFloat(cos(time * (0.21 + Double(index % 7) * 0.02) + phase) * 4.4)
        return base + drift
    }

    private func animatedStarOpacity(for index: Int, time: TimeInterval) -> Double {
        let base = starOpacity(for: index)
        let twinkle = 0.12 * sin(time * (0.95 + Double(index % 9) * 0.06) + Double(index))
        return min(max(base + twinkle, 0.15), 0.95)
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
                    .foregroundColor(.spaceNavy)
                    .padding(.horizontal, compact ? 6 : 8)
                    .padding(.vertical, 4)
                    .background(muscle.tint.opacity(0.95))
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
                    .foregroundColor(.spaceNavy)
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
        Group {
            if muscle == .abs {
                absGlyph
            } else if let image = customIconImage {
                Image(uiImage: image)
                    .resizable()
                    .renderingMode(.template)
                    .scaledToFit()
            } else {
                Image(systemName: muscle.symbolName)
                    .font(.system(size: compact ? 10 : 12, weight: .semibold))
            }
        }
        .foregroundColor(muscle.tint)
        .frame(width: compact ? 12 : 14, height: compact ? 12 : 14)
    }

    private var absGlyph: some View {
        HStack(spacing: compact ? 1.4 : 1.8) {
            absColumn
            absColumn
        }
        .frame(width: compact ? 9 : 11, height: compact ? 11 : 13)
    }

    private var absColumn: some View {
        VStack(spacing: compact ? 1.4 : 1.8) {
            absBlock
            absBlock
            absBlock
        }
    }

    private var absBlock: some View {
        RoundedRectangle(cornerRadius: compact ? 0.8 : 1.0, style: .continuous)
            .frame(width: compact ? 3.6 : 4.4, height: compact ? 2.4 : 3.0)
    }

    private var customIconImage: UIImage? {
        #if canImport(UIKit)
        UIImage(named: muscle.iconAssetName)
        #else
        nil
        #endif
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

extension View {
    func themedCard(cornerRadius: CGFloat = 16) -> some View {
        self
            .background(
                LinearGradient(
                    colors: [
                        Color.themedCard.opacity(0.95),
                        Color.spaceMidnight.opacity(0.86)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .cornerRadius(cornerRadius)
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color.spaceGlow.opacity(0.35),
                                Color.spaceStroke.opacity(0.55)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
            .shadow(color: .black.opacity(0.52), radius: 14, y: 9)
    }
}
