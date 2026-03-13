import SwiftUI

struct AudioPulseView: View {
    let level: Double
    let isSpeaking: Bool

    var body: some View {
        HStack(alignment: .center, spacing: 5) {
            ForEach(0 ..< 5, id: \.self) { index in
                Capsule(style: .continuous)
                    .fill(isSpeaking ? AppTheme.accent : AppTheme.muted.opacity(0.35))
                    .frame(width: 7, height: barHeight(for: index))
                    .animation(.spring(duration: 0.24), value: level)
            }
        }
        .frame(height: 34)
    }

    private func barHeight(for index: Int) -> CGFloat {
        let base = [10.0, 16.0, 24.0, 16.0, 10.0][index]
        let amplified = base + (level * Double(index + 2) * 8)
        return CGFloat(amplified)
    }
}

