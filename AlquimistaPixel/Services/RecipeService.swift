import Foundation
import FirebaseFirestore

struct RecipeService {
    private let db = Firestore.firestore()
    
    // Recupera la clave dinámicamente desde el archivo Secrets.plist
    private var openAIKey: String {
        guard let path = Bundle.main.path(forResource: "Secrets", ofType: "plist"),
              let dict = NSDictionary(contentsOfFile: path),
              let key = dict["OpenAIKey"] as? String else {
            print("⚠️ ERROR: No se encontró la clave 'OpenAIKey' en Secrets.plist")
            return ""
        }
        return key
    }
    
    struct CombinationResult: Codable {
        let name: String
        let emoji: String
        let colorHex: String
        var isFirstDiscovery: Bool = false // Propiedad para el aviso visual
    }

    private func makeGlobalKey(_ item1: String, _ item2: String) -> String {
        let key = [item1.lowercased().trimmingCharacters(in: .whitespaces),
                item2.lowercased().trimmingCharacters(in: .whitespaces)]
                .sorted().joined(separator: "_")
        return key
    }

    /// Obtiene la combinación, verificando si es un descubrimiento nuevo para el usuario
    func getCombination(_ item1: String, _ item2: String, userId: String) async -> CombinationResult? {
        let key = makeGlobalKey(item1, item2)
        print("🔍 Buscando combinación para: \(key)")
        
        do {
            let document = try await db.collection("recipes").document(key).getDocument()
            
            if document.exists, let data = document.data() {
                print("✅ Receta encontrada en Firebase!")
                let creatorID = data["createdBy"] as? String ?? ""
                
                return CombinationResult(
                    name: data["name"] as? String ?? "",
                    emoji: data["emoji"] as? String ?? "",
                    colorHex: data["color"] as? String ?? "#FFFFFF",
                    // Si el ID del creador coincide con el tuyo, fue tu primer descubrimiento
                    isFirstDiscovery: creatorID == userId
                )
            }
        } catch {
            print("⚠️ Error Firebase: \(error.localizedDescription)")
        }
        
        // B. Generar con IA si no existe
        print("🤖 No está en Firebase. Generando con IA...")
        guard var aiResult = await fetchFromOpenAI(item1: item1, item2: item2) else {
            return nil
        }
        
        // C. Guardar el nuevo descubrimiento GLOBAL
        // Al ser nuevo, marcamos isFirstDiscovery como true
        aiResult.isFirstDiscovery = true
        
        do {
            try await db.collection("recipes").document(key).setData([
                "name": aiResult.name,
                "emoji": aiResult.emoji,
                "color": aiResult.colorHex,
                "createdBy": userId, // Guardamos quién lo descubrió primero
                "createdAt": FieldValue.serverTimestamp()
            ])
            print("🚀 ¡ERES EL PRIMERO! Nuevo descubrimiento guardado: \(aiResult.name)")
        } catch {
            print("❌ Error al guardar en Firebase: \(error.localizedDescription)")
        }
        
        return aiResult
    }

    // Struct auxiliar para decodificar solo los campos que devuelve OpenAI
    private struct AIResult: Codable {
        let name: String
        let emoji: String
        let colorHex: String
    }

    private func fetchFromOpenAI(item1: String, item2: String) async -> CombinationResult? {
            let url = URL(string: "https://api.openai.com/v1/chat/completions")!
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.addValue("Bearer \(openAIKey)", forHTTPHeaderField: "Authorization")
            request.addValue("application/json", forHTTPHeaderField: "Content-Type")

            let prompt = """
            Eres el motor del juego Infinite Craft. Combinas dos elementos para crear algo nuevo usando lógica creativa.

            CÓMO RAZONAR (ejemplos reales del juego):
            Fuego + Agua = Vapor | Tierra + Fuego = Lava | Agua + Agua = Océano | Fuego + Fuego = Volcán
            Humano + Fuego = Cocinero | Tierra + Vida = Planta | Agua + Tierra = Barro | Viento + Fuego = Humo
            Humano + Humano = Familia | Ciencia + Humano = Einstein | Héroe + Ciudad = Batman
            Guerrero + Norte = Vikingo | Mago + Fuego = Gandalf | Robot + Inteligencia = IA

            TIPOS DE RESULTADOS (sé ambicioso y creativo):
            - Elementos: Lava, Vapor, Tormenta, Hielo, Electricidad
            - Criaturas: Dragón, Fénix, Sirena, Unicornio, Zombie
            - Personas reales: Einstein, Darwin, Tesla, Cleopatra, Da Vinci, Napoleon
            - Personajes ficticios: Batman, Goku, Sherlock, Gandalf, Spiderman
            - Marcas/Empresas: Tesla, Apple, Netflix, Google, McDonald's, NASA
            - Lugares: Roma, Sahara, Olimpo, Atlantis, Silicon Valley
            - Comidas: Pizza, Sushi, Curry, Chocolate, Ramen
            - Conceptos: Democracia, Internet, Magia, Guerra, Arte, Amor
            - Tecnología: Cohete, Ordenador, Nuclear, Satélite

            REGLAS:
            1. Máximo 2 palabras en el nombre, sin artículos ni preposiciones (sin "de","el","la","un")
            2. Si la combinación es absurda, crea algo poético o filosófico
            3. El emoji representa visualmente el resultado
            4. El colorHex (#RRGGBB) evoca el color principal del resultado

            Elementos: "\(item1)" + "\(item2)"
            JSON: {"name":"...","emoji":"...","colorHex":"#..."}
            """

            let body: [String: Any] = [
                "model": "gpt-4o-mini",
                "messages": [
                    ["role": "system", "content": "Solo devuelves conceptos transformados en JSON."],
                    ["role": "user", "content": prompt]
                ],
                "temperature": 0.3,
                "response_format": ["type": "json_object"]
            ]

            request.httpBody = try? JSONSerialization.data(withJSONObject: body)

            do {
                let (data, _) = try await URLSession.shared.data(for: request)
                let response = try JSONDecoder().decode(OpenAIResponse.self, from: data)
                if let content = response.choices.first?.message.content,
                   let contentData = content.data(using: .utf8) {
                    let ai = try JSONDecoder().decode(AIResult.self, from: contentData)
                    return CombinationResult(name: ai.name, emoji: ai.emoji, colorHex: ai.colorHex)
                }
            } catch {
                print("❌ Error OpenAI: \(error)")
            }
            return nil
        }
}

// Estructuras de soporte
struct OpenAIResponse: Codable {
    struct Choice: Codable {
        struct Message: Codable { let content: String }
        let message: Message
    }
    let choices: [Choice]
}
