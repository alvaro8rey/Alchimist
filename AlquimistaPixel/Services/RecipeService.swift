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
        var isFirstDiscovery: Bool = false
        var creatorName: String = ""
    }

    private var username: String {
        UserDefaults.standard.string(forKey: UserService.usernameKey) ?? "Desconocido"
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
                return CombinationResult(
                    name: data["name"] as? String ?? "",
                    emoji: data["emoji"] as? String ?? "",
                    colorHex: data["color"] as? String ?? "#FFFFFF",
                    isFirstDiscovery: false,
                    creatorName: data["creatorName"] as? String ?? ""
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
        aiResult.isFirstDiscovery = true
        aiResult.creatorName = username

        do {
            try await db.collection("recipes").document(key).setData([
                "name": aiResult.name,
                "emoji": aiResult.emoji,
                "color": aiResult.colorHex,
                "createdBy": userId,
                "creatorName": username,
                "createdAt": FieldValue.serverTimestamp()
            ])
            print("🚀 ¡ERES EL PRIMERO! Nuevo descubrimiento guardado: \(aiResult.name)")

            // Incrementar contador de primicias del usuario
            if !userId.isEmpty {
                try? await db.collection("users").document(userId).setData(
                    ["discoveryCount": FieldValue.increment(Int64(1))],
                    merge: true
                )
            }
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
            Eres el motor del juego Infinite Craft. Combinas dos elementos y produces un concepto NUEVO e INESPERADO.

            EJEMPLOS DE BUENAS COMBINACIONES (el resultado sorprende, no es obvio):
            Fuego + Agua = Vapor | Tierra + Fuego = Lava | Humano + Fuego = Cocinero
            Tormenta + Ecosistema = Huracán | Furia + Naturaleza = Volcán | Tormenta + Tormenta = Tifón
            Guerrero + Norte = Vikingo | Mago + Fuego = Gandalf | Ciencia + Humano = Einstein
            Héroe + Ciudad = Batman | Robot + Inteligencia = IA | Océano + Vida = Sirena

            TIPOS DE RESULTADOS (sé ambicioso):
            - Elementos: Lava, Vapor, Tifón, Huracán, Plasma, Aurora
            - Criaturas: Dragón, Fénix, Sirena, Unicornio, Leviatán
            - Personas reales: Einstein, Darwin, Tesla, Cleopatra, Napoleón
            - Personajes ficticios: Batman, Goku, Gandalf, Poseidón, Thor
            - Lugares: Roma, Olimpo, Atlantis, Sahara, Pompeya
            - Conceptos: Caos, Karma, Entropía, Apocalipsis, Renacimiento
            - Tecnología: Cohete, Nuclear, Satélite, Láser

            REGLAS CRÍTICAS:
            1. PROHIBIDO usar palabras de los elementos de entrada en el resultado (ni variantes, ni sinónimos directos)
            2. El resultado debe ser un concepto DIFERENTE a ambos inputs, no una mezcla literal
            3. Máximo 2 palabras, sin artículos ni preposiciones
            4. El emoji representa visualmente el resultado
            5. El colorHex (#RRGGBB) evoca el color del resultado

            Elementos: "\(item1)" + "\(item2)"
            JSON: {"name":"...","emoji":"...","colorHex":"#..."}
            """

            let body: [String: Any] = [
                "model": "gpt-4o-mini",
                "messages": [
                    ["role": "system", "content": "Solo devuelves conceptos transformados en JSON."],
                    ["role": "user", "content": prompt]
                ],
                "temperature": 0.8,
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
