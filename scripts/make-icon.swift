import AppKit

let output = CommandLine.arguments[1]
try FileManager.default.createDirectory(atPath: output, withIntermediateDirectories: true)
for size in [16, 32, 64, 128, 256, 512, 1024] {
    let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
        bytesPerRow: 0, bitsPerPixel: 0)!
    let context = NSGraphicsContext(bitmapImageRep: bitmap)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = context
    let scale = CGFloat(size) / 1024
    context.cgContext.scaleBy(x: scale, y: scale)
    let rect = CGRect(x: 54, y: 54, width: 916, height: 916)
    let background = NSBezierPath(roundedRect: rect, xRadius: 210, yRadius: 210)
    NSGradient(starting: NSColor(calibratedRed: 0.33, green: 0.55, blue: 0.70, alpha: 1),
               ending: NSColor(calibratedRed: 0.09, green: 0.20, blue: 0.34, alpha: 1))!.draw(in: background, angle: -60)
    let cg = context.cgContext
    cg.setStrokeColor(NSColor(calibratedRed: 0.93, green: 0.98, blue: 1, alpha: 1).cgColor)
    cg.setLineWidth(27)
    cg.setLineCap(.round)
    cg.setLineJoin(.round)
    for i in 0..<6 {
        let angle = CGFloat(i) * .pi / 3 + .pi / 6
        let direction = CGPoint(x: cos(angle), y: sin(angle))
        let perpendicular = CGPoint(x: -sin(angle), y: cos(angle))
        func point(_ length: CGFloat, _ sideways: CGFloat = 0) -> CGPoint {
            CGPoint(x: 512 + direction.x * length + perpendicular.x * sideways,
                    y: 545 + direction.y * length + perpendicular.y * sideways)
        }
        cg.move(to: point(0)); cg.addLine(to: point(245))
        cg.move(to: point(175, 70)); cg.addLine(to: point(115)); cg.addLine(to: point(175, -70))
        cg.move(to: point(245, 51)); cg.addLine(to: point(195)); cg.addLine(to: point(245, -51))
    }
    cg.strokePath()
    cg.setFillColor(NSColor.white.withAlphaComponent(0.95).cgColor)
    for dot in [CGPoint(x: 242, y: 733), CGPoint(x: 777, y: 683), CGPoint(x: 729, y: 337)] {
        cg.fillEllipse(in: CGRect(x: dot.x, y: dot.y, width: 14, height: 14))
    }
    let hill = NSBezierPath()
    hill.move(to: CGPoint(x: 220, y: 231))
    hill.curve(to: CGPoint(x: 804, y: 231), controlPoint1: CGPoint(x: 418, y: 281), controlPoint2: CGPoint(x: 630, y: 180))
    hill.lineWidth = 17
    NSColor.white.withAlphaComponent(0.8).setStroke()
    hill.lineCapStyle = .round
    hill.stroke()
    NSGraphicsContext.restoreGraphicsState()
    let data = bitmap.representation(using: .png, properties: [:])!
    let names: [String]
    switch size {
    case 16: names = ["icon_16x16.png"]
    case 32: names = ["icon_16x16@2x.png", "icon_32x32.png"]
    case 64: names = ["icon_32x32@2x.png"]
    case 128: names = ["icon_128x128.png"]
    case 256: names = ["icon_128x128@2x.png", "icon_256x256.png"]
    case 512: names = ["icon_256x256@2x.png", "icon_512x512.png"]
    default: names = ["icon_512x512@2x.png"]
    }
    for name in names { try data.write(to: URL(fileURLWithPath: output).appendingPathComponent(name)) }
}
