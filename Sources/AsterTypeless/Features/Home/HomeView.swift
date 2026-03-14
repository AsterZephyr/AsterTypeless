import SwiftUI

struct HomeView: View {
    @ObservedObject var model: TypelessAppModel
    @State private var searchText = ""
    @State private var selectedSessionID: DictationSession.ID?
    @State private var heroIsFloating = false

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .topTrailing) {
                background

                workspaceFrame(size: proxy.size)

                if shouldShowHomeHUD {
                    RecordingStatusHUD(model: model)
                        .padding(.top, 42)
                        .padding(.trailing, 42)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .onAppear {
            selectedSessionID = selectedSessionID ?? UUID(uuidString: "11111111-1111-1111-1111-111111111111")

            withAnimation(.easeInOut(duration: 3.6).repeatForever(autoreverses: true)) {
                heroIsFloating = true
            }
        }
        .frame(minWidth: 1180, minHeight: 760)
    }

    private var shouldShowHomeHUD: Bool {
        model.quickBar.isRecording || model.quickBar.phase == .processing
    }

    private var background: some View {
        ZStack {
            LinearGradient(
                colors: [
                    AppTheme.brand50.opacity(0.95),
                    Color.white,
                    Color(nsColor: .windowBackgroundColor),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            Circle()
                .fill(AppTheme.brand200.opacity(0.55))
                .frame(width: 600, height: 600)
                .blur(radius: 100)
                .offset(x: 360, y: -260)

            Circle()
                .fill(Color.blue.opacity(0.16))
                .frame(width: 500, height: 500)
                .blur(radius: 82)
                .offset(x: -330, y: 280)
        }
    }

    @ViewBuilder
    private func workspaceFrame(size: CGSize) -> some View {
        let width = min(max(size.width - 96, 960), 1100)
        let height = min(max(size.height - 92, 640), 700)

        HStack(spacing: 0) {
            TranscriptSidebarView(
                model: model,
                searchText: $searchText,
                selectedSessionID: $selectedSessionID
            )
            .frame(width: 320)

            CaptureHeroView(model: model, isFloating: heroIsFloating)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(width: width, height: height)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color.white.opacity(0.72))
        )
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color.white.opacity(0.65), lineWidth: 1)
        }
        .overlay {
            AcousticPatternOverlay()
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                .allowsHitTesting(false)
        }
        .shadow(color: Color.black.opacity(0.14), radius: 40, y: 18)
    }
}

private struct AcousticPatternOverlay: View {
    var body: some View {
        Canvas { context, size in
            let spacing: CGFloat = 60
            for x in stride(from: spacing / 2, through: size.width, by: spacing) {
                for y in stride(from: spacing / 2, through: size.height, by: spacing) {
                    let outer = CGRect(x: x - 15, y: y - 15, width: 30, height: 30)
                    let inner = CGRect(x: x - 8, y: y - 8, width: 16, height: 16)
                    context.stroke(
                        Path(ellipseIn: outer),
                        with: .color(Color(red: 100 / 255, green: 116 / 255, blue: 139 / 255).opacity(0.05)),
                        lineWidth: 1
                    )
                    context.stroke(
                        Path(ellipseIn: inner),
                        with: .color(Color(red: 100 / 255, green: 116 / 255, blue: 139 / 255).opacity(0.03)),
                        lineWidth: 1
                    )
                }
            }
        }
        .opacity(0.42)
    }
}
