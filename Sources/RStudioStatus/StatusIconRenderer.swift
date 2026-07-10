import AppKit

enum StatusVisualState {
    case idle
    case running
    case complete
    case fail
    case interrupted

    var color: NSColor {
        switch self {
        case .idle: return NSColor(calibratedWhite: 0.28, alpha: 1)
        case .running: return NSColor(calibratedRed: 0.08, green: 0.42, blue: 0.92, alpha: 1)
        case .complete: return NSColor(calibratedRed: 0.08, green: 0.62, blue: 0.28, alpha: 1)
        case .fail: return NSColor(calibratedRed: 0.92, green: 0.20, blue: 0.12, alpha: 1)
        case .interrupted: return NSColor(calibratedRed: 0.95, green: 0.52, blue: 0.08, alpha: 1)
        }
    }
}

enum StatusIconRenderer {
    static func image(style: StatusIconStyle, state: StatusVisualState, size: CGFloat) -> NSImage {
        let image = NSImage(size: NSSize(width: size, height: size), flipped: false) { rect in
            guard let context = NSGraphicsContext.current?.cgContext else { return false }
            context.setShouldAntialias(true)
            context.setAllowsAntialiasing(true)
            draw(style: style, state: state, in: rect.insetBy(dx: size * 0.08, dy: size * 0.08), context: context)
            return true
        }
        image.isTemplate = false
        return image
    }

    static func applicationIcon(style: StatusIconStyle, size: CGFloat) -> NSImage {
        let image = NSImage(size: NSSize(width: size, height: size), flipped: false) { rect in
            guard let context = NSGraphicsContext.current?.cgContext else { return false }
            context.setShouldAntialias(true)
            context.setAllowsAntialiasing(true)

            let tile = rect.insetBy(dx: size * 0.07, dy: size * 0.07)
            let isCat = style == .catOutline || style == .catSilhouette
            context.setFillColor(
                (isCat
                    ? NSColor(calibratedRed: 0.07, green: 0.39, blue: 0.92, alpha: 1)
                    : NSColor.white).cgColor
            )
            context.addPath(CGPath(roundedRect: tile, cornerWidth: size * 0.20,
                                   cornerHeight: size * 0.20, transform: nil))
            context.fillPath()

            let iconRect = tile.insetBy(dx: size * 0.16, dy: size * 0.16)
            if style == .catOutline || style == .catSilhouette {
                drawCat(style: style, state: .running, rect: iconRect,
                        context: context, forApplicationIcon: true, brandEyes: true)
            } else {
                draw(style: style, state: .running, in: iconRect, context: context)
            }
            return true
        }
        image.isTemplate = false
        return image
    }

    private static func draw(style: StatusIconStyle, state: StatusVisualState,
                             in rect: CGRect, context: CGContext) {
        switch style {
        case .catOutline, .catSilhouette:
            drawCat(style: style, state: state, rect: rect,
                    context: context, forApplicationIcon: false, brandEyes: false)
        case .statusPulse: drawPulse(state: state, rect: rect, context: context)
        case .progressBlocks: drawBlocks(state: state, rect: rect, context: context)
        case .signalOrbit: drawOrbit(state: state, rect: rect, context: context)
        case .windowCheck: drawWindow(state: state, rect: rect, context: context)
        case .layeredS: drawLayeredS(state: state, rect: rect, context: context)
        }
    }

    private static func configureStroke(_ context: CGContext, color: NSColor, width: CGFloat) {
        context.setStrokeColor(color.cgColor)
        context.setLineWidth(width)
        context.setLineCap(.round)
        context.setLineJoin(.round)
    }

    private static func drawCat(style: StatusIconStyle, state: StatusVisualState,
                                rect: CGRect, context: CGContext,
                                forApplicationIcon: Bool, brandEyes: Bool) {
        let head = catHeadPath(in: rect)
        let dark = NSColor(calibratedRed: 0.10, green: 0.14, blue: 0.20, alpha: 1)

        if style == .catOutline {
            context.setFillColor(
                (forApplicationIcon ? NSColor.white : NSColor.controlBackgroundColor).cgColor
            )
            context.addPath(head)
            context.fillPath()
            configureStroke(
                context,
                color: forApplicationIcon ? dark : NSColor.labelColor,
                width: rect.width * 0.075
            )
            context.addPath(head)
            context.strokePath()
        } else {
            context.setFillColor((forApplicationIcon ? dark : NSColor.labelColor).cgColor)
            context.addPath(head)
            context.fillPath()
        }

        drawForeheadMark(style: style, rect: rect, context: context,
                         forApplicationIcon: forApplicationIcon)
        drawCatEyes(state: state, rect: rect, context: context, brandEyes: brandEyes)
    }

    private static func catHeadPath(in rect: CGRect) -> CGPath {
        func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: rect.minX + rect.width * x, y: rect.minY + rect.height * y)
        }

        let path = CGMutablePath()
        path.move(to: point(0.18, 0.23))
        path.addCurve(to: point(0.15, 0.58), control1: point(0.10, 0.34), control2: point(0.11, 0.48))
        path.addLine(to: point(0.12, 0.91))
        path.addLine(to: point(0.38, 0.72))
        path.addCurve(to: point(0.62, 0.72), control1: point(0.45, 0.76), control2: point(0.55, 0.76))
        path.addLine(to: point(0.88, 0.91))
        path.addLine(to: point(0.85, 0.58))
        path.addCurve(to: point(0.82, 0.23), control1: point(0.89, 0.48), control2: point(0.90, 0.34))
        path.addCurve(to: point(0.18, 0.23), control1: point(0.68, 0.05), control2: point(0.32, 0.05))
        path.closeSubpath()
        return path
    }

    private static func drawForeheadMark(style: StatusIconStyle, rect: CGRect,
                                         context: CGContext, forApplicationIcon: Bool) {
        let color: NSColor
        if style == .catSilhouette {
            color = NSColor(calibratedWhite: 0.72, alpha: 1)
        } else if forApplicationIcon {
            color = NSColor(calibratedWhite: 0.42, alpha: 1)
        } else {
            color = NSColor.secondaryLabelColor
        }
        context.setFillColor(color.cgColor)

        let mark = CGMutablePath()
        mark.move(to: CGPoint(x: rect.midX - rect.width * 0.10, y: rect.minY + rect.height * 0.73))
        mark.addLine(to: CGPoint(x: rect.midX + rect.width * 0.10, y: rect.minY + rect.height * 0.73))
        mark.addLine(to: CGPoint(x: rect.midX + rect.width * 0.045, y: rect.minY + rect.height * 0.61))
        mark.addLine(to: CGPoint(x: rect.midX, y: rect.minY + rect.height * 0.67))
        mark.addLine(to: CGPoint(x: rect.midX - rect.width * 0.045, y: rect.minY + rect.height * 0.61))
        mark.closeSubpath()
        context.addPath(mark)
        context.fillPath()
    }

    private static func drawCatEyes(state: StatusVisualState, rect: CGRect,
                                    context: CGContext, brandEyes: Bool) {
        let centers = [
            CGPoint(x: rect.minX + rect.width * 0.35, y: rect.minY + rect.height * 0.43),
            CGPoint(x: rect.minX + rect.width * 0.65, y: rect.minY + rect.height * 0.43)
        ]
        if brandEyes {
            context.setFillColor(NSColor(calibratedRed: 0.20, green: 0.72, blue: 1.00, alpha: 1).cgColor)
            for center in centers {
                let diameter = rect.width * 0.14
                context.fillEllipse(in: CGRect(x: center.x - diameter / 2, y: center.y - diameter / 2,
                                               width: diameter, height: diameter))
            }
            return
        }

        let color: NSColor
        switch state {
        case .idle: color = NSColor(calibratedWhite: 0.62, alpha: 1)
        case .running: color = NSColor(calibratedRed: 0.07, green: 0.42, blue: 0.92, alpha: 1)
        case .complete: color = NSColor(calibratedRed: 0.07, green: 0.68, blue: 0.30, alpha: 1)
        case .interrupted: color = NSColor(calibratedRed: 0.96, green: 0.55, blue: 0.05, alpha: 1)
        case .fail: color = NSColor(calibratedRed: 0.93, green: 0.20, blue: 0.17, alpha: 1)
        }
        context.setFillColor(color.cgColor)
        configureStroke(context, color: color, width: max(1.2, rect.width * 0.065))

        for center in centers {
            switch state {
            case .idle:
                let diameter = rect.width * 0.13
                context.fillEllipse(in: CGRect(x: center.x - diameter / 2, y: center.y - diameter / 2,
                                               width: diameter, height: diameter))
            case .running:
                let eye = CGMutablePath()
                eye.move(to: CGPoint(x: center.x - rect.width * 0.055, y: center.y - rect.height * 0.075))
                eye.addLine(to: CGPoint(x: center.x + rect.width * 0.075, y: center.y))
                eye.addLine(to: CGPoint(x: center.x - rect.width * 0.055, y: center.y + rect.height * 0.075))
                eye.closeSubpath()
                context.addPath(eye)
                context.fillPath()
            case .complete:
                context.move(to: CGPoint(x: center.x - rect.width * 0.065, y: center.y))
                context.addLine(to: CGPoint(x: center.x - rect.width * 0.015, y: center.y - rect.height * 0.05))
                context.addLine(to: CGPoint(x: center.x + rect.width * 0.075, y: center.y + rect.height * 0.055))
                context.strokePath()
            case .interrupted:
                let bar = CGRect(x: center.x - rect.width * 0.035,
                                 y: center.y - rect.height * 0.09,
                                 width: rect.width * 0.07,
                                 height: rect.height * 0.18)
                context.addPath(CGPath(roundedRect: bar, cornerWidth: rect.width * 0.02,
                                       cornerHeight: rect.width * 0.02, transform: nil))
                context.fillPath()
            case .fail:
                let radius = rect.width * 0.065
                context.move(to: CGPoint(x: center.x - radius, y: center.y - radius))
                context.addLine(to: CGPoint(x: center.x + radius, y: center.y + radius))
                context.move(to: CGPoint(x: center.x - radius, y: center.y + radius))
                context.addLine(to: CGPoint(x: center.x + radius, y: center.y - radius))
                context.strokePath()
            }
        }
    }

    private static func drawPulse(state: StatusVisualState, rect: CGRect, context: CGContext) {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let width = rect.width * 0.09
        configureStroke(context, color: state.color, width: width)
        for scale in [0.48, 0.78] as [CGFloat] {
            let diameter = rect.width * scale
            context.strokeEllipse(in: CGRect(x: center.x - diameter / 2, y: center.y - diameter / 2,
                                             width: diameter, height: diameter))
        }
        context.setFillColor(state.color.cgColor)
        let dot = rect.width * 0.24
        context.fillEllipse(in: CGRect(x: center.x - dot / 2, y: center.y - dot / 2, width: dot, height: dot))
        drawStateGlyph(state, center: center, scale: rect.width * 0.22, context: context)
    }

    private static func drawBlocks(state: StatusVisualState, rect: CGRect, context: CGContext) {
        let color = state.color
        let heights: [CGFloat] = [0.36, 0.58, 0.82]
        let gap = rect.width * 0.08
        let barWidth = (rect.width - gap * 2) / 3
        for (index, height) in heights.enumerated() {
            let h = rect.height * height
            let barRect = CGRect(x: rect.minX + CGFloat(index) * (barWidth + gap), y: rect.minY,
                                 width: barWidth, height: h)
            let path = CGPath(roundedRect: barRect, cornerWidth: barWidth * 0.26,
                              cornerHeight: barWidth * 0.26, transform: nil)
            context.setFillColor(color.withAlphaComponent(0.55 + CGFloat(index) * 0.22).cgColor)
            context.addPath(path)
            context.fillPath()
        }
        drawStateGlyph(state, center: CGPoint(x: rect.midX, y: rect.midY),
                       scale: rect.width * 0.28, context: context)
    }

    private static func drawOrbit(state: StatusVisualState, rect: CGRect, context: CGContext) {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        configureStroke(context, color: state.color, width: rect.width * 0.09)
        for rotation in stride(from: CGFloat(0), to: .pi * 2, by: .pi * 2 / 3) {
            context.addArc(center: center, radius: rect.width * 0.36,
                           startAngle: rotation + 0.18, endAngle: rotation + 1.42, clockwise: false)
            context.strokePath()
        }
        context.setFillColor(state.color.cgColor)
        let dot = rect.width * 0.26
        context.fillEllipse(in: CGRect(x: center.x - dot / 2, y: center.y - dot / 2, width: dot, height: dot))
        drawStateGlyph(state, center: center, scale: rect.width * 0.22, context: context)
    }

    private static func drawWindow(state: StatusVisualState, rect: CGRect, context: CGContext) {
        let body = rect.insetBy(dx: rect.width * 0.08, dy: rect.height * 0.12)
        configureStroke(context, color: state.color, width: rect.width * 0.09)
        context.addPath(CGPath(roundedRect: body, cornerWidth: rect.width * 0.14,
                               cornerHeight: rect.width * 0.14, transform: nil))
        context.strokePath()
        context.move(to: CGPoint(x: body.minX, y: body.maxY - body.height * 0.28))
        context.addLine(to: CGPoint(x: body.maxX, y: body.maxY - body.height * 0.28))
        context.strokePath()
        let badgeCenter = CGPoint(x: body.maxX - body.width * 0.23, y: body.minY + body.height * 0.26)
        context.setFillColor(state.color.cgColor)
        context.fillEllipse(in: CGRect(x: badgeCenter.x - rect.width * 0.18,
                                       y: badgeCenter.y - rect.width * 0.18,
                                       width: rect.width * 0.36, height: rect.width * 0.36))
        drawStateGlyph(state, center: badgeCenter, scale: rect.width * 0.25, context: context)
    }

    private static func drawLayeredS(state: StatusVisualState, rect: CGRect, context: CGContext) {
        let barHeight = rect.height * 0.22
        let bars = [
            CGRect(x: rect.minX + rect.width * 0.08, y: rect.maxY - barHeight, width: rect.width * 0.76, height: barHeight),
            CGRect(x: rect.minX + rect.width * 0.18, y: rect.midY - barHeight / 2, width: rect.width * 0.74, height: barHeight),
            CGRect(x: rect.minX + rect.width * 0.08, y: rect.minY, width: rect.width * 0.76, height: barHeight)
        ]
        for (index, bar) in bars.enumerated() {
            context.setFillColor(state.color.withAlphaComponent(index == 1 ? 0.82 : 1).cgColor)
            context.addPath(CGPath(roundedRect: bar, cornerWidth: barHeight * 0.48,
                                   cornerHeight: barHeight * 0.48, transform: nil))
            context.fillPath()
        }
        drawStateGlyph(state, center: CGPoint(x: rect.midX, y: rect.midY),
                       scale: rect.width * 0.26, context: context)
    }

    private static func drawStateGlyph(_ state: StatusVisualState, center: CGPoint,
                                       scale: CGFloat, context: CGContext) {
        guard state == .complete || state == .fail || state == .interrupted else { return }
        configureStroke(context, color: .white, width: max(1.5, scale * 0.16))
        if state == .complete {
            context.move(to: CGPoint(x: center.x - scale * 0.35, y: center.y))
            context.addLine(to: CGPoint(x: center.x - scale * 0.08, y: center.y - scale * 0.27))
            context.addLine(to: CGPoint(x: center.x + scale * 0.38, y: center.y + scale * 0.28))
            context.strokePath()
        } else {
            context.move(to: CGPoint(x: center.x, y: center.y + scale * 0.30))
            context.addLine(to: CGPoint(x: center.x, y: center.y - scale * 0.06))
            context.strokePath()
            context.setFillColor(NSColor.white.cgColor)
            let dot = scale * 0.13
            context.fillEllipse(in: CGRect(x: center.x - dot / 2, y: center.y - scale * 0.35,
                                           width: dot, height: dot))
        }
    }
}
