import SwiftUI
import SwiftData

// MARK: - Lista de inventario

/// Vista principal que muestra todos los artículos del inventario en una lista filtrable.
///
/// Incluye:
/// - Barra superior con el total de artículos visibles y el valor de reposición acumulado.
/// - Campo de búsqueda que filtra por artículo, marca, modelo y categoría.
/// - Lista con filas `InventoryRow`; deslizar a la izquierda para eliminar.
/// - Navegación al detalle al tocar una fila.
/// - Botón "+" en la barra de navegación que abre el asistente de añadir artículo.
struct InventoryListView: View {

    @EnvironmentObject var locale: AppLocale
    @Environment(\.modelContext) private var modelContext

    /// Todos los artículos ordenados por ID ascendente.
    @Query(sort: \InventoryItem.itemId) private var items: [InventoryItem]

    /// Texto de búsqueda introducido por el usuario.
    @State private var searchText = ""

    /// Controla si el asistente de nuevo artículo está visible.
    @State private var showAddWizard = false

    // MARK: Datos filtrados

    /// Subconjunto de artículos que coinciden con el texto de búsqueda.
    /// Si la búsqueda está vacía devuelve todos los artículos sin coste adicional.
    private var filtered: [InventoryItem] {
        guard !searchText.isEmpty else { return items }
        let q = searchText.lowercased()
        return items.filter {
            $0.articulo.lowercased().contains(q) ||
            $0.marca.lowercased().contains(q) ||
            $0.modelo.lowercased().contains(q) ||
            $0.categoria.lowercased().contains(q)
        }
    }

    /// Suma del valor de reposición total de todos los artículos visibles actualmente.
    private var totalReplacement: Double {
        filtered.reduce(0) { $0 + $1.valorReposicionTotal }
    }

    // MARK: Cuerpo

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                summaryBar
                Divider()
                contentArea
            }
            .navigationTitle(locale.t("tab.inventory"))
            .searchable(text: $searchText,
                        placement: .navigationBarDrawer(displayMode: .always),
                        prompt: locale.t("search.placeholder"))
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { showAddWizard = true } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .navigationDestination(for: InventoryItem.self) { item in
                ItemDetailView(item: item)
                    .environmentObject(locale)
            }
            .sheet(isPresented: $showAddWizard) {
                AddItemWizardView()
                    .environmentObject(locale)
            }
        }
    }

    // MARK: Subvistas

    /// Barra superior con el número de artículos visibles y el valor total de reposición.
    private var summaryBar: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("\(filtered.count) \(locale.t("summary.items"))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(formatEur(totalReplacement))
                    .font(.headline)
                    .fontWeight(.bold)
            }
            Spacer()
            Text(locale.t("summary.total.replacement"))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(.bar)
    }

    /// Área central: lista de artículos o estado vacío.
    @ViewBuilder
    private var contentArea: some View {
        if filtered.isEmpty {
            ContentUnavailableView(
                locale.t("no.items"),
                systemImage: "camera.metering.none",
                description: Text(searchText.isEmpty ? "" : "Para: \"\(searchText)\"")
            )
        } else {
            List {
                ForEach(filtered) { item in
                    NavigationLink(value: item) {
                        InventoryRow(item: item)
                    }
                    .buttonStyle(.plain)
                }
                .onDelete(perform: deleteItems)
            }
            .listStyle(.plain)
        }
    }

    // MARK: Acciones

    /// Elimina los artículos en las posiciones indicadas y persiste el contexto.
    /// - Parameter offsets: Índices de la lista filtrada a eliminar.
    private func deleteItems(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(filtered[index])
        }
        try? modelContext.save()
    }

    /// Formatea un valor en euros usando separadores del locale del dispositivo.
    /// - Parameter v: Valor en euros.
    /// - Returns: Cadena formateada, p. ej. "1.234,56 €".
    private func formatEur(_ v: Double) -> String {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.minimumFractionDigits = 2
        f.maximumFractionDigits = 2
        return (f.string(from: NSNumber(value: v)) ?? "0,00") + " €"
    }
}

// MARK: - Fila de artículo

/// Fila compacta que muestra la miniatura, nombre, marca/modelo,
/// valor de reposición, categoría y prioridad de seguro de un artículo.
struct InventoryRow: View {

    /// Artículo a representar.
    let item: InventoryItem

    var body: some View {
        HStack(spacing: 12) {
            thumbnail
            infoStack
        }
        .padding(.vertical, 4)
    }

    // MARK: Subvistas

    /// Miniatura cuadrada del artículo o icono de cámara si no hay imagen.
    private var thumbnail: some View {
        Group {
            if let data = item.imagenData, let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
            } else {
                Image(systemName: "camera")
                    .font(.title2)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: 56, height: 56)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    /// Columna derecha con nombre, marca/modelo, valor y etiquetas de categoría/prioridad.
    private var infoStack: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                Text(item.articulo)
                    .font(.headline)
                    .lineLimit(1)
                Spacer()
                VStack(alignment: .trailing, spacing: 1) {
                    Text(formatEur(item.valorReposicionTotal))
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    if let sn = item.numeroSerie, !sn.isEmpty {
                        Text("S/N: \(sn)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            HStack {
                if !item.marca.isEmpty {
                    Text(item.marca).font(.caption).foregroundStyle(.secondary)
                }
                if !item.modelo.isEmpty {
                    Text("· \(item.modelo)").font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                if item.cantidad > 1 {
                    Text("×\(item.cantidad)").font(.caption).foregroundStyle(.secondary)
                }
            }
            HStack {
                Text(item.categoria)
                    .font(.caption2)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.accentColor.opacity(0.1))
                    .foregroundStyle(Color.accentColor)
                    .clipShape(Capsule())
                if item.facturaData != nil {
                    Image(systemName: "doc.text.fill")
                        .font(.caption2)
                        .foregroundStyle(.green)
                }
                Spacer()
                PriorityBadge(priority: item.prioridadSeguro)
            }
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

// MARK: - Etiqueta de prioridad

/// Pastilla de color que indica la prioridad de seguro de un artículo.
///
/// | Prioridad | Color   |
/// |-----------|---------|
/// | Crítica   | Rojo    |
/// | Alta      | Naranja |
/// | Media     | Amarillo|
/// | Baja/otro | Gris    |
struct PriorityBadge: View {

    /// Valor de prioridad del artículo (p. ej. "Crítica").
    let priority: String

    /// Color semántico según la prioridad.
    private var color: Color {
        switch priority.lowercased() {
        case "crítica": return .red
        case "alta":    return .orange
        case "media":   return .yellow
        default:        return .gray
        }
    }

    var body: some View {
        Text(priority)
            .font(.caption2)
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(color.opacity(0.15))
            .foregroundStyle(color)
            .clipShape(Capsule())
    }
}
