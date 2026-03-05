import SwiftUI

struct InventoryView: View {
    let discoveredElements: [DiscoveredElement]
    let activeElements: [ActiveElement]
    let newlyAddedName: String?
    let onSpawn: (DiscoveredElement) -> Void

    @State private var showFullList = false
    @State private var searchText = ""
    @State private var flashingName: String? = nil

    private var canvasCounts: [String: Int] {
        activeElements.reduce(into: [:]) { $0[$1.name, default: 0] += 1 }
    }

    private var recentElements: [DiscoveredElement] {
        Array(discoveredElements.sorted { $0.discoveryDate > $1.discoveryDate }.prefix(10))
    }

    private var filteredFullList: [DiscoveredElement] {
        let sorted = discoveredElements.sorted { $0.discoveryDate > $1.discoveryDate }
        return searchText.isEmpty
            ? sorted
            : sorted.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Barra superior del inventario
            HStack(spacing: 0) {
                // Contador total
                Button { showFullList = true } label: {
                    VStack(alignment: .center, spacing: 1) {
                        Text("\(discoveredElements.count)")
                            .font(.system(size: 22, weight: .black, design: .rounded))
                            .foregroundStyle(.white)
                            .contentTransition(.numericText())
                        Text("elementos")
                            .font(.system(size: 8, weight: .bold))
                            .textCase(.uppercase)
                            .foregroundStyle(.white.opacity(0.45))
                            .tracking(0.8)
                    }
                    .frame(width: 62)
                }

                // Separador
                Rectangle()
                    .fill(.white.opacity(0.1))
                    .frame(width: 1, height: 44)
                    .padding(.horizontal, 10)

                // Scroll horizontal de recientes
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(recentElements) { element in
                            InventoryChip(
                                element: element,
                                count: canvasCounts[element.name] ?? 0,
                                isFlashing: flashingName == element.name,
                                onTap: {
                                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                    onSpawn(element)
                                }
                            )
                        }
                    }
                    .padding(.vertical, 10)
                    .padding(.horizontal, 2)
                }

                // Separador
                Rectangle()
                    .fill(.white.opacity(0.1))
                    .frame(width: 1, height: 44)
                    .padding(.horizontal, 10)

                // Botón ver todos
                Button { showFullList = true } label: {
                    VStack(spacing: 4) {
                        Image(systemName: "square.grid.2x2.fill")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundStyle(.white.opacity(0.75))
                        Text("Ver todo")
                            .font(.system(size: 8, weight: .bold))
                            .textCase(.uppercase)
                            .foregroundStyle(.white.opacity(0.45))
                            .tracking(0.5)
                    }
                    .frame(width: 52)
                }
            }
            .padding(.horizontal, 12)
            .frame(height: 86)
            .background(.ultraThinMaterial)
            .overlay(alignment: .top) {
                Rectangle()
                    .fill(.white.opacity(0.12))
                    .frame(height: 0.5)
            }
        }
        .sheet(isPresented: $showFullList) {
            InventorySheetView(
                elements: filteredFullList,
                canvasCounts: canvasCounts,
                discoveredCount: discoveredElements.count,
                flashingName: flashingName,
                searchText: $searchText,
                onSpawn: onSpawn,
                onClose: { showFullList = false }
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
            .preferredColorScheme(.dark)
        }
        .onChange(of: newlyAddedName) { _, name in
            guard let name else { return }
            withAnimation(.spring(response: 0.3, dampingFraction: 0.55)) {
                flashingName = name
            }
            Task {
                try? await Task.sleep(nanoseconds: 1_800_000_000)
                withAnimation(.easeOut(duration: 0.4)) { flashingName = nil }
            }
        }
    }
}

// MARK: - Chip del scroll rápido

struct InventoryChip: View {
    let element: DiscoveredElement
    let count: Int
    let isFlashing: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            ZStack(alignment: .topTrailing) {
                VStack(spacing: 3) {
                    Text(element.emoji)
                        .font(.system(size: isFlashing ? 30 : 26))
                        .scaleEffect(isFlashing ? 1.15 : 1.0)
                        .animation(.spring(response: 0.3, dampingFraction: 0.5), value: isFlashing)
                    Text(element.name)
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(.white.opacity(isFlashing ? 1.0 : 0.85))
                        .lineLimit(1)
                }
                .frame(width: 64, height: 64)
                .background {
                    ZStack {
                        RoundedRectangle(cornerRadius: 16)
                            .fill(.ultraThinMaterial)
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.hex(element.colorHex).opacity(isFlashing ? 0.55 : 0.22))
                    }
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(
                            isFlashing ? Color.white.opacity(0.9) : Color.white.opacity(0.1),
                            lineWidth: isFlashing ? 1.5 : 1
                        )
                }
                .shadow(
                    color: isFlashing ? Color.hex(element.colorHex).opacity(0.75) : .clear,
                    radius: 14
                )
                .scaleEffect(isFlashing ? 1.08 : 1.0)
                .animation(.spring(response: 0.35, dampingFraction: 0.55), value: isFlashing)

                // Badge de cantidad en el plano
                if count > 0 {
                    Text("\(count)")
                        .font(.system(size: 9, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                        .frame(minWidth: 16, minHeight: 16)
                        .padding(.horizontal, 4)
                        .background(Color.hex(element.colorHex))
                        .clipShape(Capsule())
                        .overlay(Capsule().strokeBorder(.black.opacity(0.3), lineWidth: 1))
                        .offset(x: 5, y: -5)
                }
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Sheet completo del inventario

struct InventorySheetView: View {
    let elements: [DiscoveredElement]
    let canvasCounts: [String: Int]
    let discoveredCount: Int
    let flashingName: String?
    @Binding var searchText: String
    let onSpawn: (DiscoveredElement) -> Void
    let onClose: () -> Void

    @State private var selectedElement: DiscoveredElement? = nil
    private let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

    var body: some View {
        NavigationStack {
            ScrollView {
                Group {
                    if elements.isEmpty {
                        VStack(spacing: 10) {
                            Text("Sin resultados")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(.white.opacity(0.5))
                            Text("Prueba con otra búsqueda")
                                .font(.system(size: 13))
                                .foregroundStyle(.white.opacity(0.3))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 60)
                    } else {
                        LazyVGrid(columns: columns, spacing: 12) {
                            ForEach(elements) { element in
                                InventoryGridCell(
                                    element: element,
                                    count: canvasCounts[element.name] ?? 0,
                                    isFlashing: flashingName == element.name,
                                    onTap: { onSpawn(element) },
                                    onLongPress: { selectedElement = element }
                                )
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 40)
            }
            .navigationTitle("Colección · \(discoveredCount)")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: "Buscar elemento...")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cerrar") { onClose() }
                        .font(.subheadline.bold())
                }
            }
        }
        .sheet(item: $selectedElement) { element in
            ElementDetailView(element: element)
                .preferredColorScheme(.dark)
        }
    }
}

// MARK: - Celda de la cuadrícula

struct InventoryGridCell: View {
    let element: DiscoveredElement
    let count: Int
    let isFlashing: Bool
    let onTap: () -> Void
    let onLongPress: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Zona emoji con badge
            ZStack(alignment: .topTrailing) {
                Text(element.emoji)
                    .font(.system(size: 44))
                    .frame(maxWidth: .infinity)
                    .padding(.top, 16)
                    .padding(.bottom, 8)
                    .scaleEffect(isFlashing ? 1.12 : 1.0)
                    .animation(.spring(response: 0.3, dampingFraction: 0.5), value: isFlashing)

                // Badge "X en plano"
                if count > 0 {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(Color.hex(element.colorHex))
                            .frame(width: 6, height: 6)
                        Text(count == 1 ? "1 en plano" : "\(count) en plano")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.white)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.black.opacity(0.45))
                    .clipShape(Capsule())
                    .padding(.top, 8)
                    .padding(.trailing, 8)
                }
            }

            // Nombre
            Text(element.name)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .padding(.horizontal, 10)
                .padding(.bottom, 14)
        }
        .frame(maxWidth: .infinity)
        .background {
            ZStack {
                RoundedRectangle(cornerRadius: 20)
                    .fill(.ultraThinMaterial)
                RoundedRectangle(cornerRadius: 20)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.hex(element.colorHex).opacity(isFlashing ? 0.5 : 0.28),
                                Color.hex(element.colorHex).opacity(isFlashing ? 0.18 : 0.06)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            }
        }
        .overlay {
            RoundedRectangle(cornerRadius: 20)
                .strokeBorder(
                    isFlashing
                        ? Color.white.opacity(0.85)
                        : Color.hex(element.colorHex).opacity(0.35),
                    lineWidth: isFlashing ? 1.5 : 1
                )
        }
        .shadow(
            color: isFlashing ? Color.hex(element.colorHex).opacity(0.6) : .clear,
            radius: 16
        )
        .scaleEffect(isFlashing ? 1.04 : 1.0)
        .animation(.spring(response: 0.35, dampingFraction: 0.55), value: isFlashing)
        .contentShape(Rectangle())
        .onTapGesture {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            onTap()
        }
        .onLongPressGesture(minimumDuration: 0.4) {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            onLongPress()
        }
    }
}
