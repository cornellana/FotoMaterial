import Foundation
import SwiftData
import zlib

// MARK: - Servicio de backup completo

/// Genera y restaura copias de seguridad completas del inventario,
/// incluyendo datos textuales, fotografías de artículos y facturas.
///
/// Formato del archivo: ZIP estándar (extensión `.fotomaterial`) con:
/// - `inventory.json` — todos los campos de texto de los artículos.
/// - `images/<uuid>.jpg` — fotografía de cada artículo (si existe).
/// - `invoices/<uuid>.jpg` — factura de cada artículo (si existe).
///
/// Las imágenes se almacenan sin compresión adicional (método "store"),
/// ya que JPEG/HEIC ya son formatos comprimidos.
struct BackupService {

    // MARK: - DTO

    /// Representación `Codable` de un `InventoryItem`.
    /// Separa el modelo SwiftData de la serialización para evitar dependencias del ORM.
    struct ItemDTO: Codable {
        var uuid: UUID
        var itemId: Int
        var categoria: String
        var subcategoria: String
        var articulo: String
        var marca: String
        var modelo: String
        var numeroSerie: String
        var cantidad: Int
        var estadoComercial: String
        var precioReposicionUnitario: Double
        var factorSegundaMano: Double
        var factorSeguro: Double
        var prioridadSeguro: String
        var evidenciaPDF: String
        var urlBusquedaAmazon: String
        var notas: String
        var revisionOriginal: String
        var revisionES: String
        var revisionCA: String
        var revisionEN: String
        var imagenURL: String
        var fechaCompra: Date
        var fechaCreacion: Date
    }

    struct BackupManifest: Codable {
        var version: Int
        var items: [ItemDTO]
    }

    struct RestoreResult {
        var inserted: Int
        var updated: Int
    }

    // MARK: - Backup

    /// Genera el ZIP de backup con todos los artículos e imágenes.
    /// - Parameter items: Lista completa de artículos del inventario.
    /// - Returns: Datos binarios del archivo ZIP listo para exportar.
    static func generateBackup(items: [InventoryItem]) -> Data {
        var writer = ZIPWriter()

        let dtos = items.sorted { $0.itemId < $1.itemId }.map { i in
            ItemDTO(
                uuid: i.uuid, itemId: i.itemId,
                categoria: i.categoria, subcategoria: i.subcategoria,
                articulo: i.articulo, marca: i.marca, modelo: i.modelo,
                numeroSerie: i.numeroSerie, cantidad: i.cantidad,
                estadoComercial: i.estadoComercial,
                precioReposicionUnitario: i.precioReposicionUnitario,
                factorSegundaMano: i.factorSegundaMano,
                factorSeguro: i.factorSeguro, prioridadSeguro: i.prioridadSeguro,
                evidenciaPDF: i.evidenciaPDF, urlBusquedaAmazon: i.urlBusquedaAmazon,
                notas: i.notas, revisionOriginal: i.revisionOriginal,
                revisionES: i.revisionES, revisionCA: i.revisionCA,
                revisionEN: i.revisionEN, imagenURL: i.imagenURL,
                fechaCompra: i.fechaCompra, fechaCreacion: i.fechaCreacion
            )
        }

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .prettyPrinted
        if let jsonData = try? encoder.encode(BackupManifest(version: 1, items: dtos)) {
            writer.addFile(name: "inventory.json", data: jsonData)
        }

        for item in items {
            if let img = item.imagenData {
                writer.addFile(name: "images/\(item.uuid).jpg", data: img)
            }
            if let fac = item.facturaData {
                writer.addFile(name: "invoices/\(item.uuid).jpg", data: fac)
            }
        }

        return writer.finalize()
    }

    // MARK: - Restore

    /// Restaura artículos desde un ZIP de backup.
    ///
    /// Usa el UUID para deduplicar: artículos ya presentes se actualizan;
    /// artículos nuevos se insertan. Las imágenes se restauran en ambos casos.
    ///
    /// - Parameters:
    ///   - data: Contenido binario del archivo `.fotomaterial`.
    ///   - context: ModelContext activo donde insertar/actualizar los artículos.
    /// - Returns: Resumen con número de artículos insertados y actualizados.
    /// - Throws: `BackupError` si el archivo no es válido.
    static func restoreBackup(data: Data, into context: ModelContext) throws -> RestoreResult {
        guard let entries = ImportService.extractZIPEntries(data: data) else {
            throw BackupError.invalidFormat
        }
        guard let jsonData = entries["inventory.json"] else {
            throw BackupError.missingManifest
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let manifest = try decoder.decode(BackupManifest.self, from: jsonData)

        let existing = (try? context.fetch(FetchDescriptor<InventoryItem>())) ?? []
        let existingByUUID = Dictionary(uniqueKeysWithValues: existing.map { ($0.uuid, $0) })

        var inserted = 0
        var updated = 0

        for dto in manifest.items {
            let imgData = entries["images/\(dto.uuid).jpg"]
            let facData = entries["invoices/\(dto.uuid).jpg"]

            if let item = existingByUUID[dto.uuid] {
                applyDTO(dto, to: item, imagenData: imgData, facturaData: facData)
                updated += 1
            } else {
                let item = InventoryItem(
                    uuid: dto.uuid, itemId: dto.itemId,
                    categoria: dto.categoria, subcategoria: dto.subcategoria,
                    articulo: dto.articulo, marca: dto.marca, modelo: dto.modelo,
                    numeroSerie: dto.numeroSerie, cantidad: dto.cantidad,
                    estadoComercial: dto.estadoComercial,
                    precioReposicionUnitario: dto.precioReposicionUnitario,
                    factorSegundaMano: dto.factorSegundaMano,
                    factorSeguro: dto.factorSeguro,
                    prioridadSeguro: dto.prioridadSeguro,
                    evidenciaPDF: dto.evidenciaPDF,
                    urlBusquedaAmazon: dto.urlBusquedaAmazon,
                    notas: dto.notas,
                    revisionOriginal: dto.revisionOriginal,
                    revisionES: dto.revisionES, revisionCA: dto.revisionCA,
                    revisionEN: dto.revisionEN, imagenURL: dto.imagenURL,
                    imagenData: imgData, facturaData: facData,
                    fechaCompra: dto.fechaCompra, fechaCreacion: dto.fechaCreacion
                )
                context.insert(item)
                inserted += 1
            }
        }

        try context.save()
        return RestoreResult(inserted: inserted, updated: updated)
    }

    private static func applyDTO(_ dto: ItemDTO, to item: InventoryItem,
                                  imagenData: Data?, facturaData: Data?) {
        item.itemId = dto.itemId
        item.categoria = dto.categoria; item.subcategoria = dto.subcategoria
        item.articulo = dto.articulo; item.marca = dto.marca; item.modelo = dto.modelo
        item.numeroSerie = dto.numeroSerie; item.cantidad = dto.cantidad
        item.estadoComercial = dto.estadoComercial
        item.precioReposicionUnitario = dto.precioReposicionUnitario
        item.factorSegundaMano = dto.factorSegundaMano; item.factorSeguro = dto.factorSeguro
        item.prioridadSeguro = dto.prioridadSeguro; item.evidenciaPDF = dto.evidenciaPDF
        item.urlBusquedaAmazon = dto.urlBusquedaAmazon; item.notas = dto.notas
        item.revisionOriginal = dto.revisionOriginal
        item.revisionES = dto.revisionES; item.revisionCA = dto.revisionCA
        item.revisionEN = dto.revisionEN; item.imagenURL = dto.imagenURL
        item.fechaCompra = dto.fechaCompra; item.fechaCreacion = dto.fechaCreacion
        if let img = imagenData { item.imagenData = img }
        if let fac = facturaData { item.facturaData = fac }
    }

    // MARK: - Errores

    enum BackupError: LocalizedError {
        case invalidFormat
        case missingManifest

        var errorDescription: String? {
            switch self {
            case .invalidFormat:   return "El archivo no es un backup válido de FotoMaterial."
            case .missingManifest: return "El backup no contiene el inventario (inventory.json)."
            }
        }
    }
}

// MARK: - ZIP Writer

/// Escritor de archivos ZIP con método "store" (sin compresión adicional).
private struct ZIPWriter {

    private struct Entry {
        let nameData: Data
        let fileData: Data
        let crc:      UInt32
        let offset:   UInt32
    }

    private var output  = Data()
    private var entries = [Entry]()

    /// Añade un fichero al archivo ZIP.
    /// - Parameters:
    ///   - name: Ruta dentro del ZIP (puede incluir directorios, p. ej. "images/abc.jpg").
    ///   - data: Contenido del fichero.
    mutating func addFile(name: String, data: Data) {
        let nameBytes = Data(name.utf8)
        let crc       = computeCRC32(data)
        let offset    = UInt32(output.count)

        // Local file header (30 bytes + nombre)
        output.append(contentsOf: [0x50, 0x4B, 0x03, 0x04])  // signature
        appendLE16(20)                                          // version needed
        appendLE16(0)                                           // flags
        appendLE16(0)                                           // compression: stored
        appendLE16(0); appendLE16(0)                            // mod time, date
        appendLE32(crc)
        appendLE32(UInt32(data.count))                          // compressed size
        appendLE32(UInt32(data.count))                          // uncompressed size
        appendLE16(UInt16(nameBytes.count))
        appendLE16(0)                                           // extra field length
        output.append(nameBytes)
        output.append(data)

        entries.append(Entry(nameData: nameBytes, fileData: data, crc: crc, offset: offset))
    }

    /// Finaliza el ZIP añadiendo el directorio central y devuelve los datos completos.
    mutating func finalize() -> Data {
        let cdStart = UInt32(output.count)

        for e in entries {
            output.append(contentsOf: [0x50, 0x4B, 0x01, 0x02])  // central dir signature
            appendLE16(20); appendLE16(20)                          // version made, needed
            appendLE16(0)                                           // flags
            appendLE16(0)                                           // compression: stored
            appendLE16(0); appendLE16(0)                            // mod time, date
            appendLE32(e.crc)
            appendLE32(UInt32(e.fileData.count))                    // compressed size
            appendLE32(UInt32(e.fileData.count))                    // uncompressed size
            appendLE16(UInt16(e.nameData.count))
            appendLE16(0)                                           // extra field
            appendLE16(0)                                           // comment
            appendLE16(0)                                           // disk start
            appendLE16(0)                                           // internal attrs
            appendLE32(0)                                           // external attrs
            appendLE32(e.offset)
            output.append(e.nameData)
        }

        let cdSize = UInt32(output.count) - cdStart

        // End of central directory (22 bytes)
        output.append(contentsOf: [0x50, 0x4B, 0x05, 0x06])
        appendLE16(0); appendLE16(0)
        appendLE16(UInt16(entries.count))
        appendLE16(UInt16(entries.count))
        appendLE32(cdSize)
        appendLE32(cdStart)
        appendLE16(0)  // comment length

        return output
    }

    private mutating func appendLE16(_ v: UInt16) {
        output.append(contentsOf: [UInt8(v & 0xFF), UInt8(v >> 8)])
    }

    private mutating func appendLE32(_ v: UInt32) {
        output.append(contentsOf: [
            UInt8(v & 0xFF), UInt8((v >> 8) & 0xFF),
            UInt8((v >> 16) & 0xFF), UInt8((v >> 24) & 0xFF)
        ])
    }

    private func computeCRC32(_ data: Data) -> UInt32 {
        data.withUnsafeBytes { ptr -> UInt32 in
            guard let base = ptr.bindMemory(to: Bytef.self).baseAddress else { return 0 }
            return UInt32(zlib.crc32(0, base, uInt(data.count)))
        }
    }
}
