#!/usr/bin/env swift
import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

// Turn the pen-and-ink redwood into a theme-tintable app icon.
// Usage: generate-tree-icon.swift <mode light|dark|tinted> <r> <g> <b> <src> <out>
let args = Array(CommandLine.arguments.dropFirst())
guard args.count >= 6 else { fatalError("need: mode r g b src out") }
let mode = args[0]
let inkR = Double(args[1])!, inkG = Double(args[2])!, inkB = Double(args[3])!
let srcPath = args[4], outPath = args[5]

// Grounds match Paper.* (cream / designer-black).
let cream = (0.965, 0.961, 0.945)
let black = (0.086, 0.078, 0.068)

// Resolve ink + ground per appearance.
let ink: (Double, Double, Double)
let ground: (Double, Double, Double)
let fillGround: Bool
switch mode {
case "dark":     ink = (inkR, inkG, inkB); ground = black;      fillGround = true   // accent on black
case "tinted":   ink = (1, 1, 1);          ground = (0, 0, 0);  fillGround = true   // grayscale; iOS tints
case "template": ink = (0, 0, 0);          ground = (0, 0, 0);  fillGround = false  // transparent; in-app tint
default:         ink = (inkR, inkG, inkB); ground = cream;      fillGround = true   // accent on cream
}

// --- Load source pixels ---
guard let src = CGImageSourceCreateWithURL(URL(fileURLWithPath: srcPath) as CFURL, nil),
      let img = CGImageSourceCreateImageAtIndex(src, 0, nil) else { fatalError("load") }
let w = img.width, h = img.height
var px = [UInt8](repeating: 0, count: w * h * 4)
let cs = CGColorSpaceCreateDeviceRGB()
guard let rctx = CGContext(data: &px, width: w, height: h, bitsPerComponent: 8,
                           bytesPerRow: w * 4, space: cs,
                           bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
else { fatalError("read ctx") }
rctx.draw(img, in: CGRect(x: 0, y: 0, width: w, height: h))

// --- Ink coverage (dark → opaque) + bounding box, with tint applied ---
func coverage(_ i: Int) -> Double {
    let a = Double(px[i + 3]) / 255
    if a < 0.01 { return 0 }                       // transparent source pixel
    let r = Double(px[i]) / 255, g = Double(px[i + 1]) / 255, b = Double(px[i + 2]) / 255
    let lum = 0.299 * r + 0.587 * g + 0.114 * b
    var c = (1.0 - lum) * a                         // dark ink → high coverage
    c = min(1, max(0, (c - 0.12) / 0.88))           // drop near-white background, keep strokes
    return c
}

var minX = w, minY = h, maxX = 0, maxY = 0
for y in 0..<h { for x in 0..<w {
    if coverage((y * w + x) * 4) > 0.15 {
        if x < minX { minX = x }; if x > maxX { maxX = x }
        if y < minY { minY = y }; if y > maxY { maxY = y }
    }
}}
guard maxX > minX, maxY > minY else { fatalError("no ink found") }
let bw = maxX - minX + 1, bh = maxY - minY + 1

// Tinted, cropped tree as premultiplied RGBA.
var tree = [UInt8](repeating: 0, count: bw * bh * 4)
for y in 0..<bh { for x in 0..<bw {
    let c = coverage(((y + minY) * w + (x + minX)) * 4)
    let o = (y * bw + x) * 4
    tree[o]     = UInt8(ink.0 * c * 255)
    tree[o + 1] = UInt8(ink.1 * c * 255)
    tree[o + 2] = UInt8(ink.2 * c * 255)
    tree[o + 3] = UInt8(c * 255)
}}
guard let treeCtx = CGContext(data: &tree, width: bw, height: bh, bitsPerComponent: 8,
                              bytesPerRow: bw * 4, space: cs,
                              bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue),
      let treeImg = treeCtx.makeImage() else { fatalError("tree ctx") }

// --- Compose the 1024 icon ---
let size = 1024
guard let ctx = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8,
                          bytesPerRow: 0, space: cs,
                          bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
else { fatalError("icon ctx") }
ctx.interpolationQuality = .high
if fillGround {
    ctx.setFillColor(CGColor(red: ground.0, green: ground.1, blue: ground.2, alpha: 1))
    ctx.fill(CGRect(x: 0, y: 0, width: size, height: size))
}

// Fit the tree by height with padding; center.
let padV = Double(size) * 0.07
let drawH = Double(size) - padV * 2
let scale = drawH / Double(bh)
let drawW = Double(bw) * scale
let ox = (Double(size) - drawW) / 2
let oy = (Double(size) - drawH) / 2
// CGImage draws with y-down origin flipped by CG; draw into rect directly.
ctx.draw(treeImg, in: CGRect(x: ox, y: oy, width: drawW, height: drawH))

guard let out = ctx.makeImage() else { fatalError("out") }
guard let dest = CGImageDestinationCreateWithURL(URL(fileURLWithPath: outPath) as CFURL,
                                                 UTType.png.identifier as CFString, 1, nil)
else { fatalError("dest") }
CGImageDestinationAddImage(dest, out, nil)
guard CGImageDestinationFinalize(dest) else { fatalError("finalize") }
print("wrote \(outPath)")
