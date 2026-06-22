#!/usr/bin/env swift
import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

// Palette (matches Paper.* RGB)
let paper  = CGColor(red: 0.965, green: 0.961, blue: 0.945, alpha: 1)
let accent = CGColor(red: 0.604, green: 0.290, blue: 0.176, alpha: 1)

let size = 1024
let cs = CGColorSpaceCreateDeviceRGB()
guard let ctx = CGContext(
    data: nil,
    width: size, height: size,
    bitsPerComponent: 8, bytesPerRow: 0,
    space: cs,
    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
) else { fatalError("ctx") }

// Paper background — fill the whole bitmap.
ctx.setFillColor(paper)
ctx.fill(CGRect(x: 0, y: 0, width: size, height: size))

// Splitmix64 inline (same constants as the app)
var state: UInt64 = 4_211 &+ 0x9E3779B97F4A7C15
func rand() -> Double {
    state &+= 0x9E3779B97F4A7C15
    var z = state
    z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
    z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
    return Double(z ^ (z >> 31)) / Double(UInt64.max)
}

// Run Barnsley — points in math coords (base at origin, grows +y "up").
let count = 120_000
var x = 0.0, y = 0.0
var pts = [(Double, Double)](); pts.reserveCapacity(count)
for _ in 0..<count {
    let r = rand()
    let (nx, ny): (Double, Double)
    switch r {
    case ..<0.01: nx = 0;                     ny = 0.16 * y
    case ..<0.86: nx = 0.85 * x + 0.04 * y;   ny = -0.04 * x + 0.85 * y + 1.6
    case ..<0.93: nx = 0.20 * x - 0.26 * y;   ny =  0.23 * x + 0.22 * y + 1.6
    default:      nx = -0.15 * x + 0.28 * y;  ny =  0.26 * x + 0.24 * y + 0.44
    }
    x = nx; y = ny; pts.append((x, y))
}

// Rotate the whole frond for a diagonal composition (base lower-left, tip upper-right).
let angle = -Double.pi / 6   // -30°
let ca = cos(angle), sa = sin(angle)
var rpts = [(Double, Double)](); rpts.reserveCapacity(pts.count)
var mnx = Double.infinity, mxx = -Double.infinity
var mny = Double.infinity, mxy = -Double.infinity
for (px, py) in pts {
    let rx = px * ca - py * sa
    let ry = px * sa + py * ca
    rpts.append((rx, ry))
    if rx < mnx { mnx = rx }
    if rx > mxx { mxx = rx }
    if ry < mny { mny = ry }
    if ry > mxy { mxy = ry }
}

// Fit the rotated bounding box into a centered, padded square.
// CGContext is y-up, so larger ry maps higher on the image → fern points up.
let pad = Double(size) * 0.12
let drawW = Double(size) - pad * 2
let drawH = Double(size) - pad * 2
let spanX = max(0.001, mxx - mnx)
let spanY = max(0.001, mxy - mny)
let scale = min(drawW / spanX, drawH / spanY)
let offX = (Double(size) - spanX * scale) / 2
let offY = (Double(size) - spanY * scale) / 2

ctx.setFillColor(accent.copy(alpha: 0.62) ?? accent)
let dot = 2.6
for (rx, ry) in rpts {
    let sx = offX + (rx - mnx) * scale - dot / 2
    let sy = offY + (ry - mny) * scale - dot / 2
    ctx.fillEllipse(in: CGRect(x: sx, y: sy, width: dot, height: dot))
}

guard let image = ctx.makeImage() else { fatalError("image") }

let outURL = URL(fileURLWithPath: CommandLine.arguments.dropFirst().first
                 ?? "Fern/Assets.xcassets/AppIcon.appiconset/icon-1024.png")
guard let dest = CGImageDestinationCreateWithURL(
    outURL as CFURL, UTType.png.identifier as CFString, 1, nil
) else { fatalError("dest") }
CGImageDestinationAddImage(dest, image, nil)
guard CGImageDestinationFinalize(dest) else { fatalError("finalize") }

print("wrote \(outURL.path)")
