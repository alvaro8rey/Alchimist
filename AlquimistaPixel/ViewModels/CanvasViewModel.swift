import Combine
import SwiftUI

class CanvasViewModel: ObservableObject {
    @Published var activeElements: [ActiveElement] = []
    @Published var canvasOffset: CGSize = .zero
    @Published var scale: CGFloat = 1.0
    @Published var draggingElementID: UUID? = nil
    @Published var showTrashBin: Bool = false
    @Published var dragStartWorldPosition: CGPoint? = nil
    @Published var highlightedElementID: UUID? = nil
    @Published var firstDiscoveryName: String? = nil
    @Published var combiningPosition: CGPoint? = nil
    
    private let recipeService = RecipeService()
    var onNewDiscovery: ((String, String, String) -> Void)?

    private var shownFirstDiscoveries: Set<String> {
        get { Set(UserDefaults.standard.stringArray(forKey: "shownFirstDiscoveries") ?? []) }
        set { UserDefaults.standard.set(Array(newValue), forKey: "shownFirstDiscoveries") }
    }

    private var userId: String {
        if let id = UserDefaults.standard.string(forKey: "userId") { return id }
        let id = UUID().uuidString
        UserDefaults.standard.set(id, forKey: "userId")
        return id
    }
    
    init(screenSize: CGSize = .zero) {
        spawnInitialElements()
        if screenSize != .zero {
            resetCamera(screenSize: screenSize)
        }
    }
    
    private func spawnInitialElements() {
        activeElements = [
            ActiveElement(id: UUID(), name: "Fuego", emoji: "🔥", colorHex: "#FF5722", position: CGPoint(x: -120, y: -100)),
            ActiveElement(id: UUID(), name: "Agua", emoji: "💧", colorHex: "#2196F3", position: CGPoint(x: 120, y: -100)),
            ActiveElement(id: UUID(), name: "Tierra", emoji: "🌍", colorHex: "#8B4513", position: CGPoint(x: -120, y: 100)),
            ActiveElement(id: UUID(), name: "Aire", emoji: "💨", colorHex: "#E0E0E0", position: CGPoint(x: 120, y: 100))
        ]
    }
    
    // MARK: - Duplicado
    func duplicateElement(_ element: ActiveElement) {
        let offset: CGFloat = 30
        let clone = ActiveElement(
            id: UUID(),
            name: element.name,
            emoji: element.emoji,
            colorHex: element.colorHex,
            position: CGPoint(x: element.position.x + offset, y: element.position.y + offset)
        )
        
        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
            activeElements.append(clone)
        }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }
    
    // MARK: - Camera Controls
    func zoomIn() {
        if scale >= 4.0 { UIImpactFeedbackGenerator(style: .rigid).impactOccurred(); return }
        withAnimation(.spring(response: 0.3)) {
            let newScale = min(4.0, scale + 0.25)
            let ratio = newScale / scale
            canvasOffset = CGSize(width: canvasOffset.width * ratio, height: canvasOffset.height * ratio)
            scale = newScale
        }
    }

    func zoomOut() {
        if scale <= 0.2 { UIImpactFeedbackGenerator(style: .rigid).impactOccurred(); return }
        withAnimation(.spring(response: 0.3)) {
            let newScale = max(0.2, scale - 0.25)
            let ratio = newScale / scale
            canvasOffset = CGSize(width: canvasOffset.width * ratio, height: canvasOffset.height * ratio)
            scale = newScale
        }
    }

    func spawnElement(from discovered: DiscoveredElement, at worldPos: CGPoint) {
        let new = ActiveElement(id: UUID(), name: discovered.name, emoji: discovered.emoji, colorHex: discovered.colorHex, position: worldPos)
        activeElements.append(new)
    }
    
    func updatePosition(for id: UUID, to newPos: CGPoint) {
        if let i = activeElements.firstIndex(where: { $0.id == id }) {
            activeElements[i].position = newPos
        }
        // Resaltar el elemento más cercano si está dentro del rango de combinación
        var minDist: CGFloat = .infinity
        var closestID: UUID? = nil
        for other in activeElements where other.id != id {
            let d = hypot(newPos.x - other.position.x, newPos.y - other.position.y)
            if d < minDist { minDist = d; closestID = other.id }
        }
        highlightedElementID = (minDist < 65) ? closestID : nil
    }

    func handleElementDrop(id: UUID, screenSize: CGSize) {
        guard let element = activeElements.first(where: { $0.id == id }) else {
            resetDragState()
            return
        }
        
        // screenPos(P) = P * scale + screenCenter + canvasOffset
        let screenX = element.position.x * scale + screenSize.width / 2 + canvasOffset.width
        let screenY = element.position.y * scale + screenSize.height / 2 + canvasOffset.height
        
        // Área de la papelera corregida
        let trashRect = CGRect(x: 0, y: screenSize.height - 230, width: 120, height: 120)
        
        if trashRect.contains(CGPoint(x: screenX, y: screenY)) {
            deleteElement(id)
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        } else {
            checkCombinations(for: element)
        }
        
        resetDragState()
    }
    
    private func resetDragState() {
        withAnimation(.spring()) {
            showTrashBin = false
            draggingElementID = nil
            dragStartWorldPosition = nil
            highlightedElementID = nil
        }
    }
    
    private func checkCombinations(for element: ActiveElement) {
        var closest: ActiveElement?
        var minDist: CGFloat = .infinity
        
        for other in activeElements where other.id != element.id {
            let d = hypot(element.position.x - other.position.x, element.position.y - other.position.y)
            if d < minDist {
                minDist = d
                closest = other
            }
        }
        
        if let closest, minDist < 65 {
            combineElements(id1: element.id, id2: closest.id)
        }
    }
    
    private func combineElements(id1: UUID, id2: UUID) {
        guard let e1 = activeElements.first(where: { $0.id == id1 }),
              let e2 = activeElements.first(where: { $0.id == id2 }) else { return }
        
        let mid = CGPoint(x: (e1.position.x + e2.position.x)/2, y: (e1.position.y + e2.position.y)/2)
        let backupE1 = e1
        let backupE2 = e2
        
        activeElements.removeAll { $0.id == id1 || $0.id == id2 }
        combiningPosition = mid

        Task {
            if let result = await recipeService.getCombination(e1.name, e2.name, userId: userId) {
                await MainActor.run {
                    self.combiningPosition = nil
                    let new = ActiveElement(id: UUID(), name: result.name, emoji: result.emoji, colorHex: result.colorHex, position: mid)
                    activeElements.append(new)
                    self.onNewDiscovery?(result.name, result.emoji, result.colorHex)
                    UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
                    let key = result.name.lowercased()
                    if result.isFirstDiscovery && !self.shownFirstDiscoveries.contains(key) {
                        var seen = self.shownFirstDiscoveries
                        seen.insert(key)
                        self.shownFirstDiscoveries = seen
                        self.firstDiscoveryName = result.name
                        Task {
                            try? await Task.sleep(for: .seconds(3))
                            await MainActor.run { self.firstDiscoveryName = nil }
                        }
                    }
                }
            } else {
                await MainActor.run {
                    self.combiningPosition = nil
                    UINotificationFeedbackGenerator().notificationOccurred(.error)
                    activeElements.append(backupE1)
                    activeElements.append(backupE2)
                }
            }
        }
    }
    
    func deleteElement(_ id: UUID) {
        activeElements.removeAll { $0.id == id }
    }
    
    func resetCamera(screenSize: CGSize) {
        withAnimation(.spring()) {
            scale = 1.0
            canvasOffset = .zero
        }
    }
}
