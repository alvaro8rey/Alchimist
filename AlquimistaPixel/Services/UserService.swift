import Foundation
import FirebaseFirestore

struct UserService {
    static let usernameKey = "username"
    private static let joinedAtKey = "joinedAt"
    private let db = Firestore.firestore()

    var username: String {
        UserDefaults.standard.string(forKey: Self.usernameKey) ?? ""
    }

    var hasUsername: Bool {
        !username.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var joinedAt: Date? {
        UserDefaults.standard.object(forKey: Self.joinedAtKey) as? Date
    }

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
            return false // Si no se puede comprobar, dejamos pasar
        }
    }

    func save(username: String) async {
        let name = username.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        UserDefaults.standard.set(name, forKey: Self.usernameKey)
        if UserDefaults.standard.object(forKey: Self.joinedAtKey) == nil {
            UserDefaults.standard.set(Date(), forKey: Self.joinedAtKey)
        }
        let userId = UserDefaults.standard.string(forKey: "userId") ?? ""
        guard !userId.isEmpty else { return }
        try? await db.collection("users").document(userId).setData([
            "username": name,
            "joinedAt": FieldValue.serverTimestamp()
        ])
    }
}
