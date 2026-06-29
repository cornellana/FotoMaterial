import SwiftUI
import SwiftData
import Translation

struct AddItemWizardView: View {
    @EnvironmentObject var locale: AppLocale
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \InventoryItem.itemId) private var existingItems: [InventoryItem]

    // Wizard state
    @State private var step = 0
    private let totalSteps = 5

    // Item fields
    @State private var articulo = ""
    @State private var marca = ""
    @State private var modelo = ""
    @State private var numeroSerie = ""
    @State private var subcategoria = ""
    @State private var imagenData: Data? = nil
    @State private var revisionOriginal = ""
    @State private var revisionES = ""
    @State private var revisionCA = ""
    @State private var revisionEN = ""
    @State private var cantidad = 1
    @State private var fechaCompra = Date()
    @State private var precio = 0.0
    @State private var categoria = ""
    @State private var newCategoryName = ""
    @State private var addingNewCategory = false
    @State private var estadoComercial = ""
    @State private var prioridadSeguro = "Media"
    @State private var notas = ""

    // Sheet presenters
    @State private var showImagePicker = false
    @State private var showCameraPicker = false
    @State private var showReviewPicker = false
    @State private var showPricePicker = false

    // Translation
    @State private var translationConfig: TranslationSession.Configuration?
    @State private var translatingTo = ""

    private var searchQuery: String { articulo.trimmingCharacters(in: .whitespaces) }

    private var availableCategories: [String] {
        var cats = Set(existingItems.map(\.categoria).filter { !$0.isEmpty })
        InventoryItem.defaultCategories.forEach { cats.insert($0) }
        return cats.sorted()
    }

    private var nextItemId: Int {
        (existingItems.map(\.itemId).max() ?? 0) + 1
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Progress bar
                progressBar

                // Step content
                ScrollView {
                    VStack(spacing: 20) {
                        stepView
                    }
                    .padding()
                    .padding(.bottom, 100)
                }

                // Navigation buttons
                navButtons
            }
            .navigationTitle(locale.t("wizard.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(locale.t("cancel")) { dismiss() }
                }
            }
            .sheet(isPresented: $showImagePicker) {
                WebImagePickerView(query: searchQuery, selectedImageData: $imagenData)
                    .environmentObject(locale)
            }
            // fullScreenCover es obligatorio para UIImagePickerController con cámara;
            // .sheet provoca conflictos de presentación que causan EXC_BAD_ACCESS.
            .fullScreenCover(isPresented: $showCameraPicker) {
                CameraPickerView(imageData: $imagenData)
            }
            .sheet(isPresented: $showReviewPicker) {
                ReviewWebPickerView(query: searchQuery, selectedReviewText: $revisionOriginal)
                    .environmentObject(locale)
            }
            .sheet(isPresented: $showPricePicker) {
                WebPriceView(
                    query: searchQuery,
                    detectedPrice: Binding(
                        get: { nil },
                        set: { if let v = $0 { precio = v } }
                    )
                )
                .environmentObject(locale)
            }
            .translationTask(translationConfig) { session in
                do {
                    let response = try await session.translate(revisionOriginal)
                    switch translatingTo {
                    case "es": revisionES = response.targetText
                    case "ca": revisionCA = response.targetText
                    case "en": revisionEN = response.targetText
                    default: break
                    }
                } catch {}
                translationConfig = nil
            }
        }
    }

    // MARK: - Progress Bar

    private var progressBar: some View {
        VStack(spacing: 6) {
            HStack(spacing: 4) {
                ForEach(0..<totalSteps, id: \.self) { i in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(i <= step ? Color.accentColor : Color(.systemGray4))
                        .frame(height: 4)
                        .animation(.easeInOut, value: step)
                }
            }
            .padding(.horizontal)

            HStack {
                ForEach(0..<totalSteps, id: \.self) { i in
                    Text(stepTitle(i))
                        .font(.caption2)
                        .foregroundStyle(i == step ? .primary : .secondary)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 8)
        .background(Color(.systemGroupedBackground))
    }

    private func stepTitle(_ i: Int) -> String {
        switch i {
        case 0: return locale.t("wizard.step.item")
        case 1: return locale.t("wizard.step.photo")
        case 2: return locale.t("wizard.step.review")
        case 3: return locale.t("wizard.step.details")
        case 4: return locale.t("wizard.step.category")
        default: return ""
        }
    }

    // MARK: - Step Views

    @ViewBuilder
    private var stepView: some View {
        switch step {
        case 0: step0ItemInfo
        case 1: step1Photo
        case 2: step2Review
        case 3: step3Details
        case 4: step4Category
        default: EmptyView()
        }
    }

    // Step 0: Item name, brand, model
    private var step0ItemInfo: some View {
        VStack(alignment: .leading, spacing: 16) {
            WizardStepHeader(
                icon: "camera",
                title: locale.t("wizard.step.item"),
                hint: locale.t("wizard.item.hint")
            )

            FormCard {
                FormField(label: locale.t("field.articulo"), text: $articulo)
                Divider()
                FormField(label: locale.t("field.marca"), text: $marca)
                Divider()
                FormField(label: locale.t("field.modelo"), text: $modelo)
                Divider()
                FormField(label: locale.t("field.numero.serie"), text: $numeroSerie)
                Divider()
                FormField(label: locale.t("field.subcategoria"), text: $subcategoria)
            }
        }
    }

    // Step 1: Photo selection
    private var step1Photo: some View {
        VStack(alignment: .leading, spacing: 16) {
            WizardStepHeader(
                icon: "photo",
                title: locale.t("wizard.step.photo"),
                hint: locale.t("wizard.photo.tap")
            )

            // Current photo
            Group {
                if let data = imagenData, let uiImage = UIImage(data: data) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity)
                        .frame(height: 220)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                } else {
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Color(.systemGray5))
                        .frame(height: 180)
                        .overlay {
                            Image(systemName: "photo")
                                .font(.system(size: 40))
                                .foregroundStyle(.secondary)
                        }
                }
            }

            HStack(spacing: 12) {
                Button {
                    showImagePicker = true
                } label: {
                    Label(locale.t("wizard.photo.search"), systemImage: "magnifyingglass")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(searchQuery.isEmpty)

                Button {
                    showCameraPicker = true
                } label: {
                    Label(locale.t("wizard.photo.camera"), systemImage: "camera.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .disabled(!UIImagePickerController.isSourceTypeAvailable(.camera))
            }

            if searchQuery.isEmpty {
                Text(locale.t("wizard.item.hint"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // Step 2: Review + translation
    private var step2Review: some View {
        VStack(alignment: .leading, spacing: 16) {
            WizardStepHeader(
                icon: "doc.text",
                title: locale.t("wizard.step.review"),
                hint: locale.t("wizard.review.tap")
            )

            Button {
                showReviewPicker = true
            } label: {
                Label(locale.t("wizard.review.search"), systemImage: "magnifyingglass")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(searchQuery.isEmpty)

            if !revisionOriginal.isEmpty {
                FormCard {
                    Text(revisionOriginal)
                        .font(.subheadline)
                        .lineSpacing(4)
                        .lineLimit(8)

                    Divider()

                    VStack(alignment: .leading, spacing: 8) {
                        Text(locale.t("translate") + ":")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        HStack(spacing: 8) {
                            translateButton("es", label: locale.t("translate.es"), done: !revisionES.isEmpty)
                            translateButton("ca", label: locale.t("translate.ca"), done: !revisionCA.isEmpty)
                            translateButton("en", label: locale.t("translate.en"), done: !revisionEN.isEmpty)
                        }
                    }
                }
            }
        }
    }

    private func translateButton(_ lang: String, label: String, done: Bool) -> some View {
        Button {
            translatingTo = lang
            translationConfig = TranslationSession.Configuration(
                source: nil,
                target: Locale.Language(identifier: lang)
            )
        } label: {
            HStack(spacing: 4) {
                if done { Image(systemName: "checkmark").font(.caption2) }
                Text(label).font(.caption)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(done ? Color.green.opacity(0.1) : Color.accentColor.opacity(0.1))
            .foregroundStyle(done ? .green : .accentColor)
            .clipShape(Capsule())
        }
    }

    // Step 3: Quantity, date, price
    private var step3Details: some View {
        VStack(alignment: .leading, spacing: 16) {
            WizardStepHeader(
                icon: "slider.horizontal.3",
                title: locale.t("wizard.step.details"),
                hint: ""
            )

            FormCard {
                // Quantity
                HStack {
                    Text(locale.t("field.cantidad"))
                        .foregroundStyle(.secondary)
                        .font(.subheadline)
                    Spacer()
                    Stepper("\(cantidad)", value: $cantidad, in: 1...999)
                }

                Divider()

                // Purchase date
                DatePicker(
                    locale.t("field.fecha.compra"),
                    selection: $fechaCompra,
                    displayedComponents: .date
                )
                .font(.subheadline)

                Divider()

                // Price
                VStack(alignment: .leading, spacing: 6) {
                    Text(locale.t("field.precio.unitario"))
                        .foregroundStyle(.secondary)
                        .font(.caption)
                    HStack {
                        TextField("0.00", value: $precio, format: .number)
                            .keyboardType(.decimalPad)
                            .textFieldStyle(.roundedBorder)
                        Text("€")
                        Button {
                            showPricePicker = true
                        } label: {
                            Image(systemName: "magnifyingglass")
                        }
                        .disabled(searchQuery.isEmpty)
                    }
                }

                Divider()

                // Estado comercial
                FormField(label: locale.t("field.estado"), text: $estadoComercial)

                Divider()

                // Insurance priority
                Picker(locale.t("field.prioridad"), selection: $prioridadSeguro) {
                    ForEach(InventoryItem.priorityOptions, id: \.self) { Text($0) }
                }
                .font(.subheadline)
            }
        }
    }

    // Step 4: Category
    private var step4Category: some View {
        VStack(alignment: .leading, spacing: 16) {
            WizardStepHeader(
                icon: "folder",
                title: locale.t("wizard.step.category"),
                hint: ""
            )

            FormCard {
                if addingNewCategory {
                    HStack {
                        TextField(locale.t("wizard.category.placeholder"), text: $newCategoryName)
                            .textFieldStyle(.roundedBorder)
                        Button {
                            if !newCategoryName.isEmpty {
                                categoria = newCategoryName
                                addingNewCategory = false
                            }
                        } label: {
                            Text(locale.t("confirm"))
                        }
                        Button {
                            addingNewCategory = false
                            newCategoryName = ""
                        } label: {
                            Image(systemName: "xmark")
                        }
                    }
                } else {
                    Picker(locale.t("field.categoria"), selection: $categoria) {
                        Text("— \(locale.t("field.categoria")) —").tag("")
                        ForEach(availableCategories, id: \.self) { cat in
                            Text(cat).tag(cat)
                        }
                    }
                    .pickerStyle(.wheel)
                    .frame(height: 150)

                    Button {
                        addingNewCategory = true
                    } label: {
                        Label(locale.t("wizard.category.new"), systemImage: "plus.circle")
                            .font(.subheadline)
                    }
                }
            }

            // Summary preview
            if !categoria.isEmpty || !articulo.isEmpty {
                summaryPreview
            }
        }
    }

    private var summaryPreview: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Resumen")
                .font(.headline)
                .padding(.top, 8)

            FormCard {
                if let data = imagenData, let img = UIImage(data: data) {
                    Image(uiImage: img)
                        .resizable()
                        .scaledToFit()
                        .frame(height: 100)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                DetailRow(label: locale.t("field.articulo"), value: articulo)
                DetailRow(label: locale.t("field.marca"), value: marca)
                DetailRow(label: locale.t("field.modelo"), value: modelo)
                DetailRow(label: locale.t("field.categoria"), value: categoria)
                DetailRow(label: locale.t("field.cantidad"), value: "\(cantidad)")
                if precio > 0 {
                    DetailRow(label: locale.t("field.precio.unitario"), value: formatEur(precio))
                    DetailRow(label: locale.t("field.valor.total"), value: formatEur(Double(cantidad) * precio))
                }
            }
        }
    }

    // MARK: - Nav Buttons

    private var navButtons: some View {
        HStack(spacing: 12) {
            if step > 0 {
                Button {
                    withAnimation { step -= 1 }
                } label: {
                    Label(locale.t("back"), systemImage: "chevron.left")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }

            if step < totalSteps - 1 {
                Button {
                    withAnimation { step += 1 }
                } label: {
                    HStack {
                        Text(locale.t("next"))
                        Image(systemName: "chevron.right")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(step == 0 && articulo.isEmpty)
            } else {
                Button {
                    saveItem()
                } label: {
                    Label(locale.t("save"), systemImage: "checkmark")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
                .disabled(articulo.isEmpty)
            }
        }
        .padding()
        .background(.bar)
    }

    // MARK: - Save

    private func saveItem() {
        let item = InventoryItem(
            itemId: nextItemId,
            categoria: categoria,
            subcategoria: subcategoria,
            articulo: articulo,
            marca: marca,
            modelo: modelo,
            numeroSerie: numeroSerie,
            cantidad: cantidad,
            estadoComercial: estadoComercial,
            precioReposicionUnitario: precio,
            prioridadSeguro: prioridadSeguro,
            notas: notas,
            revisionOriginal: revisionOriginal,
            revisionES: revisionES,
            revisionCA: revisionCA,
            revisionEN: revisionEN,
            imagenData: imagenData,
            fechaCompra: fechaCompra,
            fechaCreacion: Date()
        )
        modelContext.insert(item)
        try? modelContext.save()
        dismiss()
    }

    private func formatEur(_ v: Double) -> String {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.minimumFractionDigits = 2
        f.maximumFractionDigits = 2
        return (f.string(from: NSNumber(value: v)) ?? "0,00") + " €"
    }
}

// MARK: - Reusable Wizard subviews

struct WizardStepHeader: View {
    let icon: String
    let title: String
    let hint: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(Color.accentColor)
                Text(title)
                    .font(.title2)
                    .fontWeight(.bold)
            }
            if !hint.isEmpty {
                Text(hint)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

struct FormCard<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            content
        }
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}
