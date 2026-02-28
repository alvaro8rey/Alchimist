import SwiftUI
import SwiftData

struct ProfileView: View {
    @Query(sort: \DiscoveredElement.discoveryDate, order: .reverse)
    private var elements: [DiscoveredElement]
    @Environment(\.dismiss) private var dismiss
    @State private var selectedElement: DiscoveredElement? = nil
    private let userService = UserService()

    private var username: String { userService.username }
    private var primiciasCount: Int {
        guard !username.isEmpty else { return 0 }
        return elements.filter { $0.creatorName == username }.count
    }
    private var latestElement: DiscoveredElement? { elements.first }
    private var firstElement: DiscoveredElement? { elements.last }

    private let bg = Color(red: 2/255, green: 6/255, blue: 23/255)

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 28) {
                    avatarSection
                    statsSection
                    if !elements.isEmpty { collectionSection }
                    if !elements.isEmpty { recentSection }
                }
                .padding(.bottom, 48)
            }
            .background(bg)
            .navigationTitle("Perfil")
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
        .sheet(item: $selectedElement) { element in
            ElementDetailView(element: element)
                .preferredColorScheme(.dark)
        }
    }

    // MARK: - Avatar

    private var avatarSection: some View {
        VStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(LinearGradient(
                        colors: [.white.opacity(0.1), .white.opacity(0.03)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                    .frame(width: 100, height: 100)
                Circle()
                    .strokeBorder(.white.opacity(0.12), lineWidth: 1)
                    .frame(width: 100, height: 100)
                Text("⚗️")
                    .font(.system(size: 52))
            }
            .padding(.top, 28)

            Text(username)
                .font(.system(size: 26, weight: .black, design: .rounded))
                .foregroundStyle(.white)

            HStack(spacing: 5) {
                Image(systemName: "flask.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(.white.opacity(0.3))
                Text("Alquimista")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.3))
                    .textCase(.uppercase)
                    .tracking(1.4)
            }
        }
    }

    // MARK: - Stats

    private var statsSection: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                bigStatCard(
                    value: "\(elements.count)",
                    label: "Elementos",
                    icon: "sparkles",
                    accentColor: .white
                )
                bigStatCard(
                    value: "\(primiciasCount)",
                    label: "Primicias",
                    icon: "star.fill",
                    accentColor: Color(red: 1, green: 0.85, blue: 0.3)
                )
            }
            HStack(spacing: 10) {
                infoCard(icon: "calendar", label: "Alquimista desde", value: joinDateText)
                if let el = latestElement {
                    Button { selectedElement = el } label: {
                        infoCard(
                            icon: nil,
                            label: "Último descubrimiento",
                            value: el.name,
                            emoji: el.emoji,
                            accentColor: Color.hex(el.colorHex)
                        )
                    }
                    .buttonStyle(.plain)
                } else {
                    infoCard(icon: "questionmark", label: "Último descubrimiento", value: "—")
                }
            }
        }
        .padding(.horizontal, 20)
    }

    // MARK: - Collection

    private var collectionSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader("Mi colección", badge: "\(elements.count)")

            let cols = Array(repeating: GridItem(.flexible(), spacing: 8), count: 6)
            LazyVGrid(columns: cols, spacing: 8) {
                ForEach(elements) { element in
                    Button { selectedElement = element } label: {
                        ZStack {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.hex(element.colorHex).opacity(0.18))
                            RoundedRectangle(cornerRadius: 12)
                                .strokeBorder(Color.hex(element.colorHex).opacity(0.35), lineWidth: 1)
                            Text(element.emoji)
                                .font(.system(size: 26))
                        }
                        .frame(height: 52)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.horizontal, 20)
    }

    // MARK: - Recent

    private var recentSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader("Últimos descubrimientos", badge: nil)

            VStack(spacing: 6) {
                ForEach(elements.prefix(8)) { element in
                    Button { selectedElement = element } label: {
                        HStack(spacing: 12) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(Color.hex(element.colorHex).opacity(0.2))
                                Text(element.emoji)
                                    .font(.system(size: 22))
                            }
                            .frame(width: 44, height: 44)

                            VStack(alignment: .leading, spacing: 3) {
                                Text(element.name)
                                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                                    .foregroundStyle(.white)
                                Text(element.discoveryDate.formatted(date: .abbreviated, time: .omitted))
                                    .font(.system(size: 12))
                                    .foregroundStyle(.white.opacity(0.35))
                            }

                            Spacer()

                            if element.creatorName == username && !element.creatorName.isEmpty {
                                Image(systemName: "star.fill")
                                    .font(.system(size: 11))
                                    .foregroundStyle(Color(red: 1, green: 0.85, blue: 0.3).opacity(0.9))
                            }

                            Image(systemName: "chevron.right")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(.white.opacity(0.2))
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(.white.opacity(0.04))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .strokeBorder(.white.opacity(0.06), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.horizontal, 20)
    }

    // MARK: - Sub-components

    private func sectionHeader(_ title: String, badge: String?) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(.white.opacity(0.5))
                .textCase(.uppercase)
                .tracking(0.9)
            Spacer()
            if let badge {
                Text(badge)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.3))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(.white.opacity(0.07))
                    .clipShape(Capsule())
            }
        }
    }

    private func bigStatCard(value: String, label: String, icon: String, accentColor: Color) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundStyle(accentColor.opacity(0.65))
            Text(value)
                .font(.system(size: 40, weight: .black, design: .rounded))
                .foregroundStyle(accentColor)
                .contentTransition(.numericText())
                .lineLimit(1)
                .minimumScaleFactor(0.5)
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .textCase(.uppercase)
                .foregroundStyle(.white.opacity(0.35))
                .tracking(0.4)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 22)
        .background(.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(.white.opacity(0.08), lineWidth: 1))
    }

    private func infoCard(
        icon: String?,
        label: String,
        value: String,
        emoji: String? = nil,
        accentColor: Color = .white
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 5) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.3))
                } else if let emoji {
                    Text(emoji)
                        .font(.system(size: 16))
                }
                Text(label)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.white.opacity(0.3))
                    .textCase(.uppercase)
                    .tracking(0.5)
                    .lineLimit(1)
            }
            Text(value)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(accentColor)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 14)
        .padding(.vertical, 14)
        .background(.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(.white.opacity(0.08), lineWidth: 1))
    }

    private var joinDateText: String {
        guard let date = userService.joinedAt else { return "—" }
        return date.formatted(.dateTime.day().month(.abbreviated).year())
    }
}
