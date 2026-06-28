#!/usr/bin/swift
// Genera el icono de FotoMaterial — silueta de cámara fotográfica (1024×1024, sin alfa).
// Ejecutar desde la raíz del proyecto: swift scripts/render_icon.swift
import Foundation
import CoreGraphics
import ImageIO

// MARK: - Lienzo

let size: CGFloat = 1024
let cx   = size / 2   // 512

let cs = CGColorSpaceCreateDeviceRGB()
guard let ctx = CGContext(
    data: nil, width: Int(size), height: Int(size),
    bitsPerComponent: 8, bytesPerRow: Int(size) * 4,
    space: cs,
    bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
) else { fatalError("No se puede crear CGContext") }

// CoreGraphics: origen abajo-izquierda → lo invertimos para trabajar arriba-izquierda
ctx.translateBy(x: 0, y: size)
ctx.scaleBy(x: 1, y: -1)

// MARK: - Fondo (degradado radial oscuro, viñeta fotográfica)

let bgColors = [
    CGColor(red: 0.14, green: 0.10, blue: 0.22, alpha: 1),  // violeta muy oscuro
    CGColor(red: 0.04, green: 0.04, blue: 0.10, alpha: 1),  // casi negro
] as CFArray
let bgGrad = CGGradient(colorsSpace: cs, colors: bgColors, locations: [0.0, 1.0])!
ctx.drawRadialGradient(bgGrad,
    startCenter: CGPoint(x: cx, y: 420), startRadius: 0,
    endCenter:   CGPoint(x: cx, y: 512), endRadius: 740,
    options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])

// MARK: - Utilidades

func roundedRectPath(_ rect: CGRect, radius: CGFloat) -> CGMutablePath {
    let p = CGMutablePath()
    p.addRoundedRect(in: rect, cornerWidth: radius, cornerHeight: radius)
    return p
}

func fillGradientInRect(_ rect: CGRect, radius: CGFloat,
                        colors: CFArray, start: CGPoint, end: CGPoint) {
    let grad = CGGradient(colorsSpace: cs, colors: colors, locations: nil)!
    ctx.saveGState()
    ctx.addPath(roundedRectPath(rect, radius: radius))
    ctx.clip()
    ctx.drawLinearGradient(grad, start: start, end: end, options: [])
    ctx.restoreGState()
}

func fillRadialInCircle(cx: CGFloat, cy: CGFloat, r: CGFloat,
                        colors: CFArray, innerCX: CGFloat, innerCY: CGFloat) {
    let grad = CGGradient(colorsSpace: cs, colors: colors, locations: nil)!
    ctx.saveGState()
    ctx.addEllipse(in: CGRect(x: cx - r, y: cy - r, width: r * 2, height: r * 2))
    ctx.clip()
    ctx.drawRadialGradient(grad,
        startCenter: CGPoint(x: innerCX, y: innerCY), startRadius: 0,
        endCenter:   CGPoint(x: cx, y: cy),            endRadius: r,
        options: [])
    ctx.restoreGState()
}

// MARK: - Geometría de la cámara

let bodyCY: CGFloat = 545        // centro vertical del cuerpo
let bodyW:  CGFloat = 700
let bodyH:  CGFloat = 400
let bodyX   = (size - bodyW) / 2 // 162
let bodyY   = bodyCY - bodyH / 2 // 345  (top del cuerpo)
let bodyR:  CGFloat = 55          // radio de esquinas del cuerpo

// MARK: - Sombra del cuerpo

ctx.saveGState()
ctx.setShadow(offset: CGSize(width: 0, height: 14), blur: 40,
              color: CGColor(red: 0, green: 0, blue: 0, alpha: 0.65))
ctx.addPath(roundedRectPath(CGRect(x: bodyX, y: bodyY, width: bodyW, height: bodyH), radius: bodyR))
ctx.setFillColor(CGColor(red: 0.2, green: 0.2, blue: 0.2, alpha: 1))
ctx.fillPath()
ctx.restoreGState()

// MARK: - Cuerpo principal

let bodyColors = [
    CGColor(red: 0.30, green: 0.30, blue: 0.33, alpha: 1),  // gris plateado
    CGColor(red: 0.14, green: 0.14, blue: 0.16, alpha: 1),  // gris oscuro
] as CFArray
fillGradientInRect(CGRect(x: bodyX, y: bodyY, width: bodyW, height: bodyH), radius: bodyR,
    colors: bodyColors,
    start: CGPoint(x: cx, y: bodyY),
    end:   CGPoint(x: cx, y: bodyY + bodyH))

// Borde plateado del cuerpo
ctx.addPath(roundedRectPath(CGRect(x: bodyX, y: bodyY, width: bodyW, height: bodyH), radius: bodyR))
ctx.setStrokeColor(CGColor(red: 0.60, green: 0.60, blue: 0.65, alpha: 0.50))
ctx.setLineWidth(3.5)
ctx.strokePath()

// Línea de luz en el borde superior (highlight)
let highlightPath = CGMutablePath()
highlightPath.move(to:    CGPoint(x: bodyX + bodyR + 10, y: bodyY + 1.5))
highlightPath.addLine(to: CGPoint(x: bodyX + bodyW - bodyR - 10, y: bodyY + 1.5))
ctx.addPath(highlightPath)
ctx.setStrokeColor(CGColor(red: 1, green: 1, blue: 1, alpha: 0.18))
ctx.setLineWidth(2.5)
ctx.strokePath()

// MARK: - Pentaprisma / joroba del visor

let humpW: CGFloat = 210
let humpH: CGFloat = 90
let humpX = cx - humpW / 2
let humpY = bodyY - humpH + 6   // se solapa 6pt con el cuerpo

let humpPath = CGMutablePath()
let hR: CGFloat = 28
// Arco superior con esquinas redondeadas, base recta coincide con tope del cuerpo
humpPath.move(to: CGPoint(x: humpX, y: bodyY + 6))
humpPath.addLine(to: CGPoint(x: humpX, y: humpY + hR))
humpPath.addArc(center: CGPoint(x: humpX + hR, y: humpY + hR), radius: hR,
    startAngle: .pi, endAngle: .pi * 1.5, clockwise: false)
humpPath.addLine(to: CGPoint(x: humpX + humpW - hR, y: humpY))
humpPath.addArc(center: CGPoint(x: humpX + humpW - hR, y: humpY + hR), radius: hR,
    startAngle: .pi * 1.5, endAngle: 0, clockwise: false)
humpPath.addLine(to: CGPoint(x: humpX + humpW, y: bodyY + 6))
humpPath.closeSubpath()

let humpColors = [
    CGColor(red: 0.34, green: 0.34, blue: 0.37, alpha: 1),
    CGColor(red: 0.18, green: 0.18, blue: 0.20, alpha: 1),
] as CFArray
let humpGrad = CGGradient(colorsSpace: cs, colors: humpColors, locations: nil)!
ctx.saveGState()
ctx.addPath(humpPath)
ctx.clip()
ctx.drawLinearGradient(humpGrad,
    start: CGPoint(x: cx, y: humpY),
    end:   CGPoint(x: cx, y: bodyY + 6), options: [])
ctx.restoreGState()

// Borde del pentaprisma
ctx.addPath(humpPath)
ctx.setStrokeColor(CGColor(red: 0.60, green: 0.60, blue: 0.65, alpha: 0.45))
ctx.setLineWidth(2.5)
ctx.strokePath()

// MARK: - Botón disparador (rojo, esquina superior derecha del cuerpo)

let shutX: CGFloat = bodyX + bodyW - 108
let shutY: CGFloat = bodyY - 18
let shutR: CGFloat = 30

// Base metálica del disparador
ctx.setFillColor(CGColor(red: 0.25, green: 0.25, blue: 0.28, alpha: 1))
ctx.fillEllipse(in: CGRect(x: shutX - shutR - 6, y: shutY - 10, width: (shutR + 6) * 2, height: shutR * 1.5))

// Botón rojo
let redColors = [
    CGColor(red: 0.95, green: 0.22, blue: 0.18, alpha: 1),
    CGColor(red: 0.65, green: 0.06, blue: 0.05, alpha: 1),
] as CFArray
fillRadialInCircle(cx: shutX, cy: shutY, r: shutR,
    colors: redColors as CFArray,
    innerCX: shutX - 8, innerCY: shutY - 8)

// Brillo del botón
ctx.setFillColor(CGColor(red: 1, green: 0.65, blue: 0.65, alpha: 0.40))
ctx.fillEllipse(in: CGRect(x: shutX - 12, y: shutY - shutR + 6, width: 20, height: 11))

// MARK: - Ventana del flash / indicador LED (izquierda del cuerpo)

let flashRect = CGRect(x: bodyX + 32, y: bodyY + 28, width: 58, height: 22)
let flashColors = [
    CGColor(red: 0.85, green: 0.90, blue: 0.55, alpha: 1),
    CGColor(red: 0.65, green: 0.72, blue: 0.28, alpha: 1),
] as CFArray
fillGradientInRect(flashRect, radius: 6, colors: flashColors as CFArray,
    start: CGPoint(x: flashRect.midX, y: flashRect.minY),
    end:   CGPoint(x: flashRect.midX, y: flashRect.maxY))

// MARK: - Objetivo (lente principal)

let lensCX: CGFloat = cx         // centrado en el cuerpo
let lensCY: CGFloat = bodyCY + 15

// Radio exterior del aro del objetivo
let lensOuterR: CGFloat = 172

// --- Sombra de la lente ---
ctx.setFillColor(CGColor(red: 0, green: 0, blue: 0, alpha: 0.40))
ctx.fillEllipse(in: CGRect(x: lensCX - lensOuterR + 8, y: lensCY - lensOuterR + 12,
    width: lensOuterR * 2, height: lensOuterR * 2))

// --- Aro exterior plateado (bisel del objetivo) ---
let barrelColors = [
    CGColor(red: 0.75, green: 0.75, blue: 0.80, alpha: 1),  // plata clara arriba
    CGColor(red: 0.28, green: 0.28, blue: 0.32, alpha: 1),  // gris oscuro abajo
] as CFArray
fillRadialInCircle(cx: lensCX, cy: lensCY, r: lensOuterR,
    colors: barrelColors as CFArray,
    innerCX: lensCX - lensOuterR * 0.28, innerCY: lensCY - lensOuterR * 0.28)

// --- Aro interior oscuro (separación) ---
let sep1R: CGFloat = lensOuterR - 18
ctx.setFillColor(CGColor(red: 0.07, green: 0.07, blue: 0.09, alpha: 1))
ctx.fillEllipse(in: CGRect(x: lensCX - sep1R, y: lensCY - sep1R, width: sep1R * 2, height: sep1R * 2))

// --- Segundo aro plateado (aro interior del barrel) ---
let ring2R: CGFloat = sep1R - 4
let ring2Colors = [
    CGColor(red: 0.65, green: 0.65, blue: 0.70, alpha: 1),
    CGColor(red: 0.32, green: 0.32, blue: 0.36, alpha: 1),
] as CFArray
fillRadialInCircle(cx: lensCX, cy: lensCY, r: ring2R,
    colors: ring2Colors as CFArray,
    innerCX: lensCX - ring2R * 0.3, innerCY: lensCY - ring2R * 0.3)

// --- Cristal de la lente (vidrio óptico azul profundo con coating) ---
let glassR: CGFloat = ring2R - 10
let glassColors = [
    CGColor(red: 0.08, green: 0.14, blue: 0.38, alpha: 1),  // azul índigo profundo
    CGColor(red: 0.02, green: 0.04, blue: 0.14, alpha: 1),  // casi negro azulado
] as CFArray
fillRadialInCircle(cx: lensCX, cy: lensCY, r: glassR,
    colors: glassColors as CFArray,
    innerCX: lensCX - glassR * 0.2, innerCY: lensCY - glassR * 0.2)

// Tinte azul-morado del coating antirreflejo (borde del cristal)
ctx.setStrokeColor(CGColor(red: 0.35, green: 0.30, blue: 0.75, alpha: 0.55))
ctx.setLineWidth(4)
ctx.strokeEllipse(in: CGRect(x: lensCX - glassR, y: lensCY - glassR, width: glassR * 2, height: glassR * 2))

// --- Anillo interior del cristal ---
let innerR: CGFloat = glassR - 22
ctx.setStrokeColor(CGColor(red: 0.45, green: 0.45, blue: 0.55, alpha: 0.35))
ctx.setLineWidth(2)
ctx.strokeEllipse(in: CGRect(x: lensCX - innerR, y: lensCY - innerR, width: innerR * 2, height: innerR * 2))

// --- Reflejo de arco (coating violeta) en parte superior-izquierda del cristal ---
ctx.saveGState()
let arcPath = CGMutablePath()
arcPath.addArc(center: CGPoint(x: lensCX, y: lensCY), radius: glassR - 26,
    startAngle: .pi * 1.05, endAngle: .pi * 1.65, clockwise: false)
arcPath.addArc(center: CGPoint(x: lensCX, y: lensCY), radius: glassR - 50,
    startAngle: .pi * 1.65, endAngle: .pi * 1.05, clockwise: true)
arcPath.closeSubpath()
ctx.addPath(arcPath)
ctx.setFillColor(CGColor(red: 0.55, green: 0.40, blue: 0.90, alpha: 0.30))
ctx.fillPath()
ctx.restoreGState()

// --- Brillo especular grande (reflejo de luz superior izquierda) ---
let specCX = lensCX - glassR * 0.42
let specCY = lensCY - glassR * 0.44
let specR: CGFloat = 38
let specColors = [
    CGColor(red: 1, green: 1, blue: 1, alpha: 0.60),
    CGColor(red: 1, green: 1, blue: 1, alpha: 0.00),
] as CFArray
fillRadialInCircle(cx: specCX, cy: specCY, r: specR,
    colors: specColors as CFArray,
    innerCX: specCX, innerCY: specCY)

// Brillo secundario (más pequeño, inferior derecha — reflejo cruzado)
let spec2CX = lensCX + glassR * 0.38
let spec2CY = lensCY + glassR * 0.35
let spec2R: CGFloat = 14
let spec2Colors = [
    CGColor(red: 0.70, green: 0.80, blue: 1.00, alpha: 0.45),
    CGColor(red: 0.70, green: 0.80, blue: 1.00, alpha: 0.00),
] as CFArray
fillRadialInCircle(cx: spec2CX, cy: spec2CY, r: spec2R,
    colors: spec2Colors as CFArray,
    innerCX: spec2CX, innerCY: spec2CY)

// MARK: - Franja de agarre de cuero (grip, izquierda del cuerpo)

let gripRect = CGRect(x: bodyX + 1, y: bodyY + 1, width: 64, height: bodyH - 2)
let gripPath = CGMutablePath()
// Solo esquinas izquierdas redondeadas
gripPath.move(to: CGPoint(x: bodyX + bodyR, y: bodyY + 1))
gripPath.addLine(to: CGPoint(x: bodyX + 64, y: bodyY + 1))
gripPath.addLine(to: CGPoint(x: bodyX + 64, y: bodyY + bodyH - 1))
gripPath.addLine(to: CGPoint(x: bodyX + bodyR, y: bodyY + bodyH - 1))
gripPath.addArc(center: CGPoint(x: bodyX + bodyR, y: bodyY + bodyH - bodyR), radius: bodyR - 1,
    startAngle: .pi / 2, endAngle: .pi, clockwise: false)
gripPath.addLine(to: CGPoint(x: bodyX + 1, y: bodyY + bodyR))
gripPath.addArc(center: CGPoint(x: bodyX + bodyR, y: bodyY + bodyR), radius: bodyR - 1,
    startAngle: .pi, endAngle: .pi * 1.5, clockwise: false)
gripPath.closeSubpath()

let gripColors = [
    CGColor(red: 0.12, green: 0.12, blue: 0.13, alpha: 1),
    CGColor(red: 0.09, green: 0.09, blue: 0.10, alpha: 1),
] as CFArray
let gripGrad = CGGradient(colorsSpace: cs, colors: gripColors as CFArray, locations: nil)!
ctx.saveGState()
ctx.addPath(gripPath)
ctx.clip()
ctx.drawLinearGradient(gripGrad,
    start: CGPoint(x: bodyX, y: bodyCY),
    end:   CGPoint(x: bodyX + 64, y: bodyCY), options: [])
// Textura punteada del cuero (líneas finas diagonales)
ctx.setStrokeColor(CGColor(red: 1, green: 1, blue: 1, alpha: 0.04))
ctx.setLineWidth(1)
var dy: CGFloat = bodyY + 8
while dy < bodyY + bodyH {
    ctx.move(to: CGPoint(x: bodyX + 2, y: dy))
    ctx.addLine(to: CGPoint(x: bodyX + 62, y: dy))
    ctx.strokePath()
    dy += 7
}
ctx.restoreGState()

// MARK: - Guardado del PNG

guard let image = ctx.makeImage() else { fatalError("makeImage falló") }

let outputPath = "FotoMaterial/Assets.xcassets/AppIcon.appiconset/AppIcon.png"
let outputURL  = URL(fileURLWithPath: outputPath)

guard let dest = CGImageDestinationCreateWithURL(outputURL as CFURL, "public.png" as CFString, 1, nil) else {
    fatalError("No se puede crear destino de imagen en \(outputPath)")
}
CGImageDestinationAddImage(dest, image, nil)
guard CGImageDestinationFinalize(dest) else { fatalError("CGImageDestinationFinalize falló") }
print("✓ Icono guardado → \(outputPath)")
