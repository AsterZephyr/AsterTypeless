import AppKit
import SwiftUI

enum AppTheme {
    static let cardCornerRadius: CGFloat = 14
    static let insetCornerRadius: CGFloat = 12
    static let brand50 = Color(red: 239 / 255, green: 242 / 255, blue: 1.0)
    static let brand100 = Color(red: 224 / 255, green: 230 / 255, blue: 1.0)
    static let brand200 = Color(red: 198 / 255, green: 209 / 255, blue: 1.0)
    static let brand300 = Color(red: 163 / 255, green: 181 / 255, blue: 1.0)
    static let brand400 = Color(red: 127 / 255, green: 144 / 255, blue: 1.0)
    static let brand500 = Color(red: 92 / 255, green: 104 / 255, blue: 1.0)
    static let brand600 = Color(red: 59 / 255, green: 59 / 255, blue: 1.0)
    static let brand700 = Color(red: 50 / 255, green: 43 / 255, blue: 230 / 255)
    static let brand800 = Color(red: 41 / 255, green: 36 / 255, blue: 188 / 255)
    static let brand900 = Color(red: 37 / 255, green: 34 / 255, blue: 148 / 255)
    static let brand950 = Color(red: 21 / 255, green: 19 / 255, blue: 86 / 255)
    static let backgroundTop = Color(nsColor: .windowBackgroundColor)
    static let backgroundBottom = Color(nsColor: .windowBackgroundColor)
    static let card = Color(nsColor: .controlBackgroundColor)
    static let cardBorder = Color(nsColor: .separatorColor).opacity(0.24)
    static let insetCard = Color(nsColor: .textBackgroundColor)
    static let insetCardBorder = Color(nsColor: .separatorColor).opacity(0.14)
    static let accent = brand500
    static let accentSoft = brand500.opacity(0.10)
    static let ink = Color(nsColor: .labelColor)
    static let muted = Color(nsColor: .secondaryLabelColor)
    static let success = Color(nsColor: .systemGreen)
    static let warning = Color(nsColor: .systemOrange)
}

struct CardSurface: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(18)
            .background(
                RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius, style: .continuous)
                    .fill(AppTheme.card)
            )
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius, style: .continuous)
                    .stroke(AppTheme.cardBorder, lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.02), radius: 8, y: 2)
    }
}

struct InsetSurface: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(11)
            .background(
                RoundedRectangle(cornerRadius: AppTheme.insetCornerRadius, style: .continuous)
                    .fill(AppTheme.insetCard)
            )
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.insetCornerRadius, style: .continuous)
                    .stroke(AppTheme.insetCardBorder, lineWidth: 1)
            )
    }
}

extension View {
    func cardSurface() -> some View {
        modifier(CardSurface())
    }

    func insetSurface() -> some View {
        modifier(InsetSurface())
    }
}

struct StatusPill: View {
    let title: String
    let tint: Color

    var body: some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .foregroundStyle(tint)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(tint.opacity(0.12), in: Capsule())
    }
}
