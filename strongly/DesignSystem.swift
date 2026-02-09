




import SwiftUI



extension Color {
    
    static let appAccent = Color(hexString: "FFFFFF")
    
    
    static let black = Color(hexString: "000000")
    static let gray900 = Color(hexString: "1A1A1A")
    static let gray700 = Color(hexString: "525252")
    static let gray400 = Color(hexString: "A3A3A3")
    static let gray100 = Color(hexString: "F5F5F5")
    static let white = Color(hexString: "FFFFFF")
    
    
    static let text = black
    static let textSecondary = gray700
    static let textTertiary = gray400
    static let background = white
    static let surface = gray100
    
    
    static let ink = black
    static let ash = gray400
    static let graphite = gray700
    static let ghost = gray100
    static let paper = white
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



extension Font {
    
    static let display = Font.system(size: 56, weight: .black, design: .default)
    static let title = Font.system(size: 32, weight: .bold, design: .default)
    static let body = Font.system(size: 17, weight: .medium, design: .default)
    static let detail = Font.system(size: 15, weight: .regular, design: .default)
    static let label = Font.system(size: 13, weight: .semibold, design: .default)
    
    
    static let micro = label
    static let caption = label
    static let mega = display
    
    
    static func display(_ size: CGFloat) -> Font {
        Font.system(size: size, weight: .black, design: .default)
    }
    
    static func title(_ size: CGFloat) -> Font {
        Font.system(size: size, weight: .bold, design: .default)
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
    static let quick = Animation.easeOut(duration: 0.2)
    static let normal = Animation.easeOut(duration: 0.3)
    static let slow = Animation.spring(response: 0.5, dampingFraction: 0.7)
    
    
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
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, Space.m)
            .background(Color.black)
            .cornerRadius(16)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(Motion.quick, value: configuration.isPressed)
    }
}

struct CardStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(Space.l)
            .background(Color.white)
            .cornerRadius(20)
            .shadow(color: .black.opacity(0.04), radius: 8, y: 2)
    }
}

struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(Motion.quick, value: configuration.isPressed)
    }
}