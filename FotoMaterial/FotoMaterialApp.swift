import SwiftUI
import SwiftData

// MARK: - Entrada de la aplicación

/// Punto de entrada principal de FotoMaterial.
///
/// Configura:
/// - El contenedor SwiftData con `InventoryItem` como único modelo persistente.
/// - La instancia de `AppLocale` inyectada como `@EnvironmentObject` en todo el árbol de vistas.
/// - El handler `onOpenURL` para abrir archivos `.fotomaterial` directamente desde
///   la app Archivos o AirDrop, disparando la restauración automática.
@main
struct FotoMaterialApp: App {

    /// Objeto de localización compartido para toda la app.
    @StateObject private var locale = AppLocale()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(locale)
                .onOpenURL { url in
                    // Un archivo .fotomaterial recibido por AirDrop o abierto desde Archivos
                    // se publica como notificación; ContentView cambia al tab de Ajustes y
                    // SettingsView lanza la restauración automáticamente.
                    guard url.pathExtension.lowercased() == "fotomaterial" else { return }
                    NotificationCenter.default.post(name: .fotomaterialBackupReceived, object: url)
                }
        }
        .modelContainer(for: InventoryItem.self)
    }
}

// MARK: - Nombre de notificación

extension Notification.Name {
    /// Publicada cuando el sistema abre un archivo `.fotomaterial` en la app.
    static let fotomaterialBackupReceived = Notification.Name("FotoMaterial.backupReceived")
}
