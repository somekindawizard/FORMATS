# Press.

**An image converter for iPhone — paper-and-ink calm, state-of-the-art under the hood.**

Press turns any image you have into the format you need. It is built for
iPhone 17 / 17 Pro on iOS 27, runs entirely on-device, and is designed to feel
like a well-set page: warm cream stock, ink-black serif type, hairline rules,
and a single restrained sienna accent.

---

## What it does

- **Convert** one image or a batch into a chosen format.
- **Quality, resolution, metadata and HDR** controls per run.
- **Remove background** — lifts the subject to a transparent PNG, fully on-device.
- **Share or save** results to Files or Photos.

Nothing leaves the phone. There is no network code.

## Output formats

Press asks the operating system at launch which formats it can actually
*encode* (`CGImageDestinationCopyTypeIdentifiers`) and offers exactly those,
plus PDF. On current iOS that means **HEIC, HEIF, AVIF, JPEG, PNG, TIFF, GIF,
BMP and PDF**. Because the list is resolved at runtime, any encoder a future
iOS adds (e.g. WebP or JPEG XL writing) appears automatically — no update
needed.

It can *open* far more than it writes, including **WebP, JPEG XL and most
camera RAW** files, since Apple's ImageIO decodes those today.

## The 2026 state of the art, and how Press uses it

Research that shaped the design (sources below):

- **AVIF is the best general-purpose format in 2026** — roughly 50–60% smaller
  than JPEG at equal quality, with HDR, wide gamut and alpha. Press defaults new
  conversions to AVIF when the device can write it.
- **JPEG XL is the connoisseur's choice** for stills (best high-quality
  compression, preserves grain/texture, lossless transcode from legacy JPEG).
  Apple decodes it; Press will surface JXL *encoding* the moment iOS exposes it.
- **HEIC remains Apple's efficient default** and the right pick for photos that
  live on-device.
- **HDR via gain maps (ISO 21496-1)** is the modern way to carry high dynamic
  range across JPEG / HEIC / AVIF / JXL. Press preserves the gain map on
  full-fidelity conversions (`kCGImageDestinationPreserveGainMap`) when the
  source has one and the target supports it.
- **Wide colour (Display P3)** and EXIF orientation are preserved; orientation
  is baked into pixels whenever the image is resized or stripped, so files never
  appear rotated.
- **On-device subject lifting** uses Vision's foreground instance mask
  (`VNGenerateForegroundInstanceMaskRequest`) — the same class of model behind
  system "lift subject" features — to produce clean transparent cut-outs.

### Conversion engine notes

- Raster conversion is built on **ImageIO**; PDF on **Core Graphics**.
- **Full-fidelity path** (keep metadata, no resize): the image is copied
  straight through with `CGImageDestinationAddImageFromSource`, preserving
  metadata, colour profile and the HDR gain map.
- **Processed path** (resize or privacy-strip): pixels are re-decoded with
  orientation applied, and a properties dictionary we fully control is attached
  — dropping EXIF/GPS/IPTC when "Keep metadata" is off.
- Quality is exposed only for lossy targets via
  `kCGImageDestinationLossyCompressionQuality`.

## Project layout

```
Press.xcodeproj          – Xcode 16+ project (synchronized file groups)
Press/
  PressApp.swift         – app entry + navigation
  Theme/                 – colours, type scale, paper background, components
  Models/                – ImageFormat, ConversionSettings, SourceImage, results
  Engine/                – FormatCatalog, ConversionEngine, BackgroundRemover, importer
  Store/AppModel.swift   – observable app state and run loop
  Views/                 – Home, Convert, Results, format picker, helpers
  Assets.xcassets/       – app icon + accent colour
```

## Building

1. Open `Press.xcodeproj` in Xcode (16 or newer).
2. Select your iPhone (or a simulator) and set your signing team on the **Press**
   target (Signing & Capabilities). The bundle id is `studio.formats.Press` —
   change it to your own if you like.
3. Run.

Deployment target is iOS 18.0 so it builds on shipping Xcode and runs great on
iPhone 17 / iOS 27. UI is locked to light mode by design.

## Possible next steps

- Bundle `libwebp` / a JPEG XL coder via Swift Package Manager to *write* WebP
  and JXL even before iOS exposes native encoders.
- Multi-image "combine into one PDF" mode.
- ML super-resolution upscaling.

---

### Sources

- ISO 21496-1:2025, *Gain map metadata for image conversion* — https://www.iso.org/standard/86775.html
- "AVIF vs WebP vs HEIC vs JPEG XL: which to use in 2026?" — https://dev.to/serhii_kalyna_730b636889c/avif-vs-webp-vs-heic-vs-jpeg-xl-which-image-format-should-you-use-in-2026-4gn0
- AVIF in 2026 complete guide — https://kitmul.com/en/blog/avif-image-format-complete-guide
- Guide to HDR image formats (gain maps) — https://www.mark-heath.com/hdr-image-formats/
- Which file formats to use for photography — https://gregbenzphotography.com/other/which-file-formats-to-use-for-photography/
- Apple, `CGImageDestinationCopyTypeIdentifiers()` — https://developer.apple.com/documentation/imageio/cgimagedestinationcopytypeidentifiers()
- Apple, *Explore media formats for the web* (WWDC23) — https://developer.apple.com/videos/play/wwdc2023/10122/
