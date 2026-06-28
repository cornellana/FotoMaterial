import UIKit
import WebKit

// MARK: - Servicio de exportación

/// Servicio sin estado que genera exportaciones del inventario en formato PDF y CSV.
///
/// El PDF se genera cargando el HTML en un `WKWebView` fuera de pantalla y llamando
/// a `createPDF` (iOS 14+), que es la única vía fiable en iOS 16+ para obtener un PDF
/// completo desde HTML/CSS sin depender del sistema de impresión (`UIMarkupTextPrintFormatter`
/// + `UIPrintPageRenderer`), que no funciona correctamente fuera del flujo de impresión real.
///
/// El CSV usa punto y coma como separador y comillas RFC 4180 para compatibilidad
/// con Excel en locales europeos (que usan coma como separador decimal).
struct ExportService {

    // MARK: - PDF

    /// Genera un PDF del inventario agrupado por categoría.
    ///
    /// La operación es asíncrona porque `WKWebView` necesita un ciclo de run-loop
    /// para cargar y renderizar el HTML antes de poder exportar.
    ///
    /// - Parameters:
    ///   - items: Lista de artículos a incluir en el PDF.
    ///   - locale: Instancia de localización para los textos del encabezado y columnas.
    /// - Returns: Datos binarios del PDF. Vacío si el renderizado falla.
    @MainActor
    static func generatePDF(items: [InventoryItem], locale: AppLocale) async -> Data {
        let html = buildHTML(items: items, locale: locale)

        // WKWebView fuera de pantalla; el ancho A4 (595 pt) define el layout de columnas.
        let webView = WKWebView(frame: CGRect(x: 0, y: 0, width: 595, height: 1))

        return await withCheckedContinuation { continuation in
            let loader = HTMLPDFLoader(continuation: continuation)
            webView.navigationDelegate = loader
            // Retener el loader asociado al webView para que no sea liberado antes de completarse.
            objc_setAssociatedObject(webView, &HTMLPDFLoader.retainKey, loader, .OBJC_ASSOCIATION_RETAIN)
            webView.loadHTMLString(html, baseURL: nil)
        }
    }

    // MARK: - HTML

    /// Construye el HTML con los datos del inventario, estilos CSS y estructura de tabla.
    /// - Parameters:
    ///   - items: Artículos ordenados por ID y agrupados por categoría.
    ///   - locale: Localización activa para traducir los literales de UI.
    /// - Returns: Cadena HTML completa lista para renderizar a PDF.
    private static func buildHTML(items: [InventoryItem], locale: AppLocale) -> String {
        let df = DateFormatter()
        df.dateStyle = .medium
        df.timeStyle = .none
        let dateStr = df.string(from: Date())

        let totalReplacement = items.reduce(0.0) { $0 + $1.valorReposicionTotal }
        let totalSM          = items.reduce(0.0) { $0 + $1.valorSegundaMano }
        let totalInsured     = items.reduce(0.0) { $0 + $1.valorAsegurado }

        let grouped    = Dictionary(grouping: items.sorted { $0.itemId < $1.itemId }, by: \.categoria)
        let sortedKeys = grouped.keys.sorted()

        var rowsHTML = ""
        for cat in sortedKeys {
            let catItems = grouped[cat] ?? []
            let catTotal = catItems.reduce(0.0) { $0 + $1.valorReposicionTotal }
            rowsHTML += """
            <tr class="cat-row"><td colspan="7"><strong>\(htmlEscape(cat))</strong></td>
            <td class="num"><strong>\(formatEur(catTotal))</strong></td></tr>
            """
            for item in catItems {
                rowsHTML += """
                <tr>
                <td>\(item.itemId)</td>
                <td>\(htmlEscape(item.articulo))</td>
                <td>\(htmlEscape(item.marca))</td>
                <td>\(htmlEscape(item.modelo))</td>
                <td class="num">\(item.cantidad)</td>
                <td class="num">\(formatEur(item.precioReposicionUnitario))</td>
                <td class="num">\(formatEur(item.valorReposicionTotal))</td>
                <td class="num">\(formatEur(item.valorAsegurado))</td>
                </tr>
                """
            }
        }

        return """
        <!DOCTYPE html><html><head><meta charset="UTF-8">
        <style>
        body{font-family:-apple-system,Helvetica,sans-serif;font-size:11px;margin:24px;color:#1a1a2e}
        h1{font-size:18px;margin-bottom:4px}
        .meta{display:flex;justify-content:space-between;margin-bottom:16px;font-size:11px;color:#555}
        table{width:100%;border-collapse:collapse}
        th{background:#1a1a2e;color:#fff;padding:6px 4px;text-align:left;font-size:10px}
        td{padding:5px 4px;border-bottom:1px solid #e0e0e0;font-size:10px}
        .cat-row td{background:#dce8f0;font-size:10px}
        .total-row td{background:#1a1a2e;color:#fff;font-weight:bold;padding:6px 4px}
        .num{text-align:right}
        .summary{margin-top:16px;font-size:11px}
        .summary table{width:300px;margin-left:auto}
        .summary td{padding:4px 8px}
        .summary .label{color:#555}
        .summary .amount{text-align:right;font-weight:bold}
        </style></head><body>
        <h1>\(locale.t("pdf.title"))</h1>
        <div class="meta">
          <span>\(locale.t("pdf.owner")): Francisco Cornellana</span>
          <span>\(locale.t("pdf.date")): \(dateStr)</span>
        </div>
        <table>
          <tr>
            <th>ID</th>
            <th>\(locale.t("field.articulo"))</th>
            <th>\(locale.t("field.marca"))</th>
            <th>\(locale.t("field.modelo"))</th>
            <th class="num">Ud</th>
            <th class="num">€/ud</th>
            <th class="num">Total €</th>
            <th class="num">Aseg. €</th>
          </tr>
          \(rowsHTML)
          <tr class="total-row">
            <td colspan="6">TOTAL (\(items.count) \(locale.t("summary.items")))</td>
            <td class="num">\(formatEur(totalReplacement))</td>
            <td class="num">\(formatEur(totalInsured))</td>
          </tr>
        </table>
        <div class="summary">
          <table>
            <tr><td class="label">\(locale.t("summary.total.replacement"))</td><td class="amount">\(formatEur(totalReplacement))</td></tr>
            <tr><td class="label">\(locale.t("summary.total.sm"))</td><td class="amount">\(formatEur(totalSM))</td></tr>
            <tr><td class="label">\(locale.t("summary.total.insured"))</td><td class="amount">\(formatEur(totalInsured))</td></tr>
          </table>
        </div>
        <p style="font-size:9px;color:#999;margin-top:16px">
          \(locale.t("pdf.criterion")): \(locale.t("pdf.criterion.value"))
        </p>
        </body></html>
        """
    }

    /// Formatea un valor monetario con separadores europeos (punto de miles, coma decimal).
    /// - Parameter value: Valor en euros.
    /// - Returns: Cadena con formato "1.234,56 €".
    private static func formatEur(_ value: Double) -> String {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.minimumFractionDigits = 2
        f.maximumFractionDigits = 2
        f.groupingSeparator = "."
        f.decimalSeparator = ","
        return (f.string(from: NSNumber(value: value)) ?? "0,00") + " €"
    }

    /// Escapa los caracteres especiales HTML en un texto.
    /// - Parameter s: Texto sin escapar.
    /// - Returns: Texto seguro para incluir en HTML.
    private static func htmlEscape(_ s: String) -> String {
        s.replacingOccurrences(of: "&", with: "&amp;")
         .replacingOccurrences(of: "<", with: "&lt;")
         .replacingOccurrences(of: ">", with: "&gt;")
    }

    // MARK: - CSV

    /// Genera un CSV del inventario con todos los campos del modelo.
    ///
    /// Formato: cabecera en la primera fila, separador `;`, campos entre comillas dobles.
    /// El orden de columnas es compatible con `ImportService.importCSV`.
    ///
    /// - Parameter items: Lista de artículos a exportar.
    /// - Returns: Cadena de texto con el contenido CSV completo (codificación UTF-8).
    static func generateCSV(items: [InventoryItem]) -> String {
        let header = [
            "ID", "Categoria", "Subcategoria", "Articulo", "Marca", "Modelo",
            "Cantidad", "EstadoComercial", "PrecioReposicionUnitario",
            "ValorReposicionTotal", "FactorSegundaMano", "ValorSegundaMano",
            "FactorSeguro", "ValorAsegurado", "PrioridadSeguro",
            "EvidenciaPDF", "URLAmazon", "FechaCompra", "Notas", "Revision"
        ].joined(separator: ";")

        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"

        let rows = items.sorted { $0.itemId < $1.itemId }.map { item in
            [
                "\(item.itemId)",
                csvEscape(item.categoria),
                csvEscape(item.subcategoria),
                csvEscape(item.articulo),
                csvEscape(item.marca),
                csvEscape(item.modelo),
                "\(item.cantidad)",
                csvEscape(item.estadoComercial),
                String(format: "%.2f", item.precioReposicionUnitario),
                String(format: "%.2f", item.valorReposicionTotal),
                String(format: "%.4f", item.factorSegundaMano),
                String(format: "%.2f", item.valorSegundaMano),
                String(format: "%.4f", item.factorSeguro),
                String(format: "%.2f", item.valorAsegurado),
                csvEscape(item.prioridadSeguro),
                csvEscape(item.evidenciaPDF),
                csvEscape(item.urlBusquedaAmazon),
                df.string(from: item.fechaCompra),
                csvEscape(item.notas),
                csvEscape(item.revisionOriginal)
            ].joined(separator: ";")
        }

        return ([header] + rows).joined(separator: "\n")
    }

    /// Envuelve un valor de campo CSV entre comillas dobles y escapa las comillas internas.
    /// - Parameter value: Texto del campo.
    /// - Returns: Texto escapado listo para incluir en el CSV.
    private static func csvEscape(_ value: String) -> String {
        let escaped = value.replacingOccurrences(of: "\"", with: "\"\"")
        return "\"\(escaped)\""
    }
}

// MARK: - Delegado privado para carga HTML → PDF

/// Carga HTML en el WKWebView y, cuando termina, solicita el PDF con `createPDF`.
///
/// Se retiene via `objc_setAssociatedObject` en el WKWebView para garantizar que
/// el objeto no sea liberado antes de completarse la operación asíncrona.
private final class HTMLPDFLoader: NSObject, WKNavigationDelegate {

    /// Clave para `objc_setAssociatedObject`; necesita ser una dirección de memoria estable.
    static var retainKey: UInt8 = 0

    private let continuation: CheckedContinuation<Data, Never>
    private var completed = false

    init(continuation: CheckedContinuation<Data, Never>) {
        self.continuation = continuation
    }

    func webView(_ webView: WKWebView, didFinish _: WKNavigation!) {
        guard !completed else { return }
        completed = true
        webView.createPDF { [weak self] result in
            self?.continuation.resume(returning: (try? result.get()) ?? Data())
        }
    }

    func webView(_ webView: WKWebView, didFail _: WKNavigation!, withError _: Error) {
        guard !completed else { return }
        completed = true
        continuation.resume(returning: Data())
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation _: WKNavigation!, withError _: Error) {
        guard !completed else { return }
        completed = true
        continuation.resume(returning: Data())
    }
}
