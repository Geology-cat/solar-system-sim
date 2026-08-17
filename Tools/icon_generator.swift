import Cocoa

let width: CGFloat = 1024
let height: CGFloat = 1024
let size = CGSize(width: width, height: height)

let image = NSImage(size: size)
image.lockFocus()

// 背景
NSColor(calibratedRed: 0.05, green: 0.05, blue: 0.1, alpha: 1.0).set()
let rect = NSRect(origin: .zero, size: size)
NSBezierPath(roundedRect: rect, xRadius: 200, yRadius: 200).fill()

// 軌道の描画
let center = NSPoint(x: width/2, y: height/2)
NSColor(white: 1.0, alpha: 0.2).setStroke()
for radius in [180, 300, 420] {
    let path = NSBezierPath(ovalIn: NSRect(x: center.x - CGFloat(radius), y: center.y - CGFloat(radius), width: CGFloat(radius*2), height: CGFloat(radius*2)))
    path.lineWidth = 6
    path.stroke()
}

// 太陽
NSColor(calibratedRed: 1.0, green: 0.8, blue: 0.0, alpha: 1.0).set()
NSBezierPath(ovalIn: NSRect(x: center.x - 70, y: center.y - 70, width: 140, height: 140)).fill()

// 惑星
NSColor.systemBlue.set()
NSBezierPath(ovalIn: NSRect(x: center.x + 300 - 30, y: center.y - 30, width: 60, height: 60)).fill()
NSColor.systemRed.set()
NSBezierPath(ovalIn: NSRect(x: center.x - 30, y: center.y + 180 - 20, width: 40, height: 40)).fill()
NSColor.systemOrange.set()
NSBezierPath(ovalIn: NSRect(x: center.x - 420 + 25, y: center.y - 25, width: 50, height: 50)).fill()

image.unlockFocus()

if let tiff = image.tiffRepresentation, let bitmap = NSBitmapImageRep(data: tiff), let png = bitmap.representation(using: .png, properties: [:]) {
    try? png.write(to: URL(fileURLWithPath: "icon.png"))
}
