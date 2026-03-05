import SwiftUI
import SwiftData
import FirebaseFirestore

// Helper class for building the recipe tree asynchronously (class avoids inout+async issues)
private final class RecipeTreeBuilder {
    var visited: Set<String> = []
    var steps: [Step] = []

    struct Step: Identifiable {
        let id = UUID()
        let ing1Name: String
        let ing1Emoji: String
        let ing2Name: String
        let ing2Emoji: String
        let resultName: String
        let resultEmoji: String
        let resultColorHex: String
    }
}

struct ElementDetailView: View {
    let element: DiscoveredElement
    @Environment(\.dismiss) private var dismiss
    @Query private var allElements: [DiscoveredElement]

    @State private var recipeSteps: [RecipeTreeBuilder.Step] = []
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

                    // Árbol de origen
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
        .task { await loadFullTree() }
    }

    // MARK: - Origin section

    private var originSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Árbol de origen")
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
            } else if recipeSteps.isEmpty {
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
            } else {
                VStack(spacing: 6) {
                    ForEach(Array(recipeSteps.enumerated()), id: \.offset) { index, step in
                        stepRow(step: step, stepNumber: index + 1, isLast: index == recipeSteps.count - 1)
                    }
                }
            }
        }
        .padding(.horizontal, 24)
    }

    private func stepRow(step: RecipeTreeBuilder.Step, stepNumber: Int, isLast: Bool) -> some View {
        HStack(spacing: 8) {
            Text("\(stepNumber)")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundStyle(.white.opacity(0.2))
                .frame(width: 16, alignment: .trailing)

            miniChip(name: step.ing1Name, emoji: step.ing1Emoji, colorHex: nil)

            Text("+")
                .font(.system(size: 13, weight: .light))
                .foregroundStyle(.white.opacity(0.3))

            miniChip(name: step.ing2Name, emoji: step.ing2Emoji, colorHex: nil)

            Image(systemName: "arrow.right")
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(.white.opacity(0.2))
                .padding(.horizontal, 2)

            miniChip(name: step.resultName, emoji: step.resultEmoji, colorHex: isLast ? step.resultColorHex : nil)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(.white.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(
                    isLast
                        ? Color.hex(element.colorHex).opacity(0.3)
                        : .white.opacity(0.06),
                    lineWidth: 1
                )
        )
    }

    private func miniChip(name: String, emoji: String, colorHex: String?) -> some View {
        VStack(spacing: 2) {
            Text(emoji)
                .font(.system(size: 18))
            Text(name)
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(.white.opacity(0.6))
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(
            colorHex != nil
                ? Color.hex(colorHex!).opacity(0.15)
                : Color.white.opacity(0.06)
        )
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(
                    colorHex != nil
                        ? Color.hex(colorHex!).opacity(0.3)
                        : Color.clear,
                    lineWidth: 1
                )
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

    // MARK: - Tree loading

    private func loadFullTree() async {
        let baseNames: Set<String> = ["fuego", "agua", "tierra", "aire"]
        guard !baseNames.contains(element.name.lowercased()) else {
            await MainActor.run { originLoading = false }
            return
        }
        let builder = RecipeTreeBuilder()
        await collectRecipes(for: element.name, baseNames: baseNames, builder: builder)
        await MainActor.run {
            recipeSteps = builder.steps
            originLoading = false
        }
    }

    /// Recursively fetches the recipe chain for `name`, adding steps in post-order
    /// so base combinations appear first and the final element last.
    private func collectRecipes(for name: String, baseNames: Set<String>, builder: RecipeTreeBuilder) async {
        let lower = name.lowercased()
        guard !baseNames.contains(lower), !builder.visited.contains(lower) else { return }
        builder.visited.insert(lower)

        do {
            let snapshot = try await Firestore.firestore()
                .collection("recipes")
                .whereField("name", isEqualTo: name)
                .limit(to: 1)
                .getDocuments()

            guard let doc = snapshot.documents.first,
                  let (ing1, ing2) = parseDocId(doc.documentID) else { return }

            // Recurse into ingredients first (post-order)
            await collectRecipes(for: ing1, baseNames: baseNames, builder: builder)
            await collectRecipes(for: ing2, baseNames: baseNames, builder: builder)

            let resultColorHex = allElements.first { $0.name.lowercased() == lower }?.colorHex
                ?? element.colorHex

            builder.steps.append(RecipeTreeBuilder.Step(
                ing1Name: ing1,
                ing1Emoji: getEmoji(ing1),
                ing2Name: ing2,
                ing2Emoji: getEmoji(ing2),
                resultName: name,
                resultEmoji: getEmoji(name),
                resultColorHex: resultColorHex
            ))
        } catch {}
    }

    private func getEmoji(_ name: String) -> String {
        let lower = name.lowercased()
        let baseEmojis = ["fuego": "🔥", "agua": "💧", "tierra": "🌍", "aire": "💨"]
        if let e = baseEmojis[lower] { return e }
        return allElements.first { $0.name.lowercased() == lower }?.emoji ?? "✦"
    }

    private func parseDocId(_ docId: String) -> (String, String)? {
        guard let range = docId.range(of: "_") else { return nil }
        let p1 = String(docId[docId.startIndex..<range.lowerBound]).capitalized
        let p2 = String(docId[range.upperBound...]).capitalized
        return (p1, p2)
    }
}
