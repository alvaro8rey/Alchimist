import Combine
import SwiftUI

class CanvasViewModel: ObservableObject {
    @Published var activeElements: [ActiveElement] = []
    @Published var canvasOffset: CGSize = .zero
    @Published var scale: CGFloat = 1.0
    @Published var draggingElementID: UUID? = nil
    @Published var showTrashBin: Bool = false
    @Published var dragStartWorldPosition: CGPoint? = nil
    
    private let recipeService = RecipeService()
    var onNewDiscovery: ((String, String, String) -> Void)?

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
        withAnimation(.spring(response: 0.3)) {
            scale = min(4.0, scale + 0.25)
        }
    }
    
    func zoomOut() {
        withAnimation(.spring(response: 0.3)) {
            scale = max(0.2, scale - 0.25)
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
    }
    
    func handleElementDrop(id: UUID, screenSize: CGSize) {
        guard let element = activeElements.first(where: { $0.id == id }) else {
            resetDragState()
            return
        }
        
        // scaleEffect ancla en el centro de la pantalla, hay que compensar ese desplazamiento
        let screenX = (element.position.x - screenSize.width / 2) * scale + screenSize.width / 2 + canvasOffset.width
        let screenY = (element.position.y - screenSize.height / 2) * scale + screenSize.height / 2 + canvasOffset.height
        
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
        
        Task {
            if let result = await recipeService.getCombination(e1.name, e2.name, userId: userId) {
                await MainActor.run {
                    let new = ActiveElement(id: UUID(), name: result.name, emoji: result.emoji, colorHex: result.colorHex, position: mid)
                    activeElements.append(new)
                    self.onNewDiscovery?(result.name, result.emoji, result.colorHex)
                    UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
                }
            } else {
                await MainActor.run {
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
            canvasOffset = CGSize(width: screenSize.width/2, height: screenSize.height/2)
        }
    }
}
