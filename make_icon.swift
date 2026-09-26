import Cocoa

let size = CGSize(width: 1024, height: 1024)
let image = NSImage(size: size)
image.lockFocus()

if let symbol = NSImage(systemSymbolName: "shippingbox.fill", accessibilityDescription: nil) {
    // AppTheme.accent color is approx (148/255.0, 80/255.0, 246/255.0) wait let me check the actual color.
    let tint = NSColor.systemPurple
    let config = NSImage.SymbolConfiguration(pointSize: 800, weight: .regular)
        .applying(.init(paletteColors: [tint]))
    if let tintedSymbol = symbol.withSymbolConfiguration(config) {
        let drawRect = NSRect(x: 112, y: 112, width: 800, height: 800)
        tintedSymbol.draw(in: drawRect)
    }
}

image.unlockFocus()
if let tiff = image.tiffRepresentation,
   let bitmap = NSBitmapImageRep(data: tiff),
   let png = bitmap.representation(using: .png, properties: [:]) {
    try? png.write(to: URL(fileURLWithPath: "icon_1024x1024.png"))
}
