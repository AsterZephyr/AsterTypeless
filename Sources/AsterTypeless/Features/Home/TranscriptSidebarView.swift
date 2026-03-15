import SwiftUI

struct TranscriptSidebarView: View {
    @ObservedObject var model: TypelessAppModel
    @Binding var searchText: String
    @Binding var selectedSessionID: DictationSession.ID?

    var body: some View {
        VStack(spacing: 0) {
            // Leave space for native traffic lights
            Spacer()
                .frame(height: 52)

            searchField

            ScrollView {
                VStack(alignment: .leading, spacing: 4) {
                    if model.sessions.isEmpty {
                        emptyState
                    } else {
                        ForEach(sessionGroups) { group in
                            VStack(alignment: .leading, spacing: 4) {
                                groupHeader(group.title)

                                ForEach(group.sessions) { session in
                                    Button {
                                        selectedSessionID = session.id
                                    } label: {
                                        SessionSidebarRow(
                                            session: session,
                                            isSelected: session.id == selectedSessionID
                                        )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 12)
            }

            footer
        }
        .background(AppTheme.surface.opacity(0.40))
        .overlay(alignment: .trailing) {
            Rectangle()
                .fill(AppTheme.border.opacity(0.65))
                .frame(width: 1)
        }
    }

    // MARK: - Data

    private var filteredSessions: [DictationSession] {
        let sessions = model.sessions
        guard !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return sessions
        }

        return sessions.filter { session in
            [session.sourceAppName, session.transcriptPreview, session.finalText, session.mode.title]
                .joined(separator: " ")
                .localizedCaseInsensitiveContains(searchText)
        }
    }

    private var sessionGroups: [SessionGroup] {
        let calendar = Calendar.current
        let now = Date()

        let grouped = Dictionary(grouping: filteredSessions) { session -> String in
            if calendar.isDateInToday(session.createdAt) {
                return "Today"
            } else if calendar.isDateInYesterday(session.createdAt) {
                return "Yesterday"
            } else if let weekAgo = calendar.date(byAdding: .day, value: -7, to: now),
                      session.createdAt > weekAgo {
                return "This Week"
            } else {
                return "Earlier"
            }
        }

        let order = ["Today", "Yesterday", "This Week", "Earlier"]
        let sortedKeys = grouped.keys.sorted { lhs, rhs in
            let leftIndex = order.firstIndex(of: lhs) ?? Int.max
            let rightIndex = order.firstIndex(of: rhs) ?? Int.max
            return leftIndex < rightIndex
        }

        return sortedKeys.map { key in
            SessionGroup(
                title: key,
                sessions: grouped[key, default: []].sorted { $0.createdAt > $1.createdAt }
            )
        }
    }

    // MARK: - Subviews

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()
                .frame(height: 40)

            Image(systemName: "waveform.badge.mic")
                .font(.system(size: 36, weight: .light))
                .foregroundStyle(Color(red: 148 / 255, green: 163 / 255, blue: 184 / 255))

            VStack(spacing: 6) {
                Text("No transcripts yet")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color(red: 51 / 255, green: 65 / 255, blue: 85 / 255))

                Text("Start a dictation to see your history here.")
                    .font(.system(size: 12, weight: .regular))
                    .foregroundStyle(Color(red: 100 / 255, green: 116 / 255, blue: 139 / 255))
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 20)
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
        .frame(height: 38)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.white.opacity(0.5))
        )
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color(red: 226 / 255, green: 232 / 255, blue: 240 / 255).opacity(0.8), lineWidth: 1)
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
        .padding(.horizontal, 12)
        .padding(.top, 8)
        .padding(.bottom, 2)
    }

    private var footer: some View {
        HStack {
            HStack(spacing: 8) {
                Circle()
                    .fill(Color.green)
                    .frame(width: 8, height: 8)
                    .shadow(color: Color.green.opacity(0.45), radius: 5)

                Text(model.providerRuntime.canUseOpenAI ? "Provider Ready" : "Engine Ready")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color(red: 71 / 255, green: 85 / 255, blue: 105 / 255))
            }

            Spacer()

            if !model.sessions.isEmpty {
                Text("\(model.sessions.count) sessions")
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
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
        .background(Color.white.opacity(0.30))
    }
}

// MARK: - Supporting types

private struct SessionGroup: Identifiable {
    let id = UUID()
    let title: String
    let sessions: [DictationSession]
}

private struct SessionSidebarRow: View {
    let session: DictationSession
    let isSelected: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                Text(session.sourceAppName.isEmpty ? session.mode.title : session.sourceAppName)
                    .font(.system(size: 13.5, weight: isSelected ? .semibold : .medium))
                    .foregroundStyle(isSelected ? Color(red: 30 / 255, green: 41 / 255, blue: 59 / 255) : Color(red: 51 / 255, green: 65 / 255, blue: 85 / 255))
                    .lineLimit(1)

                Spacer(minLength: 10)

                Text(timestampLabel)
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundStyle(Color(red: 148 / 255, green: 163 / 255, blue: 184 / 255))
            }

            Text(session.transcriptPreview.isEmpty ? session.finalText : session.transcriptPreview)
                .font(.system(size: 12, weight: .regular))
                .foregroundStyle(Color(red: 100 / 255, green: 116 / 255, blue: 139 / 255))
                .lineLimit(isSelected ? 2 : 1)
                .multilineTextAlignment(.leading)

            if isSelected {
                HStack(spacing: 8) {
                    badge(text: durationLabel, icon: "waveform")
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
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.white.opacity(0.82))
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(AppTheme.brand500)
                        .frame(width: 4)
                        .padding(.vertical, 2)
                        .padding(.leading, 0.5)
                } else {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.clear)
                }
            }
        )
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(isSelected ? Color.white.opacity(0.8) : Color.clear, lineWidth: 1)
        }
        .shadow(color: isSelected ? Color.black.opacity(0.06) : .clear, radius: 12, y: 6)
    }

    private var timestampLabel: String {
        let calendar = Calendar.current
        if calendar.isDateInToday(session.createdAt) {
            let formatter = DateFormatter()
            formatter.dateFormat = "HH:mm"
            return formatter.string(from: session.createdAt)
        } else if calendar.isDateInYesterday(session.createdAt) {
            return "Yesterday"
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "MM/dd"
            return formatter.string(from: session.createdAt)
        }
    }

    private var durationLabel: String {
        let minutes = Int(session.durationSeconds) / 60
        let seconds = Int(session.durationSeconds) % 60
        return String(format: "%d:%02d", minutes, seconds)
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
