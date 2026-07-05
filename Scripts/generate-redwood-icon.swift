#!/usr/bin/env swift
import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

// Mode: light (default) | dark | tinted. Usage: generate-redwood-icon.swift <mode> <outPath>
let mode = CommandLine.arguments.dropFirst().first ?? "light"

// Palette — a muted pine green sets Redwood apart from Fern's sienna fern,
// while sharing the same cream/black paper grounds.
let bg: CGColor
let treeColor: CGColor
let trunkColor: CGColor
switch mode {
case "dark":
    bg         = CGColor(red: 0.086, green: 0.078, blue: 0.068, alpha: 1)     // designer black
    treeColor  = CGColor(red: 0.965, green: 0.961, blue: 0.945, alpha: 0.80)  // cream
    trunkColor = CGColor(red: 0.965, green: 0.961, blue: 0.945, alpha: 0.55)
case "tinted":
    bg         = CGColor(red: 0, green: 0, blue: 0, alpha: 1)
    treeColor  = CGColor(red: 1, green: 1, blue: 1, alpha: 0.85)
    trunkColor = CGColor(red: 1, green: 1, blue: 1, alpha: 0.55)
default:
    bg         = CGColor(red: 0.965, green: 0.961, blue: 0.945, alpha: 1)     // cream
    treeColor  = CGColor(red: 0.208, green: 0.376, blue: 0.278, alpha: 0.92)  // muted pine
    trunkColor = CGColor(red: 0.404, green: 0.274, blue: 0.180, alpha: 0.85)  // bark brown
}

let size = 1024
let cs = CGColorSpaceCreateDeviceRGB()
guard let ctx = CGContext(
    data: nil, width: size, height: size,
    bitsPerComponent: 8, bytesPerRow: 0, space: cs,
    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
) else { fatalError("ctx") }
ctx.setShouldAntialias(true)

// Background.
ctx.setFillColor(bg)
ctx.fill(CGRect(x: 0, y: 0, width: size, height: size))

let S = Double(size)
func P(_ x: Double, _ y: Double) -> CGPoint { CGPoint(x: x * S, y: y * S) }
let cx = 0.5

// Trunk — a slim tapered bark column (y-up: origin bottom-left).
let trunkBottom = 0.075, trunkTop = 0.30
let trunkHalfB = 0.032, trunkHalfT = 0.022
let trunk = CGMutablePath()
trunk.move(to: P(cx - trunkHalfB, trunkBottom))
trunk.addLine(to: P(cx - trunkHalfT, trunkTop))
trunk.addLine(to: P(cx + trunkHalfT, trunkTop))
trunk.addLine(to: P(cx + trunkHalfB, trunkBottom))
trunk.closeSubpath()
ctx.setFillColor(trunkColor)
ctx.addPath(trunk)
ctx.fillPath()

// Canopy — stacked tiers with gently drooping (concave) sides, narrowing up.
// Each tier: base-left → quad curve to apex → quad curve to base-right.
func tier(baseY: Double, apexY: Double, half: Double) {
    let h = apexY - baseY
    let path = CGMutablePath()
    path.move(to: P(cx - half, baseY))
    path.addQuadCurve(to: P(cx, apexY),
                      control: P(cx - half * 0.34, baseY + h * 0.58))
    path.addQuadCurve(to: P(cx + half, baseY),
                      control: P(cx + half * 0.34, baseY + h * 0.58))
    path.closeSubpath()
    ctx.addPath(path)
    ctx.fillPath()
}

ctx.setFillColor(treeColor)
// bottom → top; tiers overlap so the silhouette reads continuous and tall.
tier(baseY: 0.235, apexY: 0.50, half: 0.290)
tier(baseY: 0.400, apexY: 0.645, half: 0.232)
tier(baseY: 0.545, apexY: 0.780, half: 0.175)
tier(baseY: 0.680, apexY: 0.910, half: 0.118)

guard let image = ctx.makeImage() else { fatalError("image") }
let outURL = URL(fileURLWithPath: CommandLine.arguments.dropFirst(2).first
                 ?? "Redwood/Assets.xcassets/AppIcon.appiconset/icon-1024.png")
guard let dest = CGImageDestinationCreateWithURL(
    outURL as CFURL, UTType.png.identifier as CFString, 1, nil
) else { fatalError("dest") }
CGImageDestinationAddImage(dest, image, nil)
guard CGImageDestinationFinalize(dest) else { fatalError("finalize") }
print("wrote \(outURL.path)")
