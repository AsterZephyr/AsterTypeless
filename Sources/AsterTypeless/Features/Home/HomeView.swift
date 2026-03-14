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

                workspaceFrame
                    .padding(16)

                if shouldShowHomeHUD {
                    RecordingStatusHUD(model: model)
                        .padding(.top, 28)
                        .padding(.trailing, 28)
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
                    Color(red: 244 / 255, green: 247 / 255, blue: 252 / 255),
                    Color.white,
                    Color(red: 236 / 255, green: 242 / 255, blue: 250 / 255),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            Circle()
                .fill(AppTheme.brand100.opacity(0.45))
                .frame(width: 420, height: 420)
                .blur(radius: 84)
                .offset(x: 250, y: -180)

            Circle()
                .fill(Color(red: 219 / 255, green: 234 / 255, blue: 254 / 255).opacity(0.42))
                .frame(width: 360, height: 360)
                .blur(radius: 70)
                .offset(x: -220, y: 220)
        }
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
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color.white.opacity(0.78))
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
