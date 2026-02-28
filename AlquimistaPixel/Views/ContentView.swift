import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var discoveredElements: [DiscoveredElement]
    
    @StateObject private var vm = CanvasViewModel()
    @State private var screenSize: CGSize = .zero
    
    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .bottom) {
                CanvasView(vm: vm, screenSize: $screenSize)
                
                InventoryView(
                    discoveredElements: discoveredElements,
                    onSpawn: { element in
                        let centerScreenX = screenSize.width / 2
                        let centerScreenY = screenSize.height / 2 - 80
                        
                        let worldX = (centerScreenX - vm.canvasOffset.width) / vm.scale
                        let worldY = (centerScreenY - vm.canvasOffset.height) / vm.scale
                        
                        vm.spawnElement(from: element, at: CGPoint(x: worldX, y: worldY))
                    }
                )
            }
            .onAppear {
                screenSize = geo.size
                ensureBasicElements()
                
                // ESCUCHADOR DE DESCUBRIMIENTOS
                vm.onNewDiscovery = { name, emoji, hex in
                    // Comprobación insensible a mayúsculas
                    let exists = discoveredElements.contains { $0.name.lowercased() == name.lowercased() }
                    
                    if !exists {
                        print("Nuevo descubrimiento detectado: \(name). Guardando en inventario...")
                        let new = DiscoveredElement(name: name, emoji: emoji, colorHex: hex)
                        modelContext.insert(new)
                        
                        do {
                            try modelContext.save()
                        } catch {
                            print("Error SwiftData: \(error)")
                        }
                    }
                }
            }
            .onChange(of: geo.size) { _, newSize in
                screenSize = newSize
                vm.resetCamera(screenSize: newSize)
            }
        }
        .preferredColorScheme(.dark)
    }
    
    private func ensureBasicElements() {
        let basics = [
            ("Fuego",  "🔥", "#FF5722"),
            ("Agua",   "💧", "#2196F3"),
            ("Tierra", "🌍", "#8B4513"),
            ("Aire",   "💨", "#E0E0E0")
        ]
        
        for (name, emoji, hex) in basics {
            if !discoveredElements.contains(where: { $0.name == name }) {
                let de = DiscoveredElement(name: name, emoji: emoji, colorHex: hex)
                modelContext.insert(de)
            }
        }
        try? modelContext.save()
    }
}
