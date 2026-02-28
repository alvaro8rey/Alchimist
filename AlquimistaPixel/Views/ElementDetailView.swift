import SwiftUI
import SwiftData
import FirebaseFirestore

struct ElementDetailView: View {
    let element: DiscoveredElement
    @Environment(\.dismiss) private var dismiss
    @Query private var allElements: [DiscoveredElement]

    // Recipe origin state
    @State private var recipeOrigin: (String, String)? = nil
    @State private var originLoading = true

    private var currentUsername: String { UserService().username }
    private var isOwnDiscovery: Bool {
        !element.creatorName.isEmpty && element.creatorName == currentUsername
    }
    private var discovererText: String {
        if element.creatorName.isEmpty { return "Elemento base" }
        return isOwnDiscovery ? "Tú" : element.creatorName
    }
    private let bg = Color(red: 2/255, green: 6/255, blue: 23/255)

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Emoji con halo
                    ZStack {
                        Circle()
                            .fill(Color.hex(element.colorHex).opacity(0.18))
                            .frame(width: 130, height: 130)
                        Circle()
                            .strokeBorder(Color.hex(element.colorHex).opacity(0.35), lineWidth: 1.5)
                            .frame(width: 130, height: 130)
                        Text(element.emoji)
                            .font(.system(size: 64))
                    }
                    .padding(.top, 20)

                    Text(element.name)
                        .font(.system(size: 30, weight: .black, design: .rounded))
                        .foregroundStyle(.white)

                    // Info cards
                    VStack(spacing: 10) {
                        infoRow(
                            icon: isOwnDiscovery ? "star.fill" : "person.fill",
                            label: "Primer descubridor",
                            value: discovererText,
                            valueColor: isOwnDiscovery ? Color.hex(element.colorHex) : .white
                        )
                        infoRow(
                            icon: "calendar",
                            label: "En tu colección desde",
                            value: element.discoveryDate.formatted(date: .long, time: .omitted)
                        )
                        colorRow
                    }
                    .padding(.horizontal, 24)

                    // Origen
                    originSection
                        .padding(.bottom, 36)
                }
                .frame(maxWidth: .infinity)
            }
            .background(bg)
            .navigationTitle(element.name)
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
        .task { await loadOrigin() }
    }

    // MARK: - Origin section

    private var originSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Origen")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.white.opacity(0.5))
                    .textCase(.uppercase)
                    .tracking(0.9)
                Spacer()
            }

            if originLoading {
                HStack {
                    Spacer()
                    ProgressView().tint(.white.opacity(0.35))
                    Spacer()
                }
                .frame(height: 64)
                .background(.white.opacity(0.04))
                .clipShape(RoundedRectangle(cornerRadius: 14))
            } else if let (ing1, ing2) = recipeOrigin {
                HStack(spacing: 8) {
                    ingredientChip(ing1)
                    Text("+")
                        .font(.system(size: 18, weight: .light))
                        .foregroundStyle(.white.opacity(0.35))
                    ingredientChip(ing2)
                    Image(systemName: "arrow.right")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.25))
                        .padding(.horizontal, 4)
                    resultChip
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(.white.opacity(0.04))
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .strokeBorder(.white.opacity(0.07), lineWidth: 1)
                )
            } else {
                HStack(spacing: 8) {
                    Image(systemName: "sparkle")
                        .font(.system(size: 13))
                        .foregroundStyle(.white.opacity(0.3))
                    Text("Elemento base del juego")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.white.opacity(0.4))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.white.opacity(0.04))
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .strokeBorder(.white.opacity(0.07), lineWidth: 1)
                )
            }
        }
        .padding(.horizontal, 24)
    }

    private func ingredientChip(_ name: String) -> some View {
        let match = allElements.first { $0.name.lowercased() == name.lowercased() }
        return VStack(spacing: 3) {
            Text(match?.emoji ?? "✦")
                .font(.system(size: 22))
            Text(name)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.white.opacity(0.65))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(.white.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private var resultChip: some View {
        VStack(spacing: 3) {
            Text(element.emoji)
                .font(.system(size: 22))
            Text(element.name)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.white.opacity(0.65))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color.hex(element.colorHex).opacity(0.18))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(Color.hex(element.colorHex).opacity(0.35), lineWidth: 1)
        )
    }

    // MARK: - Info rows

    private var colorRow: some View {
        HStack {
            Image(systemName: "paintpalette")
                .font(.system(size: 14))
                .foregroundStyle(.white.opacity(0.4))
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 4) {
                Text("Color")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white.opacity(0.35))
                HStack(spacing: 8) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.hex(element.colorHex))
                        .frame(width: 18, height: 18)
                    Text(element.colorHex.uppercased())
                        .font(.system(size: 15, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.white)
                }
            }
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private func infoRow(icon: String, label: String, value: String, valueColor: Color = .white) -> some View {
        HStack {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(.white.opacity(0.4))
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 4) {
                Text(label)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white.opacity(0.35))
                Text(value)
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundStyle(valueColor)
            }
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    // MARK: - Data

    private func loadOrigin() async {
        let baseNames = ["fuego", "agua", "tierra", "aire"]
        guard !baseNames.contains(element.name.lowercased()) else {
            await MainActor.run { originLoading = false }
            return
        }
        do {
            let snapshot = try await Firestore.firestore()
                .collection("recipes")
                .whereField("name", isEqualTo: element.name)
                .limit(to: 1)
                .getDocuments()

            if let doc = snapshot.documents.first {
                let parsed = parseDocId(doc.documentID)
                await MainActor.run {
                    recipeOrigin = parsed
                    originLoading = false
                }
            } else {
                await MainActor.run { originLoading = false }
            }
        } catch {
            await MainActor.run { originLoading = false }
        }
    }

    private func parseDocId(_ docId: String) -> (String, String)? {
        guard let range = docId.range(of: "_") else { return nil }
        let p1 = String(docId[docId.startIndex..<range.lowerBound]).capitalized
        let p2 = String(docId[range.upperBound...]).capitalized
        return (p1, p2)
    }
}
