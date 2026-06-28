import SwiftUI
import SwiftData

// MARK: - Vista agrupada por categoría

/// Vista que agrupa todos los artículos del inventario por su campo `categoria`.
///
/// Cada categoría se muestra como una sección colapsable con:
/// - Cabecera con el nombre, número de artículos y subtotal de reposición.
/// - Filas `InventoryRow` visibles cuando la sección está expandida.
///
/// Por defecto todas las secciones aparecen expandidas al entrar en la vista.
struct GroupedInventoryView: View {

    @EnvironmentObject var locale: AppLocale
    @Environment(\.modelContext) private var modelContext

    /// Todos los artículos ordenados por ID ascendente.
    @Query(sort: \InventoryItem.itemId) private var items: [InventoryItem]

    /// Artículo seleccionado para navegar al detalle.
    @State private var selectedItem: InventoryItem?

    /// Conjunto de categorías actualmente expandidas.
    @State private var expandedGroups: Set<String> = []

    // MARK: Datos agrupados

    /// Lista de pares (categoría, artículos) ordenada alfabéticamente por categoría.
    private var grouped: [(category: String, items: [InventoryItem])] {
        let dict = Dictionary(grouping: items, by: \.categoria)
        return dict.keys.sorted().map { key in
            (category: key, items: dict[key]!.sorted { $0.itemId < $1.itemId })
        }
    }

    // MARK: Cuerpo

    var body: some View {
        NavigationStack {
            Group {
                if grouped.isEmpty {
                    ContentUnavailableView(
                        locale.t("no.items"),
                        systemImage: "folder",
                        description: Text("")
                    )
                } else {
                    List {
                        ForEach(grouped, id: \.category) { group in
                            GroupSection(
                                group: group,
                                isExpanded: expandedGroups.contains(group.category),
                                locale: locale,
                                onToggle: { toggleGroup(group.category) },
                                onSelect: { item in selectedItem = item }
                            )
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle(locale.t("tab.groups"))
            .navigationDestination(item: $selectedItem) { item in
                ItemDetailView(item: item)
                    .environmentObject(locale)
            }
            .onAppear {
                // Expandir todas las categorías la primera vez que aparece la vista
                if expandedGroups.isEmpty {
                    expandedGroups = Set(grouped.map(\.category))
                }
            }
        }
    }

    // MARK: Acciones

    /// Alterna el estado expandido/colapsado de una categoría.
    /// - Parameter category: Nombre de la categoría a alternar.
    private func toggleGroup(_ category: String) {
        if expandedGroups.contains(category) {
            expandedGroups.remove(category)
        } else {
            expandedGroups.insert(category)
        }
    }
}

// MARK: - Sección de grupo

/// Sección de la lista que representa una categoría con su cabecera y artículos.
///
/// La cabecera es un botón que dispara `onToggle` para expandir/colapsar la sección.
/// Los artículos solo se renderizan cuando `isExpanded` es `true`, lo que evita
/// crear las vistas `InventoryRow` innecesariamente para categorías colapsadas.
struct GroupSection: View {

    /// Par (categoría, artículos) de esta sección.
    let group: (category: String, items: [InventoryItem])

    /// Indica si los artículos de la sección son visibles.
    let isExpanded: Bool

    /// Localización activa para formatear el subtotal y los textos.
    let locale: AppLocale

    /// Callback para alternar la expansión de la sección.
    let onToggle: () -> Void

    /// Callback que proporciona el artículo seleccionado al padre para la navegación.
    let onSelect: (InventoryItem) -> Void

    /// Suma del valor de reposición de todos los artículos de este grupo.
    private var groupTotal: Double {
        group.items.reduce(0) { $0 + $1.valorReposicionTotal }
    }

    var body: some View {
        Section {
            if isExpanded {
                ForEach(group.items) { item in
                    InventoryRow(item: item)
                        .contentShape(Rectangle())
                        .onTapGesture { onSelect(item) }
                }
            }
        } header: {
            Button(action: onToggle) {
                HStack {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(group.category)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Spacer()
                    VStack(alignment: .trailing, spacing: 1) {
                        Text(formatEur(groupTotal))
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(.primary)
                        Text("\(group.items.count) \(locale.t("summary.items"))")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 4)
            }
            .buttonStyle(.plain)
        }
    }

    private func formatEur(_ v: Double) -> String {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.minimumFractionDigits = 2
        f.maximumFractionDigits = 2
        return (f.string(from: NSNumber(value: v)) ?? "0") + " €"
    }
}
