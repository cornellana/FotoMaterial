import Foundation
import zlib

struct ImportService {

    struct ImportResult {
        var items: [InventoryItem]
        var errors: [String]
    }

    // MARK: - Public entry point

    static func importFile(data: Data, filename: String) -> ImportResult {
        let ext = (filename as NSString).pathExtension.lowercased()
        if ext == "xlsx" {
            return importXLSX(data: data)
        } else {
            let text = String(data: data, encoding: .utf8)
                ?? String(data: data, encoding: .isoLatin1)
                ?? ""
            return importCSV(text: text)
        }
    }

    // MARK: - CSV Import

    static func importCSV(text: String) -> ImportResult {
        var items: [InventoryItem] = []
        var errors: [String] = []
        let separator = text.contains(";") ? ";" : ","

        var lines = text.components(separatedBy: "\n").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        guard !lines.isEmpty else { return ImportResult(items: [], errors: ["Empty file"]) }

        // Detect and skip header row
        let firstLine = lines[0].lowercased()
        if firstLine.contains("articulo") || firstLine.contains("marca") || firstLine.contains("id") {
            lines.removeFirst()
        }

        var lastCategory = ""
        var autoId = 1

        for (idx, line) in lines.enumerated() {
            guard !line.isEmpty else { continue }
            let cols = parseCSVLine(line, separator: Character(separator))

            guard cols.count >= 6 else {
                errors.append("Row \(idx + 2): not enough columns (\(cols.count))")
                continue
            }

            let item = InventoryItem()

            // ID — col 0
            item.itemId = Int(cols[0]) ?? autoId

            // Category — col 1, carry forward if empty
            let cat = cols.count > 1 ? cols[1].trimmingCharacters(in: .whitespaces) : ""
            if !cat.isEmpty { lastCategory = cat }
            item.categoria = lastCategory

            item.subcategoria = cols.count > 2 ? cols[2] : ""
            item.articulo = cols.count > 3 ? cols[3] : ""
            item.marca = cols.count > 4 ? cols[4] : ""
            item.modelo = cols.count > 5 ? cols[5] : ""
            item.cantidad = cols.count > 6 ? (Int(cols[6]) ?? 1) : 1
            item.estadoComercial = cols.count > 7 ? cols[7] : ""
            item.precioReposicionUnitario = cols.count > 8 ? parseDouble(cols[8]) : 0
            // col 9 = valorReposicionTotal (computed, skip)
            item.factorSegundaMano = cols.count > 10 ? parseDouble(cols[10]) : 0.6
            // col 11 = valorSegundaMano (computed, skip)
            item.factorSeguro = cols.count > 12 ? parseDouble(cols[12]) : 1.15
            // col 13 = valorAsegurado (computed, skip)
            item.prioridadSeguro = cols.count > 14 ? cols[14] : "Media"
            item.evidenciaPDF = cols.count > 15 ? cols[15] : ""
            item.urlBusquedaAmazon = cols.count > 16 ? cols[16] : ""

            // Col 17: intenta fecha de compra (CSVs exportados por la app);
            // si no es fecha válida, es la columna Notas de este Excel.
            if cols.count > 17 {
                if let date = parseDate(cols[17]) {
                    item.fechaCompra = date
                    item.notas = cols.count > 18 ? cols[18] : ""
                    item.revisionOriginal = cols.count > 19 ? cols[19] : ""
                    item.numeroSerie = cols.count > 20 ? cols[20] : ""
                } else {
                    item.notas = cols[17]
                    item.revisionOriginal = cols.count > 18 ? cols[18] : ""
                    item.numeroSerie = cols.count > 19 ? cols[19] : ""
                }
            }

            items.append(item)
            autoId += 1
        }

        return ImportResult(items: items, errors: errors)
    }

    // MARK: - XLSX Import

    static func importXLSX(data: Data) -> ImportResult {
        let errors: [String] = []
        guard let entries = extractZIPEntries(data: data) else {
            return ImportResult(items: [], errors: ["Could not read XLSX file"])
        }

        // Parse shared strings
        var sharedStrings: [String] = []
        if let ssData = entries["xl/sharedStrings.xml"],
           let ssText = String(data: ssData, encoding: .utf8) {
            sharedStrings = parseSharedStrings(ssText)
        }

        // Find the inventory sheet (sheet2 is "Inventario valorado")
        let sheetData = entries["xl/worksheets/sheet2.xml"]
            ?? entries["xl/worksheets/sheet1.xml"]

        guard let sheetXML = sheetData,
              let sheetText = String(data: sheetXML, encoding: .utf8) else {
            return ImportResult(items: [], errors: ["Sheet not found in XLSX"])
        }

        let csvText = convertSheetToCSV(sheetText, sharedStrings: sharedStrings)
        var result = importCSV(text: csvText)
        result.errors.append(contentsOf: errors)
        return result
    }

    // MARK: - ZIP Extraction (raw deflate via zlib)

    private static func extractZIPEntries(data: Data) -> [String: Data]? {
        var entries: [String: Data] = [:]
        let bytes = [UInt8](data)
        var offset = 0

        while offset + 30 < bytes.count {
            // Local file header signature: PK 0x03 0x04
            guard bytes[offset] == 0x50, bytes[offset+1] == 0x4B,
                  bytes[offset+2] == 0x03, bytes[offset+3] == 0x04 else {
                offset += 1
                continue
            }
            let compression  = Int(bytes[offset+8])  | (Int(bytes[offset+9])  << 8)
            let compSize     = readLE32(bytes, offset+18)
            let fnLen        = Int(bytes[offset+26])  | (Int(bytes[offset+27]) << 8)
            let extraLen     = Int(bytes[offset+28])  | (Int(bytes[offset+29]) << 8)
            let headerEnd    = offset + 30 + fnLen + extraLen

            guard headerEnd + compSize <= bytes.count else { break }

            if let name = String(bytes: bytes[(offset+30)..<(offset+30+fnLen)], encoding: .utf8) {
                let compData = Data(bytes[headerEnd..<(headerEnd+compSize)])
                if compression == 0 {
                    entries[name] = compData
                } else if compression == 8, let decompressed = inflateRaw(compData) {
                    entries[name] = decompressed
                }
            }
            offset = headerEnd + compSize
        }
        return entries.isEmpty ? nil : entries
    }

    private static func readLE32(_ bytes: [UInt8], _ offset: Int) -> Int {
        Int(bytes[offset]) | (Int(bytes[offset+1]) << 8) |
        (Int(bytes[offset+2]) << 16) | (Int(bytes[offset+3]) << 24)
    }

    private static func inflateRaw(_ data: Data) -> Data? {
        guard !data.isEmpty else { return nil }
        var stream = z_stream()
        // -15 = raw deflate; zlibVersion() returns the version string (avoids ZLIB_VERSION C macro)
        var status = inflateInit2_(&stream, -15, zlibVersion(), Int32(MemoryLayout<z_stream>.size))
        guard status == Z_OK else { return nil }
        defer { inflateEnd(&stream) }

        var output = Data()
        let bufSize = 65536
        // Allocate output buffer via pointer so we can directly assign to stream.next_out
        let buf = UnsafeMutablePointer<Bytef>.allocate(capacity: bufSize)
        defer { buf.deallocate() }

        let inputBytes = [UInt8](data)
        inputBytes.withUnsafeBufferPointer { inputBuf in
            stream.next_in = UnsafeMutablePointer(mutating: inputBuf.baseAddress!)
            stream.avail_in = uInt(inputBytes.count)
            repeat {
                stream.next_out = buf
                stream.avail_out = uInt(bufSize)
                status = inflate(&stream, Z_NO_FLUSH)
                let produced = bufSize - Int(stream.avail_out)
                if produced > 0 { output.append(buf, count: produced) }
            } while status == Z_OK && stream.avail_out == 0
        }
        return status == Z_STREAM_END ? output : (output.isEmpty ? nil : output)
    }

    // MARK: - XLSX XML Parsing

    private static func parseSharedStrings(_ xml: String) -> [String] {
        var result: [String] = []
        // Simple regex-free parser: find <t> tags
        var search = xml
        while let siRange = search.range(of: "<si>") {
            guard let endSI = search.range(of: "</si>") else { break }
            let siContent = String(search[siRange.upperBound..<endSI.lowerBound])
            var text = ""
            var inner = siContent
            while let tOpen = inner.range(of: "<t") {
                guard let tClose = inner[tOpen.upperBound...].range(of: ">") else { break }
                let afterTag = inner[tClose.upperBound...]
                guard let tEnd = afterTag.range(of: "</t>") else { break }
                text += String(afterTag[..<tEnd.lowerBound])
                    .replacingOccurrences(of: "&amp;", with: "&")
                    .replacingOccurrences(of: "&lt;", with: "<")
                    .replacingOccurrences(of: "&gt;", with: ">")
                    .replacingOccurrences(of: "&#xA;", with: "\n")
                inner = String(afterTag[tEnd.upperBound...])
            }
            result.append(text)
            search = String(search[endSI.upperBound...])
        }
        return result
    }

    /// Convierte el XML de una hoja XLSX a CSV usando las referencias de celda (`r="B3"`)
    /// para determinar la columna real de cada celda.
    ///
    /// Maneja correctamente:
    /// - Celdas auto-cierre `<c r="B3" s="1"/>` (categorías vacías en Bing).
    /// - Celdas con fórmula: lee el valor cacheado `<v>` en lugar de `<f>`.
    /// - Huecos por celdas ausentes: rellena con cadena vacía según el índice de columna.
    private static func convertSheetToCSV(_ xml: String, sharedStrings: [String]) -> String {
        var rows: [[String]] = []
        var search = xml

        while let rowOpen = search.range(of: "<row ") ?? search.range(of: "<row>") {
            guard let rowClose = search.range(of: "</row>") else { break }
            let rowXML = String(search[rowOpen.lowerBound..<rowClose.upperBound])
            search = String(search[rowClose.upperBound...])

            // Mapa columna→valor para esta fila
            var cellsByCol: [Int: String] = [:]
            var cellSearch = rowXML

            while let cStart = cellSearch.range(of: "<c ") ?? cellSearch.range(of: "<c>") {
                let fromC = String(cellSearch[cStart.lowerBound...])

                // Detectar si la celda es auto-cierre (<c r="B3"/>) o normal (<c ...>...</c>)
                let selfClosePos = fromC.range(of: "/>")
                let endTagPos    = fromC.range(of: "</c>")
                let cellXML: String
                let afterCell: String

                if let sc = selfClosePos,
                   (endTagPos == nil || sc.lowerBound < endTagPos!.lowerBound) {
                    cellXML   = String(fromC[..<sc.upperBound])
                    afterCell = String(fromC[sc.upperBound...])
                } else if let et = endTagPos {
                    cellXML   = String(fromC[..<et.upperBound])
                    afterCell = String(fromC[et.upperBound...])
                } else {
                    break
                }

                // Columna 0-based a partir del atributo r ("A1"→0, "B3"→1, "S5"→18…)
                let col = colIndex(from: extractAttr(cellXML, attr: "r"))

                // Valor: cadena compartida (t="s") o número/vacío
                let cellType  = extractAttr(cellXML, attr: "t")
                let valueText = extractTag(cellXML, tag: "v")
                let cellValue: String
                if cellType == "s", let idx = Int(valueText), idx < sharedStrings.count {
                    cellValue = sharedStrings[idx]
                } else {
                    cellValue = valueText
                }

                cellsByCol[col] = cellValue
                cellSearch = afterCell
            }

            // Construir array rellenando huecos con ""
            if !cellsByCol.isEmpty {
                let maxCol = cellsByCol.keys.max()!
                var row = Array(repeating: "", count: maxCol + 1)
                for (col, val) in cellsByCol { row[col] = val }
                rows.append(row)
            }
        }

        return rows.map { row in
            row.map { "\"\($0.replacingOccurrences(of: "\"", with: "\"\""))\"" }
               .joined(separator: ";")
        }.joined(separator: "\n")
    }

    /// Convierte una referencia de celda XLSX (ej. "B3", "AA12") al índice de columna 0-based.
    /// - Parameter ref: Referencia de celda, p. ej. `"A1"` → 0, `"B3"` → 1, `"S5"` → 18.
    private static func colIndex(from ref: String) -> Int {
        var idx = 0
        for ch in ref.uppercased() {
            guard ch.isLetter else { break }
            idx = idx * 26 + Int(ch.asciiValue! - 64)
        }
        return max(0, idx - 1)
    }

    private static func extractAttr(_ text: String, attr: String) -> String {
        guard let r = text.range(of: "\(attr)=\"") else { return "" }
        let after = text[r.upperBound...]
        guard let end = after.range(of: "\"") else { return "" }
        return String(after[..<end.lowerBound])
    }

    private static func extractTag(_ text: String, tag: String) -> String {
        // Handles both <tag> and <tag attr="…"> forms
        guard let start = text.range(of: "<\(tag)") else { return "" }
        let afterName = text[start.upperBound...]
        guard let closeBracket = afterName.range(of: ">") else { return "" }
        let content = afterName[closeBracket.upperBound...]
        guard let end = content.range(of: "</\(tag)>") else { return "" }
        return String(content[..<end.lowerBound])
    }

    // MARK: - CSV Line Parser (handles quoted fields)

    static func parseCSVLine(_ line: String, separator: Character) -> [String] {
        var fields: [String] = []
        var current = ""
        var inQuotes = false
        var chars = line.unicodeScalars.makeIterator()

        while let ch = chars.next() {
            let c = Character(ch)
            if inQuotes {
                if c == "\"" {
                    // Peek at next char
                    if current.hasSuffix("\"") {
                        // Already appended one quote - it was an escaped quote
                    }
                    inQuotes = false
                } else {
                    current.append(c)
                }
            } else {
                if c == "\"" {
                    inQuotes = true
                } else if c == separator {
                    fields.append(current)
                    current = ""
                } else {
                    current.append(c)
                }
            }
        }
        fields.append(current)
        return fields
    }

    // MARK: - Helpers

    private static func parseDouble(_ s: String) -> Double {
        let clean = s.trimmingCharacters(in: .whitespaces)
            .replacingOccurrences(of: ",", with: ".")
            .replacingOccurrences(of: " ", with: "")
        return Double(clean) ?? 0
    }

    private static func parseDate(_ s: String) -> Date? {
        let formats = ["yyyy-MM-dd", "dd/MM/yyyy", "MM/dd/yyyy", "dd-MM-yyyy"]
        let df = DateFormatter()
        for fmt in formats {
            df.dateFormat = fmt
            if let d = df.date(from: s.trimmingCharacters(in: .whitespaces)) { return d }
        }
        return nil
    }
}
