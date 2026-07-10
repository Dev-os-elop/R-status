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
    context.setFillColor(NSColor.white.cgColor)
    context.addPath(CGPath(roundedRect: tile, cornerWidth: size * 0.20,
                           cornerHeight: size * 0.20, transform: nil))
    context.fillPath()
    context.setStrokeColor(NSColor(calibratedWhite: 0.82, alpha: 1).cgColor)
    context.setLineWidth(max(1, size * 0.012))
    context.addPath(CGPath(roundedRect: tile, cornerWidth: size * 0.20,
                           cornerHeight: size * 0.20, transform: nil))
    context.strokePath()

    let blue = NSColor(calibratedRed: 0.08, green: 0.42, blue: 0.92, alpha: 1)
    let center = CGPoint(x: size / 2, y: size / 2)
    context.setStrokeColor(blue.cgColor)
    context.setLineCap(.round)
    context.setLineWidth(max(1.5, size * 0.055))
    for diameter in [size * 0.34, size * 0.58] {
        context.strokeEllipse(in: CGRect(x: center.x - diameter / 2, y: center.y - diameter / 2,
                                         width: diameter, height: diameter))
    }
    context.setFillColor(blue.cgColor)
    let dot = size * 0.17
    context.fillEllipse(in: CGRect(x: center.x - dot / 2, y: center.y - dot / 2,
                                   width: dot, height: dot))
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
