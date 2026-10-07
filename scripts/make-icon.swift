import AppKit
let directory = CommandLine.arguments[1]
for size in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let pixels = size * scale
        let image = NSImage(size: NSSize(width: pixels, height: pixels))
        image.lockFocus()
        let p = CGFloat(pixels)
        NSColor(calibratedRed: 0.20, green: 0.36, blue: 0.30, alpha: 1).setFill()
        NSBezierPath(roundedRect: NSRect(x: p * 0.05, y: p * 0.05, width: p * 0.9, height: p * 0.9), xRadius: p * 0.20, yRadius: p * 0.20).fill()
        NSColor(calibratedRed: 0.96, green: 0.96, blue: 0.90, alpha: 1).setStroke()
        for (y, width) in [(0.69, 0.46), (0.52, 0.34), (0.35, 0.20)] {
            let path = NSBezierPath(); path.lineWidth = p * 0.055; path.lineCapStyle = .round
            path.move(to: NSPoint(x: p * 0.27, y: p * y)); path.line(to: NSPoint(x: p * (0.27 + width), y: p * y)); path.stroke()
        }
        let tick = NSBezierPath(); tick.lineWidth = p * 0.055; tick.lineCapStyle = .round; tick.lineJoinStyle = .round
        tick.move(to: NSPoint(x: p * 0.56, y: p * 0.35)); tick.line(to: NSPoint(x: p * 0.64, y: p * 0.27)); tick.line(to: NSPoint(x: p * 0.79, y: p * 0.45)); tick.stroke()
        image.unlockFocus()
        let bitmap = NSBitmapImageRep(data: image.tiffRepresentation!)!
        let filename = "icon_\(size)x\(size)\(scale == 2 ? "@2x" : "").png"
        try bitmap.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: directory).appendingPathComponent(filename))
    }
}
