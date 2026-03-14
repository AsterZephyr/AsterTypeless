import SwiftUI

struct FloatingBarView: View {
    @ObservedObject var model: TypelessAppModel

    var body: some View {
        VStack(alignment: .leading, spacing: model.quickBar.isCompactLayout ? 12 : 14) {
            header

            listeningHero

            if !model.quickBar.isCompactLayout {
                composer
                actionBar
            } else {
                compactFooter
            }
        }
        .padding(model.quickBar.isCompactLayout ? 16 : 18)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius + 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius + 8, style: .continuous)
                .stroke(AppTheme.cardBorder, lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.08), radius: 20, y: 10)
        .padding(12)
        .frame(width: model.quickBar.isCompactLayout ? 308 : 404)
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                Text(model.quickBar.targetAppName.isEmpty ? "Quick Dictation" : model.quickBar.targetAppName)
                    .font(.headline)
                    .foregroundStyle(AppTheme.ink)
                Text(model.quickBar.statusText)
                    .font(.caption)
                    .foregroundStyle(AppTheme.muted)
                    .lineLimit(model.quickBar.isCompactLayout ? 2 : 3)
            }

            Spacer(minLength: 12)

            VStack(alignment: .trailing, spacing: 8) {
                StatusPill(title: model.quickBar.phase.title, tint: phaseTint)
                StatusPill(title: model.quickBar.captureMode.title, tint: captureModeTint)
            }
        }
    }

    private var listeningHero: some View {
        VStack(spacing: 10) {
            AudioPulseView(level: model.quickBar.smoothedLevel, isSpeaking: model.quickBar.isSpeaking)

            Text(primaryListeningLabel)
                .font(model.quickBar.isCompactLayout ? .subheadline.weight(.semibold) : .body.weight(.semibold))
                .foregroundStyle(AppTheme.ink)

            if !model.quickBar.selectedContextPreview.isEmpty {
                Text(model.quickBar.selectedContextPreview)
                    .font(.caption)
                    .foregroundStyle(AppTheme.muted)
                    .lineLimit(model.quickBar.isCompactLayout ? 2 : 3)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 10)
            }

            if model.quickBar.capturedDuration > 0 {
                Text("本次录音 \(String(format: "%.1f", model.quickBar.capturedDuration)) 秒")
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(AppTheme.muted)
            } else if model.quickBar.holdDuration > 0 {
                Text("本次按住 \(String(format: "%.1f", model.quickBar.holdDuration)) 秒")
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(AppTheme.muted)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, model.quickBar.isCompactLayout ? 2 : 4)
    }

    private var composer: some View {
        VStack(alignment: .leading, spacing: 12) {
            Picker("Mode", selection: $model.quickBar.mode) {
                ForEach(QuickActionMode.allCases) { mode in
                    Text(mode.title).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .controlSize(.large)

            TextEditor(text: $model.quickBar.transcriptDraft)
                .font(.body)
                .scrollContentBackground(.hidden)
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: AppTheme.insetCornerRadius, style: .continuous)
                        .fill(AppTheme.insetCard)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: AppTheme.insetCornerRadius, style: .continuous)
                        .stroke(AppTheme.insetCardBorder, lineWidth: 1)
                )
                .frame(minHeight: 98)

            if !model.quickBar.generatedText.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text(model.quickBar.generatedSourceLabel.isEmpty ? "生成结果" : "生成结果 · \(model.quickBar.generatedSourceLabel)")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppTheme.success)
                    Text(model.quickBar.generatedText)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(AppTheme.ink)
                        .lineLimit(4)
                }
                .insetSurface()
            }
        }
    }

    private var actionBar: some View {
        HStack {
            Button(model.quickBar.isRecording ? "停止" : "录音") {
                model.quickBar.isRecording ? model.stopRecording() : model.startRecording()
            }
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.roundedRectangle)
            .controlSize(.large)
            .tint(model.quickBar.isRecording ? AppTheme.warning : AppTheme.accent)

            Button("运行") {
                model.runQuickAction()
            }
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.roundedRectangle)
            .controlSize(.large)
            .tint(AppTheme.accent)

            Button("关闭") {
                model.dismissQuickBar()
            }
            .buttonStyle(.bordered)
            .buttonBorderShape(.roundedRectangle)
            .controlSize(.large)

            Spacer()
        }
    }

    private var compactFooter: some View {
        HStack {
            Label(model.quickBar.mode.subtitle, systemImage: model.quickBar.isRecording ? "waveform" : "mic")
                .font(.caption.weight(.medium))
                .foregroundStyle(AppTheme.muted)

            Spacer()

            Button("关闭") {
                model.dismissQuickBar()
            }
            .buttonStyle(.plain)
            .font(.caption.weight(.semibold))
            .foregroundStyle(AppTheme.muted)
        }
    }

    private var primaryListeningLabel: String {
        switch model.quickBar.phase {
        case .armed:
            switch model.quickBar.captureMode {
            case .holdToTalk:
                return "按住 Fn 开始口述"
            case .tapToggle:
                return "轻点 Fn 开始录音"
            case .handsFree:
                return "已进入 hands-free"
            case .manual:
                return "准备开始"
            }
        case .recording:
            return model.quickBar.isSpeaking ? "正在捕获你的语音" : "继续说话，浮窗会跟着声音抖动"
        case .processing:
            return "正在整理当前输入"
        case .ready:
            return model.quickBar.generatedText.isEmpty ? "可以继续编辑或直接运行" : "结果已准备好"
        case .idle:
            return "待机中"
        }
    }

    private var captureModeTint: Color {
        switch model.quickBar.captureMode {
        case .manual, .tapToggle:
            return AppTheme.accent
        case .holdToTalk:
            return AppTheme.warning
        case .handsFree:
            return AppTheme.success
        }
    }

    private var phaseTint: Color {
        switch model.quickBar.phase {
        case .idle, .armed:
            return AppTheme.accent
        case .recording:
            return AppTheme.warning
        case .processing:
            return AppTheme.muted
        case .ready:
            return AppTheme.success
        }
    }
}
