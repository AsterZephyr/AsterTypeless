import SwiftUI

struct AudioPulseView: View {
    let level: Double
    let isSpeaking: Bool

    var body: some View {
        ZStack {
            Circle()
                .fill(AppTheme.accent.opacity(isSpeaking ? 0.18 : 0.08))
                .frame(width: 76, height: 76)
                .blur(radius: isSpeaking ? 4 : 0)
                .scaleEffect(isSpeaking ? 1.02 : 0.96)
                .animation(.easeInOut(duration: 0.18), value: isSpeaking)

            HStack(alignment: .center, spacing: 4) {
                ForEach(0 ..< 7, id: \.self) { index in
                    Capsule(style: .continuous)
                        .fill(isSpeaking ? AppTheme.accent : AppTheme.muted.opacity(0.32))
                        .frame(width: 5, height: barHeight(for: index))
                        .animation(.spring(duration: 0.18, bounce: 0.22), value: level)
                }
            }
        }
        .frame(width: 92, height: 92)
    }

    private func barHeight(for index: Int) -> CGFloat {
        let base = [10.0, 18.0, 30.0, 40.0, 30.0, 18.0, 10.0][index]
        let amplified = base + (level * Double(index + 3) * 7.5)
        return CGFloat(amplified)
    }
}
