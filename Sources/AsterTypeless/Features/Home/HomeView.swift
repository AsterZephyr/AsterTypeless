import SwiftUI

struct HomeView: View {
    @ObservedObject var model: TypelessAppModel
    @State private var searchText = ""
    @State private var selectedSessionID: DictationSession.ID?
    @State private var heroIsFloating = false

    var body: some View {
        GeometryReader { _ in
            ZStack(alignment: .topTrailing) {
                background

                workspaceFrame

                if shouldShowHomeHUD {
                    RecordingStatusHUD(model: model)
                        .padding(.top, 48)
                        .padding(.trailing, 48)
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
                    Color(red: 238 / 255, green: 242 / 255, blue: 255 / 255),
                    Color.white,
                    Color(red: 226 / 255, green: 232 / 255, blue: 240 / 255),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            Circle()
                .fill(AppTheme.brand100.opacity(0.58))
                .frame(width: 600, height: 600)
                .blur(radius: 100)
                .offset(x: 430, y: -260)

            Circle()
                .fill(Color(red: 219 / 255, green: 234 / 255, blue: 254 / 255).opacity(0.56))
                .frame(width: 500, height: 500)
                .blur(radius: 80)
                .offset(x: -360, y: 300)
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
        .frame(width: 960, height: 640)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.white.opacity(0.75))
        )
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.white.opacity(0.6), lineWidth: 1)
        }
        .overlay {
            AcousticPatternOverlay()
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .allowsHitTesting(false)
        }
        .shadow(color: Color.black.opacity(0.15), radius: 40, y: 20)
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
