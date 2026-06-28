import SwiftUI
import SwiftData

// MARK: - Vista raíz

/// Vista raíz de la app con una barra de pestañas de cuatro secciones.
///
/// | Pestaña | Vista           | Descripción                              |
/// |---------|-----------------|------------------------------------------|
/// | 0       | InventoryListView | Lista plana de todos los artículos     |
/// | 1       | GroupedInventoryView | Vista agrupada por categoría         |
/// | 2       | — (acción)      | Dispara el asistente de nuevo artículo   |
/// | 3       | SettingsView    | Ajustes, importación y exportación       |
///
/// El tab 2 no tiene vista asociada: su selección se intercepta en `onChange(of:selectedTab)`
/// para mostrar el asistente como `sheet` y volver al tab 0.
struct ContentView: View {

    @EnvironmentObject var locale: AppLocale

    /// Pestaña actualmente seleccionada (0–3).
    @State private var selectedTab = 0

    /// Controla la presentación del asistente para añadir un artículo.
    @State private var showAddWizard = false

    var body: some View {
        TabView(selection: $selectedTab) {
            InventoryListView()
                .tabItem {
                    Label(locale.t("tab.inventory"), systemImage: "list.bullet.rectangle.portrait")
                }
                .tag(0)

            GroupedInventoryView()
                .tabItem {
                    Label(locale.t("tab.groups"), systemImage: "folder")
                }
                .tag(1)

            // Placeholder para el botón "+": su selección la captura onChange
            Color.clear
                .tabItem {
                    Label(locale.t("tab.add"), systemImage: "plus.circle.fill")
                }
                .tag(2)
                .onAppear {
                    // Fallback por si onAppear se dispara antes que onChange
                    if selectedTab == 2 {
                        showAddWizard = true
                        selectedTab = 0
                    }
                }

            SettingsView()
                .tabItem {
                    Label(locale.t("tab.settings"), systemImage: "gearshape")
                }
                .tag(3)
        }
        .onChange(of: selectedTab) { _, newValue in
            if newValue == 2 {
                showAddWizard = true
                selectedTab = 0
            }
        }
        .sheet(isPresented: $showAddWizard) {
            AddItemWizardView()
                .environmentObject(locale)
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(AppLocale())
        .modelContainer(for: InventoryItem.self, inMemory: true)
}
