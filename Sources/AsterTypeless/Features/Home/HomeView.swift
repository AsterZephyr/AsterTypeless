import SwiftUI

struct HomeView: View {
    @ObservedObject var model: TypelessAppModel
    @State private var searchText = ""
    @State private var selectedSessionID: DictationSession.ID?
    @State private var heroIsFloating = false

    var body: some View {
        ZStack {
            background

            workspaceFrame

            if shouldShowHomeHUD {
                RecordingStatusHUD(model: model)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                    .padding(.top, 48)
                    .padding(.trailing, 48)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea()
        .onAppear {
            if selectedSessionID == nil {
                selectedSessionID = model.sessions.first?.id
            }

            withAnimation(.easeInOut(duration: 3.6).repeatForever(autoreverses: true)) {
                heroIsFloating = true
            }
        }
        .frame(minWidth: 960, minHeight: 640)
    }

    private var shouldShowHomeHUD: Bool {
        model.quickBar.isRecording || model.quickBar.phase == .processing
    }

    private var background: some View {
        AppTheme.backgroundTop
            .ignoresSafeArea()
    }

    private var workspaceFrame: some View {
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
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppTheme.surface.opacity(0.75))
        .background(.ultraThinMaterial)
        .overlay(alignment: .topTrailing) {
            AcousticPatternOverlay()
                .frame(width: 400, height: 400)
                .offset(x: -40, y: -40)
                .opacity(0.3)
                .allowsHitTesting(false)
        }
        .clipped()
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
        .opacity(0.5)
    }
}
