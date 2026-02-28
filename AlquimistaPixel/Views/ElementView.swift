import SwiftUI

struct ElementView: View {
    let element: ActiveElement
    let isDragging: Bool
    
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
                
                // CAMBIO AQUÍ: Usamos Color(hex:) en lugar de Color()
                RoundedRectangle(cornerRadius: 22)
                    .fill(Color(element.colorHex).opacity(0.35))
            }
        }
        .overlay {
            RoundedRectangle(cornerRadius: 22)
                .strokeBorder(.white.opacity(0.25), lineWidth: 1.5)
        }
        .shadow(color: .black.opacity(0.6), radius: 12, y: 6)
        .scaleEffect(isDragging ? 1.15 : 1.0)
        .animation(.spring(response: 0.25, dampingFraction: 0.7), value: isDragging)
    }
}
