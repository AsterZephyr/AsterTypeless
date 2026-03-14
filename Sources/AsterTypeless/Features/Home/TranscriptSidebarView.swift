import SwiftUI

struct TranscriptSidebarView: View {
    @ObservedObject var model: TypelessAppModel
    @Binding var searchText: String
    @Binding var selectedSessionID: DictationSession.ID?

    var body: some View {
        VStack(spacing: 0) {
            trafficLights
            searchField

            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(sessionGroups) { group in
                        VStack(alignment: .leading, spacing: 6) {
                            groupHeader(group.title)

                            ForEach(group.sessions) { session in
                                Button {
                                    selectedSessionID = session.id
                                } label: {
                                    TranscriptSidebarRow(
                                        session: session,
                                        isSelected: session.id == selectedSessionID
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 14)
            }

            footer
        }
        .background(Color.white.opacity(0.38))
        .background(.ultraThinMaterial.opacity(0.92))
        .overlay(alignment: .trailing) {
            Rectangle()
                .fill(Color(red: 226 / 255, green: 232 / 255, blue: 240 / 255).opacity(0.65))
                .frame(width: 1)
        }
    }

    private var filteredSessions: [DictationSession] {
        guard !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return model.sessions
        }

        return model.sessions.filter { session in
            [session.finalText, session.transcriptPreview, session.sourceAppName, session.mode.title]
                .joined(separator: " ")
                .localizedCaseInsensitiveContains(searchText)
        }
    }

    private var sessionGroups: [SidebarSessionGroup] {
        let calendar = Calendar.current
        let today = Date()

        let grouped = Dictionary(grouping: filteredSessions) { session -> String in
            if calendar.isDate(session.createdAt, inSameDayAs: today) {
                return "Today"
            }

            if let yesterday = calendar.date(byAdding: .day, value: -1, to: today),
               calendar.isDate(session.createdAt, inSameDayAs: yesterday) {
                return "Yesterday"
            }

            return session.createdAt.formatted(.dateTime.weekday(.abbreviated))
        }

        let order = ["Today", "Yesterday"]
        let sortedKeys = grouped.keys.sorted { lhs, rhs in
            let leftIndex = order.firstIndex(of: lhs) ?? Int.max
            let rightIndex = order.firstIndex(of: rhs) ?? Int.max
            if leftIndex != rightIndex {
                return leftIndex < rightIndex
            }
            return lhs < rhs
        }

        return sortedKeys.map { key in
            SidebarSessionGroup(
                title: key,
                sessions: grouped[key, default: []].sorted { $0.createdAt > $1.createdAt }
            )
        }
    }

    private var trafficLights: some View {
        HStack(spacing: 8) {
            Circle().fill(Color(red: 248 / 255, green: 113 / 255, blue: 113 / 255)).frame(width: 12, height: 12)
            Circle().fill(Color(red: 250 / 255, green: 204 / 255, blue: 21 / 255)).frame(width: 12, height: 12)
            Circle().fill(Color(red: 74 / 255, green: 222 / 255, blue: 128 / 255)).frame(width: 12, height: 12)
            Spacer()
        }
        .padding(.horizontal, 18)
        .padding(.top, 16)
        .padding(.bottom, 12)
    }

    private var searchField: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Color(red: 148 / 255, green: 163 / 255, blue: 184 / 255))

            TextField("Search transcripts...", text: $searchText)
                .textFieldStyle(.plain)
                .font(.system(size: 14, weight: .medium))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.white.opacity(0.58))
        )
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color(red: 226 / 255, green: 232 / 255, blue: 240 / 255).opacity(0.9), lineWidth: 1)
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 16)
    }

    private func groupHeader(_ title: String) -> some View {
        HStack(spacing: 8) {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Color(red: 148 / 255, green: 163 / 255, blue: 184 / 255))
                .textCase(.uppercase)
                .tracking(1.1)

            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 226 / 255, green: 232 / 255, blue: 240 / 255),
                            .clear,
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(height: 1)
        }
        .padding(.horizontal, 8)
        .padding(.top, 6)
    }

    private var footer: some View {
        HStack {
            HStack(spacing: 8) {
                Circle()
                    .fill(Color.green)
                    .frame(width: 8, height: 8)
                    .shadow(color: Color.green.opacity(0.45), radius: 5)

                Text(model.providerRuntime.executionMode == .providerReady ? "Engine Ready" : "Prototype Ready")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color(red: 71 / 255, green: 85 / 255, blue: 105 / 255))
            }

            Spacer()

            Text(appVersionLabel)
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundStyle(Color(red: 148 / 255, green: 163 / 255, blue: 184 / 255))
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(Color.white.opacity(0.45))
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .stroke(Color(red: 226 / 255, green: 232 / 255, blue: 240 / 255).opacity(0.9), lineWidth: 1)
                }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(Color.white.opacity(0.28))
    }

    private var appVersionLabel: String {
        let shortVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.1.0"
        return "v\(shortVersion)"
    }
}

private struct SidebarSessionGroup: Identifiable {
    let id = UUID()
    let title: String
    let sessions: [DictationSession]
}

private struct TranscriptSidebarRow: View {
    let session: DictationSession
    let isSelected: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                Text(title)
                    .font(.system(size: 14, weight: isSelected ? .semibold : .medium))
                    .foregroundStyle(isSelected ? Color(red: 30 / 255, green: 41 / 255, blue: 59 / 255) : Color(red: 51 / 255, green: 65 / 255, blue: 85 / 255))
                    .lineLimit(1)

                Spacer(minLength: 10)

                Text(timestamp)
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(Color(red: 148 / 255, green: 163 / 255, blue: 184 / 255))
            }

            Text(session.transcriptPreview)
                .font(.system(size: 12, weight: .regular))
                .foregroundStyle(Color(red: 100 / 255, green: 116 / 255, blue: 139 / 255))
                .lineLimit(isSelected ? 2 : 1)
                .multilineTextAlignment(.leading)

            if isSelected {
                HStack(spacing: 8) {
                    badge(text: durationText, icon: "waveform")
                    badge(text: session.mode.title, icon: "tag")
                }
                .padding(.top, 2)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            ZStack(alignment: .leading) {
                if isSelected {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.white.opacity(0.82))
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(AppTheme.brand500)
                        .frame(width: 4)
                        .padding(.vertical, 3)
                        .padding(.leading, 1)
                } else {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.clear)
                }
            }
        )
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(isSelected ? Color.white.opacity(0.8) : Color.clear, lineWidth: 1)
        }
        .shadow(color: isSelected ? Color.black.opacity(0.06) : .clear, radius: 12, y: 6)
    }

    private var title: String {
        let raw = session.finalText.isEmpty ? session.transcriptPreview : session.finalText
        let cleaned = raw.replacingOccurrences(of: "\n", with: " ")
        let words = cleaned.split(separator: " ").prefix(3).joined(separator: " ")
        return words.isEmpty ? session.sourceAppName : words
    }

    private var timestamp: String {
        if Calendar.current.isDateInToday(session.createdAt) {
            return session.createdAt.formatted(.dateTime.hour().minute())
        }

        if Calendar.current.isDateInYesterday(session.createdAt) {
            return "Yesterday"
        }

        return session.createdAt.formatted(.dateTime.weekday(.abbreviated))
    }

    private var durationText: String {
        "0:\(String(format: "%02d", Int(session.durationSeconds.rounded())))"
    }

    private func badge(text: String, icon: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .bold))
            Text(text)
                .font(.system(size: 10, weight: .semibold))
        }
        .foregroundStyle(icon == "waveform" ? AppTheme.brand700 : Color(red: 148 / 255, green: 163 / 255, blue: 184 / 255))
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(icon == "waveform" ? AppTheme.brand50 : Color.clear)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(icon == "waveform" ? AppTheme.brand100 : Color.clear, lineWidth: 1)
        }
    }
}
