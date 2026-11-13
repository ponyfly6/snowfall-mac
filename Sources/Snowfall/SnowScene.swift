import AppKit
import SpriteKit
import SnowfallCore

struct WindowEdge {
    var id: String
    var x: CGFloat
    var y: CGFloat
    var width: CGFloat
    var spans: [Span]
    var floor: Bool = false
}

final class SnowBank {
    var edge: WindowEdge
    var profile: SnowProfile
    let node = SKShapeNode()
    init(_ edge: WindowEdge) {
        self.edge = edge
        profile = SnowProfile(width: edge.width, maximum: edge.floor ? 30 : 18, seed: CGFloat(edge.y * 0.03))
        node.fillColor = NSColor(calibratedRed: 0.94, green: 0.98, blue: 1, alpha: 0.97)
        node.strokeColor = NSColor.white.withAlphaComponent(0.9)
        node.lineWidth = 0.7
        node.zPosition = 2
        node.isAntialiased = true
    }
    func draw() {
        let path = CGMutablePath()
        for span in edge.spans {
            let left = max(0, span.lower - edge.x)
            let right = min(edge.width, span.upper - edge.x)
            guard right > left else { continue }
            // Taper the lip at window corners and at occlusion boundaries.
            func point(_ x: CGFloat) -> CGPoint {
                let taper = min(1, min(x - left, right - x) / 9)
                return CGPoint(x: edge.x + x, y: edge.y + max(0, taper) * profile.height(at: x))
            }
            path.move(to: CGPoint(x: edge.x + left, y: edge.y - 0.6))
            var previous = point(left)
            path.addLine(to: previous)
            var x = left + profile.spacing
            while x < right {
                let current = point(x)
                let middle = CGPoint(x: (previous.x + current.x) / 2, y: (previous.y + current.y) / 2)
                path.addQuadCurve(to: middle, control: previous)
                previous = current
                x += profile.spacing
            }
            path.addQuadCurve(to: point(right), control: previous)
            path.addLine(to: CGPoint(x: edge.x + right, y: edge.y - 0.6))
            path.closeSubpath()
        }
        node.path = path
    }
}

private final class Flake {
    let node: SKSpriteNode
    var speed: CGFloat
    var sway: CGFloat
    var phase: CGFloat
    var depth: CGFloat
    init(texture: SKTexture, depth: CGFloat) {
        self.depth = depth
        node = SKSpriteNode(texture: texture)
        let diameter = 1.8 + depth * 5.4
        node.size = CGSize(width: diameter, height: diameter)
        node.alpha = 0.28 + depth * 0.63
        node.zPosition = 3 + depth
        speed = 28 + depth * 68 + CGFloat.random(in: 0...18)
        sway = CGFloat.random(in: 6...23)
        phase = CGFloat.random(in: 0...(2 * .pi))
    }
}

final class SnowScene: SKScene {
    var intensity: Double = 0.5
    var wind: Double = 0.15
    var accumulates = true
    private var flakes: [Flake] = []
    private var banks: [String: SnowBank] = [:]
    private var previousTime: TimeInterval = 0
    private var bankTime: TimeInterval = 0
    private var elapsed: CGFloat = 0
    private var texture: SKTexture!
    private var crystalTexture: SKTexture!

    override init(size: CGSize) {
        super.init(size: size)
        backgroundColor = .clear
        scaleMode = .resizeFill
        anchorPoint = .zero
        texture = Self.makeTexture(crystal: false)
        crystalTexture = Self.makeTexture(crystal: true)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func apply(intensity: Double, wind: Double, accumulates: Bool) {
        self.intensity = intensity
        self.wind = wind
        self.accumulates = accumulates
        banks.values.forEach { $0.node.isHidden = !accumulates }
        let area = size.width * size.height / 1_000_000
        let count = min(1600, max(80, Int(area * (90 + intensity * 250))))
        while flakes.count > count { flakes.removeLast().node.removeFromParent() }
        while flakes.count < count {
            let depth = CGFloat.random(in: 0.05...1)
            let flake = Flake(texture: depth > 0.85 ? crystalTexture : texture, depth: depth)
            flake.node.position = CGPoint(x: CGFloat.random(in: 0...max(1, size.width)), y: CGFloat.random(in: 0...max(1, size.height)))
            flakes.append(flake)
            addChild(flake.node)
        }
    }

    func setEdges(_ edges: [WindowEdge]) {
        let ids = Set(edges.map(\.id))
        for id in Array(banks.keys) where !ids.contains(id) { banks.removeValue(forKey: id)?.node.removeFromParent() }
        for edge in edges {
            if let bank = banks[edge.id], abs(bank.edge.width - edge.width) < 4 {
                bank.edge = edge
                bank.draw()
            } else {
                banks.removeValue(forKey: edge.id)?.node.removeFromParent()
                let bank = SnowBank(edge)
                bank.node.isHidden = !accumulates
                banks[edge.id] = bank
                addChild(bank.node)
                bank.draw()
            }
        }
    }

    func clearSnow() {
        banks.values.forEach { $0.profile.clear(); $0.draw() }
    }

    override func update(_ currentTime: TimeInterval) {
        guard previousTime > 0 else { previousTime = currentTime; return }
        let dt = CGFloat(min(1.0 / 15, max(0, currentTime - previousTime)))
        previousTime = currentTime
        elapsed += dt
        let breeze = CGFloat(wind) * 82 + sin(elapsed * 0.29) * 11
        let sortedBanks = accumulates ? banks.values.sorted { $0.edge.y > $1.edge.y } : []
        for flake in flakes {
            let old = flake.node.position
            var next = CGPoint(x: old.x + (breeze * (0.45 + flake.depth) + sin(elapsed * 0.8 + flake.phase) * flake.sway) * dt,
                               y: old.y - flake.speed * dt)
            var landed = false
            if accumulates && flake.depth > 0.2 {
                for bank in sortedBanks {
                    // Check the baseline before doing profile interpolation.
                    guard next.y <= bank.edge.y + bank.profile.maximum + 5,
                          old.y >= bank.edge.y - 1,
                          bank.edge.spans.contains(where: { $0.contains(next.x) }) else { continue }
                    let lip = bank.edge.y + bank.profile.height(at: next.x - bank.edge.x)
                    if old.y >= lip && next.y <= lip + 1 {
                        bank.profile.deposit(at: next.x - bank.edge.x, amount: 0.23 + flake.depth * 0.5)
                        landed = true
                        break
                    }
                }
            }
            if landed || next.y < -12 {
                next = CGPoint(x: CGFloat.random(in: -30...(size.width + 30)), y: size.height + CGFloat.random(in: 5...45))
            }
            if next.x < -40 { next.x = size.width + 30 }
            if next.x > size.width + 40 { next.x = -30 }
            flake.node.position = next
        }
        if currentTime - bankTime > 0.16 {
            if accumulates {
                banks.values.forEach { $0.profile.settle(delta: 0.16); $0.draw() }
            }
            bankTime = currentTime
        }
    }


    private static func makeTexture(crystal: Bool) -> SKTexture {
        let image = NSImage(size: CGSize(width: 32, height: 32), flipped: false) { _ in
            guard let context = NSGraphicsContext.current?.cgContext else { return false }
            context.clear(CGRect(x: 0, y: 0, width: 32, height: 32))
            let colors = [NSColor.white.withAlphaComponent(0.95).cgColor, NSColor.white.withAlphaComponent(0.7).cgColor, NSColor.white.withAlphaComponent(0).cgColor] as CFArray
            let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 0.35, 1])!
            context.drawRadialGradient(gradient, startCenter: CGPoint(x: 16, y: 16), startRadius: 0,
                                       endCenter: CGPoint(x: 16, y: 16), endRadius: crystal ? 10 : 15, options: [])
            if crystal {
                context.setStrokeColor(NSColor.white.withAlphaComponent(0.85).cgColor)
                context.setLineWidth(1.1)
                context.setLineCap(.round)
                for index in 0..<6 {
                    let angle = CGFloat(index) * .pi / 3
                    func p(_ length: CGFloat, _ offset: CGFloat = 0) -> CGPoint {
                        CGPoint(x: 16 + cos(angle + offset) * length, y: 16 + sin(angle + offset) * length)
                    }
                    context.move(to: p(0)); context.addLine(to: p(12))
                    let branch = p(7)
                    context.move(to: p(10, 0.23)); context.addLine(to: branch); context.addLine(to: p(10, -0.23))
                }
                context.strokePath()
            }
            return true
        }
        return SKTexture(image: image)
    }
}

final class SnowOverlay: NSPanel {
    let snowView: SKView
    let snowScene: SnowScene
    let screenFrame: CGRect
    init(screen: NSScreen) {
        screenFrame = screen.frame
        snowScene = SnowScene(size: screen.frame.size)
        snowView = SKView(frame: CGRect(origin: .zero, size: screen.frame.size))
        super.init(contentRect: screen.frame, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        title = "Snowfall overlay"
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        ignoresMouseEvents = true
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.statusWindow)) - 1)
        collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]
        animationBehavior = .none
        snowView.allowsTransparency = true
        snowView.ignoresSiblingOrder = true
        snowView.preferredFramesPerSecond = 30
        contentView = snowView
        snowView.presentScene(snowScene)
        setFrame(screen.frame, display: false)
    }
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}
