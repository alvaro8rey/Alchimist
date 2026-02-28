import SwiftUI

struct ElementView: View {
    let element: ActiveElement
    let isDragging: Bool
    var isHighlighted: Bool = false

    var body: some View {
        VStack(spacing: 4) {
            Text(element.emoji)
                .font(.system(size: 38))

            Text(element.name)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background {
            ZStack {
                RoundedRectangle(cornerRadius: 22)
                    .fill(.ultraThinMaterial)
                RoundedRectangle(cornerRadius: 22)
                    .fill(Color(hex: element.colorHex).opacity(0.35))
            }
        }
        .overlay {
            RoundedRectangle(cornerRadius: 22)
                .strokeBorder(
                    isHighlighted ? Color.white : Color.white.opacity(0.25),
                    lineWidth: isHighlighted ? 2.5 : 1.5
                )
        }
        .shadow(
            color: isHighlighted ? Color.white.opacity(0.6) : .black.opacity(0.6),
            radius: isHighlighted ? 16 : 12,
            y: isHighlighted ? 0 : 6
        )
        .scaleEffect(isDragging ? 1.15 : (isHighlighted ? 1.05 : 1.0))
        .animation(.spring(response: 0.25, dampingFraction: 0.7), value: isDragging)
        .animation(.spring(response: 0.2, dampingFraction: 0.6), value: isHighlighted)
    }
}
