import SwiftUI

struct InventoryView: View {
    let discoveredElements: [DiscoveredElement]
    let onSpawn: (DiscoveredElement) -> Void
    
    @State private var showFullList = false
    @State private var searchText = ""
    
    private var recentElements: [DiscoveredElement] {
        Array(discoveredElements
            .sorted { $0.discoveryDate > $1.discoveryDate }
            .prefix(8))
    }
    
    private var filteredFullList: [DiscoveredElement] {
        let sorted = discoveredElements.sorted { $0.discoveryDate > $1.discoveryDate }
        return searchText.isEmpty
            ? sorted
            : sorted.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Barra inferior rápida
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(discoveredElements.count)")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                    Text("Objetos")
                        .font(.system(size: 10, weight: .semibold))
                        .textCase(.uppercase)
                        .opacity(0.6)
                }
                .foregroundStyle(.white)
                .padding(.trailing, 4)
                
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(recentElements) { element in
                            Button {
                                onSpawn(element)
                            } label: {
                                VStack(spacing: 4) {
                                    Text(element.emoji)
                                        .font(.system(size: 28))
                                    Text(element.name)
                                        .font(.system(size: 10, weight: .medium))
                                        .foregroundStyle(.white)
                                        .lineLimit(1)
                                }
                                .frame(width: 65, height: 65)
                                .background {
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 16)
                                            .fill(.ultraThinMaterial)
                                        // APLICAMOS EL COLOR HEX AQUÍ
                                        RoundedRectangle(cornerRadius: 16)
                                            .fill(Color(element.colorHex).opacity(0.3))
                                    }
                                }
                                .overlay {
                                    RoundedRectangle(cornerRadius: 16)
                                        .strokeBorder(.white.opacity(0.15), lineWidth: 1)
                                }
                            }
                        }
                    }
                    .padding(.vertical, 8)
                }
                
                Button {
                    showFullList = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 32))
                        .foregroundStyle(.white)
                        .symbolRenderingMode(.hierarchical)
                }
            }
            .padding(.horizontal, 16)
            .frame(height: 90)
            .background(.ultraThinMaterial)
            .overlay(alignment: .top) {
                Rectangle()
                    .fill(.white.opacity(0.1))
                    .frame(height: 0.5)
            }
        }
        .sheet(isPresented: $showFullList) {
            NavigationStack {
                List {
                    ForEach(filteredFullList) { element in
                        Button {
                            // 1. Ejecutamos la acción de crear el elemento
                            onSpawn(element)
                            
                            // 2. Quitamos el 'showFullList = false' que había aquí
                            
                            // 3. Opcional: Añadimos una vibración suave para confirmar
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        } label: {
                            HStack(spacing: 16) {
                                ZStack {
                                    Circle()
                                        .fill(Color(element.colorHex).opacity(0.2))
                                        .frame(width: 44, height: 44)
                                    Text(element.emoji)
                                        .font(.title3)
                                }
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(element.name)
                                        .font(.headline)
                                        .foregroundStyle(.primary)
                                    Text("Descubierto \(element.discoveryDate.formatted(.relative(presentation: .named)))")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                
                                // Cambiamos el icono para que parezca un botón de "añadir"
                                Image(systemName: "plus.circle")
                                    .font(.body)
                                    .foregroundStyle(.blue)
                            }
                        }
                        .listRowBackground(Color.clear)
                    }
                }
                .navigationTitle("Colección")
                .navigationBarTitleDisplayMode(.inline)
                .searchable(text: $searchText, prompt: "Buscar en tu inventario...")
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Cerrar") { showFullList = false }
                            .font(.subheadline.bold())
                    }
                }
            }
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
            .preferredColorScheme(.dark)
        }
    }
}
