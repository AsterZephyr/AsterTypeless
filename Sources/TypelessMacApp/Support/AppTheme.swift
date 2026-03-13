import SwiftUI

enum AppTheme {
    static let backgroundTop = Color(red: 0.96, green: 0.94, blue: 0.91)
    static let backgroundBottom = Color(red: 0.90, green: 0.87, blue: 0.82)
    static let card = Color.white.opacity(0.68)
    static let cardBorder = Color.black.opacity(0.08)
    static let accent = Color(red: 0.16, green: 0.43, blue: 0.96)
    static let accentSoft = Color(red: 0.16, green: 0.43, blue: 0.96).opacity(0.12)
    static let ink = Color(red: 0.12, green: 0.11, blue: 0.09)
    static let muted = Color(red: 0.42, green: 0.40, blue: 0.37)
    static let success = Color(red: 0.20, green: 0.57, blue: 0.34)
    static let warning = Color(red: 0.78, green: 0.41, blue: 0.22)
}

struct CardSurface: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(18)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(AppTheme.cardBorder, lineWidth: 1)
            )
    }
}

extension View {
    func cardSurface() -> some View {
        modifier(CardSurface())
    }
}

struct StatusPill: View {
    let title: String
    let tint: Color

    var body: some View {
        Text(title)
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(tint)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(tint.opacity(0.12), in: Capsule())
    }
}
