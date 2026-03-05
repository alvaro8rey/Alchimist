import Foundation
import FirebaseFirestore
import FirebaseFunctions
import Network

struct RecipeService {
    private let db = Firestore.firestore()
    private let functions = Functions.functions()

    struct CombinationResult: Codable {
        let name: String
        let emoji: String
        let colorHex: String
        var isFirstDiscovery: Bool = false
        var creatorName: String = ""
    }

    // MARK: - Bundle seed (modo offline)
    private struct SeedEntry: Codable {
        let a: String
        let b: String
        let name: String
        let emoji: String
        let color: String
    }
    private struct SeedFile: Codable { let combinations: [SeedEntry] }

    private static let bundledRecipes: [SeedEntry] = {
        guard let url = Bundle.main.url(forResource: "SeedCombinations", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let seed = try? JSONDecoder().decode(SeedFile.self, from: data) else { return [] }
        return seed.combinations
    }()

    private func checkBundle(_ key: String) -> CombinationResult? {
        Self.bundledRecipes.first { makeGlobalKey($0.a, $0.b) == key }
            .map { CombinationResult(name: $0.name, emoji: $0.emoji, colorHex: $0.color, isFirstDiscovery: false, creatorName: "") }
    }

    private var username: String {
        UserDefaults.standard.string(forKey: UserService.usernameKey) ?? ""
    }

    private func makeGlobalKey(_ item1: String, _ item2: String) -> String {
        [item1.lowercased().trimmingCharacters(in: .whitespaces),
         item2.lowercased().trimmingCharacters(in: .whitespaces)]
            .sorted().joined(separator: "_")
    }

    private func isOnline() async -> Bool {
        await withCheckedContinuation { continuation in
            let monitor = NWPathMonitor()
            monitor.pathUpdateHandler = { path in
                monitor.cancel()
                continuation.resume(returning: path.status == .satisfied)
            }
            monitor.start(queue: .global())
        }
    }

    /// Obtiene la combinación: primero Firebase, luego bundle (offline), luego IA (Cloud Function)
    func getCombination(_ item1: String, _ item2: String, userId: String) async -> CombinationResult? {
        let key = makeGlobalKey(item1, item2)
        print("🔍 Buscando combinación para: \(key)")

        guard await isOnline() else {
            print("📴 Sin conexión. Buscando en bundle...")
            if let bundled = checkBundle(key) {
                print("📦 Receta en bundle (offline).")
                return bundled
            }
            print("❌ Sin conexión y combinación no encontrada en bundle.")
            return nil
        }

        do {
            let document = try await db.collection("recipes").document(key).getDocument()

            if document.exists, let data = document.data() {
                print("✅ Receta encontrada en Firebase!")
                return CombinationResult(
                    name: data["name"] as? String ?? "",
                    emoji: data["emoji"] as? String ?? "",
                    colorHex: data["color"] as? String ?? "#FFFFFF",
                    isFirstDiscovery: false,
                    creatorName: data["creatorName"] as? String ?? ""
                )
            }

            if let bundled = checkBundle(key) {
                print("📦 Receta en bundle.")
                return bundled
            }

        } catch {
            print("⚠️ Error de red (\(error.localizedDescription)). Buscando en bundle...")
            if let bundled = checkBundle(key) {
                print("📦 Receta en bundle (fallback).")
                return bundled
            }
            return nil
        }

        print("🤖 No está en Firebase ni en bundle. Generando con IA...")
        return await fetchFromCloudFunction(item1: item1, item2: item2, userId: userId)
    }


    /// Llama a la Cloud Function `generateRecipe` — la API key de OpenAI nunca sale del servidor.
    /// La Cloud Function también guarda en Firestore y devuelve isFirstDiscovery.
    private func fetchFromCloudFunction(item1: String, item2: String, userId: String) async -> CombinationResult? {
        let callable = functions.httpsCallable("generateRecipe")
        do {
            let result = try await callable.call([
                "ingredient1": item1,
                "ingredient2": item2,
                "userId": userId,
                "username": username
            ])
            guard let data = result.data as? [String: Any],
                  let name = data["name"] as? String,
                  let emoji = data["emoji"] as? String,
                  let colorHex = data["colorHex"] as? String else {
                print("❌ Respuesta inesperada de Cloud Function")
                return nil
            }
            let isFirst = data["isFirstDiscovery"] as? Bool ?? false
            let creator = data["creatorName"] as? String ?? ""
            return CombinationResult(name: name, emoji: emoji, colorHex: colorHex,
                                     isFirstDiscovery: isFirst, creatorName: creator)
        } catch {
            print("❌ Error en Cloud Function: \(error)")
            return nil
        }
    }
}
