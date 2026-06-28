import Foundation
import SwiftData

// MARK: - Modelo principal

/// Modelo SwiftData que representa un artículo del inventario fotográfico.
///
/// Cada `InventoryItem` corresponde a un equipo (cámara, objetivo, flash, etc.)
/// con sus datos de identificación, valoración económica y documentación asociada.
/// Los valores de valoración derivados (`valorReposicionTotal`, `valorSegundaMano`,
/// `valorAsegurado`) son propiedades computadas para evitar datos duplicados.
@Model
final class InventoryItem {

    // MARK: Identificación

    /// Identificador único universal del artículo (generado automáticamente).
    var uuid: UUID

    /// Número de orden correlativo dentro del inventario, asignado al crear el artículo.
    var itemId: Int

    /// Categoría principal del artículo (p. ej. "Cámaras y cuerpos").
    var categoria: String

    /// Subcategoría opcional para mayor granularidad dentro de la categoría.
    var subcategoria: String

    /// Nombre descriptivo del artículo (p. ej. "Cámara mirrorless").
    var articulo: String

    /// Fabricante o marca del artículo (p. ej. "Sony").
    var marca: String

    /// Referencia o modelo específico (p. ej. "A7R V").
    var modelo: String

    // MARK: Inventario

    /// Número de unidades de este artículo en el inventario.
    var cantidad: Int

    /// Estado comercial del artículo (p. ej. "Nuevo", "Segunda mano").
    var estadoComercial: String

    // MARK: Valoración económica

    /// Precio de reposición por unidad en euros (sin IVA aplicado).
    var precioReposicionUnitario: Double

    /// Factor multiplicador para calcular el valor de segunda mano.
    /// Por defecto 0,60 (60 % del precio de reposición).
    var factorSegundaMano: Double

    /// Factor multiplicador para calcular el valor asegurado.
    /// Por defecto 1,15 (115 % del precio de reposición, incluyendo margen).
    var factorSeguro: Double

    // MARK: Seguro

    /// Nivel de prioridad del artículo para la póliza de seguro.
    /// Valores posibles: "Crítica", "Alta", "Media", "Baja".
    var prioridadSeguro: String

    /// Nombre o ruta del fichero PDF con el justificante de compra.
    var evidenciaPDF: String

    // MARK: Referencias externas

    /// URL de búsqueda en Amazon para este artículo (para consulta rápida de precio).
    var urlBusquedaAmazon: String

    // MARK: Notas y reseñas

    /// Notas libres sobre el artículo (estado, accesorios incluidos, etc.).
    var notas: String

    /// Texto de la reseña original tal como fue extraído de la web.
    var revisionOriginal: String

    /// Traducción de la reseña al castellano (generada con Apple Translation).
    var revisionES: String

    /// Traducción de la reseña al catalán.
    var revisionCA: String

    /// Traducción de la reseña al inglés.
    var revisionEN: String

    // MARK: Imagen

    /// URL original de la imagen (puede quedar obsoleto si el artículo se copió desde la web).
    var imagenURL: String

    /// Datos binarios de la imagen del artículo.
    /// Marcado con `.externalStorage` para que SwiftData lo guarde fuera de la base de datos SQLite
    /// y así no degradar el rendimiento de las consultas cuando hay muchos artículos con imágenes.
    @Attribute(.externalStorage) var imagenData: Data?

    /// Datos binarios de la factura o justificante de compra (fotografía o captura de cámara).
    /// También en `.externalStorage` para no degradar rendimiento de consultas.
    @Attribute(.externalStorage) var facturaData: Data?

    // MARK: Fechas

    /// Fecha en que se adquirió el artículo.
    var fechaCompra: Date

    /// Fecha en que se creó el registro en el inventario.
    var fechaCreacion: Date

    // MARK: Valores computados

    /// Valor total de reposición: precio unitario × cantidad.
    /// No se persiste porque es derivable en tiempo O(1).
    var valorReposicionTotal: Double { Double(cantidad) * precioReposicionUnitario }

    /// Valor estimado de segunda mano: reposición total × factor segunda mano.
    var valorSegundaMano: Double { valorReposicionTotal * factorSegundaMano }

    /// Valor asegurado: reposición total × factor seguro.
    var valorAsegurado: Double { valorReposicionTotal * factorSeguro }

    // MARK: Inicializador

    /// Crea un nuevo artículo de inventario con todos sus campos.
    ///
    /// Los parámetros tienen valores por defecto para facilitar la creación
    /// desde el asistente y la importación CSV/XLSX.
    ///
    /// - Parameters:
    ///   - uuid: Identificador único (se genera uno nuevo si no se especifica).
    ///   - itemId: Número de orden correlativo.
    ///   - categoria: Categoría principal del artículo.
    ///   - subcategoria: Subcategoría opcional.
    ///   - articulo: Nombre descriptivo.
    ///   - marca: Fabricante.
    ///   - modelo: Referencia del modelo.
    ///   - cantidad: Número de unidades (mínimo 1).
    ///   - estadoComercial: Estado del artículo (nuevo, segunda mano, etc.).
    ///   - precioReposicionUnitario: Precio de reposición por unidad en euros.
    ///   - factorSegundaMano: Factor para calcular el valor de segunda mano (0–1).
    ///   - factorSeguro: Factor para el cálculo del valor asegurado (≥ 1 habitualmente).
    ///   - prioridadSeguro: Prioridad en la póliza.
    ///   - evidenciaPDF: Nombre del fichero PDF de justificante.
    ///   - urlBusquedaAmazon: URL de referencia en Amazon.
    ///   - notas: Notas libres.
    ///   - revisionOriginal: Reseña en el idioma original.
    ///   - revisionES: Reseña en castellano.
    ///   - revisionCA: Reseña en catalán.
    ///   - revisionEN: Reseña en inglés.
    ///   - imagenURL: URL original de la imagen.
    ///   - imagenData: Datos binarios de la imagen.
    ///   - fechaCompra: Fecha de adquisición.
    ///   - fechaCreacion: Fecha de registro en el inventario.
    init(
        uuid: UUID = UUID(),
        itemId: Int = 0,
        categoria: String = "",
        subcategoria: String = "",
        articulo: String = "",
        marca: String = "",
        modelo: String = "",
        cantidad: Int = 1,
        estadoComercial: String = "",
        precioReposicionUnitario: Double = 0.0,
        factorSegundaMano: Double = 0.6,
        factorSeguro: Double = 1.15,
        prioridadSeguro: String = "Media",
        evidenciaPDF: String = "",
        urlBusquedaAmazon: String = "",
        notas: String = "",
        revisionOriginal: String = "",
        revisionES: String = "",
        revisionCA: String = "",
        revisionEN: String = "",
        imagenURL: String = "",
        imagenData: Data? = nil,
        facturaData: Data? = nil,
        fechaCompra: Date = Date(),
        fechaCreacion: Date = Date()
    ) {
        self.uuid = uuid
        self.itemId = itemId
        self.categoria = categoria
        self.subcategoria = subcategoria
        self.articulo = articulo
        self.marca = marca
        self.modelo = modelo
        self.cantidad = cantidad
        self.estadoComercial = estadoComercial
        self.precioReposicionUnitario = precioReposicionUnitario
        self.factorSegundaMano = factorSegundaMano
        self.factorSeguro = factorSeguro
        self.prioridadSeguro = prioridadSeguro
        self.evidenciaPDF = evidenciaPDF
        self.urlBusquedaAmazon = urlBusquedaAmazon
        self.notas = notas
        self.revisionOriginal = revisionOriginal
        self.revisionES = revisionES
        self.revisionCA = revisionCA
        self.revisionEN = revisionEN
        self.imagenURL = imagenURL
        self.imagenData = imagenData
        self.facturaData = facturaData
        self.fechaCompra = fechaCompra
        self.fechaCreacion = fechaCreacion
    }
}

// MARK: - Valores de catálogo

extension InventoryItem {

    /// Categorías por defecto extraídas del inventario Excel del usuario.
    /// Se ofrecen como sugerencias en el selector de categoría del asistente.
    static let defaultCategories: [String] = [
        "Cámaras y cuerpos",
        "Objetivos y óptica",
        "Iluminación y medición",
        "Trípodes, rótulas y soportes",
        "Filtros y accesorios ópticos",
        "Macro y focus stacking",
        "Energía, carga y almacenamiento",
        "Transporte y accesorios",
        "Vídeo, audio y monitorización",
        "Disparo remoto y automatización",
        "Software y flujo",
        "Drone"
    ]

    /// Opciones de prioridad para la póliza de seguro, ordenadas de mayor a menor criticidad.
    static let priorityOptions = ["Crítica", "Alta", "Media", "Baja"]
}
