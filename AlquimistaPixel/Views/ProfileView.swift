import SwiftUI
import SwiftData

struct ProfileView: View {
    @Query private var discoveredElements: [DiscoveredElement]
    @Environment(\.dismiss) private var dismiss
    private let userService = UserService()

    var body: some View {
        NavigationStack {
            VStack(spacing: 28) {
                // Avatar
                VStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(.white.opacity(0.06))
                            .frame(width: 100, height: 100)
                        Circle()
                            .strokeBorder(.white.opacity(0.1), lineWidth: 1)
                            .frame(width: 100, height: 100)
                        Text("⚗️")
                            .font(.system(size: 50))
                    }
                    .padding(.top, 32)

                    Text(userService.username)
                        .font(.system(size: 26, weight: .black, design: .rounded))
                        .foregroundStyle(.white)

                    Text("Alquimista")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.white.opacity(0.35))
                        .textCase(.uppercase)
                        .tracking(1.2)
                }

                // Stats
                LazyVGrid(
                    columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)],
                    spacing: 12
                ) {
                    statCard(
                        value: "\(discoveredElements.count)",
                        label: "Elementos\ndescubiertos",
                        icon: "sparkles"
                    )
                    statCard(
                        value: joinDateText,
                        label: "Alquimista\ndesde",
                        icon: "calendar"
                    )
                }
                .padding(.horizontal, 24)

                Spacer()
            }
            .frame(maxWidth: .infinity)
            .background(Color(red: 2/255, green: 6/255, blue: 23/255))
            .navigationTitle("Perfil")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cerrar") { dismiss() }
                        .font(.subheadline.bold())
                        .foregroundStyle(.white)
                }
            }
            .toolbarBackground(Color(red: 2/255, green: 6/255, blue: 23/255), for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
    }

    private var joinDateText: String {
        guard let date = userService.joinedAt else { return "—" }
        return date.formatted(.dateTime.day().month(.abbreviated).year())
    }

    private func statCard(value: String, label: String, icon: String) -> some View {
        VStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 22))
                .foregroundStyle(.white.opacity(0.4))
            Text(value)
                .font(.system(size: 36, weight: .black, design: .rounded))
                .foregroundStyle(.white)
                .contentTransition(.numericText())
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .textCase(.uppercase)
                .foregroundStyle(.white.opacity(0.35))
                .tracking(0.3)
                .multilineTextAlignment(.center)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 22)
        .background(.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(.white.opacity(0.08), lineWidth: 1))
    }
}
