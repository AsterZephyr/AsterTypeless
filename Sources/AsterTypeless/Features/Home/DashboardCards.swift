import SwiftUI

struct SettingsSummaryCard: View {
    @ObservedObject var model: TypelessAppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("设置")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(AppTheme.accent)
                    Text("核心开关")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(AppTheme.ink)
                }
                Spacer()
                StatusPill(title: model.settings.primaryTrigger, tint: AppTheme.accent)
            }

            LabeledRow(title: "主触发键", value: model.settings.primaryTrigger)
            LabeledRow(title: "回退快捷键", value: model.settings.fallbackShortcut)
            LabeledRow(title: "麦克风", value: model.settings.microphoneName)
            LabeledRow(title: "输出语言", value: model.settings.outputLanguage)
            LabeledRow(title: "Provider", value: model.settings.providerDisplayName)
            LabeledRow(title: "配置来源", value: model.providerRuntime.sourceDescription)

            Divider()

            HStack {
                StatusPill(title: "辅助功能 \(model.permissions.accessibility.label)", tint: color(for: model.permissions.accessibility))
                StatusPill(title: "麦克风 \(model.permissions.microphone.label)", tint: color(for: model.permissions.microphone))
                StatusPill(title: "Fn 监听 \(model.permissions.inputMonitoring.label)", tint: color(for: model.permissions.inputMonitoring))
            }

            HStack {
                StatusPill(title: "Deepgram \(model.providerRuntime.deepgramConfigured ? "已配置" : "未配置")", tint: model.providerRuntime.deepgramConfigured ? AppTheme.success : AppTheme.warning)
                StatusPill(title: "OpenAI \(model.providerRuntime.openAIConfigured ? "已配置" : "未配置")", tint: model.providerRuntime.openAIConfigured ? AppTheme.success : AppTheme.warning)
                StatusPill(title: model.providerRuntime.executionMode.title, tint: providerTint)
            }

            HStack {
                StatusPill(title: "已测 \(model.insertionOverview.testedApps) 个 App", tint: AppTheme.muted)
                StatusPill(title: "AX 直写 \(model.insertionOverview.directWrites)", tint: AppTheme.success)
                StatusPill(title: "回退 \(model.insertionOverview.clipboardFallbacks)", tint: AppTheme.warning)
                StatusPill(title: "失败 \(model.insertionOverview.failures)", tint: model.insertionOverview.failures > 0 ? AppTheme.warning : AppTheme.muted)
            }

            HStack {
                Button("请求辅助功能权限") {
                    model.requestAccessibilityPermission()
                }
                .buttonStyle(.bordered)

                Button("请求 Fn 权限") {
                    model.requestInputMonitoringPermission()
                }
                .buttonStyle(.bordered)

                Button("刷新 Provider 状态") {
                    model.refreshRuntimeConfiguration()
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

    private var providerTint: Color {
        switch model.providerRuntime.executionMode {
        case .mockReady:
            return AppTheme.muted
        case .partial:
            return AppTheme.warning
        case .providerReady:
            return AppTheme.success
        }
    }
}

struct DictationReportCard: View {
    let overview: DictationOverview

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("口述报告")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(AppTheme.accent)
            Text("本地统计概览")
                .font(.system(size: 22, weight: .bold))
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
            Text("个人画像")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(AppTheme.accent)
            Text(report.title)
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(AppTheme.ink)
            Text(report.summary)
                .font(.system(size: 14))
                .foregroundStyle(AppTheme.muted)

            FlowTagCloud(tags: report.traits)

            VStack(alignment: .leading, spacing: 10) {
                ForEach(report.suggestions, id: \.self) { suggestion in
                    Label(suggestion, systemImage: "sparkles")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(AppTheme.ink)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardSurface()
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
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(AppTheme.accent)
            Text("入口归类")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(AppTheme.ink)

            LabeledRow(title: "最近记录", value: "\(min(model.sessions.count, 4)) 条")
            LabeledRow(title: "直接采用", value: "\(accepted) 次")
            LabeledRow(title: "手动修改", value: "\(edited) 次")
            LabeledRow(title: "重新生成", value: "\(retried) 次")

            if let latest = model.sessions.first {
                VStack(alignment: .leading, spacing: 8) {
                    Text("最近一次最终转录")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(AppTheme.muted)
                    Text(latest.finalText)
                        .font(.system(size: 13))
                        .foregroundStyle(AppTheme.ink)
                        .lineLimit(4)
                }
                .padding(12)
                .background(AppTheme.accentSoft, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }

            if let latestInsertion = model.insertionAttempts.first {
                VStack(alignment: .leading, spacing: 8) {
                    Text("最近一次写回")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(AppTheme.muted)
                    HStack {
                        StatusPill(title: latestInsertion.method.title, tint: latestInsertion.success ? AppTheme.success : AppTheme.warning)
                        Text(latestInsertion.appName.isEmpty ? "未知 App" : latestInsertion.appName)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(AppTheme.ink)
                    }
                    Text(latestInsertion.detail)
                        .font(.system(size: 12))
                        .foregroundStyle(AppTheme.muted)
                        .lineLimit(2)
                }
                .padding(12)
                .background(Color.white.opacity(0.56), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
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
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(AppTheme.accent)
                    Text("最近转录与最终输出")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(AppTheme.ink)
                }
                Spacer()
                StatusPill(title: "\(sessions.count) 项", tint: AppTheme.muted)
            }

            ForEach(sessions.prefix(6)) { session in
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(session.sourceAppName)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(AppTheme.ink)
                        StatusPill(title: session.mode.title, tint: AppTheme.accent)
                        Spacer()
                        Text(session.createdAt.formatted(date: .abbreviated, time: .shortened))
                            .font(.system(size: 12))
                            .foregroundStyle(AppTheme.muted)
                    }

                    Text(session.transcriptPreview)
                        .font(.system(size: 13))
                        .foregroundStyle(AppTheme.muted)
                        .lineLimit(2)

                    Text(session.finalText)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(AppTheme.ink)
                        .lineLimit(3)

                    HStack {
                        StatusPill(title: session.feedback.title, tint: session.feedback == .accepted ? AppTheme.success : AppTheme.warning)
                        Text("\(session.words) words · \(Int(session.durationSeconds))s")
                            .font(.system(size: 12))
                            .foregroundStyle(AppTheme.muted)
                    }
                }
                .padding(14)
                .background(Color.white.opacity(0.58), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
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
                .font(.system(size: 13))
                .foregroundStyle(AppTheme.muted)
            Spacer()
            Text(value)
                .font(.system(size: 13, weight: .semibold))
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
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(AppTheme.muted)
            HStack(alignment: .lastTextBaseline, spacing: 4) {
                Text(value)
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(AppTheme.ink)
                Text(unit)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(AppTheme.muted)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color.white.opacity(0.56), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

private struct FlowTagCloud: View {
    let tags: [String]

    var body: some View {
        HStack(spacing: 8) {
            ForEach(tags, id: \.self) { tag in
                Text(tag)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(AppTheme.accent)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(AppTheme.accentSoft, in: Capsule())
            }
        }
    }
}
