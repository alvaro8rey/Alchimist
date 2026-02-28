import SwiftUI

struct ElementDetailView: View {
    let element: DiscoveredElement
    @Environment(\.dismiss) private var dismiss

    private var currentUsername: String { UserService().username }

    private var isOwnDiscovery: Bool {
        !element.creatorName.isEmpty && element.creatorName == currentUsername
    }

    private var discovererText: String {
        if element.creatorName.isEmpty { return "Elemento base" }
        return isOwnDiscovery ? "Tú" : element.creatorName
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Emoji con halo de color
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
                    .padding(.bottom, 32)
                }
                .frame(maxWidth: .infinity)
            }
            .background(Color(red: 2/255, green: 6/255, blue: 23/255))
            .navigationTitle(element.name)
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
}
