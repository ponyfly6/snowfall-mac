import Foundation
import CoreGraphics

public struct Span: Equatable {
    public var lower: CGFloat
    public var upper: CGFloat
    public init(_ lower: CGFloat, _ upper: CGFloat) {
        self.lower = lower
        self.upper = upper
    }
    public func contains(_ x: CGFloat) -> Bool { x >= lower && x <= upper }
}

public enum SnowGeometry {
    /// WindowServer coordinates start at the top-left of the primary display.
    public static func appKitRect(_ rect: CGRect, primaryHeight: CGFloat) -> CGRect {
        CGRect(x: rect.minX, y: primaryHeight - rect.maxY, width: rect.width, height: rect.height)
    }

    public static func exposedSpans(edge: Span, y: CGFloat, occluders: [CGRect], clearance: CGFloat = 22) -> [Span] {
        guard edge.upper > edge.lower else { return [] }
        var spans = [edge]
        for rect in occluders where rect.minY < y + clearance && rect.maxY > y - 0.5 {
            spans = spans.flatMap { span -> [Span] in
                guard rect.maxX > span.lower && rect.minX < span.upper else { return [span] }
                var result: [Span] = []
                if rect.minX > span.lower { result.append(Span(span.lower, min(rect.minX, span.upper))) }
                if rect.maxX < span.upper { result.append(Span(max(rect.maxX, span.lower), span.upper)) }
                return result
            }
        }
        return spans.filter { $0.upper - $0.lower > 4 }
    }
}

public struct SnowProfile {
    public private(set) var heights: [CGFloat]
    public let width: CGFloat
    public let maximum: CGFloat
    public var spacing: CGFloat { width / CGFloat(heights.count - 1) }

    public init(width: CGFloat, maximum: CGFloat, seed: CGFloat = 0) {
        self.width = max(1, width)
        self.maximum = max(0, maximum)
        let count = max(3, Int(max(1, width) / 5) + 1)
        heights = (0..<count).map { index in
            let wave = 0.5 + 0.5 * sin(CGFloat(index) * 0.31 + seed)
            return min(maximum, 0.35 + wave * 1.2)
        }
    }

    public func height(at x: CGFloat) -> CGFloat {
        let position = min(max(0, x / spacing), CGFloat(heights.count - 1))
        let index = min(heights.count - 2, Int(position))
        let fraction = position - CGFloat(index)
        return heights[index] * (1 - fraction) + heights[index + 1] * fraction
    }

    public mutating func deposit(at x: CGFloat, amount: CGFloat) {
        guard x >= 0, x <= width, amount > 0 else { return }
        let center = Int(x / spacing)
        for index in max(0, center - 3)...min(heights.count - 1, center + 3) {
            let distance = CGFloat(index) - x / spacing
            let weight = exp(-distance * distance / 3.4)
            heights[index] = min(maximum, heights[index] + amount * weight)
        }
    }

    public mutating func settle(delta: CGFloat) {
        let previous = heights
        for index in 1..<(heights.count - 1) {
            let average = (previous[index - 1] + previous[index + 1]) / 2
            heights[index] = max(0, min(maximum, previous[index] + (average - previous[index]) * min(1, delta * 1.6) - delta * 0.016))
        }
    }

    public mutating func clear() { heights = heights.map { _ in 0 } }
}
