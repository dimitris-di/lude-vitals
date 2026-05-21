#!/bin/bash
# Regenerates Resources/AppIcon.icns from original AppKit vector artwork.
set -e

cd "$(dirname "$0")/.."

ICONSET=AppIcon.iconset
rm -rf "$ICONSET"
mkdir -p "$ICONSET"
mkdir -p Resources

# Render 1024 PNG via Swift drawing code.
swift - <<'SWIFT'
import AppKit

let size = CGSize(width: 1024, height: 1024)
let img = NSImage(size: size, flipped: false) { rect in
    let background = NSBezierPath(roundedRect: rect, xRadius: 220, yRadius: 220)
    NSGradient(colors: [
        NSColor(red: 0.02, green: 0.42, blue: 0.54, alpha: 1),
        NSColor(red: 0.10, green: 0.20, blue: 0.62, alpha: 1),
        NSColor(red: 0.52, green: 0.18, blue: 0.38, alpha: 1)
    ])!
    .draw(in: background, angle: 135)

    NSColor.white.withAlphaComponent(0.12).setFill()
    NSBezierPath(roundedRect: rect.insetBy(dx: 54, dy: 54), xRadius: 174, yRadius: 174).fill()

    NSColor(red: 0.03, green: 0.08, blue: 0.18, alpha: 0.18).setFill()
    NSBezierPath(roundedRect: CGRect(x: 132, y: 304, width: 760, height: 416), xRadius: 104, yRadius: 104).fill()

    let glow = NSShadow()
    glow.shadowBlurRadius = 34
    glow.shadowOffset = .zero
    glow.shadowColor = NSColor(red: 0.35, green: 0.95, blue: 0.86, alpha: 0.55)

    let pulse = NSBezierPath()
    pulse.move(to: CGPoint(x: 150, y: 512))
    pulse.line(to: CGPoint(x: 250, y: 512))
    pulse.line(to: CGPoint(x: 304, y: 414))
    pulse.line(to: CGPoint(x: 366, y: 628))
    pulse.line(to: CGPoint(x: 426, y: 512))
    pulse.line(to: CGPoint(x: 504, y: 512))
    pulse.line(to: CGPoint(x: 556, y: 336))
    pulse.line(to: CGPoint(x: 632, y: 704))
    pulse.line(to: CGPoint(x: 704, y: 512))
    pulse.line(to: CGPoint(x: 874, y: 512))
    pulse.lineCapStyle = .round
    pulse.lineJoinStyle = .round

    NSGraphicsContext.saveGraphicsState()
    glow.set()
    pulse.lineWidth = 74
    NSColor(red: 0.23, green: 0.95, blue: 0.84, alpha: 0.60).setStroke()
    pulse.stroke()
    NSGraphicsContext.restoreGraphicsState()

    pulse.lineWidth = 50
    NSColor.white.setStroke()
    pulse.stroke()

    pulse.lineWidth = 18
    NSColor(red: 0.39, green: 0.98, blue: 0.91, alpha: 1).setStroke()
    pulse.stroke()

    NSColor.white.withAlphaComponent(0.96).setFill()
    for point in [CGPoint(x: 150, y: 512), CGPoint(x: 874, y: 512)] {
        NSBezierPath(ovalIn: CGRect(x: point.x - 28, y: point.y - 28, width: 56, height: 56)).fill()
    }

    NSColor.white.withAlphaComponent(0.20).setFill()
    NSBezierPath(roundedRect: CGRect(x: 186, y: 770, width: 220, height: 26), xRadius: 13, yRadius: 13).fill()
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
