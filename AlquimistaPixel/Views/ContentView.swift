import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var discoveredElements: [DiscoveredElement]
    
    @StateObject private var vm = CanvasViewModel()
    @State private var screenSize: CGSize = .zero
    @State private var lastAddedElementName: String? = nil
    @State private var showOnboarding: Bool = !UserService().hasUsername
    
    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .bottom) {
                CanvasView(vm: vm, screenSize: $screenSize)

                InventoryView(
                    discoveredElements: discoveredElements,
                    activeElements: vm.activeElements,
                    newlyAddedName: lastAddedElementName,
                    onSpawn: { element in
                        let centerScreenX = screenSize.width / 2
                        let centerScreenY = screenSize.height / 2 - 80

                        // Inversa de: screenPos(P) = P * scale + screenCenter + canvasOffset
                        let worldX = (centerScreenX - screenSize.width / 2 - vm.canvasOffset.width) / vm.scale
                        let worldY = (centerScreenY - screenSize.height / 2 - vm.canvasOffset.height) / vm.scale

                        vm.spawnElement(from: element, at: CGPoint(x: worldX, y: worldY))
                    }
                )

                // Toast de primer descubrimiento mundial
                if let name = vm.firstDiscoveryName {
                    VStack {
                        Spacer()
                        HStack(spacing: 10) {
                            Text("🌟")
                                .font(.title2)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("¡Primer descubrimiento mundial!")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(.white.opacity(0.7))
                                Text(name)
                                    .font(.system(size: 16, weight: .black, design: .rounded))
                                    .foregroundStyle(.white)
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 14)
                        .background(.ultraThinMaterial)
                        .clipShape(Capsule())
                        .shadow(color: .white.opacity(0.15), radius: 20)
                        .padding(.bottom, 110)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                    .animation(.spring(response: 0.4, dampingFraction: 0.75), value: vm.firstDiscoveryName)
                }
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
                        lastAddedElementName = name
                        Task {
                            try? await Task.sleep(nanoseconds: 50_000_000)
                            await MainActor.run { lastAddedElementName = nil }
                        }

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
        .fullScreenCover(isPresented: $showOnboarding) {
            OnboardingView { name in
                Task {
                    await UserService().save(username: name)
                    await MainActor.run { showOnboarding = false }
                }
            }
        }
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
