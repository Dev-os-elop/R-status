import AppKit
import Foundation

guard CommandLine.arguments.count == 2 else {
    fputs("usage: generate-app-icon.swift OUTPUT.icns\n", stderr)
    exit(2)
}

let outputURL = URL(fileURLWithPath: CommandLine.arguments[1])
let fileManager = FileManager.default
let iconsetURL = fileManager.temporaryDirectory
    .appendingPathComponent("ESStatus-\(UUID().uuidString).iconset", isDirectory: true)
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

    let cat = tile.insetBy(dx: size * 0.13, dy: size * 0.12)
    func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
        CGPoint(x: cat.minX + cat.width * x, y: cat.minY + cat.height * y)
    }

    context.setStrokeColor(NSColor(calibratedRed: 0.28, green: 0.58, blue: 1.0, alpha: 0.9).cgColor)
    context.setLineWidth(max(1, size * 0.035))
    for scale in [0.92, 1.14] as [CGFloat] {
        let diameter = cat.width * scale
        context.strokeEllipse(in: CGRect(x: cat.midX - diameter / 2,
                                         y: cat.midY - diameter / 2,
                                         width: diameter, height: diameter))
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
    let dark = NSColor(calibratedRed: 0.18, green: 0.23, blue: 0.32, alpha: 1)
    context.setFillColor(NSColor.white.cgColor)
    context.addPath(head)
    context.fillPath()
    context.setStrokeColor(dark.cgColor)
    context.setLineWidth(max(1, cat.width * 0.065))
    context.setLineCap(.round)
    context.setLineJoin(.round)
    context.addPath(head)
    context.strokePath()

    context.setFillColor(NSColor(calibratedRed: 1.0, green: 0.63, blue: 0.60, alpha: 1).cgColor)
    for points in [
        [point(0.18, 0.82), point(0.30, 0.72), point(0.22, 0.90)],
        [point(0.82, 0.82), point(0.70, 0.72), point(0.78, 0.90)]
    ] {
        let ear = CGMutablePath()
        ear.move(to: points[0])
        ear.addLine(to: points[1])
        ear.addLine(to: points[2])
        ear.closeSubpath()
        context.addPath(ear)
        context.fillPath()
    }

    let mark = CGMutablePath()
    mark.move(to: point(0.40, 0.73))
    mark.addLine(to: point(0.60, 0.73))
    mark.addLine(to: point(0.545, 0.61))
    mark.addLine(to: point(0.50, 0.67))
    mark.addLine(to: point(0.455, 0.61))
    mark.closeSubpath()
    context.setFillColor(NSColor(calibratedWhite: 0.38, alpha: 1).cgColor)
    context.addPath(mark)
    context.fillPath()

    context.setFillColor(dark.cgColor)
    for x in [0.35, 0.65] as [CGFloat] {
        let center = point(x, 0.45)
        let diameter = cat.width * 0.16
        context.fillEllipse(in: CGRect(x: center.x - diameter / 2, y: center.y - diameter / 2,
                                       width: diameter, height: diameter))
        context.setFillColor(NSColor.white.cgColor)
        let highlight = cat.width * 0.045
        context.fillEllipse(in: CGRect(x: center.x - diameter * 0.20,
                                       y: center.y + diameter * 0.08,
                                       width: highlight, height: highlight))
        context.setFillColor(dark.cgColor)
    }

    let pink = NSColor(calibratedRed: 0.95, green: 0.45, blue: 0.45, alpha: 1)
    let noseCenter = point(0.50, 0.32)
    let nose = CGMutablePath()
    nose.move(to: CGPoint(x: noseCenter.x - cat.width * 0.045,
                          y: noseCenter.y + cat.height * 0.025))
    nose.addLine(to: CGPoint(x: noseCenter.x + cat.width * 0.045,
                             y: noseCenter.y + cat.height * 0.025))
    nose.addLine(to: CGPoint(x: noseCenter.x, y: noseCenter.y - cat.height * 0.035))
    nose.closeSubpath()
    context.setFillColor(pink.cgColor)
    context.addPath(nose)
    context.fillPath()

    context.setStrokeColor(dark.cgColor)
    context.setLineWidth(max(1, cat.width * 0.035))
    let mouthY = noseCenter.y - cat.height * 0.075
    context.move(to: CGPoint(x: cat.midX, y: noseCenter.y - cat.height * 0.03))
    context.addLine(to: CGPoint(x: cat.midX, y: mouthY + cat.height * 0.02))
    context.addCurve(to: CGPoint(x: cat.midX - cat.width * 0.10, y: mouthY + cat.height * 0.05),
                     control1: CGPoint(x: cat.midX - cat.width * 0.03, y: mouthY - cat.height * 0.04),
                     control2: CGPoint(x: cat.midX - cat.width * 0.08, y: mouthY - cat.height * 0.01))
    context.move(to: CGPoint(x: cat.midX, y: mouthY + cat.height * 0.02))
    context.addCurve(to: CGPoint(x: cat.midX + cat.width * 0.10, y: mouthY + cat.height * 0.05),
                     control1: CGPoint(x: cat.midX + cat.width * 0.03, y: mouthY - cat.height * 0.04),
                     control2: CGPoint(x: cat.midX + cat.width * 0.08, y: mouthY - cat.height * 0.01))
    context.strokePath()

    for side in [-1.0, 1.0] as [CGFloat] {
        let innerX = cat.midX + side * cat.width * 0.25
        let outerX = cat.midX + side * cat.width * 0.39
        for yOffset in [-0.02, 0.045] as [CGFloat] {
            let y = cat.minY + cat.height * (0.30 + yOffset)
            context.move(to: CGPoint(x: innerX, y: y))
            context.addLine(to: CGPoint(x: outerX, y: y + side * cat.height * 0.006))
            context.strokePath()
        }
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
