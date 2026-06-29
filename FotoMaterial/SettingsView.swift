import SwiftUI
import SwiftData
import UniformTypeIdentifiers

// MARK: - Vista de ajustes

/// Vista de configuración con selector de idioma, importación/exportación
/// y un resumen del valor total del inventario.
///
/// Secciones:
/// - **Idioma**: selector segmentado ES / CA / EN.
/// - **Importar / Exportar**: botones para importar CSV/XLSX y exportar PDF o CSV.
/// - **Resumen**: totales de reposición, segunda mano e importe asegurado.
/// - **Acerca de**: versión y propietario.
struct SettingsView: View {

    @EnvironmentObject var locale: AppLocale
    @Environment(\.modelContext) private var modelContext

    /// Todos los artículos del inventario (para calcular los totales).
    @Query private var items: [InventoryItem]

    // MARK: Estado de importación CSV

    @State private var showImportPicker = false
    @State private var importMessage = ""
    @State private var showImportAlert = false

    // MARK: Estado de exportación

    @State private var exportData: Data?
    @State private var exportFilename = ""
    @State private var showShareSheet = false
    @State private var isGeneratingPDF = false

    // MARK: Estado de backup

    @State private var showBackupRestorePicker = false
    @State private var isGeneratingBackup = false
    @State private var backupMessage = ""
    @State private var showBackupAlert = false

    // MARK: Cuerpo

    var body: some View {
        NavigationStack {
            Form {
                languageSection
                importExportSection
                backupSection
                summarySection
                aboutSection
            }
            .navigationTitle(locale.t("settings.title"))
            .onReceive(NotificationCenter.default.publisher(for: .fotomaterialBackupReceived)) { notif in
                // Apertura directa desde la app Archivos o AirDrop
                if let url = notif.object as? URL {
                    performRestore(url: url)
                }
            }
            .fileImporter(
                isPresented: $showImportPicker,
                allowedContentTypes: [
                    .commaSeparatedText,
                    UTType(filenameExtension: "xlsx") ?? .data,
                    UTType(filenameExtension: "csv")  ?? .commaSeparatedText,
                    .data
                ],
                allowsMultipleSelection: false,
                onCompletion: handleImport
            )
            .sheet(isPresented: $showShareSheet) {
                if let data = exportData {
                    ShareSheet(items: [data], filename: exportFilename)
                }
            }
            .fileImporter(
                isPresented: $showBackupRestorePicker,
                allowedContentTypes: [
                    UTType(filenameExtension: "fotomaterial") ?? .data,
                    .zip, .data
                ],
                allowsMultipleSelection: false,
                onCompletion: handleBackupRestore
            )
            .alert(
                importMessage.hasPrefix("✓") ? locale.t("import.success") : locale.t("import.error"),
                isPresented: $showImportAlert
            ) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(importMessage)
            }
            .alert(
                backupMessage.hasPrefix("✓") ? locale.t("backup.success") : locale.t("backup.error"),
                isPresented: $showBackupAlert
            ) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(backupMessage)
            }
        }
    }

    // MARK: Secciones

    /// Sección con el selector segmentado de idioma de la interfaz.
    private var languageSection: some View {
        Section(locale.t("settings.language")) {
            Picker(locale.t("settings.language"), selection: $locale.language) {
                ForEach(AppLocale.availableLanguages, id: \.code) { lang in
                    Text(lang.name).tag(lang.code)
                }
            }
            .pickerStyle(.segmented)
            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
        }
    }

    /// Sección con los botones de importar CSV/XLSX y exportar PDF/CSV.
    private var importExportSection: some View {
        Section(locale.t("settings.import.export")) {
            Button {
                showImportPicker = true
            } label: {
                Label(locale.t("import.csv"), systemImage: "arrow.down.doc")
            }

            Button {
                exportPDF()
            } label: {
                if isGeneratingPDF {
                    Label(locale.t("loading"), systemImage: "doc.richtext")
                } else {
                    Label(locale.t("export.pdf"), systemImage: "doc.richtext")
                }
            }
            .disabled(isGeneratingPDF)

            Button { exportCSV() } label: {
                Label(locale.t("export.csv"), systemImage: "tablecells")
            }
        }
    }

    /// Sección de backup completo (incluye fotografías y facturas).
    private var backupSection: some View {
        Section(locale.t("backup.section")) {
            Button {
                exportBackup()
            } label: {
                if isGeneratingBackup {
                    Label(locale.t("loading"), systemImage: "archivebox")
                } else {
                    Label(locale.t("backup.export"), systemImage: "archivebox.fill")
                }
            }
            .disabled(isGeneratingBackup)

            Button {
                showBackupRestorePicker = true
            } label: {
                Label(locale.t("backup.import"), systemImage: "arrow.down.doc.fill")
            }
        }
    }

    /// Sección con el resumen financiero del inventario completo.
    private var summarySection: some View {
        Section("Resumen") {
            summaryRow("total.replacement", value: items.reduce(0) { $0 + $1.valorReposicionTotal })
            summaryRow("total.sm",          value: items.reduce(0) { $0 + $1.valorSegundaMano })
            summaryRow("total.insured",     value: items.reduce(0) { $0 + $1.valorAsegurado })
            HStack {
                Text(locale.t("summary.items"))
                Spacer()
                Text("\(items.count)").bold()
            }
        }
    }

    /// Sección con información de versión y propietario.
    private var aboutSection: some View {
        Section(locale.t("settings.about")) {
            LabeledContent("Versión", value: "1.0")
            LabeledContent("Propietario", value: "Francisco Cornellana")
        }
    }

    // MARK: Helpers

    /// Crea una fila de resumen con etiqueta localizada y valor formateado en euros.
    /// - Parameters:
    ///   - key: Sufijo de la clave de localización (se antepone "summary.").
    ///   - value: Valor monetario a mostrar.
    private func summaryRow(_ key: String, value: Double) -> some View {
        HStack {
            Text(locale.t("summary.\(key)"))
            Spacer()
            Text(formatEur(value)).bold().foregroundStyle(.primary)
        }
    }

    // MARK: Exportación

    /// Genera el PDF del inventario y abre la hoja de compartición.
    ///
    /// La generación es asíncrona (WKWebView necesita renderizar el HTML antes de exportar).
    /// El botón se deshabilita mientras se genera para evitar llamadas concurrentes.
    private func exportPDF() {
        isGeneratingPDF = true
        Task { @MainActor in
            exportData      = await ExportService.generatePDF(items: items, locale: locale)
            exportFilename  = "FotoMaterial_\(dateStamp()).pdf"
            isGeneratingPDF = false
            showShareSheet  = true
        }
    }

    /// Genera el CSV del inventario y abre la hoja de compartición.
    private func exportCSV() {
        exportData     = ExportService.generateCSV(items: items).data(using: .utf8)
        exportFilename = "FotoMaterial_\(dateStamp()).csv"
        showShareSheet = true
    }

    // MARK: Importación

    /// Maneja el resultado del selector de fichero de importación.
    /// - Parameter result: Resultado con la lista de URLs seleccionadas o el error.
    private func handleImport(result: Result<[URL], Error>) {
        do {
            let urls = try result.get()
            guard let url = urls.first else { return }
            _ = url.startAccessingSecurityScopedResource()
            defer { url.stopAccessingSecurityScopedResource() }

            let data       = try Data(contentsOf: url)
            let filename   = url.lastPathComponent
            let imported   = ImportService.importFile(data: data, filename: filename)

            for item in imported.items { modelContext.insert(item) }
            try modelContext.save()

            let count    = imported.items.count
            let errCount = imported.errors.count
            importMessage = errCount > 0
                ? "✓ \(count) \(locale.t("import.rows")). \(errCount) errores."
                : "✓ \(count) \(locale.t("import.rows"))."
        } catch {
            importMessage = error.localizedDescription
        }
        showImportAlert = true
    }

    // MARK: Backup

    /// Genera el backup completo y abre la hoja de compartición.
    private func exportBackup() {
        isGeneratingBackup = true
        Task { @MainActor in
            let data           = BackupService.generateBackup(items: items)
            exportData         = data
            exportFilename     = "FotoMaterial_backup_\(dateStamp()).fotomaterial"
            isGeneratingBackup = false
            showShareSheet     = true
        }
    }

    /// Maneja el archivo de backup seleccionado por el usuario y restaura su contenido.
    private func handleBackupRestore(result: Result<[URL], Error>) {
        do {
            let urls = try result.get()
            guard let url = urls.first else { return }
            performRestore(url: url)
        } catch {
            backupMessage = error.localizedDescription
            showBackupAlert = true
        }
    }

    /// Restaura un backup desde una URL (picker o apertura directa desde Archivos/AirDrop).
    private func performRestore(url: URL) {
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }
        do {
            let data    = try Data(contentsOf: url)
            let summary = try BackupService.restoreBackup(data: data, into: modelContext)
            backupMessage = "✓ \(summary.inserted) añadidos, \(summary.updated) actualizados."
        } catch {
            backupMessage = error.localizedDescription
        }
        showBackupAlert = true
    }

    // MARK: Utilidades

    /// Devuelve la fecha actual en formato `yyyyMMdd` para nombrar los ficheros exportados.
    private func dateStamp() -> String {
        let df = DateFormatter()
        df.dateFormat = "yyyyMMdd"
        return df.string(from: Date())
    }

    private func formatEur(_ v: Double) -> String {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.minimumFractionDigits = 2
        f.maximumFractionDigits = 2
        return (f.string(from: NSNumber(value: v)) ?? "0,00") + " €"
    }
}

// MARK: - Hoja de compartición

/// Representable que envuelve `UIActivityViewController` para compartir ficheros.
///
/// Si el primer elemento de `items` es un `Data`, lo escribe en un fichero temporal
/// antes de compartirlo para que las apps receptoras puedan acceder al contenido.
struct ShareSheet: UIViewControllerRepresentable {

    /// Elementos a compartir (normalmente un único `Data`).
    let items: [Any]

    /// Nombre del fichero temporal que se creará en el directorio de temporales.
    let filename: String

    func makeUIViewController(context: Context) -> UIActivityViewController {
        var shareItems = items
        if let data = items.first as? Data {
            let tmp = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
            try? data.write(to: tmp)
            shareItems = [tmp]
        }
        return UIActivityViewController(activityItems: shareItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
