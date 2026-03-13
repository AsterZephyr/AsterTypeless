import SwiftUI

struct FloatingBarView: View {
    @ObservedObject var model: TypelessAppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(model.quickBar.targetAppName.isEmpty ? "Quick Dictation" : model.quickBar.targetAppName)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(AppTheme.ink)
                    Text(model.quickBar.statusText)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(AppTheme.muted)
                }

                Spacer()

                StatusPill(title: model.quickBar.triggerLabel, tint: model.quickBar.isRecording ? AppTheme.warning : AppTheme.accent)
            }

            HStack(spacing: 12) {
                AudioPulseView(level: model.quickBar.smoothedLevel, isSpeaking: model.quickBar.isSpeaking)
                Text(model.quickBar.isRecording ? "正在捕获语音输入" : "待机中")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(model.quickBar.isRecording ? AppTheme.ink : AppTheme.muted)
                Spacer()
                if !model.quickBar.selectedContextPreview.isEmpty {
                    Text(model.quickBar.selectedContextPreview)
                        .font(.system(size: 12))
                        .foregroundStyle(AppTheme.muted)
                        .lineLimit(1)
                }
            }

            Picker("Mode", selection: $model.quickBar.mode) {
                ForEach(QuickActionMode.allCases) { mode in
                    Text(mode.title).tag(mode)
                }
            }
            .pickerStyle(.segmented)

            TextEditor(text: $model.quickBar.transcriptDraft)
                .font(.system(size: 14, weight: .medium))
                .scrollContentBackground(.hidden)
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color.white.opacity(0.74))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(AppTheme.cardBorder, lineWidth: 1)
                )
                .frame(minHeight: 108)

            HStack {
                Button(model.quickBar.isRecording ? "停止" : "录音") {
                    model.quickBar.isRecording ? model.stopRecording() : model.startRecording()
                }
                .buttonStyle(.borderedProminent)

                Button("运行") {
                    model.runQuickAction()
                }
                .buttonStyle(.borderedProminent)
                .tint(AppTheme.accent)

                Button("关闭") {
                    model.dismissQuickBar()
                }
                .buttonStyle(.bordered)

                Spacer()

                if !model.quickBar.generatedText.isEmpty {
                    Text("已生成结果")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(AppTheme.success)
                }
            }
        }
        .padding(18)
        .background(
            LinearGradient(
                colors: [
                    Color.white.opacity(0.86),
                    Color(red: 0.95, green: 0.93, blue: 0.89).opacity(0.86),
                ],
                startPoint: .top,
                endPoint: .bottom
            ),
            in: RoundedRectangle(cornerRadius: 24, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(AppTheme.cardBorder, lineWidth: 1)
        )
        .padding(12)
        .frame(width: 438)
    }
}

