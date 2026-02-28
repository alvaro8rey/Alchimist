import Foundation
import FirebaseFirestore

struct UserService {
    static let usernameKey = "username"
    private let db = Firestore.firestore()

    var username: String {
        UserDefaults.standard.string(forKey: Self.usernameKey) ?? ""
    }

    var hasUsername: Bool {
        !username.trimmingCharacters(in: .whitespaces).isEmpty
    }

    func save(username: String) async {
        let name = username.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        UserDefaults.standard.set(name, forKey: Self.usernameKey)
        let userId = UserDefaults.standard.string(forKey: "userId") ?? ""
        guard !userId.isEmpty else { return }
        try? await db.collection("users").document(userId).setData([
            "username": name,
            "joinedAt": FieldValue.serverTimestamp()
        ])
    }
}
