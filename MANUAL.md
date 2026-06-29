# FotoMaterial — Manual de usuario

**Versión 1.1 · Inventario fotográfico profesional para iPhone y iPad**

---

## Tabla de contenidos

1. [¿Qué es FotoMaterial?](#qué-es-fotomaterial)
2. [Pantallas principales](#pantallas-principales)
3. [Añadir un artículo](#añadir-un-artículo)
4. [Detalle y edición de un artículo](#detalle-y-edición-de-un-artículo)
5. [Exportar el inventario](#exportar-el-inventario)
6. [Importar desde CSV o Excel](#importar-desde-csv-o-excel)
7. [Backup completo (con fotografías)](#backup-completo-con-fotografías)
8. [Restaurar un backup](#restaurar-un-backup)
9. [Traspasar el inventario a otro iPhone](#traspasar-el-inventario-a-otro-iphone)
10. [Recomendaciones de seguridad](#recomendaciones-de-seguridad)

---

## ¿Qué es FotoMaterial?

FotoMaterial es una aplicación para iPhone y iPad que permite gestionar un inventario completo del equipo fotográfico personal o profesional. Para cada artículo registra:

- Identificación: nombre, marca, modelo, número de serie.
- Valoración económica: precio de reposición, factor de segunda mano, factor de seguro.
- Documentación: fotografía del artículo, factura de compra (foto o escaneado), reseña técnica en varios idiomas.
- Logística: categoría, subcategoría, cantidad, estado comercial, prioridad para el seguro, notas libres.

Con esos datos la app calcula automáticamente el valor total de reposición, el valor de segunda mano y el valor asegurado, tanto por artículo como para todo el inventario.

---

## Pantallas principales

La app tiene cuatro pestañas en la barra inferior.

### Inventario (pestaña 1)

Lista completa de todos los artículos, ordenada por número de ID correlativo.

- **Barra superior**: muestra el número de artículos visibles y el valor de reposición acumulado de los que están en pantalla.
- **Búsqueda**: campo en la parte superior que filtra en tiempo real por nombre de artículo, marca, modelo o categoría.
- **Fila de artículo**: muestra la miniatura de la fotografía, el nombre, la marca/modelo y el precio de reposición. Un punto de color indica la prioridad del seguro (rojo = Crítica, naranja = Alta, amarillo = Media, gris = Baja).
- **Eliminar**: desliza una fila hacia la izquierda para borrar el artículo (se pide confirmación).
- **Ir al detalle**: toca cualquier fila para ver el detalle completo.
- **Añadir artículo**: botón "+" en la esquina superior derecha, o la pestaña central "+".

### Grupos (pestaña 2)

Misma lista de artículos pero agrupada por categoría. Útil para ver de un vistazo cuántos elementos hay en cada grupo y el valor acumulado por categoría.

### Ajustes (pestaña 4)

Gestión global de la app:

- **Idioma**: selector para cambiar el idioma de la interfaz entre Castellano, Català e English. El cambio es inmediato y se recuerda entre sesiones.
- **Importar / Exportar**: importación de CSV y Excel; exportación a PDF y CSV.
- **Backup completo**: exportación e importación del backup con fotografías (ver sección dedicada).
- **Resumen financiero**: totales de reposición, segunda mano y valor asegurado de todo el inventario, y número total de artículos.

---

## Añadir un artículo

El proceso de alta es un asistente de cinco pasos que guía paso a paso.

### Paso 1 — Artículo

Introduce el **nombre del artículo** (obligatorio), la **marca**, el **modelo** y el **número de serie** (opcional). El número de serie es el que figura en el propio equipo o en la factura; se usa para identificar de forma inequívoca cada unidad.

Una vez escritos estos datos puedes buscar información en internet tocando la lupa que aparece junto al nombre.

### Paso 2 — Fotografía

Hay tres formas de añadir la imagen del artículo:

- **Buscar en internet**: abre un navegador web integrado. Navega hasta encontrar una foto del artículo y toca el botón azul "Detectar imagen" que aparece en la parte inferior. La app escanea la página y extrae la imagen principal. Si la imagen detectada no es la correcta, sigue navegando o usa el botón "Seleccionar esta imagen".
- **Cámara**: fotografía el artículo directamente.
- **Fotos**: elige una imagen de tu biblioteca de fotos.

### Paso 3 — Reseña

Busca reseñas o análisis técnicos del artículo en internet.

- Toca "Buscar reseñas en internet" para abrir el navegador integrado.
- Navega hasta el texto que te interese y toca la barra azul en la parte inferior para seleccionar la reseña de la página actual.
- La reseña se guarda en el idioma original. Puedes traducirla a Castellano, Català o English con el botón "Traducir" (requiere conexión y el idioma de destino instalado en el dispositivo).

### Paso 4 — Detalles económicos

- **Precio de reposición unitario (€)**: precio actual de mercado para reponer el artículo. Puedes introducirlo a mano o buscar el precio actual en Amazon tocando "Buscar precio en Amazon", que abre el navegador integrado y detecta automáticamente el precio de la página de Amazon cuando la encuentras.
- **Cantidad**: número de unidades de este artículo.
- **Estado comercial**: nuevo, segunda mano, etc.
- **Factor de segunda mano** (defecto 0,60): porcentaje del precio de reposición al que valorarías el artículo de segunda mano. El valor de segunda mano = precio unitario × cantidad × factor.
- **Factor de seguro** (defecto 1,15): multiplicador para el valor asegurado. El valor asegurado = precio unitario × cantidad × factor.
- **Prioridad de seguro**: Crítica, Alta, Media o Baja. Útil para negociar coberturas y franquicias.
- **Fecha de compra**.

### Paso 5 — Categoría

Selecciona la categoría del artículo desde la lista (que incluye las categorías ya usadas en el inventario más una lista de categorías fotográficas predefinidas) o crea una nueva tocando el botón "+".

Opcionalmente añade una subcategoría para mayor granularidad (p. ej. categoría "Objetivos y óptica", subcategoría "Gran angular").

Toca **Guardar** para añadir el artículo al inventario.

---

## Detalle y edición de un artículo

Al tocar un artículo de la lista se abre la vista de detalle, que muestra toda la información organizada en secciones.

### Lo que se muestra en modo vista

- **Fotografía**: imagen grande en la parte superior. Toca para ver a pantalla completa.
- **Datos de identificación**: ID, categoría/subcategoría, artículo, marca, modelo, número de serie.
- **Valoración**: precio unitario, valor total reposición, valor segunda mano, valor asegurado. Los factores y la prioridad de seguro se muestran en su propia fila.
- **Reseña**: texto completo con botón para cambiar el idioma de visualización (original, castellano, catalán, inglés) y botón "Traducir" para generar la traducción si todavía no existe.
- **Factura**: miniatura de la factura adjunta, o indicador de que no hay factura. Botones para ver la factura completa, fotografiarla con la cámara o elegirla de la biblioteca.
- **Notas**: campo de texto libre.
- **Fechas**: fecha de compra y fecha de creación del registro.

### Editar un artículo

Toca el botón **Editar** (esquina superior derecha). En modo edición:

- Todos los campos de texto son editables directamente.
- La **categoría** tiene un selector con todas las categorías existentes más un botón "+" para crear una nueva sin salir de la pantalla.
- El campo de **precio** usa un buffer local: puedes borrar el valor completamente y escribir el nuevo sin que el campo vuelva al precio anterior. El precio se guarda al tocar **Hecho**.
- Puedes cambiar o eliminar la fotografía y la factura.
- Toca **Hecho** para guardar los cambios.

---

## Exportar el inventario

Desde **Ajustes → Importar / Exportar**:

### Exportar PDF

Genera un informe completo del inventario en formato PDF, agrupado por categoría. Para cada artículo incluye:

- Fotografía en miniatura.
- Nombre, marca, modelo y número de serie (si está relleno).
- Valores económicos (reposición, segunda mano, asegurado).

Al final del informe aparece una tabla de resumen con los totales por categoría y el gran total. El PDF se puede compartir por correo, AirDrop, guardar en iCloud Drive, etc.

### Exportar CSV

Genera un fichero CSV (separador punto y coma, compatible con Excel en locales europeos) con todos los artículos en una hoja plana, un artículo por fila. Incluye 21 columnas con todos los campos textuales y numéricos (incluyendo el número de serie en la última columna). Las imágenes no se incluyen en el CSV.

---

## Importar desde CSV o Excel

Desde **Ajustes → Importar / Exportar → Importar desde CSV/Excel**:

- Admite ficheros `.csv` y `.xlsx`.
- La primera fila se trata como cabecera y se omite.
- Los artículos importados se **añaden** al inventario existente (no reemplazan nada).
- Si el fichero tiene 21 columnas (formato nuevo con número de serie), el campo de número de serie se importa de la columna 21. Si tiene 20 columnas (formato antiguo), el número de serie queda vacío.
- Los errores por fila (formato incorrecto, valores no numéricos) se acumulan y se notifican al terminar sin interrumpir la importación del resto.

---

## Backup completo (con fotografías)

El CSV y el PDF son exportaciones del texto y los datos. El **backup completo** guarda también las fotografías de los artículos y las fotos de las facturas.

El backup se genera como un fichero ZIP con extensión `.fotomaterial`. Internamente contiene:

- `inventory.json`: todos los campos de texto de todos los artículos, en formato JSON.
- `images/<uuid>.jpg`: fotografía de cada artículo (si existe).
- `invoices/<uuid>.jpg`: foto de la factura de cada artículo (si existe).

### Cómo exportar un backup

1. Abre **Ajustes → Backup completo**.
2. Toca **Exportar backup (con fotos)**.
3. Se abre la hoja de compartición estándar de iOS. Las opciones recomendadas son:
   - **Guardar en Archivos** → iCloud Drive (queda sincronizado y accesible desde cualquier dispositivo).
   - **AirDrop** → enviar directamente a otro iPhone o al Mac.
   - **Correo** o cualquier otra app de mensajería.
4. El fichero se nombra automáticamente `FotoMaterial_backup_YYYYMMDD.fotomaterial`.

---

## Restaurar un backup

### Opción A — Desde la app (manual)

1. Abre **Ajustes → Backup completo**.
2. Toca **Restaurar backup**.
3. Elige el fichero `.fotomaterial` desde la app Archivos (iCloud Drive, En este iPhone, etc.).
4. La app muestra cuántos artículos se han **añadido** y cuántos se han **actualizado**.

### Opción B — Apertura directa (automática)

Si recibes el fichero `.fotomaterial` por **AirDrop** o lo tocas en la **app Archivos**:

1. iOS abre FotoMaterial automáticamente.
2. La app navega al tab de Ajustes.
3. La restauración se ejecuta sin pasos adicionales.
4. Aparece un aviso con el resultado (artículos añadidos / actualizados).

### Cómo funciona la restauración (deduplicación)

La restauración usa el **UUID** de cada artículo como clave de deduplicación:

- Si el artículo del backup **no existe** en el dispositivo (UUID distinto) → se **inserta** como nuevo.
- Si el artículo del backup **ya existe** (mismo UUID) → se **actualiza** con los datos del backup, sobrescribiendo los campos actuales y reemplazando las imágenes si el backup las incluye.

Esto permite restaurar sin duplicar artículos, y también permite usar el backup para **sincronizar** dos dispositivos: los artículos nuevos se añaden, los existentes se actualizan.

---

## Traspasar el inventario a otro iPhone

Hay dos métodos para llevar el inventario completo (artículos + fotos) de un iPhone a otro.

### Método 1 — AirDrop (recomendado, más rápido)

1. En el **iPhone de origen**, abre **Ajustes → Backup completo → Exportar backup**.
2. En la hoja de compartición, toca **AirDrop** y selecciona el iPhone de destino (ambos deben tener AirDrop activo y estar cerca).
3. En el **iPhone de destino**, aparece una notificación de AirDrop. Acepta el fichero.
4. iOS pregunta con qué app abrirlo: selecciona **FotoMaterial** (o la app lo abre sola si ya está instalada y el tipo de fichero está registrado).
5. La restauración se ejecuta automáticamente y aparece el aviso de confirmación.

### Método 2 — iCloud Drive (válido si no están en el mismo lugar)

1. En el **iPhone de origen**, exporta el backup y elige **Guardar en Archivos → iCloud Drive**.
2. En el **iPhone de destino**, abre la app **Archivos**, navega a iCloud Drive y localiza el fichero `.fotomaterial`.
3. Toca el fichero.
4. iOS abre FotoMaterial y la restauración se ejecuta automáticamente.

### Mantener dos iPhones sincronizados

Si quieres tener el inventario actualizado en dos dispositivos de forma habitual:

1. Haz cambios en el iPhone principal.
2. Exporta un backup y cómpártelo (AirDrop o iCloud Drive) con el iPhone secundario.
3. En el secundario, abre el fichero: los artículos nuevos se añaden y los modificados se actualizan. Los artículos que no estaban en el backup **no se eliminan** del secundario (la restauración es aditiva/actualizadora, nunca destructiva).

> **Nota**: no existe sincronización automática en tiempo real. El traspaso es siempre manual mediante el fichero de backup.

---

## Recomendaciones de seguridad

| Situación | Acción recomendada |
|-----------|-------------------|
| Antes de instalar una nueva versión de la app | Exportar un backup `.fotomaterial` y guardarlo en iCloud Drive |
| Después de añadir o modificar artículos | Exportar backup periódicamente (semanal o tras sesiones largas de entrada de datos) |
| Antes de cambiar de iPhone | Exportar backup + verificar que se puede restaurar correctamente en otro dispositivo |
| Pérdida o rotura del iPhone | Restaurar desde el último backup guardado en iCloud Drive |

El fichero `.fotomaterial` contiene **todo**: datos, fotos y facturas. Guardarlo en iCloud Drive garantiza que siempre hay una copia accesible aunque el iPhone se pierda o se rompa.

---

*Documento generado para FotoMaterial v1.1 — Francisco Cornellana*
