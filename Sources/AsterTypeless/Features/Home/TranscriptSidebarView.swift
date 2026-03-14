import SwiftUI

struct TranscriptSidebarView: View {
    @ObservedObject var model: TypelessAppModel
    @Binding var searchText: String
    @Binding var selectedSessionID: DictationSession.ID?

    private let conceptSessions = ConceptTranscript.samples

    var body: some View {
        VStack(spacing: 0) {
            trafficLights
            searchField

            ScrollView {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(sessionGroups) { group in
                        VStack(alignment: .leading, spacing: 4) {
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
                .padding(.bottom, 12)
            }

            footer
        }
        .background(Color.white.opacity(0.40))
        .overlay(alignment: .trailing) {
            Rectangle()
                .fill(Color(red: 226 / 255, green: 232 / 255, blue: 240 / 255).opacity(0.65))
                .frame(width: 1)
        }
    }

    private var filteredSessions: [ConceptTranscript] {
        guard !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return conceptSessions
        }

        return conceptSessions.filter { session in
            [session.title, session.preview, session.metaPrimary, session.metaSecondary]
                .joined(separator: " ")
                .localizedCaseInsensitiveContains(searchText)
        }
    }

    private var sessionGroups: [SidebarSessionGroup] {
        let grouped = Dictionary(grouping: filteredSessions) { session in
            session.sectionTitle
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
                sessions: grouped[key, default: []]
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
        .frame(height: 56)
        .padding(.horizontal, 16)
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

                Text("Engine Ready")
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
        .padding(.vertical, 16)
        .background(Color.white.opacity(0.30))
    }

    private var appVersionLabel: String {
        "v2.1.0"
    }
}

private struct SidebarSessionGroup: Identifiable {
    let id = UUID()
    let title: String
    let sessions: [ConceptTranscript]
}

private struct TranscriptSidebarRow: View {
    let session: ConceptTranscript
    let isSelected: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                Text(session.title)
                    .font(.system(size: 13.5, weight: isSelected ? .semibold : .medium))
                    .foregroundStyle(isSelected ? Color(red: 30 / 255, green: 41 / 255, blue: 59 / 255) : Color(red: 51 / 255, green: 65 / 255, blue: 85 / 255))
                    .lineLimit(1)

                Spacer(minLength: 10)

                Text(session.timestampLabel)
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundStyle(Color(red: 148 / 255, green: 163 / 255, blue: 184 / 255))
            }

            Text(session.preview)
                .font(.system(size: 12, weight: .regular))
                .foregroundStyle(Color(red: 100 / 255, green: 116 / 255, blue: 139 / 255))
                .lineLimit(isSelected ? 2 : 1)
                .multilineTextAlignment(.leading)

            if isSelected {
                HStack(spacing: 8) {
                    badge(text: session.metaPrimary, icon: "waveform")
                    badge(text: session.metaSecondary, icon: "tag")
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

private struct ConceptTranscript: Identifiable {
    let id: UUID
    let sectionTitle: String
    let title: String
    let timestampLabel: String
    let preview: String
    let metaPrimary: String
    let metaSecondary: String

    static let samples: [ConceptTranscript] = [
        ConceptTranscript(
            id: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
            sectionTitle: "Today",
            title: "Docker Compose Setup",
            timestampLabel: "10:42 AM",
            preview: "Note to self: The database container isn't persisting volumes correctly. Need to update the docker-compose.yml to mount a local directory for postgres data.",
            metaPrimary: "0:45",
            metaSecondary: "Dev"
        ),
        ConceptTranscript(
            id: UUID(uuidString: "22222222-2222-2222-2222-222222222222")!,
            sectionTitle: "Today",
            title: "API Rate Limiting",
            timestampLabel: "09:15 AM",
            preview: "We should implement a sliding window rate limiter on the public API endpoints before launch to prevent abuse.",
            metaPrimary: "0:31",
            metaSecondary: "Infra"
        ),
        ConceptTranscript(
            id: UUID(uuidString: "33333333-3333-3333-3333-333333333333")!,
            sectionTitle: "Yesterday",
            title: "Weekly Standup Update",
            timestampLabel: "Yesterday",
            preview: "Finished the React migration for the dashboard. Blocked on design assets for the new settings modal.",
            metaPrimary: "0:28",
            metaSecondary: "Team"
        ),
        ConceptTranscript(
            id: UUID(uuidString: "44444444-4444-4444-4444-444444444444")!,
            sectionTitle: "Yesterday",
            title: "Feature Idea: Webhooks",
            timestampLabel: "Yesterday",
            preview: "What if we allowed users to register webhooks that trigger when a new transcription finishes? Could be useful for Zapier integrations.",
            metaPrimary: "0:39",
            metaSecondary: "Idea"
        ),
        ConceptTranscript(
            id: UUID(uuidString: "55555555-5555-5555-5555-555555555555")!,
            sectionTitle: "Yesterday",
            title: "Bug Report: Safari Audio",
            timestampLabel: "Mon",
            preview: "Audio context isn't resuming properly on Safari after backgrounding. Needs investigation.",
            metaPrimary: "0:21",
            metaSecondary: "Bug"
        ),
    ]
}
