import Combine
import SwiftUI

// MARK: - Combination History Entry
struct CombinationEntry: Identifiable {
    let id = UUID()
    let input1: String
    let emoji1: String
    let input2: String
    let emoji2: String
    let result: String
    let resultEmoji: String
    let resultColorHex: String
}

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
    @Published var combinationHistory: [CombinationEntry] = []

    private let recipeService = RecipeService()
    var onNewDiscovery: ((String, String, String, String) -> Void)?
    private var cancellables = Set<AnyCancellable>()

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
        if let saved = Self.loadCanvas(), !saved.isEmpty {
            activeElements = saved
        } else {
            spawnInitialElements()
        }
        if screenSize != .zero {
            resetCamera(screenSize: screenSize)
        }
        setupAutoSave()
    }

    // MARK: - Canvas Persistence

    private func setupAutoSave() {
        $activeElements
            .combineLatest($combiningPosition)
            .debounce(for: .seconds(0.5), scheduler: RunLoop.main)
            .filter { _, combining in combining == nil }
            .map { elements, _ in elements }
            .sink { elements in
                Self.saveCanvas(elements)
            }
            .store(in: &cancellables)
    }

    private static func saveCanvas(_ elements: [ActiveElement]) {
        guard let data = try? JSONEncoder().encode(elements) else { return }
        UserDefaults.standard.set(data, forKey: "canvasState")
    }

    private static func loadCanvas() -> [ActiveElement]? {
        guard let data = UserDefaults.standard.data(forKey: "canvasState"),
              let elements = try? JSONDecoder().decode([ActiveElement].self, from: data) else { return nil }
        return elements
    }

    func clearCanvas() {
        withAnimation(.spring()) {
            activeElements.removeAll()
        }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    // MARK: - Initial Elements

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

        let screenX = element.position.x * scale + screenSize.width / 2 + canvasOffset.width
        let screenY = element.position.y * scale + screenSize.height / 2 + canvasOffset.height
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
            if d < minDist { minDist = d; closest = other }
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
                    self.onNewDiscovery?(result.name, result.emoji, result.colorHex, result.creatorName)
                    UIImpactFeedbackGenerator(style: .heavy).impactOccurred()

                    // Añadir al historial
                    let entry = CombinationEntry(
                        input1: e1.name, emoji1: e1.emoji,
                        input2: e2.name, emoji2: e2.emoji,
                        result: result.name, resultEmoji: result.emoji,
                        resultColorHex: result.colorHex
                    )
                    combinationHistory.insert(entry, at: 0)
                    if combinationHistory.count > 30 { combinationHistory.removeLast() }

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
