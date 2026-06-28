import SwiftUI
import SwiftData
import Translation
import PhotosUI
import NaturalLanguage

struct ItemDetailView: View {
    @Bindable var item: InventoryItem
    @EnvironmentObject var locale: AppLocale
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var isEditing = false
    @State private var showImagePicker = false
    @State private var showCameraPicker = false
    @State private var showReviewPicker = false
    @State private var showPricePicker = false
    @State private var showDeleteConfirm = false
    @State private var reviewLanguage = "original"

    // Estado factura
    @State private var showFacturaPhotoPicker = false
    @State private var showFacturaCameraPicker = false
    @State private var showFacturaViewer = false
    @State private var selectedFacturaItem: PhotosPickerItem?

    // Translation state
    @State private var translationConfig: TranslationSession.Configuration?
    @State private var translatingTo = ""
    @State private var translationTrigger = 0
    @State private var translationError: String?
    @State private var isTranslating = false

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Hero image
                heroImageSection

                // Content
                VStack(spacing: 16) {
                    financialSummaryCard
                    itemInfoSection
                    reviewSection
                    facturaSection

                    if isEditing {
                        advancedFieldsSection
                    }
                }
                .padding()
            }
        }
        .navigationTitle(item.articulo.isEmpty ? locale.t("field.articulo") : item.articulo)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack(spacing: 16) {
                    if isEditing {
                        Button(locale.t("done")) {
                            try? modelContext.save()
                            isEditing = false
                        }
                        .fontWeight(.semibold)
                    } else {
                        Button(locale.t("edit")) { isEditing = true }
                        Button(role: .destructive) {
                            showDeleteConfirm = true
                        } label: {
                            Image(systemName: "trash")
                        }
                    }
                }
            }
        }
        .confirmationDialog(locale.t("delete"), isPresented: $showDeleteConfirm, titleVisibility: .visible) {
            Button(locale.t("delete"), role: .destructive) {
                modelContext.delete(item)
                try? modelContext.save()
                dismiss()
            }
            Button(locale.t("cancel"), role: .cancel) {}
        }
        .sheet(isPresented: $showImagePicker) {
            WebImagePickerView(
                query: item.articulo,
                selectedImageData: $item.imagenData
            )
            .environmentObject(locale)
        }
        // fullScreenCover es obligatorio para UIImagePickerController con cámara;
        // .sheet provoca conflictos de presentación que causan EXC_BAD_ACCESS.
        .fullScreenCover(isPresented: $showCameraPicker) {
            CameraPickerView(imageData: $item.imagenData)
        }
        .sheet(isPresented: $showReviewPicker) {
            ReviewWebPickerView(
                query: item.articulo,
                selectedReviewText: $item.revisionOriginal
            )
            .environmentObject(locale)
        }
        .sheet(isPresented: $showPricePicker) {
            WebPriceView(
                query: item.articulo,
                detectedPrice: Binding(
                    get: { nil },
                    set: { if let v = $0 { item.precioReposicionUnitario = v } }
                )
            )
            .environmentObject(locale)
        }
        // Visor de factura a pantalla completa con zoom
        .sheet(isPresented: $showFacturaViewer) {
            if let data = item.facturaData, let uiImage = UIImage(data: data) {
                NavigationStack {
                    // Sin ScrollView: scaledToFit con maxWidth/maxHeight infinito
                    // obliga a la imagen a encajar en el espacio disponible de la pantalla.
                    // Un ScrollView sin contenedor fijo hace que scaledToFit use el tamaño
                    // nativo de la imagen (4K+ desde cámara) y desborde la pantalla.
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color(.systemBackground))
                        .navigationTitle(locale.t("field.factura"))
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button(locale.t("done")) { showFacturaViewer = false }
                            }
                        }
                }
            }
        }
        // Cámara para capturar la factura; fullScreenCover obligatorio para UIImagePickerController
        .fullScreenCover(isPresented: $showFacturaCameraPicker) {
            CameraPickerView(imageData: $item.facturaData)
        }
        // Presenta el picker nativo de Fotos (no funciona dentro de Menu, se activa con bool)
        .photosPicker(isPresented: $showFacturaPhotoPicker, selection: $selectedFacturaItem, matching: .images)
        // Carga la imagen seleccionada desde la biblioteca de fotos
        .onChange(of: selectedFacturaItem) { _, newItem in
            Task {
                if let data = try? await newItem?.loadTransferable(type: Data.self) {
                    item.facturaData = data
                    try? modelContext.save()
                }
                selectedFacturaItem = nil
            }
        }
        .overlay(alignment: .top) {
            // Vista de tamaño cero que aloja translationTask. Al cambiar id(translationTrigger)
            // SwiftUI destruye y recrea esta vista desde cero en cada solicitud de traducción,
            // garantizando que translationTask vea siempre la transición "sin estado → config
            // no nula" y se dispare de forma fiable, sin importar el idioma anterior.
            Color.clear
                .frame(width: 0, height: 0)
                .allowsHitTesting(false)
                .id(translationTrigger)
                .translationTask(translationConfig) { session in
                    await MainActor.run { isTranslating = true }
                    do {
                        let response = try await session.translate(item.revisionOriginal)
                        await MainActor.run {
                            switch translatingTo {
                            case "es": item.revisionES = response.targetText
                            case "ca": item.revisionCA = response.targetText
                            case "en": item.revisionEN = response.targetText
                            default: break
                            }
                            try? modelContext.save()
                            isTranslating = false
                        }
                    } catch {
                        await MainActor.run {
                            translationError = error.localizedDescription
                            isTranslating = false
                        }
                    }
                }
        }
        .alert("Error de traducción", isPresented: Binding(
            get: { translationError != nil },
            set: { if !$0 { translationError = nil } }
        )) {
            Button("OK") { translationError = nil }
        } message: {
            if let err = translationError { Text(err) }
        }
    }

    // MARK: - Hero Image

    private var heroImageSection: some View {
        ZStack(alignment: .bottomTrailing) {
            if let data = item.imagenData, let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity)
                    .background(Color(.systemGray6))
            } else {
                Color(.systemGray5)
                    .frame(maxWidth: .infinity)
                    .frame(height: 220)
                    .overlay {
                        Image(systemName: "camera.fill")
                            .font(.system(size: 48))
                            .foregroundStyle(.secondary)
                    }
            }

            if isEditing {
                HStack(spacing: 8) {
                    Button {
                        showImagePicker = true
                    } label: {
                        Label(locale.t("wizard.photo.search"), systemImage: "magnifyingglass")
                            .font(.caption)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(.ultraThinMaterial)
                            .clipShape(Capsule())
                    }
                    if UIImagePickerController.isSourceTypeAvailable(.camera) {
                        Button {
                            showCameraPicker = true
                        } label: {
                            Label(locale.t("wizard.photo.camera"), systemImage: "camera.fill")
                                .font(.caption)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(.ultraThinMaterial)
                                .clipShape(Capsule())
                        }
                    }
                }
                .padding(12)
            }
        }
    }

    // MARK: - Financial Summary Card

    private var financialSummaryCard: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                financialCell(
                    label: locale.t("field.valor.total"),
                    value: item.valorReposicionTotal,
                    color: .blue
                )
                Divider().frame(height: 50)
                financialCell(
                    label: locale.t("field.valor.sm"),
                    value: item.valorSegundaMano,
                    color: .orange
                )
                Divider().frame(height: 50)
                financialCell(
                    label: locale.t("field.valor.asegurado"),
                    value: item.valorAsegurado,
                    color: .green
                )
            }
        }
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private func financialCell(label: String, value: Double, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(formatEur(value))
                .font(.headline)
                .fontWeight(.bold)
                .foregroundStyle(color)
                .minimumScaleFactor(0.7)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
    }

    // MARK: - Item Info Section

    private var itemInfoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: locale.t("field.articulo"))

            if isEditing {
                FormField(label: locale.t("field.articulo"), text: $item.articulo)
                FormField(label: locale.t("field.marca"), text: $item.marca)
                FormField(label: locale.t("field.modelo"), text: $item.modelo)
                FormField(label: locale.t("field.subcategoria"), text: $item.subcategoria)

                HStack {
                    Text(locale.t("field.cantidad"))
                        .foregroundStyle(.secondary)
                        .font(.subheadline)
                    Spacer()
                    Stepper("\(item.cantidad)", value: $item.cantidad, in: 1...999)
                }

                DatePicker(locale.t("field.fecha.compra"), selection: $item.fechaCompra, displayedComponents: .date)
                    .font(.subheadline)

                HStack {
                    FormField(label: locale.t("field.precio.unitario"),
                              text: Binding(
                                get: { item.precioReposicionUnitario == 0 ? "" : String(format: "%.2f", item.precioReposicionUnitario) },
                                set: { item.precioReposicionUnitario = Double($0.replacingOccurrences(of: ",", with: ".")) ?? item.precioReposicionUnitario }
                              ))
                    .keyboardType(.decimalPad)

                    Button {
                        showPricePicker = true
                    } label: {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(Color.accentColor)
                    }
                }

                Picker(locale.t("field.prioridad"), selection: $item.prioridadSeguro) {
                    ForEach(InventoryItem.priorityOptions, id: \.self) { Text($0) }
                }

                FormField(label: locale.t("field.notas"), text: $item.notas)
            } else {
                infoGrid
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private var infoGrid: some View {
        VStack(spacing: 8) {
            DetailRow(label: locale.t("field.marca"), value: item.marca)
            DetailRow(label: locale.t("field.modelo"), value: item.modelo)
            DetailRow(label: locale.t("field.categoria"), value: item.categoria)
            DetailRow(label: locale.t("field.subcategoria"), value: item.subcategoria)
            DetailRow(label: locale.t("field.cantidad"), value: "\(item.cantidad)")
            DetailRow(label: locale.t("field.estado"), value: item.estadoComercial)
            DetailRow(label: locale.t("field.precio.unitario"), value: formatEur(item.precioReposicionUnitario))
            DetailRow(label: locale.t("field.prioridad"), value: item.prioridadSeguro)
            let df = DateFormatter(); let _ = (df.dateStyle = .medium)
            DetailRow(label: locale.t("field.fecha.compra"), value: df.string(from: item.fechaCompra))
            if !item.notas.isEmpty { DetailRow(label: locale.t("field.notas"), value: item.notas) }
        }
    }

    // MARK: - Review Section

    private var reviewSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                SectionHeader(title: locale.t("field.revision"))
                Spacer()
                if isEditing {
                    Button {
                        showReviewPicker = true
                    } label: {
                        Label(locale.t("search"), systemImage: "magnifyingglass")
                            .font(.caption)
                    }
                }
            }

            // Language selector
            Picker("", selection: $reviewLanguage) {
                Text(locale.t("translate.original")).tag("original")
                if !item.revisionES.isEmpty { Text(locale.t("translate.es")).tag("es") }
                if !item.revisionCA.isEmpty { Text(locale.t("translate.ca")).tag("ca") }
                if !item.revisionEN.isEmpty { Text(locale.t("translate.en")).tag("en") }
            }
            .pickerStyle(.segmented)

            if isEditing {
                // En modo edición, TextEditor vinculado al campo del idioma activo
                TextEditor(text: currentReviewBinding)
                    .font(.subheadline)
                    .frame(minHeight: 120)
                    .scrollContentBackground(.hidden)
                    .background(Color(.systemGray5))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                let reviewText = currentReviewText
                if reviewText.isEmpty {
                    Text(locale.t("no.items"))
                        .foregroundStyle(.secondary)
                        .font(.subheadline)
                } else {
                    Text(reviewText)
                        .font(.subheadline)
                        .lineSpacing(4)
                }
            }

            // Translation buttons
            if !item.revisionOriginal.isEmpty {
                Divider()
                Text(locale.t("translate") + ":")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                HStack(spacing: 8) {
                    translateButton(lang: "es", label: locale.t("translate.es"))
                    translateButton(lang: "ca", label: locale.t("translate.ca"))
                    translateButton(lang: "en", label: locale.t("translate.en"))
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private var currentReviewText: String {
        switch reviewLanguage {
        case "es": return item.revisionES.isEmpty ? item.revisionOriginal : item.revisionES
        case "ca": return item.revisionCA.isEmpty ? item.revisionOriginal : item.revisionCA
        case "en": return item.revisionEN.isEmpty ? item.revisionOriginal : item.revisionEN
        default: return item.revisionOriginal
        }
    }

    /// Binding mutable al campo de reseña del idioma activo, para el TextEditor en modo edición.
    private var currentReviewBinding: Binding<String> {
        switch reviewLanguage {
        case "es": return $item.revisionES
        case "ca": return $item.revisionCA
        case "en": return $item.revisionEN
        default:   return $item.revisionOriginal
        }
    }

    /// Detecta el idioma dominante del texto de la reseña con NLLanguageRecognizer.
    /// Evita usar `source: nil` en TranslationSession.Configuration, que muestra
    /// un diálogo del sistema cuyo flujo async no retorna al closure en iOS 17/18.
    private func detectedSourceLanguage() -> Locale.Language {
        let recognizer = NLLanguageRecognizer()
        recognizer.processString(item.revisionOriginal)
        let tag = recognizer.dominantLanguage?.rawValue ?? "en"
        return Locale.Language(identifier: tag)
    }

    private func translateButton(lang: String, label: String) -> some View {
        Button {
            translatingTo = lang
            translationConfig = TranslationSession.Configuration(
                source: detectedSourceLanguage(),
                target: Locale.Language(identifier: lang)
            )
            // Incrementar el trigger recrea la vista auxiliar (id cambia → SwiftUI
            // la destruye y vuelve a crear), lo que garantiza que translationTask
            // se dispara en cada tap sin depender de transiciones nil↔nonNil.
            translationTrigger += 1
        } label: {
            Text(label)
                .font(.caption)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Color.accentColor.opacity(0.1))
                .foregroundStyle(Color.accentColor)
                .clipShape(Capsule())
        }
        .disabled(isTranslating)
    }

    // MARK: - Advanced Fields (edit mode)

    private var advancedFieldsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Valoración")

            HStack {
                Text(locale.t("field.factor.sm"))
                    .foregroundStyle(.secondary).font(.subheadline)
                Spacer()
                TextField("0.60", text: Binding(
                    get: { String(format: "%.2f", item.factorSegundaMano) },
                    set: { item.factorSegundaMano = Double($0) ?? item.factorSegundaMano }
                ))
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .frame(width: 80)
            }

            HStack {
                Text(locale.t("field.factor.seguro"))
                    .foregroundStyle(.secondary).font(.subheadline)
                Spacer()
                TextField("1.15", text: Binding(
                    get: { String(format: "%.2f", item.factorSeguro) },
                    set: { item.factorSeguro = Double($0) ?? item.factorSeguro }
                ))
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .frame(width: 80)
            }

            FormField(label: locale.t("field.evidencia"), text: $item.evidenciaPDF)
            FormField(label: locale.t("field.url.amazon"), text: $item.urlBusquedaAmazon)
        }
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private func formatEur(_ v: Double) -> String {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.minimumFractionDigits = 2
        f.maximumFractionDigits = 2
        return (f.string(from: NSNumber(value: v)) ?? "0,00") + " €"
    }

    // MARK: - Factura

    private var facturaSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                SectionHeader(title: locale.t("field.factura"))
                Spacer()
                if isEditing {
                    Menu {
                        // PhotosPicker no funciona dentro de Menu; se usa Button + modifier externo
                        Button {
                            showFacturaPhotoPicker = true
                        } label: {
                            Label(locale.t("factura.add.photo"), systemImage: "photo.on.rectangle")
                        }
                        // Cámara (solo si está disponible en el dispositivo)
                        if UIImagePickerController.isSourceTypeAvailable(.camera) {
                            Button {
                                showFacturaCameraPicker = true
                            } label: {
                                Label(locale.t("factura.add.camera"), systemImage: "camera")
                            }
                        }
                        // Eliminar (solo si ya hay factura)
                        if item.facturaData != nil {
                            Divider()
                            Button(role: .destructive) {
                                item.facturaData = nil
                                try? modelContext.save()
                            } label: {
                                Label(locale.t("factura.delete"), systemImage: "trash")
                            }
                        }
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title3)
                            .foregroundStyle(Color.accentColor)
                    }
                }
            }

            if let data = item.facturaData, let uiImage = UIImage(data: data) {
                // Miniatura con botón para abrir el visor a pantalla completa
                Button { showFacturaViewer = true } label: {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity)
                        .frame(maxHeight: 260)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .overlay(alignment: .bottomTrailing) {
                            Image(systemName: "arrow.up.left.and.arrow.down.right")
                                .font(.caption)
                                .padding(6)
                                .background(.ultraThinMaterial)
                                .clipShape(Circle())
                                .padding(8)
                        }
                }
                .buttonStyle(.plain)
            } else {
                Text(locale.t("factura.none"))
                    .foregroundStyle(.secondary)
                    .font(.subheadline)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

// MARK: - Reusable subviews

struct SectionHeader: View {
    let title: String
    var body: some View {
        Text(title)
            .font(.headline)
            .fontWeight(.semibold)
    }
}

struct DetailRow: View {
    let label: String
    let value: String
    var body: some View {
        if !value.isEmpty {
            HStack(alignment: .top) {
                Text(label)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(width: 130, alignment: .leading)
                Text(value)
                    .font(.subheadline)
                    .multilineTextAlignment(.leading)
                Spacer()
            }
        }
    }
}

struct FormField: View {
    let label: String
    @Binding var text: String
    var keyboardType: UIKeyboardType = .default

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            TextField(label, text: $text)
                .textFieldStyle(.roundedBorder)
                .keyboardType(keyboardType)
        }
    }
}
