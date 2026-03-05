import SwiftUI

struct CombinationHistoryView: View {
    let history: [CombinationEntry]
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                if history.isEmpty {
                    VStack(spacing: 8) {
                        Text("🧪")
                            .font(.system(size: 48))
                        Text("Sin combinaciones aún")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.5))
                        Text("Tus mezclas aparecerán aquí")
                            .font(.system(size: 13))
                            .foregroundStyle(.white.opacity(0.3))
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        ForEach(history) { entry in
                            HStack(spacing: 12) {
                                Text("\(entry.emoji1)\(entry.emoji2)")
                                    .font(.system(size: 26))
                                    .frame(width: 56)

                                VStack(alignment: .leading, spacing: 3) {
                                    Text("\(entry.input1) + \(entry.input2)")
                                        .font(.system(size: 12))
                                        .foregroundStyle(.white.opacity(0.45))
                                        .lineLimit(1)
                                    HStack(spacing: 5) {
                                        Text(entry.resultEmoji)
                                        Text(entry.result)
                                            .font(.system(size: 15, weight: .bold, design: .rounded))
                                            .foregroundStyle(.white)
                                    }
                                }
                                Spacer()

                                Circle()
                                    .fill(Color(hex: entry.resultColorHex) ?? .white)
                                    .frame(width: 10, height: 10)
                                    .opacity(0.7)
                            }
                            .padding(.vertical, 4)
                            .listRowBackground(Color.white.opacity(0.04))
                            .listRowSeparatorTint(.white.opacity(0.08))
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }
            }
            .background(Color(red: 2/255, green: 6/255, blue: 23/255))
            .navigationTitle("Historial")
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
}

// Helper para crear Color desde hex
private extension Color {
    init?(hex: String) {
        var h = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if h.hasPrefix("#") { h = String(h.dropFirst()) }
        guard h.count == 6, let val = UInt64(h, radix: 16) else { return nil }
        self.init(
            red: Double((val >> 16) & 0xFF) / 255,
            green: Double((val >> 8) & 0xFF) / 255,
            blue: Double(val & 0xFF) / 255
        )
    }
}
