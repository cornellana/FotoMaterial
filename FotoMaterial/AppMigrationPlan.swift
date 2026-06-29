import SwiftData
import Foundation

// MARK: - Historial de versiones del esquema SwiftData

/// V1 — esquema en producción antes de añadir número de serie y datos de factura.
///
/// La definición de `InventoryItem` aquí debe coincidir exactamente con el modelo
/// con el que se crearon los stores existentes. SwiftData calcula un hash del esquema
/// para identificar versiones; si coincide, aplica la migración ligera a V2.
enum AppSchemaV1: VersionedSchema {
    static let versionIdentifier = Schema.Version(1, 0, 0)
    static var models: [any PersistentModel.Type] { [InventoryItem.self] }

    // swiftlint:disable:next type_name
    @Model
    final class InventoryItem {
        var uuid: UUID = UUID()
        var itemId: Int = 0
        var categoria: String = ""
        var subcategoria: String = ""
        var articulo: String = ""
        var marca: String = ""
        var modelo: String = ""
        var cantidad: Int = 1
        var estadoComercial: String = ""
        var precioReposicionUnitario: Double = 0.0
        var factorSegundaMano: Double = 0.6
        var factorSeguro: Double = 1.15
        var prioridadSeguro: String = ""
        var evidenciaPDF: String = ""
        var urlBusquedaAmazon: String = ""
        var notas: String = ""
        var revisionOriginal: String = ""
        var revisionES: String = ""
        var revisionCA: String = ""
        var revisionEN: String = ""
        var imagenURL: String = ""
        @Attribute(.externalStorage) var imagenData: Data?
        var fechaCompra: Date = Date()
        var fechaCreacion: Date = Date()

        init(
            uuid: UUID = UUID(), itemId: Int = 0,
            categoria: String = "", subcategoria: String = "",
            articulo: String = "", marca: String = "", modelo: String = "",
            cantidad: Int = 1, estadoComercial: String = "",
            precioReposicionUnitario: Double = 0.0,
            factorSegundaMano: Double = 0.6, factorSeguro: Double = 1.15,
            prioridadSeguro: String = "", evidenciaPDF: String = "",
            urlBusquedaAmazon: String = "", notas: String = "",
            revisionOriginal: String = "", revisionES: String = "",
            revisionCA: String = "", revisionEN: String = "",
            imagenURL: String = "", imagenData: Data? = nil,
            fechaCompra: Date = Date(), fechaCreacion: Date = Date()
        ) {
            self.uuid = uuid; self.itemId = itemId
            self.categoria = categoria; self.subcategoria = subcategoria
            self.articulo = articulo; self.marca = marca; self.modelo = modelo
            self.cantidad = cantidad; self.estadoComercial = estadoComercial
            self.precioReposicionUnitario = precioReposicionUnitario
            self.factorSegundaMano = factorSegundaMano; self.factorSeguro = factorSeguro
            self.prioridadSeguro = prioridadSeguro; self.evidenciaPDF = evidenciaPDF
            self.urlBusquedaAmazon = urlBusquedaAmazon; self.notas = notas
            self.revisionOriginal = revisionOriginal
            self.revisionES = revisionES; self.revisionCA = revisionCA
            self.revisionEN = revisionEN; self.imagenURL = imagenURL
            self.imagenData = imagenData
            self.fechaCompra = fechaCompra; self.fechaCreacion = fechaCreacion
        }
    }
}

/// V2 — esquema actual: añade `numeroSerie` (String) y `facturaData` (Data?).
enum AppSchemaV2: VersionedSchema {
    static let versionIdentifier = Schema.Version(2, 0, 0)
    static var models: [any PersistentModel.Type] { [InventoryItem.self] }
}

// MARK: - Plan de migración

/// Migración ligera (sin conversión de datos) de V1 a V2.
///
/// SwiftData añade automáticamente las dos columnas nuevas usando sus valores
/// por defecto: `numeroSerie = ""` y `facturaData = nil`.
enum AppMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] { [AppSchemaV1.self, AppSchemaV2.self] }
    static var stages: [MigrationStage] {
        [.lightweight(fromVersion: AppSchemaV1.self, toVersion: AppSchemaV2.self)]
    }
}
