import AppKit
import Foundation

guard CommandLine.arguments.count == 2 else {
    fputs("usage: generate-app-icon.swift OUTPUT.icns\n", stderr)
    exit(2)
}

let outputURL = URL(fileURLWithPath: CommandLine.arguments[1])
let fileManager = FileManager.default
let iconsetURL = fileManager.temporaryDirectory
    .appendingPathComponent("RStatus-\(UUID().uuidString).iconset", isDirectory: true)
try fileManager.createDirectory(at: iconsetURL, withIntermediateDirectories: true)
defer { try? fileManager.removeItem(at: iconsetURL) }

func pngData(pixelSize: Int) -> Data {
    let bitmap = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: pixelSize,
        pixelsHigh: pixelSize,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    )!
    bitmap.size = NSSize(width: pixelSize, height: pixelSize)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
    let context = NSGraphicsContext.current!.cgContext
    context.setShouldAntialias(true)
    context.clear(CGRect(x: 0, y: 0, width: pixelSize, height: pixelSize))

    let size = CGFloat(pixelSize)
    let tile = CGRect(x: size * 0.07, y: size * 0.07, width: size * 0.86, height: size * 0.86)
    let blue = NSColor(calibratedRed: 0.07, green: 0.39, blue: 0.92, alpha: 1)
    context.setFillColor(blue.cgColor)
    context.addPath(CGPath(roundedRect: tile, cornerWidth: size * 0.20,
                           cornerHeight: size * 0.20, transform: nil))
    context.fillPath()

    let cat = tile.insetBy(dx: size * 0.16, dy: size * 0.15)
    func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
        CGPoint(x: cat.minX + cat.width * x, y: cat.minY + cat.height * y)
    }
    let head = CGMutablePath()
    head.move(to: point(0.18, 0.23))
    head.addCurve(to: point(0.15, 0.58), control1: point(0.10, 0.34), control2: point(0.11, 0.48))
    head.addLine(to: point(0.12, 0.91))
    head.addLine(to: point(0.38, 0.72))
    head.addCurve(to: point(0.62, 0.72), control1: point(0.45, 0.76), control2: point(0.55, 0.76))
    head.addLine(to: point(0.88, 0.91))
    head.addLine(to: point(0.85, 0.58))
    head.addCurve(to: point(0.82, 0.23), control1: point(0.89, 0.48), control2: point(0.90, 0.34))
    head.addCurve(to: point(0.18, 0.23), control1: point(0.68, 0.05), control2: point(0.32, 0.05))
    head.closeSubpath()
    context.setFillColor(NSColor(calibratedRed: 0.10, green: 0.14, blue: 0.20, alpha: 1).cgColor)
    context.addPath(head)
    context.fillPath()

    let mark = CGMutablePath()
    mark.move(to: point(0.40, 0.73))
    mark.addLine(to: point(0.60, 0.73))
    mark.addLine(to: point(0.545, 0.61))
    mark.addLine(to: point(0.50, 0.67))
    mark.addLine(to: point(0.455, 0.61))
    mark.closeSubpath()
    context.setFillColor(NSColor(calibratedWhite: 0.74, alpha: 1).cgColor)
    context.addPath(mark)
    context.fillPath()

    context.setFillColor(NSColor(calibratedRed: 0.20, green: 0.72, blue: 1.00, alpha: 1).cgColor)
    for x in [0.35, 0.65] as [CGFloat] {
        let center = point(x, 0.43)
        let diameter = cat.width * 0.14
        context.fillEllipse(in: CGRect(x: center.x - diameter / 2, y: center.y - diameter / 2,
                                       width: diameter, height: diameter))
    }
    NSGraphicsContext.restoreGraphicsState()
    return bitmap.representation(using: .png, properties: [:])!
}

let files: [(String, Int)] = [
    ("icon_16x16.png", 16), ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32), ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128), ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256), ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512), ("icon_512x512@2x.png", 1024)
]
for (name, size) in files {
    try pngData(pixelSize: size).write(to: iconsetURL.appendingPathComponent(name))
}

let iconutil = Process()
iconutil.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
iconutil.arguments = ["-c", "icns", iconsetURL.path, "-o", outputURL.path]
try iconutil.run()
iconutil.waitUntilExit()
guard iconutil.terminationStatus == 0 else { exit(iconutil.terminationStatus) }
