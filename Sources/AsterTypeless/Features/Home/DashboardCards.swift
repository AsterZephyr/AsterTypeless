import SwiftUI

struct QuickStartCard: View {
    @ObservedObject var model: TypelessAppModel
    let overview: DictationOverview

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            CardHeader(
                eyebrow: "开始使用",
                title: "把口述直接写进当前输入框",
                detail: "把光标放到任意输入框，按住 \(model.settings.primaryTrigger) 说话；如果 `Fn` 还没开好，也可以用 \(model.settings.fallbackShortcut) 直接唤起。"
            )

            HStack(spacing: 10) {
                Button("开始口述") {
                    model.presentQuickBar(trigger: "手动")
                }
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.roundedRectangle)
                .controlSize(.large)
                .tint(AppTheme.accent)

                SettingsLink {
                    Label("打开设置", systemImage: "gearshape")
                }
                .buttonStyle(.bordered)
                .buttonBorderShape(.roundedRectangle)
                .controlSize(.large)

                Spacer()

                StatusPill(title: quickStartState, tint: quickStartTint)
            }

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 132), spacing: 10)], spacing: 10) {
                CompactMetricTile(title: "总口述时间", value: "\(overview.totalMinutes)", unit: "分钟")
                CompactMetricTile(title: "总口述字数", value: "\(overview.totalWords)", unit: "字")
                CompactMetricTile(title: "节省时间", value: "\(overview.savedMinutes)", unit: "分钟")
                CompactMetricTile(title: "平均速度", value: "\(overview.averageWordsPerMinute)", unit: "WPM")
            }

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 160), spacing: 10)], spacing: 10) {
                KeyValueTile(title: "主触发键", value: model.settings.primaryTrigger)
                KeyValueTile(title: "回退快捷键", value: model.settings.fallbackShortcut)
                KeyValueTile(title: "输出语言", value: model.settings.outputLanguage)
                KeyValueTile(title: "最近写回", value: model.insertionAttempts.first?.appName ?? "还没有样本")
            }

            HStack(spacing: 8) {
                StatusPill(title: "麦克风 \(model.permissions.microphone.label)", tint: color(for: model.permissions.microphone))
                StatusPill(title: "辅助功能 \(model.permissions.accessibility.label)", tint: color(for: model.permissions.accessibility))
            }

            if needsSetup {
                Label("首次使用需要先在设置里打开权限，系统才知道该往哪里写回文本。", systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundStyle(AppTheme.muted)
                    .insetSurface()
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

struct PersonaReportCard: View {
    let report: PersonaReport

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            CardHeader(
                eyebrow: "Personalization",
                title: report.title,
                detail: report.summary
            )

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 180), spacing: 10)], spacing: 10) {
                KeyValueTile(title: "当前状态", value: report.personalizationState)
                KeyValueTile(title: "推荐语气", value: report.tonePreset)
            }

            if !report.focusApps.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Text("高频场景")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppTheme.muted)
                    FlowTagCloud(tags: report.focusApps)
                }
                .insetSurface()
            }

            if !report.traits.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Text("表达偏好")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppTheme.muted)
                    FlowTagCloud(tags: report.traits)
                }
                .insetSurface()
            }

            VStack(alignment: .leading, spacing: 10) {
                ForEach(report.suggestions, id: \.self) { suggestion in
                    Label(suggestion, systemImage: "sparkles")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(AppTheme.ink)
                }
            }
            .insetSurface()
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

        return VStack(alignment: .leading, spacing: 18) {
            CardHeader(
                eyebrow: "反馈与写回",
                title: "最近活动",
                detail: "只保留用户会关心的结果：采用、修改、重试，以及最近一次写回。"
            )

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: 10)], spacing: 10) {
                FeedbackCountTile(title: "直接采用", value: "\(accepted)")
                FeedbackCountTile(title: "手动修改", value: "\(edited)")
                FeedbackCountTile(title: "重新生成", value: "\(retried)")
            }

            if let latest = model.sessions.first {
                VStack(alignment: .leading, spacing: 8) {
                    Text("最近一次最终转录")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppTheme.muted)
                    Text(latest.finalText)
                        .font(.body.weight(.medium))
                        .foregroundStyle(AppTheme.ink)
                        .lineLimit(4)
                    Text("来自 \(latest.sourceAppName) · \(latest.createdAt.formatted(date: .abbreviated, time: .shortened))")
                        .font(.caption)
                        .foregroundStyle(AppTheme.muted)
                }
                .insetSurface()
            }

            if let latestInsertion = model.insertionAttempts.first {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("最近一次写回")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(AppTheme.muted)
                        Spacer()
                        StatusPill(title: latestInsertion.method.title, tint: latestInsertion.success ? AppTheme.success : AppTheme.warning)
                    }

                    Text(latestInsertion.appName.isEmpty ? "未知 App" : latestInsertion.appName)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppTheme.ink)

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
        let recentSessions = Array(sessions.prefix(4))

        return VStack(alignment: .leading, spacing: 18) {
            CardHeader(
                eyebrow: "记录",
                title: "最近转录与最终输出",
                detail: "只保留最后几次口述，方便你回看来源、最终输出和采用结果。"
            )

            if recentSessions.isEmpty {
                Text("还没有历史记录。完成几次口述后，这里会自动出现最近输出。")
                    .font(.callout)
                    .foregroundStyle(AppTheme.muted)
                    .padding(.vertical, 6)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(recentSessions.enumerated()), id: \.element.id) { index, session in
                        HistorySessionRow(session: session)

                        if index < recentSessions.count - 1 {
                            Divider()
                                .padding(.vertical, 2)
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardSurface()
    }
}

private struct CardHeader: View {
    let eyebrow: String
    let title: String
    let detail: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(eyebrow)
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppTheme.accent)
            Text(title)
                .font(.title3.weight(.semibold))
                .foregroundStyle(AppTheme.ink)
            Text(detail)
                .font(.callout)
                .foregroundStyle(AppTheme.muted)
        }
    }
}

private struct KeyValueTile: View {
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

private struct CompactMetricTile: View {
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

private struct FeedbackCountTile: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppTheme.muted)
            Text(value)
                .font(.title2.weight(.bold))
                .foregroundStyle(AppTheme.ink)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .insetSurface()
    }
}

private struct HistorySessionRow: View {
    let session: DictationSession

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(session.sourceAppName)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.ink)
                StatusPill(title: session.feedback.title, tint: session.feedback == .accepted ? AppTheme.success : AppTheme.warning)
                Spacer()
                Text(session.createdAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption)
                    .foregroundStyle(AppTheme.muted)
            }

            Text(session.finalText)
                .font(.body.weight(.medium))
                .foregroundStyle(AppTheme.ink)
                .lineLimit(3)

            Text(session.transcriptPreview)
                .font(.subheadline)
                .foregroundStyle(AppTheme.muted)
                .lineLimit(2)

            Text("\(session.words) words · \(Int(session.durationSeconds))s · \(session.mode.title)")
                .font(.caption)
                .foregroundStyle(AppTheme.muted)
        }
        .padding(.vertical, 12)
    }
}

private struct FlowTagCloud: View {
    let tags: [String]

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 96), spacing: 8)], alignment: .leading, spacing: 8) {
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
