import Foundation
import FirebaseFirestore
import CryptoKit

struct UserService {
    static let usernameKey = "username"
    private static let joinedAtKey = "joinedAt"
    private static let isGuestKey = "isGuest"
    private let db = Firestore.firestore()

    var username: String {
        UserDefaults.standard.string(forKey: Self.usernameKey) ?? ""
    }

    var hasUsername: Bool {
        !username.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var isGuest: Bool {
        UserDefaults.standard.bool(forKey: Self.isGuestKey)
    }

    var joinedAt: Date? {
        UserDefaults.standard.object(forKey: Self.joinedAtKey) as? Date
    }

    func enterGuestMode() {
        UserDefaults.standard.set(true, forKey: Self.isGuestKey)
    }

    // MARK: - Password

    private func hashPassword(_ password: String, salt: String) -> String {
        let data = Data((password + salt).utf8)
        let hash = SHA256.hash(data: data)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }

    // MARK: - Username check

    func isUsernameTaken(_ name: String) async -> Bool {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return false }
        do {
            let snapshot = try await db.collection("users")
                .whereField("username", isEqualTo: trimmed)
                .limit(to: 1)
                .getDocuments()
            return !snapshot.documents.isEmpty
        } catch {
            return false
        }
    }

    // MARK: - Register (nueva cuenta con contraseña)

    func register(username: String, password: String) async throws {
        let name = username.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }

        let userId = UUID().uuidString
        let salt = UUID().uuidString
        let hash = hashPassword(password, salt: salt)

        // Firebase primero — si falla, UserDefaults no quedan en estado inconsistente
        try await db.collection("users").document(userId).setData([
            "username": name,
            "joinedAt": FieldValue.serverTimestamp(),
            "discoveryCount": 0,
            "passwordHash": hash,
            "salt": salt
        ])

        UserDefaults.standard.set(name, forKey: Self.usernameKey)
        UserDefaults.standard.set(Date(), forKey: Self.joinedAtKey)
        UserDefaults.standard.set(userId, forKey: "userId")
        UserDefaults.standard.set(false, forKey: Self.isGuestKey)
    }

    // MARK: - Login (recuperar cuenta existente)

    struct InventoryItem {
        let name: String
        let emoji: String
        let colorHex: String
        let creatorName: String
        let discoveryDate: Date?
    }

    func login(username: String, password: String) async throws -> [InventoryItem] {
        let trimmed = username.trimmingCharacters(in: .whitespaces)

        let snapshot = try await db.collection("users")
            .whereField("username", isEqualTo: trimmed)
            .limit(to: 1)
            .getDocuments()

        guard let doc = snapshot.documents.first else {
            throw AuthError.userNotFound
        }

        let data = doc.data()
        guard let salt = data["salt"] as? String,
              let storedHash = data["passwordHash"] as? String else {
            throw AuthError.invalidCredentials
        }

        guard hashPassword(password, salt: salt) == storedHash else {
            throw AuthError.wrongPassword
        }

        let userId = doc.documentID
        UserDefaults.standard.set(userId, forKey: "userId")
        UserDefaults.standard.set(trimmed, forKey: Self.usernameKey)
        UserDefaults.standard.set(false, forKey: Self.isGuestKey)
        if let ts = (data["joinedAt"] as? Timestamp)?.dateValue() {
            UserDefaults.standard.set(ts, forKey: Self.joinedAtKey)
        }

        let inventorySnapshot = try await db.collection("users")
            .document(userId)
            .collection("inventory")
            .getDocuments()

        return inventorySnapshot.documents.compactMap { d -> InventoryItem? in
            let d = d.data()
            guard let name = d["name"] as? String,
                  let emoji = d["emoji"] as? String,
                  let colorHex = d["colorHex"] as? String else { return nil }
            let creator = d["creatorName"] as? String ?? ""
            let discoveryDate = (d["discoveryDate"] as? Timestamp)?.dateValue()
            return InventoryItem(name: name, emoji: emoji, colorHex: colorHex, creatorName: creator, discoveryDate: discoveryDate)
        }
    }

    // MARK: - Sync inventory item to Firestore

    func saveToInventory(name: String, emoji: String, colorHex: String, creatorName: String) async {
        guard let userId = UserDefaults.standard.string(forKey: "userId"), !userId.isEmpty else { return }
        let docId = name.lowercased().replacingOccurrences(of: " ", with: "_")
        try? await db.collection("users").document(userId)
            .collection("inventory").document(docId).setData([
                "name": name,
                "emoji": emoji,
                "colorHex": colorHex,
                "creatorName": creatorName,
                "discoveryDate": FieldValue.serverTimestamp()
            ])
    }

    // MARK: - Delete account

    func deleteAccount() async throws {
        guard let userId = UserDefaults.standard.string(forKey: "userId"), !userId.isEmpty else {
            throw AuthError.userNotFound
        }

        // Borrar subcolección de inventario (batch)
        let inventoryRef = db.collection("users").document(userId).collection("inventory")
        let inventoryDocs = try await inventoryRef.getDocuments()
        let batch = db.batch()
        for doc in inventoryDocs.documents {
            batch.deleteDocument(doc.reference)
        }
        try await batch.commit()

        // Borrar documento principal del usuario
        try await db.collection("users").document(userId).delete()

        // Limpiar UserDefaults
        clearLocalSession()
    }

    func logout() {
        clearLocalSession()
    }

    private func clearLocalSession() {
        let keys = [Self.usernameKey, Self.joinedAtKey, Self.isGuestKey, "userId"]
        keys.forEach { UserDefaults.standard.removeObject(forKey: $0) }
    }

    // MARK: - Legacy (compatibilidad con cuentas sin contraseña)

    func save(username: String) async {
        let name = username.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        UserDefaults.standard.set(name, forKey: Self.usernameKey)
        if UserDefaults.standard.object(forKey: Self.joinedAtKey) == nil {
            UserDefaults.standard.set(Date(), forKey: Self.joinedAtKey)
        }
        let userId: String
        if let existingId = UserDefaults.standard.string(forKey: "userId") {
            userId = existingId
        } else {
            let newId = UUID().uuidString
            UserDefaults.standard.set(newId, forKey: "userId")
            userId = newId
        }
        try? await db.collection("users").document(userId).setData([
            "username": name,
            "joinedAt": FieldValue.serverTimestamp()
        ], merge: true)
    }
}

// MARK: - Auth Errors

enum AuthError: LocalizedError {
    case userNotFound
    case wrongPassword
    case invalidCredentials

    var errorDescription: String? {
        switch self {
        case .userNotFound: return "No existe ningún usuario con ese nombre."
        case .wrongPassword: return "Contraseña incorrecta."
        case .invalidCredentials: return "Credenciales inválidas."
        }
    }
}
