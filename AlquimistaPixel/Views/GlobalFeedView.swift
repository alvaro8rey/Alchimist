import SwiftUI
import FirebaseFirestore

struct FeedEntry: Identifiable {
    let id: String
    let name: String
    let emoji: String
    let colorHex: String
    let creatorName: String
    let createdAt: Date?
    let ingredient1: String
    let ingredient2: String
}

struct GlobalFeedView: View {
    @State private var entries: [FeedEntry] = []
    @State private var isLoading = true
    @State private var listener: ListenerRegistration? = nil
    @Environment(\.dismiss) private var dismiss

    private let db = Firestore.firestore()
    private let currentUsername = UserService().username
    private let bg = Color(red: 2/255, green: 6/255, blue: 23/255)

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 8) {
                    if isLoading {
                        Spacer().frame(height: 80)
                        ProgressView()
                            .tint(.white.opacity(0.4))
                            .scaleEffect(1.3)
                    } else if entries.isEmpty {
                        emptyView
                    } else {
                        ForEach(entries) { entry in
                            feedRow(entry)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 40)
            }
            .background(bg)
            .navigationTitle("Descubrimientos Globales")
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
        .onAppear { startListening() }
        .onDisappear { listener?.remove(); listener = nil }
    }

    // MARK: - Empty state

    private var emptyView: some View {
        VStack(spacing: 14) {
            Spacer().frame(height: 80)
            Text("🌍")
                .font(.system(size: 54))
            Text("Aún no hay descubrimientos")
                .font(.system(size: 17, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.45))
            Text("¡Sé el primero en combinar algo nuevo!")
                .font(.system(size: 13))
                .foregroundStyle(.white.opacity(0.25))
        }
    }

    // MARK: - Row

    private func feedRow(_ entry: FeedEntry) -> some View {
        let isMe = entry.creatorName == currentUsername
        return HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.hex(entry.colorHex).opacity(0.2))
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(Color.hex(entry.colorHex).opacity(0.3), lineWidth: 1)
                Text(entry.emoji)
                    .font(.system(size: 26))
            }
            .frame(width: 50, height: 50)

            VStack(alignment: .leading, spacing: 4) {
                Text(entry.name)
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)

                Text("\(entry.ingredient1) + \(entry.ingredient2)")
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.4))

                HStack(spacing: 5) {
                    Text(isMe ? "Tú" : entry.creatorName)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(
                            isMe
                                ? Color(red: 1, green: 0.85, blue: 0.3)
                                : Color.white.opacity(0.5)
                        )
                    if let date = entry.createdAt {
                        Text("·")
                            .foregroundStyle(.white.opacity(0.2))
                            .font(.system(size: 10))
                        Text(relativeTime(date))
                            .font(.system(size: 12))
                            .foregroundStyle(.white.opacity(0.3))
                    }
                }
            }

            Spacer()

            if isMe {
                Image(systemName: "star.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(Color(red: 1, green: 0.85, blue: 0.3).opacity(0.85))
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .background(
            isMe
                ? Color(red: 1, green: 0.85, blue: 0.3).opacity(0.06)
                : Color.white.opacity(0.04)
        )
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(
                    isMe
                        ? Color(red: 1, green: 0.85, blue: 0.3).opacity(0.2)
                        : Color.white.opacity(0.06),
                    lineWidth: 1
                )
        )
    }

    // MARK: - Realtime listener

    private func startListening() {
        guard listener == nil else { return }
        listener = db.collection("recipes")
            .order(by: "createdAt", descending: true)
            .limit(to: 40)
            .addSnapshotListener { snapshot, _ in
                guard let snapshot else {
                    Task { @MainActor in isLoading = false }
                    return
                }
                let parsed: [FeedEntry] = snapshot.documents.compactMap { doc in
                    let data = doc.data()
                    guard
                        let name = data["name"] as? String,
                        let emoji = data["emoji"] as? String
                    else { return nil }
                    let colorHex    = data["color"] as? String ?? "#FFFFFF"
                    let creatorName = data["creatorName"] as? String ?? ""
                    let date        = (data["createdAt"] as? Timestamp)?.dateValue()
                    let (ing1, ing2) = parseDocId(doc.documentID)
                    return FeedEntry(
                        id: doc.documentID,
                        name: name,
                        emoji: emoji,
                        colorHex: colorHex,
                        creatorName: creatorName,
                        createdAt: date,
                        ingredient1: ing1,
                        ingredient2: ing2
                    )
                }
                Task { @MainActor in
                    entries = parsed
                    isLoading = false
                }
            }
    }

    // MARK: - Helpers

    private func parseDocId(_ docId: String) -> (String, String) {
        // Key format: "[item1]_[item2]" (items sorted, lowercased).
        // Split at the first "_" so multi-word names (e.g. "monte carlo") are preserved.
        if let range = docId.range(of: "_") {
            let p1 = String(docId[docId.startIndex..<range.lowerBound]).capitalized
            let p2 = String(docId[range.upperBound...]).capitalized
            return (p1, p2)
        }
        return (docId.capitalized, "")
    }

    private func relativeTime(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}
