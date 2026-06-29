import SwiftUI
import WebKit

// MARK: - Selector de imagen (búsqueda web)

/// Vista que permite al usuario buscar y seleccionar una fotografía del equipo
/// usando el navegador Bing Images integrado.
///
/// El flujo es:
/// 1. Se carga Bing Images con la consulta del artículo.
/// 2. El usuario navega hasta encontrar el artículo (puede tocar un thumbnail para
///    abrir el panel de detalle de Bing con la imagen grande).
/// 3. El usuario pulsa "Detectar imagen" → JS recoge todos los src de `<img>` de la
///    página y se muestra un selector nativo de miniaturas.
/// 4. El usuario toca la miniatura correcta → se descarga y devuelve via `selectedImageData`.
struct WebImagePickerView: View {

    // MARK: Propiedades

    /// Consulta de búsqueda, normalmente «marca modelo artículo».
    let query: String

    /// Binding de salida: datos binarios de la imagen seleccionada.
    @Binding var selectedImageData: Data?

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var locale: AppLocale

    /// Indica si el WebView está cargando una página.
    @State private var isLoading = true

    /// URL de la imagen elegida en el selector nativo, pendiente de descarga.
    @State private var pendingURL: String?

    /// `true` mientras se descarga la imagen seleccionada.
    @State private var isDownloading = false

    /// Lista de URLs recogidos de la página para mostrar en el selector nativo.
    @State private var detectedImages: [String] = []

    /// Controla si el selector nativo de imágenes detectadas está visible.
    @State private var showDetectedGrid = false

    /// `true` cuando el escaneo no encuentra ninguna imagen válida en la página.
    @State private var noImagesDetected = false

    /// Referencia directa al WKWebView para evaluar JS desde los botones nativos SwiftUI.
    /// Se mantiene fuera del representable para no depender del ciclo makeUIView/updateUIView.
    @State private var webView: WKWebView = {
        let wv = WKWebView()
        wv.allowsBackForwardNavigationGestures = true
        return wv
    }()

    // MARK: Cuerpo

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                ImageBrowserView(query: query, webView: webView, isLoading: $isLoading)
                    .ignoresSafeArea(edges: .bottom)

                selectionBar
            }
            .navigationTitle(locale.t("wizard.step.photo"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(locale.t("cancel")) { dismiss() }
                }
                if isLoading {
                    ToolbarItem(placement: .status) { ProgressView() }
                }
            }
            // Selector nativo: cuadrícula de miniaturas de las imágenes detectadas
            .sheet(isPresented: $showDetectedGrid) {
                DetectedImageGridView(urls: detectedImages, selectedURL: $pendingURL)
            }
            .alert("No se encontraron imágenes", isPresented: $noImagesDetected) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Navega a una página con el artículo y vuelve a pulsar 'Detectar imagen'.")
            }
        }
    }

    // MARK: Barra de selección

    /// Barra inferior siempre visible con el estado de selección y los botones de acción.
    private var selectionBar: some View {
        VStack(spacing: 0) {
            // Indicador del estado actual
            HStack {
                Image(systemName: pendingURL == nil ? "photo.on.rectangle" : "checkmark.circle")
                    .foregroundStyle(pendingURL == nil ? AnyShapeStyle(.secondary) : AnyShapeStyle(Color.white))
                Text(pendingURL == nil
                     ? locale.t("wizard.photo.tap")
                     : locale.t("web.select.image"))
                    .font(.subheadline)
                    .foregroundStyle(pendingURL == nil ? AnyShapeStyle(.secondary) : AnyShapeStyle(Color.white))
                    .lineLimit(1)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(pendingURL == nil ? Color(.systemGray6) : Color.accentColor)
            .animation(.easeInOut(duration: 0.2), value: pendingURL)

            // Botones de acción
            HStack(spacing: 12) {
                Button {
                    detectSelectedImage()
                } label: {
                    Label(locale.t("web.detect.image"), systemImage: "viewfinder")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
                .buttonStyle(.bordered)
                .disabled(isLoading)

                if let url = pendingURL {
                    Button {
                        downloadAndSelect(urlString: url)
                    } label: {
                        Group {
                            if isDownloading {
                                ProgressView().tint(.white)
                            } else {
                                Label(locale.t("confirm"), systemImage: "checkmark")
                                    .fontWeight(.semibold)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isDownloading)
                }
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 8)
            .background(Color(.systemGray6))
        }
    }

    // MARK: Lógica de detección y descarga

    /// Recoge los URLs de imágenes de la página actual y los muestra en un selector nativo.
    ///
    /// Estrategia de extracción por orden de prioridad:
    /// 1. `data-src-no-exif` — atributo específico de Bing para el thumbnail en alta calidad.
    /// 2. `data-src` / `data-original` — atributos estándar de lazy loading.
    /// 3. Atributo `src` bruto — solo si es una URL absoluta de imagen (no la URL de la página,
    ///    que es lo que devuelve `img.src` cuando `src=""` está vacío).
    ///
    /// Las imágenes se filtran para que parezcan URLs de imagen válidas (extensión o CDN conocido).
    private func detectSelectedImage() {
        let js = """
        (function(){
            var seen = {}, out = [];
            var page = window.location.href;
            var imgs = document.getElementsByTagName('img');
            for (var i = 0; i < imgs.length; i++) {
                var img = imgs[i];
                var src = '';

                // 1. Atributos de lazy loading de Bing (tienen el thumbnail de calidad)
                src = img.getAttribute('data-src-no-exif')
                   || img.getAttribute('data-src')
                   || img.getAttribute('data-original') || '';

                // 2. Atributo src bruto — solo si es URL absoluta de imagen
                if (!src || src.indexOf('data:') === 0) {
                    var raw = img.getAttribute('src') || '';
                    if (raw && raw.indexOf('http') === 0 && raw !== page) {
                        src = raw;
                    }
                }

                if (!src || src.indexOf('data:') === 0 || src.length < 12 || seen[src]) continue;

                // Filtro: URL que parezca imagen por extensión o CDN conocido
                var ok = /\\.(jpg|jpeg|png|webp|gif|avif|bmp)/i.test(src)
                      || src.indexOf('th.bing.com') >= 0
                      || src.indexOf('tse') >= 0
                      || src.indexOf('/th/id/') >= 0
                      || src.indexOf('media') >= 0
                      || src.indexOf('photo') >= 0
                      || src.indexOf('image') >= 0
                      || src.indexOf('img') >= 0;
                if (!ok) continue;

                seen[src] = 1;
                out.push(src);
            }
            return out.slice(0, 60).join('|');
        })()
        """
        webView.evaluateJavaScript(js) { result, _ in
            DispatchQueue.main.async {
                guard let joined = result as? String, !joined.isEmpty else {
                    noImagesDetected = true
                    return
                }
                let urls = joined.split(separator: "|").map(String.init).filter { !$0.isEmpty }
                guard !urls.isEmpty else {
                    noImagesDetected = true
                    return
                }
                detectedImages = urls
                showDetectedGrid = true
            }
        }
    }

    /// Descarga de forma asíncrona los bytes de la imagen y los devuelve via `selectedImageData`.
    /// - Parameter urlString: URL absoluto de la imagen a descargar.
    private func downloadAndSelect(urlString: String) {
        guard let url = URL(string: urlString) else { return }
        isDownloading = true
        Task {
            if let (data, _) = try? await URLSession.shared.data(from: url) {
                await MainActor.run {
                    selectedImageData = data
                    dismiss()
                }
            }
            await MainActor.run { isDownloading = false }
        }
    }
}

// MARK: - Navegador Bing Images (UIViewRepresentable)

/// Representable que envuelve WKWebView y carga Bing Images con la consulta dada.
///
/// Al finalizar cada navegación, inyecta JS que:
/// - Escucha `click`/`touchend` en modo captura (antes que los handlers de Bing).
/// - Al tocar una imagen, guarda su URL en `window._fmLastURL`.
/// - Aplica un borde azul para confirmar visualmente la selección.
struct ImageBrowserView: UIViewRepresentable {

    /// Consulta de búsqueda en Bing Images.
    let query: String

    /// Referencia compartida al WKWebView, creada en el padre para que los botones SwiftUI
    /// puedan evaluar JS directamente sin depender de mensajes JS→Swift.
    let webView: WKWebView

    /// Binding para indicar al padre si hay una carga en curso.
    @Binding var isLoading: Bool

    /// JavaScript inyectado vía `evaluateJavaScript` al completar cada navegación.
    ///
    /// Guarda el URL en `window._fmLastURL` en el instante del toque, antes de que
    /// Bing mute el DOM al abrir el panel de detalle. Así `detectSelectedImage` puede
    /// recuperar el URL aunque el elemento DOM haya desaparecido.
    static let highlightJS = """
    (function(){
        if (window._fmHighlight) return;
        window._fmHighlight = true;
        var prev = null;

        // Extrae el primer URL de imagen válido del elemento o de su hijo <img>
        function extractSrc(el) {
            if (!el) return '';
            var s = el.currentSrc || el.src
                   || el.getAttribute('data-src-no-exif')
                   || el.getAttribute('data-src')
                   || el.getAttribute('data-original') || '';
            if (s && !s.startsWith('data:') && s.length > 15) return s;
            var child = el.querySelector && el.querySelector('img');
            if (child) {
                s = child.currentSrc || child.src
                   || child.getAttribute('data-src-no-exif') || '';
                if (s && !s.startsWith('data:') && s.length > 15) return s;
            }
            return '';
        }

        function handle(e) {
            var el = e.target;
            // Subir hasta 10 niveles buscando un elemento con imagen
            for (var i = 0; i < 10 && el; i++) {
                var src = extractSrc(el);
                if (src) {
                    window._fmLastURL = src;
                    var imgEl = el.tagName === 'IMG' ? el : (el.querySelector && el.querySelector('img')) || el;
                    if (prev && prev.isConnected) { prev.style.outline = ''; prev.style.opacity = ''; }
                    prev = imgEl;
                    if (imgEl.isConnected) {
                        imgEl.style.outline = '4px solid #007AFF';
                        imgEl.style.outlineOffset = '-2px';
                        imgEl.style.opacity = '0.85';
                    }
                    return;
                }
                el = el.parentElement;
            }
        }
        // pointerdown: se dispara antes que click/touchend, captura el URL
        // antes de que Bing abra el panel de detalle y mute el DOM
        document.addEventListener('pointerdown', handle, true);
        document.addEventListener('click',       handle, true);
        document.addEventListener('touchend',    handle, {capture:true, passive:true});
    })();
    """

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIView(context: Context) -> WKWebView {
        webView.navigationDelegate = context.coordinator
        let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        if let url = URL(string: "https://www.bing.com/images/search?q=\(encoded)&safeSearch=Moderate") {
            webView.load(URLRequest(url: url))
        }
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}

    // MARK: Coordinador de navegación

    /// Coordinador que actúa como `WKNavigationDelegate`.
    /// Re-inyecta el JS de highlight cada vez que termina una navegación.
    final class Coordinator: NSObject, WKNavigationDelegate {
        let parent: ImageBrowserView
        init(_ parent: ImageBrowserView) { self.parent = parent }

        func webView(_ wv: WKWebView, didStartProvisionalNavigation _: WKNavigation!) {
            DispatchQueue.main.async { self.parent.isLoading = true }
        }

        func webView(_ wv: WKWebView, didFinish _: WKNavigation!) {
            DispatchQueue.main.async { self.parent.isLoading = false }
            // Resetear el guard para que el handler se re-registre en la nueva página.
            // NO se borra _fmLastURL para preservar la selección del usuario entre navegaciones internas.
            let js = "window._fmHighlight = false; \(ImageBrowserView.highlightJS)"
            wv.evaluateJavaScript(js) { _, _ in }
        }

        func webView(_ wv: WKWebView, didFail _: WKNavigation!, withError _: Error) {
            DispatchQueue.main.async { self.parent.isLoading = false }
        }
    }
}

// MARK: - Selector de reseña (búsqueda web)

/// Vista que permite al usuario buscar y seleccionar una reseña del artículo
/// en Bing Search. Al pulsar "Seleccionar esta reseña", extrae el texto principal
/// del artículo o del `<main>` de la página activa.
struct ReviewWebPickerView: View {

    // MARK: Propiedades

    /// Consulta de búsqueda, normalmente «marca modelo».
    let query: String

    /// Binding de salida: texto plano de la reseña seleccionada.
    @Binding var selectedReviewText: String

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var locale: AppLocale

    @State private var isLoading = true
    @State private var webView: WKWebView = {
        let wv = WKWebView()
        wv.allowsBackForwardNavigationGestures = true
        return wv
    }()

    // MARK: Cuerpo

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                ReviewBrowserView(query: query, webView: webView, isLoading: $isLoading)
                    .ignoresSafeArea(edges: .bottom)

                // Botón siempre visible para capturar el texto de la página actual
                Button {
                    extractAndSelect()
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "doc.text.fill").font(.title3)
                        Text(locale.t("web.select.review")).fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.accentColor)
                    .foregroundStyle(.white)
                }
            }
            .navigationTitle(locale.t("wizard.step.review"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(locale.t("cancel")) { dismiss() }
                }
                if isLoading {
                    ToolbarItem(placement: .status) { ProgressView() }
                }
            }
        }
    }

    // MARK: Extracción de texto

    /// Evalúa JS para extraer el texto principal de la página (article → main → body).
    /// Limita el texto a 6.000 caracteres para no saturar el modelo de traducción.
    private func extractAndSelect() {
        let js = """
        (function(){
            var el = document.querySelector('article')
                  || document.querySelector('[role=main]')
                  || document.querySelector('main')
                  || document.body;
            return (el || document.body).innerText.substring(0, 6000);
        })()
        """
        webView.evaluateJavaScript(js) { result, _ in
            if let text = result as? String,
               !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                selectedReviewText = text
                dismiss()
            }
        }
    }
}

// MARK: - Navegador Bing Search (reseñas)

/// Representable que carga Bing Search con la consulta + " review".
struct ReviewBrowserView: UIViewRepresentable {

    let query: String
    let webView: WKWebView
    @Binding var isLoading: Bool

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIView(context: Context) -> WKWebView {
        webView.navigationDelegate = context.coordinator
        let encoded = (query + " review").addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        if let url = URL(string: "https://www.bing.com/search?q=\(encoded)") {
            webView.load(URLRequest(url: url))
        }
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}

    final class Coordinator: NSObject, WKNavigationDelegate {
        let parent: ReviewBrowserView
        init(_ parent: ReviewBrowserView) { self.parent = parent }

        func webView(_ wv: WKWebView, didStartProvisionalNavigation _: WKNavigation!) {
            DispatchQueue.main.async { self.parent.isLoading = true }
        }
        func webView(_ wv: WKWebView, didFinish _: WKNavigation!) {
            DispatchQueue.main.async { self.parent.isLoading = false }
        }
        func webView(_ wv: WKWebView, didFail _: WKNavigation!, withError _: Error) {
            DispatchQueue.main.async { self.parent.isLoading = false }
        }
    }
}

// MARK: - Selector de precio (Amazon.es)

/// Vista que carga Amazon.es y detecta automáticamente el primer precio visible
/// usando selectores CSS del DOM de Amazon. El usuario puede confirmar o ignorar
/// el precio detectado.
struct WebPriceView: View {

    // MARK: Propiedades

    /// Consulta de búsqueda enviada a Amazon.es.
    let query: String

    /// Binding de salida: precio en euros detectado en Amazon.
    @Binding var detectedPrice: Double?

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var locale: AppLocale

    @State private var isLoading = true
    @State private var suggestedPrice: Double?
    @State private var webView: WKWebView = {
        let wv = WKWebView()
        wv.allowsBackForwardNavigationGestures = true
        return wv
    }()

    // MARK: Cuerpo

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                AmazonBrowserView(query: query, webView: webView, isLoading: $isLoading)
                    .ignoresSafeArea(edges: .bottom)

                VStack(spacing: 0) {
                    if let price = suggestedPrice {
                        HStack {
                            Text(locale.t("wizard.price.search") + ":")
                                .foregroundStyle(.white.opacity(0.85))
                            Spacer()
                            Text(String(format: "%.2f €", price))
                                .fontWeight(.bold)
                                .foregroundStyle(.white)
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 10)
                        .padding(.bottom, 6)
                        .background(Color.green)
                    }

                    HStack(spacing: 12) {
                        Button { scanPrices() } label: {
                            Label(locale.t("wizard.price.search"), systemImage: "magnifyingglass")
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                        }
                        .buttonStyle(.bordered)

                        if suggestedPrice != nil {
                            Button {
                                detectedPrice = suggestedPrice
                                dismiss()
                            } label: {
                                Label(locale.t("confirm"), systemImage: "checkmark")
                                    .fontWeight(.semibold)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.green)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color(.systemGray6))
                }
            }
            .navigationTitle(locale.t("wizard.price.search"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(locale.t("cancel")) { dismiss() }
                }
                if isLoading {
                    ToolbarItem(placement: .status) { ProgressView() }
                }
            }
            .onChange(of: isLoading) { _, loading in
                // Escanear automáticamente al terminar de cargar la página de resultados
                if !loading { scanPrices() }
            }
        }
    }

    // MARK: Detección de precio

    /// Evalúa JS para encontrar el primer precio visible en la página de Amazon.
    /// Los selectores CSS usados son específicos del DOM de Amazon.es.
    private func scanPrices() {
        // Estrategia: .a-price .a-offscreen contiene el precio completo para lectores
        // de pantalla ("549,99 €"), a diferencia de .a-price-whole que solo da el entero.
        // Formato es_ES: "1.549,99 €" → quitar dots (miles) → "1549,99" → coma→punto → "1549.99"
        let js = """
        (function(){
            function parse(txt){
                var raw = txt.trim()
                    .replace(/[^0-9,.]/g, '')
                    .replace(/\\./g, '')
                    .replace(',', '.');
                var v = parseFloat(raw);
                return (!isNaN(v) && v > 0.5 && v < 100000) ? v : null;
            }
            var candidates = [];
            document.querySelectorAll('.a-price .a-offscreen').forEach(function(el){
                var v = parse(el.innerText); if (v) candidates.push(v);
            });
            if (candidates.length === 0) {
                document.querySelectorAll('.a-offscreen').forEach(function(el){
                    var v = parse(el.innerText); if (v) candidates.push(v);
                });
            }
            if (candidates.length === 0) {
                document.querySelectorAll('.a-price-whole').forEach(function(el){
                    var frac = el.nextElementSibling;
                    var txt = el.innerText + (frac && frac.classList.contains('a-price-fraction') ? '.' + frac.innerText : '');
                    var v = parse(txt); if (v) candidates.push(v);
                });
            }
            return candidates.length > 0 ? candidates[0] : null;
        })()
        """
        webView.evaluateJavaScript(js) { result, _ in
            var price: Double?
            if let d = result as? Double { price = d }
            else if let i = result as? Int { price = Double(i) }
            if let p = price { DispatchQueue.main.async { self.suggestedPrice = p } }
        }
    }
}

// MARK: - Navegador Amazon.es

/// Representable que carga Amazon.es con la consulta dada.
struct AmazonBrowserView: UIViewRepresentable {

    let query: String
    let webView: WKWebView
    @Binding var isLoading: Bool

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIView(context: Context) -> WKWebView {
        webView.navigationDelegate = context.coordinator
        let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        if let url = URL(string: "https://www.amazon.es/s?k=\(encoded)") {
            webView.load(URLRequest(url: url))
        }
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}

    final class Coordinator: NSObject, WKNavigationDelegate {
        let parent: AmazonBrowserView
        init(_ parent: AmazonBrowserView) { self.parent = parent }

        func webView(_ wv: WKWebView, didStartProvisionalNavigation _: WKNavigation!) {
            DispatchQueue.main.async { self.parent.isLoading = true }
        }
        func webView(_ wv: WKWebView, didFinish _: WKNavigation!) {
            DispatchQueue.main.async { self.parent.isLoading = false }
            acceptAmazonCookies(wv)
            // Segundo intento por si el botón se renderiza via JS tras el onload
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak wv] in
                guard let wv else { return }
                self.acceptAmazonCookies(wv)
            }
        }
        func webView(_ wv: WKWebView, didFail _: WKNavigation!, withError _: Error) {
            DispatchQueue.main.async { self.parent.isLoading = false }
        }

        /// Inyecta JS para aceptar automáticamente el banner/página de cookies de Amazon.es.
        ///
        /// Amazon puede mostrar la cookie consent como página completa (redirect) o como overlay.
        /// Se prueban selectores por id/class primero; si no se encuentran, se busca por texto del botón.
        private func acceptAmazonCookies(_ wv: WKWebView) {
            let js = """
            (function(){
                var sel = [
                    '#sp-cc-accept',
                    '[data-action="accept-all"]',
                    '.sp-cc-accept',
                    '#acceptAllCookiesBtn',
                    'input[name="accept"]'
                ];
                for (var i = 0; i < sel.length; i++) {
                    var el = document.querySelector(sel[i]);
                    if (el) { el.click(); return; }
                }
                // Búsqueda por texto visible del botón
                var btns = document.querySelectorAll('button,input[type="submit"],[role="button"]');
                for (var j = 0; j < btns.length; j++) {
                    var txt = (btns[j].innerText || btns[j].value || '').trim().toLowerCase();
                    if (txt === 'acepta todas las cookies' ||
                        txt === 'accept all cookies'       ||
                        txt === 'aceptar todas'            ||
                        txt === 'aceptar cookies'          ||
                        txt.indexOf('acepta') === 0        ||
                        txt.indexOf('accept all') === 0) {
                        btns[j].click();
                        return;
                    }
                }
            })()
            """
            wv.evaluateJavaScript(js) { _, _ in }
        }
    }
}

// MARK: - Cuadrícula nativa de imágenes detectadas

/// Vista que muestra en un grid nativo las imágenes detectadas en el WebView.
///
/// El usuario toca la miniatura que le interesa; la vista escribe el URL en `selectedURL`
/// y se descarta automáticamente. Si la imagen no carga (403, formato no soportado, etc.)
/// la celda muestra un icono de error y sigue siendo ignorada.
struct DetectedImageGridView: View {

    // MARK: Propiedades

    /// URLs de las imágenes detectadas en la página web.
    let urls: [String]

    /// Binding de salida: URL de la imagen elegida por el usuario.
    @Binding var selectedURL: String?

    @Environment(\.dismiss) private var dismiss

    // Cuadrícula densa: columnas adaptativas de 90 pt para mostrar más imágenes a la vez
    private let columns = [GridItem(.adaptive(minimum: 90, maximum: 130))]

    // MARK: Cuerpo

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 6) {
                    ForEach(urls, id: \.self) { url in
                        imageCell(url: url)
                    }
                }
                .padding(8)
            }
            .navigationTitle("Elige una imagen (\(urls.count))")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
            }
        }
    }

    // MARK: Celda

    /// Celda con `AsyncImage`: toca para seleccionar; muestra un icono si falla la carga.
    @ViewBuilder
    private func imageCell(url: String) -> some View {
        AsyncImage(url: URL(string: url)) { phase in
            switch phase {
            case .success(let image):
                image
                    .resizable()
                    .scaledToFill()
                    .frame(width: 100, height: 100)
                    .clipped()
                    .contentShape(Rectangle())
                    .onTapGesture {
                        selectedURL = url
                        dismiss()
                    }
            case .failure:
                // Imagen no descargable: mostrar placeholder sin ocupar espacio visible
                Color(.systemGray6)
                    .frame(width: 100, height: 100)
                    .overlay {
                        Image(systemName: "photo.slash")
                            .font(.caption)
                            .foregroundStyle(Color(.systemGray3))
                    }
            default:
                Color(.systemGray5)
                    .frame(width: 100, height: 100)
                    .overlay { ProgressView().scaleEffect(0.7) }
            }
        }
        .frame(width: 100, height: 100)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - Selector de imagen con cámara

/// Representable que presenta `UIImagePickerController` en modo cámara para que
/// el usuario tome una foto directamente desde la app.
///
/// **Crash fix**: no usa `@Environment(\.dismiss)` porque el entorno SwiftUI puede
/// quedar inválido mientras el controlador de la cámara está activo (el sistema
/// toma control de la pantalla completa). En su lugar, el coordinador llama a
/// `picker.dismiss(animated:)` directamente — UIKit notifica a SwiftUI, que
/// actualiza el binding `isPresented` automáticamente.
struct CameraPickerView: UIViewControllerRepresentable {

    // MARK: Propiedades

    /// Binding de salida: datos JPEG de la foto capturada.
    @Binding var imageData: Data?

    // MARK: UIViewControllerRepresentable

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    /// Configura y devuelve el `UIImagePickerController` apuntando a la cámara.
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.allowsEditing = false
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    // MARK: Coordinador de delegado

    /// Coordinador que implementa `UIImagePickerControllerDelegate` y `UINavigationControllerDelegate`.
    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {

        /// Referencia al representable padre para escribir el resultado en el binding.
        let parent: CameraPickerView

        init(_ parent: CameraPickerView) { self.parent = parent }

        /// Llamado cuando el usuario confirma una foto.
        /// - Parameters:
        ///   - picker: El controlador de la cámara.
        ///   - info: Diccionario con la imagen original y metadatos.
        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            if let image = info[.originalImage] as? UIImage {
                // JPEG al 85 %: equilibrio óptimo entre calidad visual e inventario de tamaño del modelo SwiftData
                parent.imageData = image.jpegData(compressionQuality: 0.85)
            }
            // Usar UIKit directamente: más seguro que DismissAction de SwiftUI durante la presentación de cámara
            picker.dismiss(animated: true)
        }

        /// Llamado cuando el usuario cancela la cámara.
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            picker.dismiss(animated: true)
        }
    }
}
