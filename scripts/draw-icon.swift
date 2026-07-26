// Renders a 1024×1024 app icon PNG. Usage: swift scripts/draw-icon.swift out.png
import AppKit

let outputPath = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "icon.png"
let side: CGFloat = 1024

let image = NSImage(size: NSSize(width: side, height: side))
image.lockFocus()

// macOS icon grid: the artwork occupies the middle ~82% of the canvas.
let inset = side * 0.09
let plate = NSRect(x: inset, y: inset, width: side - inset * 2, height: side - inset * 2)
let squircle = NSBezierPath(roundedRect: plate, xRadius: plate.width * 0.235, yRadius: plate.width * 0.235)
NSGradient(
    starting: NSColor(srgbRed: 0.29, green: 0.42, blue: 0.98, alpha: 1),
    ending: NSColor(srgbRed: 0.53, green: 0.24, blue: 0.87, alpha: 1)
)?.draw(in: squircle, angle: -90)

let glyphConfig = NSImage.SymbolConfiguration(pointSize: plate.width * 0.5, weight: .medium)
if let glyph = NSImage(systemSymbolName: "shippingbox.fill", accessibilityDescription: nil)?
    .withSymbolConfiguration(glyphConfig)?
    .tinted(with: .white) {
    let size = glyph.size
    let origin = NSPoint(x: plate.midX - size.width / 2, y: plate.midY - size.height / 2)
    glyph.draw(in: NSRect(origin: origin, size: size))
}

image.unlockFocus()

guard let tiff = image.tiffRepresentation,
      let bitmap = NSBitmapImageRep(data: tiff),
      let png = bitmap.representation(using: .png, properties: [:])
else {
    FileHandle.standardError.write(Data("failed to render icon\n".utf8))
    exit(1)
}
try png.write(to: URL(fileURLWithPath: outputPath))

extension NSImage {
    func tinted(with color: NSColor) -> NSImage {
        let copy = NSImage(size: size)
        copy.lockFocus()
        color.set()
        NSRect(origin: .zero, size: size).fill(using: .sourceOver)
        draw(in: NSRect(origin: .zero, size: size), from: .zero, operation: .destinationIn, fraction: 1)
        copy.unlockFocus()
        return copy
    }
}
