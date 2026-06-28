Este archivo guía a Claude Code cuando trabaja en este proyecto.

## Perfil del proyecto

Proyectos de desarrollo iOS/macOS con Swift y SwiftUI, creados y compilados en Xcode. El usuario es un programador avanzado: las explicaciones pueden ser técnicas y directas, sin simplificar conceptos.

## Lenguaje y frameworks

- **Swift 5.9+** con concurrencia moderna (`async/await`, actors) en lugar de callbacks o GCD cuando sea posible.
- **SwiftUI** como framework de UI por defecto. UIKit/AppKit solo cuando SwiftUI no cubra el caso (y justificarlo).
- Usar las APIs más recientes disponibles según el target de despliegue del proyecto.

## Estilo de código

- Seguir las [Swift API Design Guidelines](https://www.swift.org/documentation/api-design-guidelines/): nombres descriptivos, claridad en el punto de uso.
- `struct` por defecto; `class` solo cuando se necesite semántica de referencia.
- Preferir `let` sobre `var` siempre que sea posible.
- Evitar force unwrapping (`!`) — usar `guard let`, `if let` o valores por defecto.
- Tipos e identificadores en inglés (convención del ecosistema Swift); comentarios en español.

## Comentarios y documentación

- **Documentar todo tipo, función y propiedad pública** con comentarios de documentación (`///`) compatibles con DocC, incluyendo `- Parameters:`, `- Returns:` y `- Throws:` cuando aplique.
- Comentarios en línea (`//`) para explicar el *porqué* de decisiones no obvias: invariantes, restricciones de rendimiento, workarounds de bugs de frameworks.
- No comentar lo obvio (qué hace la línea siguiente si ya se lee claramente).
- Usar `// MARK: -` para organizar secciones dentro de cada archivo.

Ejemplo del estilo esperado:

```swift
/// Calcula el total de la orden aplicando descuentos vigentes.
/// - Parameter items: Productos incluidos en la orden.
/// - Returns: Total en la moneda local, nunca negativo.
func total(for items: [LineItem]) -> Decimal {
    // Se usa Decimal (no Double) para evitar errores de redondeo monetario.
    items.reduce(.zero) { $0 + $1.subtotal }
}
```

## Optimización

- **Medir antes de optimizar**: sugerir Instruments (Time Profiler, Allocations) ante problemas de rendimiento reales, no especular.
- Evitar trabajo innecesario en el `body` de vistas SwiftUI: extraer subvistas, usar `@State`/`@Observable` con granularidad correcta para minimizar re-renders.
- Preferir `lazy` containers (`LazyVStack`, `LazyVGrid`) para listas largas.
- Usar value types y copy-on-write a favor; evitar copias innecesarias de colecciones grandes (`ContiguousArray`, slices con cuidado).
- Operaciones costosas (red, disco, parsing) fuera del main actor; UI siempre en `@MainActor`.
- Evitar retain cycles: `[weak self]` en closures escapantes que capturen `self`.

## Localización (multilenguaje)

- **Ningún texto visible al usuario va hardcodeado**: todo string de UI debe ser localizable.
- En SwiftUI, usar `LocalizedStringKey` (comportamiento por defecto de `Text("clave")`) y **String Catalogs** (`Localizable.xcstrings`), el formato moderno de Xcode 15+.
- Para strings construidos en código, usar `String(localized:)` con comentario para el traductor:
  ```swift
  String(localized: "greeting.title", comment: "Saludo principal de la pantalla de inicio")
  ```
- Usar interpolación localizable para valores dinámicos (`Text("items.count \(count)")`), nunca concatenar strings — el orden de las palabras cambia entre idiomas.
- Formatear fechas, números y monedas con `FormatStyle` (`.formatted()`), nunca a mano: respeta el locale del usuario automáticamente.
- Soportar **right-to-left**: usar `leading`/`trailing` en lugar de `left`/`right` en alineaciones y paddings.

## Multidispositivo (multidevices)

- Diseñar layouts **adaptativos**, no fijos: nada de dimensiones hardcodeadas que asuman un tamaño de pantalla concreto.
- Usar `@Environment(\.horizontalSizeClass)` para adaptar la UI entre iPhone, iPad y modos multitarea (Split View, Slide Over).
- Preferir `NavigationSplitView` sobre `NavigationStack` cuando la app tenga navegación maestro-detalle: se adapta solo entre iPhone (stack) y iPad/Mac (columnas).
- Usar `ViewThatFits`, `Grid` y layouts flexibles antes que condicionales por dispositivo; condicionar por size class, no por modelo de dispositivo.
- Respetar **Dynamic Type**: no fijar tamaños de fuente absolutos, usar los estilos semánticos (`.body`, `.title`, etc.) y verificar que el layout no rompe con tamaños de accesibilidad.
- Probar en al menos: iPhone compacto, iPhone grande, iPad (vertical y horizontal). Si el target incluye Mac (Catalyst o nativo), verificar redimensionado de ventana.
- Mantener los targets de despliegue coherentes y declarar correctamente las orientaciones e idiomas soportados en el proyecto.

## Arquitectura

- MVVM como patrón base con `@Observable` (Observation framework) para los view models.
- Inyección de dependencias por inicializador; evitar singletons salvo para servicios del sistema.
- Separar lógica de negocio de la capa de UI para que sea testeable sin simulador.

## Pruebas y verificación

- Escribir pruebas con **Swift Testing** (`@Test`, `#expect`) o XCTest según lo que use el proyecto.
- Compilar antes de dar por terminado un cambio: `xcodebuild build` o desde Xcode (⌘B).
- Si hay tests, ejecutarlos: `xcodebuild test -scheme <Scheme> -destination 'platform=iOS Simulator,name=iPhone 16'`.

## Preparación y ejecución de proyectos en Xcode

Los proyectos se generan y verifican con este flujo (no crear proyectos a mano desde Xcode ni editar el `.pbxproj`):

1. **Estructura**: los fuentes (`.swift`, `.xcstrings`, assets) viven en una carpeta con el nombre del target (p. ej. `HelloWorld/`). Nada de archivos sueltos en la raíz.
2. **Especificación**: el proyecto se define en `project.yml` (XcodeGen). Plantilla base usada en este repo:
   ```yaml
   name: NombreApp
   options:
     bundleIdPrefix: com.cornellana
     deploymentTarget:
       iOS: "17.0"
     knownRegions: [en, es, ca]
     developmentLanguage: en
   targets:
     NombreApp:
       type: application
       platform: iOS
       sources: [NombreApp]
       settings:
         base:
           GENERATE_INFOPLIST_FILE: YES
           INFOPLIST_KEY_UILaunchScreen_Generation: YES
           SWIFT_VERSION: "5.9"
           TARGETED_DEVICE_FAMILY: "1,2"   # iPhone + iPad
           CURRENT_PROJECT_VERSION: 1
           MARKETING_VERSION: 1.0
           DEVELOPMENT_TEAM: TJ6V4QM3GB    # Francisco Cornellana Castells
   ```

   **Firma**: el team de desarrollo es **Francisco Cornellana Castells** (Team ID `TJ6V4QM3GB`, cuenta personal de Apple Development). Incluir siempre `DEVELOPMENT_TEAM: TJ6V4QM3GB` en los settings base para que la firma automática funcione al ejecutar en dispositivo físico sin pasos manuales en Xcode.
3. **Generación**: `xcodegen generate` crea/regenera el `.xcodeproj`. **Re-ejecutarlo cada vez que se añadan, muevan o borren archivos** — el proyecto refleja el contenido de la carpeta de fuentes.
4. **Verificación**: compilar desde terminal antes de dar nada por terminado:
   ```bash
   xcodebuild build -project NombreApp.xcodeproj -scheme NombreApp \
     -destination 'generic/platform=iOS Simulator'
   ```
   Buscar `** BUILD SUCCEEDED **` en la salida; si falla, corregir antes de continuar.
5. **Apertura**: `open NombreApp.xcodeproj` abre el proyecto en Xcode. Xcode recarga solo el proyecto regenerado; el usuario ejecuta con ⌘R en el simulador.

XcodeGen está instalado vía Homebrew (`brew install xcodegen` si faltara en otra máquina).

## Control de versiones y respaldo en GitHub

Todo proyecto vive desde el inicio en un **repositorio público de GitHub** bajo la cuenta `cornellana`. No se trabaja "en local sin más" — el repo es la copia de seguridad, el sitio donde corren los workflows automáticos y la fuente desde la que la app puede consumir datos en vivo.

1. **Crear el repo al arrancar el proyecto** (no esperar a tener "algo terminado"):
   ```bash
   gh repo create cornellana/<nombre-proyecto> --public --source=. --remote=origin --push
   ```
   Si `gh` no está autenticado: `gh auth login` (web flow o token con scopes `repo`, `read:org`, `workflow`).

2. **`.gitignore` mínimo** desde el primer commit:
   ```gitignore
   .DS_Store
   xcuserdata/
   *.xcodeproj/project.xcworkspace/
   *.xcworkspace/xcuserdata/
   DerivedData/
   .build/
   .swiftpm/
   Pods/
   ```

3. **Estructura típica en el repo**:
   ```
   <Project>/                 ← fuentes del target
   project.yml                ← especificación XcodeGen
   .github/workflows/         ← crons y CI
   scripts/                   ← herramientas (Python, Swift CLI, render de icono)
   data/                      ← assets versionados que la app consume vía raw.githubusercontent.com
   ```

4. **Datos en vivo y auto-actualización**:
   - Si la app necesita información que cambia (resultados deportivos, precios, feeds, etc.), implementarlo con **GitHub Actions cron** — no con servidor propio.
   - El workflow regenera el archivo en `data/` y lo commitea automáticamente como `github-actions[bot]`.
   - La app consume el JSON desde `https://raw.githubusercontent.com/cornellana/<repo>/refs/heads/main/data/<file>.json`.
   - Las API keys o tokens viven en **GitHub Secrets**, nunca en el binario ni en el código.
   - Si la API que se necesita es de pago o restringe por IP, preferir APIs públicas sin autenticación (ESPN, Wikipedia, etc.) antes que comprometerse a un plan.

5. **Push frecuente**:
   - Tras cada cambio significativo o al final de cada sesión: `git add` + `git commit` + `git push`. Nunca acumular días de trabajo en local.
   - `git pull --rebase origin main` antes de cada push, para integrar los commits del bot del cron sin conflictos.
   - Si surge conflicto en archivos `data/*`, `git checkout --theirs <file>` y continuar el rebase — el remoto siempre gana, porque lo regeneró el cron con datos frescos.

6. **No** crear repos privados salvo que haya razón concreta. La app debe ser distribuible y el raw del repo público es la forma más sencilla y gratuita de servir datos a una app del App Store sin backend propio.

## Icono de la aplicación

Cada proyecto debe incluir un icono propio, generado e integrado así:

1. **Generación programática**: el icono se dibuja con un script Swift en `scripts/render_icon.swift` usando **CoreGraphics puro** (no `NSGraphicsContext` de AppKit, que falla en línea de comandos y produce un PNG negro). El script exporta un PNG de **1024×1024 px sin canal alfa** (App Store rechaza iconos de iOS con transparencia: usar `CGImageAlphaInfo.noneSkipLast`).
2. **Diseño**: estética moderna iOS — degradado vibrante de fondo, tipografía SF Rounded en pesos gruesos o un símbolo claro, elementos decorativos sutiles (círculos translúcidos). Adaptar colores y motivo al propósito de cada app. Sin esquinas redondeadas: el sistema aplica la máscara.
3. **Asset catalog**: crear `NombreApp/Assets.xcassets/AppIcon.appiconset/` con el PNG y su `Contents.json` en formato de icono único (un solo `universal` de `1024x1024`; Xcode deriva el resto de resoluciones):
   ```json
   {
     "images" : [
       { "filename" : "AppIcon.png", "idiom" : "universal",
         "platform" : "ios", "size" : "1024x1024" }
     ],
     "info" : { "author" : "xcode", "version" : 1 }
   }
   ```
   El `Assets.xcassets/Contents.json` raíz solo lleva el bloque `info`.
4. **Conexión al target**: en `project.yml`, añadir `ASSETCATALOG_COMPILER_APPICON_NAME: AppIcon` a los settings base.
5. **Verificación**: regenerar con `xcodegen generate`, compilar y comprobar que no hay warnings del asset catalog. Revisar visualmente el PNG generado (leerlo como imagen) antes de dar el icono por bueno.

El script de generación se conserva en `scripts/` (fuera de la carpeta de fuentes del target, para que no se compile en la app) y permite regenerar o retocar el icono en cualquier momento.

## Qué NO hacer

- No introducir dependencias externas (SPM/CocoaPods) sin preguntar primero.
- No editar el `.pbxproj` a mano: el proyecto se regenera siempre con `xcodegen generate` desde `project.yml`.
- No usar APIs deprecadas si existe alternativa moderna.
