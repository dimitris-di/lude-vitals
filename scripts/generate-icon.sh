#!/bin/bash
# Regenerates Resources/AppIcon.icns from scratch using AppKit + iconutil.
set -e

cd "$(dirname "$0")/.."

ICONSET=AppIcon.iconset
rm -rf "$ICONSET"
mkdir -p "$ICONSET"
mkdir -p Resources

# Render 1024 PNG via Swift one-liner
swift - <<'SWIFT'
import AppKit

let size = CGSize(width: 1024, height: 1024)
let img = NSImage(size: size, flipped: false) { rect in
    let g = NSGradient(colors: [
        NSColor(red: 0.18, green: 0.55, blue: 0.95, alpha: 1),
        NSColor(red: 0.45, green: 0.30, blue: 0.95, alpha: 1)
    ])!
    let path = NSBezierPath(roundedRect: rect, xRadius: 220, yRadius: 220)
    g.draw(in: path, angle: 135)

    let cfg = NSImage.SymbolConfiguration(pointSize: 640, weight: .semibold)
    if let s = NSImage(systemSymbolName: "waveform.path.ecg", accessibilityDescription: nil)?
        .withSymbolConfiguration(cfg) {
        let tinted = NSImage(size: s.size, flipped: false) { r in
            s.draw(in: r)
            NSColor.white.set()
            r.fill(using: .sourceAtop)
            return true
        }
        let p = CGPoint(
            x: (size.width  - tinted.size.width)  / 2,
            y: (size.height - tinted.size.height) / 2
        )
        tinted.draw(at: p, from: .zero, operation: .sourceOver, fraction: 1.0)
    }
    return true
}

guard let tiff = img.tiffRepresentation,
      let rep = NSBitmapImageRep(data: tiff),
      let png = rep.representation(using: .png, properties: [:]) else {
    FileHandle.standardError.write("Failed to render PNG\n".data(using: .utf8)!)
    exit(1)
}
try png.write(to: URL(fileURLWithPath: "icon-1024.png"))
SWIFT

# Downscale to all required sizes
for sz in 16 32 64 128 256 512 1024; do
    sips -z $sz $sz icon-1024.png --out "$ICONSET/icon_${sz}x${sz}.png" > /dev/null
done

# @2x duplicates
cp "$ICONSET/icon_32x32.png"     "$ICONSET/icon_16x16@2x.png"
cp "$ICONSET/icon_64x64.png"     "$ICONSET/icon_32x32@2x.png"
cp "$ICONSET/icon_256x256.png"   "$ICONSET/icon_128x128@2x.png"
cp "$ICONSET/icon_512x512.png"   "$ICONSET/icon_256x256@2x.png"
cp "$ICONSET/icon_1024x1024.png" "$ICONSET/icon_512x512@2x.png"

# 64x64 is non-standard for icns; remove it after using for 32@2x
rm -f "$ICONSET/icon_64x64.png"
# 1024 standalone not part of icns set; keep only as 512@2x
rm -f "$ICONSET/icon_1024x1024.png"

iconutil --convert icns "$ICONSET" --output Resources/AppIcon.icns

rm -rf "$ICONSET" icon-1024.png
echo "Generated Resources/AppIcon.icns"
