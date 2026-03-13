import SwiftUI

struct ReadinessCard: View {
    let report: ReadinessReport

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("主链路体检")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(AppTheme.accent)
                    Text(report.headline)
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(AppTheme.ink)
                    Text(report.summary)
                        .font(.system(size: 14))
                        .foregroundStyle(AppTheme.muted)
                }

                Spacer()

                StatusPill(title: report.overallLevel.title, tint: tint(for: report.overallLevel))
            }

            VStack(spacing: 10) {
                ForEach(report.items) { item in
                    HStack(alignment: .top, spacing: 12) {
                        Circle()
                            .fill(tint(for: item.level))
                            .frame(width: 9, height: 9)
                            .padding(.top, 5)

                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(item.title)
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(AppTheme.ink)
                                Spacer()
                                Text(item.level.title)
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(tint(for: item.level))
                            }

                            Text(item.detail)
                                .font(.system(size: 13))
                                .foregroundStyle(AppTheme.muted)
                        }
                    }
                    .padding(12)
                    .background(Color.white.opacity(0.6), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardSurface()
    }

    private func tint(for level: ReadinessLevel) -> Color {
        switch level {
        case .ready:
            return AppTheme.success
        case .attention:
            return AppTheme.warning
        case .blocked:
            return AppTheme.accent
        }
    }
}
