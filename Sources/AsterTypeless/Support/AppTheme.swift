import AppKit
import SwiftUI

enum AppTheme {
    static let cardCornerRadius: CGFloat = 14
    static let insetCornerRadius: CGFloat = 12
    static let backgroundTop = Color(nsColor: .windowBackgroundColor)
    static let backgroundBottom = Color(nsColor: .windowBackgroundColor)
    static let card = Color(nsColor: .controlBackgroundColor)
    static let cardBorder = Color(nsColor: .separatorColor).opacity(0.24)
    static let insetCard = Color(nsColor: .textBackgroundColor)
    static let insetCardBorder = Color(nsColor: .separatorColor).opacity(0.14)
    static let accent = Color.accentColor
    static let accentSoft = Color.accentColor.opacity(0.10)
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
