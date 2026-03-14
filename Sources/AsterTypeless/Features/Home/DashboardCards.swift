import SwiftUI

struct QuickStartCard: View {
    @ObservedObject var model: TypelessAppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("开始使用")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppTheme.accent)
                    Text("把口述留给浮窗")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(AppTheme.ink)
                }
                Spacer()
                StatusPill(title: quickStartState, tint: quickStartTint)
            }

            Text("把光标放到任意输入框，按住 \(model.settings.primaryTrigger) 说话；如果 `Fn` 还没开好，也可以用 \(model.settings.fallbackShortcut) 直接唤起。")
                .font(.callout)
                .foregroundStyle(AppTheme.muted)

            LabeledRow(title: "主触发键", value: model.settings.primaryTrigger)
            LabeledRow(title: "回退快捷键", value: model.settings.fallbackShortcut)
            LabeledRow(title: "输出语言", value: model.settings.outputLanguage)
            LabeledRow(title: "最近写回", value: model.insertionAttempts.first?.appName ?? "还没有样本")

            Divider()

            HStack {
                StatusPill(title: "麦克风 \(model.permissions.microphone.label)", tint: color(for: model.permissions.microphone))
                StatusPill(title: "辅助功能 \(model.permissions.accessibility.label)", tint: color(for: model.permissions.accessibility))
            }

            if needsSetup {
                Text("首次使用需要在设置里打开权限，系统才知道该往哪里写回文本。")
                    .font(.caption)
                    .foregroundStyle(AppTheme.muted)
            }

            HStack {
                Button("开始口述") {
                    model.presentQuickBar(trigger: "手动")
                }
                .buttonStyle(.borderedProminent)
                .tint(AppTheme.accent)

                SettingsLink {
                    Label("去设置", systemImage: "gearshape")
                }
                .buttonStyle(.bordered)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardSurface()
    }

    private func color(for state: PermissionState) -> Color {
        switch state {
        case .granted:
            return AppTheme.success
        case .required:
            return AppTheme.warning
        case .unavailable:
            return AppTheme.muted
        }
    }

    private var needsSetup: Bool {
        model.permissions.accessibility != .granted || model.permissions.microphone != .granted
    }

    private var quickStartState: String {
        needsSetup ? "需先授权" : "可以开始"
    }

    private var quickStartTint: Color {
        needsSetup ? AppTheme.warning : AppTheme.success
    }
}

struct DictationReportCard: View {
    let overview: DictationOverview

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("口述报告")
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppTheme.accent)
            Text("本地统计概览")
                .font(.title3.weight(.semibold))
                .foregroundStyle(AppTheme.ink)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                MetricTile(title: "总口述时间", value: "\(overview.totalMinutes)", unit: "分钟")
                MetricTile(title: "总口述字数", value: "\(overview.totalWords)", unit: "字")
                MetricTile(title: "节省时间", value: "\(overview.savedMinutes)", unit: "分钟")
                MetricTile(title: "平均速度", value: "\(overview.averageWordsPerMinute)", unit: "WPM")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardSurface()
    }
}

struct PersonaReportCard: View {
    let report: PersonaReport

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Personalization")
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppTheme.accent)
            Text(report.title)
                .font(.title3.weight(.semibold))
                .foregroundStyle(AppTheme.ink)
            Text(report.summary)
                .font(.callout)
                .foregroundStyle(AppTheme.muted)

            HStack(spacing: 12) {
                PersonaSummaryTile(title: "当前状态", value: report.personalizationState)
                PersonaSummaryTile(title: "推荐语气", value: report.tonePreset)
            }

            if !report.focusApps.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("高频场景")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppTheme.muted)
                    FlowTagCloud(tags: report.focusApps)
                }
            }

            FlowTagCloud(tags: report.traits)

            VStack(alignment: .leading, spacing: 10) {
                ForEach(report.suggestions, id: \.self) { suggestion in
                    Label(suggestion, systemImage: "sparkles")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(AppTheme.ink)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardSurface()
    }
}

private struct PersonaSummaryTile: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppTheme.muted)
            Text(value)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.ink)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .insetSurface()
    }
}

struct FeedbackHubCard: View {
    @ObservedObject var model: TypelessAppModel

    var body: some View {
        let accepted = model.sessions.filter { $0.feedback == .accepted }.count
        let edited = model.sessions.filter { $0.feedback == .edited }.count
        let retried = model.sessions.filter { $0.feedback == .retried }.count

        return VStack(alignment: .leading, spacing: 16) {
            Text("反馈与转录")
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppTheme.accent)
            Text("入口归类")
                .font(.title3.weight(.semibold))
                .foregroundStyle(AppTheme.ink)

            LabeledRow(title: "最近记录", value: "\(min(model.sessions.count, 4)) 条")
            LabeledRow(title: "直接采用", value: "\(accepted) 次")
            LabeledRow(title: "手动修改", value: "\(edited) 次")
            LabeledRow(title: "重新生成", value: "\(retried) 次")

            if let latest = model.sessions.first {
                VStack(alignment: .leading, spacing: 8) {
                    Text("最近一次最终转录")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppTheme.muted)
                    Text(latest.finalText)
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.ink)
                        .lineLimit(4)
                }
                .insetSurface()
            }

            if let latestInsertion = model.insertionAttempts.first {
                VStack(alignment: .leading, spacing: 8) {
                    Text("最近一次写回")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppTheme.muted)
                    HStack {
                        StatusPill(title: latestInsertion.method.title, tint: latestInsertion.success ? AppTheme.success : AppTheme.warning)
                        Text(latestInsertion.appName.isEmpty ? "未知 App" : latestInsertion.appName)
                            .font(.caption.weight(.medium))
                            .foregroundStyle(AppTheme.ink)
                    }
                    Text(latestInsertion.detail)
                        .font(.caption)
                        .foregroundStyle(AppTheme.muted)
                        .lineLimit(2)
                }
                .insetSurface()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardSurface()
    }
}

struct TranscriptHistoryCard: View {
    let sessions: [DictationSession]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("记录")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppTheme.accent)
                    Text("最近转录与最终输出")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(AppTheme.ink)
                }
                Spacer()
                StatusPill(title: "\(sessions.count) 项", tint: AppTheme.muted)
            }

            ForEach(sessions.prefix(6)) { session in
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(session.sourceAppName)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(AppTheme.ink)
                        StatusPill(title: session.mode.title, tint: AppTheme.accent)
                        Spacer()
                        Text(session.createdAt.formatted(date: .abbreviated, time: .shortened))
                            .font(.caption)
                            .foregroundStyle(AppTheme.muted)
                    }

                    Text(session.transcriptPreview)
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.muted)
                        .lineLimit(2)

                    Text(session.finalText)
                        .font(.body.weight(.medium))
                        .foregroundStyle(AppTheme.ink)
                        .lineLimit(3)

                    HStack {
                        StatusPill(title: session.feedback.title, tint: session.feedback == .accepted ? AppTheme.success : AppTheme.warning)
                        Text("\(session.words) words · \(Int(session.durationSeconds))s")
                            .font(.caption)
                            .foregroundStyle(AppTheme.muted)
                    }
                }
                .insetSurface()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardSurface()
    }
}

private struct LabeledRow: View {
    let title: String
    let value: String

    var body: some View {
        HStack {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(AppTheme.muted)
            Spacer()
            Text(value)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.ink)
        }
    }
}

private struct MetricTile: View {
    let title: String
    let value: String
    let unit: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppTheme.muted)
            HStack(alignment: .lastTextBaseline, spacing: 4) {
                Text(value)
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(AppTheme.ink)
                Text(unit)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(AppTheme.muted)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .insetSurface()
    }
}

private struct FlowTagCloud: View {
    let tags: [String]

    var body: some View {
        HStack(spacing: 8) {
            ForEach(tags, id: \.self) { tag in
                Text(tag)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppTheme.accent)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(AppTheme.accentSoft, in: Capsule())
            }
        }
    }
}
