import SwiftUI
import FirebaseFirestore

struct LeaderboardEntry: Identifiable {
    let id: String
    let rank: Int
    let username: String
    let count: Int
}

struct LeaderboardView: View {
    @State private var entries: [LeaderboardEntry] = []
    @State private var isLoading = true
    @Environment(\.dismiss) private var dismiss

    private let db = Firestore.firestore()
    private let currentUsername = UserService().username
    private let bg = Color(red: 2/255, green: 6/255, blue: 23/255)

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    if isLoading {
                        loadingView
                    } else if entries.isEmpty {
                        emptyView
                    } else {
                        if entries.count >= 3 {
                            podiumSection
                        }
                        listSection
                    }
                }
                .padding(.bottom, 48)
            }
            .background(bg)
            .navigationTitle("Ranking Global")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cerrar") { dismiss() }
                        .font(.subheadline.bold())
                        .foregroundStyle(.white)
                }
            }
            .toolbarBackground(bg, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
        .task { await loadLeaderboard() }
    }

    // MARK: - Loading / Empty

    private var loadingView: some View {
        VStack {
            Spacer().frame(height: 100)
            ProgressView()
                .tint(.white.opacity(0.4))
                .scaleEffect(1.3)
        }
    }

    private var emptyView: some View {
        VStack(spacing: 14) {
            Spacer().frame(height: 80)
            Text("🏆")
                .font(.system(size: 54))
            Text("Aún no hay datos")
                .font(.system(size: 17, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.45))
            Text("Descubre elementos para aparecer aquí")
                .font(.system(size: 13))
                .foregroundStyle(.white.opacity(0.25))
        }
    }

    // MARK: - Podium

    private var podiumSection: some View {
        HStack(alignment: .bottom, spacing: 10) {
            podiumBlock(entries[1], barHeight: 72, medal: "🥈")
            podiumBlock(entries[0], barHeight: 104, medal: "🥇")
            podiumBlock(entries[2], barHeight: 52, medal: "🥉")
        }
        .padding(.horizontal, 24)
        .padding(.top, 28)
        .padding(.bottom, 8)
    }

    private func podiumBlock(_ entry: LeaderboardEntry, barHeight: CGFloat, medal: String) -> some View {
        let isMe = entry.username == currentUsername
        return VStack(spacing: 6) {
            Text(medal)
                .font(.system(size: 28))
            Text(entry.username)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(isMe ? Color(red: 1, green: 0.85, blue: 0.3) : .white)
                .lineLimit(1)
                .minimumScaleFactor(0.65)
            Text("\(entry.count)")
                .font(.system(size: 20, weight: .black, design: .rounded))
                .foregroundStyle(.white)
            RoundedRectangle(cornerRadius: 10)
                .fill(
                    isMe
                        ? Color(red: 1, green: 0.85, blue: 0.3).opacity(0.22)
                        : Color.white.opacity(0.07)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(
                            isMe
                                ? Color(red: 1, green: 0.85, blue: 0.3).opacity(0.4)
                                : Color.white.opacity(0.1),
                            lineWidth: 1
                        )
                )
                .frame(height: barHeight)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - List

    private var listSection: some View {
        VStack(spacing: 6) {
            ForEach(entries) { entry in
                rankRow(entry)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, entries.count >= 3 ? 20 : 40)
    }

    private func rankRow(_ entry: LeaderboardEntry) -> some View {
        let isMe = entry.username == currentUsername
        let medalEmoji: String? = entry.rank == 1 ? "🥇" : entry.rank == 2 ? "🥈" : entry.rank == 3 ? "🥉" : nil
        return HStack(spacing: 12) {
            if let medal = medalEmoji {
                Text(medal)
                    .font(.system(size: 18))
                    .frame(width: 36)
            } else {
                Text("#\(entry.rank)")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.3))
                    .frame(width: 36, alignment: .center)
            }

            Text(entry.username)
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(isMe ? Color(red: 1, green: 0.85, blue: 0.3) : .white)
                .lineLimit(1)

            Spacer()

            HStack(spacing: 5) {
                Image(systemName: "sparkles")
                    .font(.system(size: 10))
                    .foregroundStyle(.white.opacity(0.3))
                Text("\(entry.count)")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
        .background(
            isMe
                ? Color(red: 1, green: 0.85, blue: 0.3).opacity(0.08)
                : Color.white.opacity(0.04)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(
                    isMe
                        ? Color(red: 1, green: 0.85, blue: 0.3).opacity(0.25)
                        : Color.white.opacity(0.06),
                    lineWidth: 1
                )
        )
    }

    // MARK: - Data

    private func loadLeaderboard() async {
        do {
            let snapshot = try await db.collection("users")
                .order(by: "discoveryCount", descending: true)
                .limit(to: 20)
                .getDocuments()

            var result: [LeaderboardEntry] = []
            for (index, doc) in snapshot.documents.enumerated() {
                let data = doc.data()
                let username = data["username"] as? String ?? "???"
                let count = data["discoveryCount"] as? Int ?? 0
                guard count > 0 else { continue }
                result.append(LeaderboardEntry(
                    id: doc.documentID,
                    rank: index + 1,
                    username: username,
                    count: count
                ))
            }
            await MainActor.run {
                entries = result
                isLoading = false
            }
        } catch {
            await MainActor.run { isLoading = false }
        }
    }
}
