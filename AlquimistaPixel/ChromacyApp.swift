import SwiftUI
import SwiftData // <--- Asegúrate de que esta línea esté aquí
import FirebaseCore

@main
struct ChromancyApp: App {
    
    // Inicializamos Firebase
    init() {
        FirebaseApp.configure()
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        // Esta línea es la que necesita 'import SwiftData'
        .modelContainer(for: DiscoveredElement.self)
    }
}
