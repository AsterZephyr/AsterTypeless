import SwiftUI

struct HomeView: View {
    @ObservedObject var model: TypelessAppModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header

                HStack(alignment: .top, spacing: 16) {
                    QuickStartCard(model: model)
                    DictationReportCard(overview: model.overview)
                }

                HStack(alignment: .top, spacing: 16) {
                    PersonaReportCard(report: model.personaReport)
                    FeedbackHubCard(model: model)
                }

                TranscriptHistoryCard(sessions: model.sessions)
            }
            .padding(24)
            .frame(maxWidth: 1040)
            .frame(maxWidth: .infinity)
        }
        .background(background)
        .toolbar {
            ToolbarItemGroup {
                Button {
                    model.presentQuickBar(trigger: "手动")
                } label: {
                    Label("快速口述", systemImage: "mic.fill")
                }

                SettingsLink {
                    Label("设置", systemImage: "gearshape")
                }
            }
        }
        .frame(minWidth: 920, minHeight: 720)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("AsterTypeless")
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppTheme.accent)
            Text("像输入法一样开始口述，把想法直接写进当前输入框。")
                .font(.title.weight(.bold))
                .foregroundStyle(AppTheme.ink)
            Text("首页只保留口述报告、个性化摘要和最近记录。真正的输入动作留给浮窗和菜单栏。")
                .font(.callout)
                .foregroundStyle(AppTheme.muted)
        }
    }

    private var background: some View {
        AppTheme.backgroundTop
    }
}
