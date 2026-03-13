import SwiftUI

struct HomeView: View {
    @ObservedObject var model: TypelessAppModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header

                HStack(alignment: .top, spacing: 16) {
                    SettingsSummaryCard(model: model)
                    DictationReportCard(overview: model.overview)
                }

                HStack(alignment: .top, spacing: 16) {
                    PersonaReportCard(report: model.personaReport)
                    FeedbackHubCard(model: model)
                }

                TranscriptHistoryCard(sessions: model.sessions)
            }
            .padding(24)
            .frame(maxWidth: 1160)
            .frame(maxWidth: .infinity)
        }
        .background(background)
        .frame(minWidth: 980, minHeight: 760)
    }

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Typeless for macOS")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(AppTheme.accent)
                Text("把首页变成概览页，而不是一张操作表单。")
                    .font(.system(size: 30, weight: .bold))
                    .foregroundStyle(AppTheme.ink)
                Text("设置、口述报告、个人画像和反馈记录都收在同一层里。真正的输入动作留给小浮窗。")
                    .font(.system(size: 14))
                    .foregroundStyle(AppTheme.muted)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 10) {
                Button("打开浮窗") {
                    model.presentQuickBar(trigger: "手动")
                }
                .buttonStyle(.borderedProminent)
                .tint(AppTheme.accent)

                SettingsLink {
                    Label("设置", systemImage: "gearshape")
                }
                .buttonStyle(.bordered)
            }
        }
        .cardSurface()
    }

    private var background: some View {
        LinearGradient(
            colors: [AppTheme.backgroundTop, AppTheme.backgroundBottom],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .overlay(alignment: .topLeading) {
            Circle()
                .fill(AppTheme.accent.opacity(0.08))
                .frame(width: 280, height: 280)
                .blur(radius: 30)
                .offset(x: -20, y: -40)
        }
    }
}

