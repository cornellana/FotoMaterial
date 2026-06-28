import SwiftUI
import SwiftData

// MARK: - Entrada de la aplicación

/// Punto de entrada principal de FotoMaterial.
///
/// Configura:
/// - El contenedor SwiftData con `InventoryItem` como único modelo persistente.
/// - La instancia de `AppLocale` inyectada como `@EnvironmentObject` en todo el árbol de vistas.
@main
struct FotoMaterialApp: App {

    /// Objeto de localización compartido para toda la app.
    /// Se crea aquí (único propietario) y se propaga hacia abajo vía `environmentObject`.
    @StateObject private var locale = AppLocale()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(locale)
        }
        // Contenedor SwiftData para el modelo principal; SwiftData gestiona la migración automática.
        .modelContainer(for: InventoryItem.self)
    }
}
