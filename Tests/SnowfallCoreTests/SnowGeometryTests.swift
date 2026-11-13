import XCTest
@testable import SnowfallCore

final class SnowGeometryTests: XCTestCase {
    func testPrimaryAndNegativeOriginDisplayConversion() {
        XCTAssertEqual(SnowGeometry.appKitRect(CGRect(x: -900, y: -300, width: 800, height: 200), primaryHeight: 1000), CGRect(x: -900, y: 1100, width: 800, height: 200))
    }

    func testOverlappingWindowsSplitAndHideSnow() {
        let spans = SnowGeometry.exposedSpans(edge: Span(0, 100), y: 200,
            occluders: [CGRect(x: 20, y: 180, width: 40, height: 100), CGRect(x: 80, y: 190, width: 40, height: 80)])
        XCTAssertEqual(spans, [Span(0, 20), Span(60, 80)])
    }

    func testWindowBelowEdgeDoesNotHideSnow() {
        XCTAssertEqual(SnowGeometry.exposedSpans(edge: Span(0, 100), y: 200,
            occluders: [CGRect(x: 0, y: 0, width: 100, height: 150)]), [Span(0, 100)])
    }

    func testFullyCoveredEdgeHasNoSnow() {
        XCTAssertTrue(SnowGeometry.exposedSpans(edge: Span(20, 80), y: 200,
            occluders: [CGRect(x: 0, y: 150, width: 100, height: 100)]).isEmpty)
    }

    func testDepositsRemainFiniteAndBounded() {
        var profile = SnowProfile(width: 150, maximum: 18)
        profile.clear()
        for _ in 0..<500 { profile.deposit(at: 75, amount: 2) }
        XCTAssertEqual(profile.height(at: 75), 18, accuracy: 0.001)
        XCTAssertEqual(profile.height(at: 0), 0)
        for _ in 0..<100 { profile.settle(delta: 0.1) }
        XCTAssertTrue(profile.heights.allSatisfy { $0.isFinite && $0 >= 0 && $0 <= 18 })
        profile.clear()
        XCTAssertEqual(profile.height(at: 75), 0)
    }

    func testTinySurfaceAndOutsideDeposits() {
        var profile = SnowProfile(width: 0, maximum: 10)
        let before = profile.heights
        profile.deposit(at: -1, amount: 2)
        profile.deposit(at: 200, amount: 2)
        XCTAssertEqual(profile.heights, before)
        XCTAssertTrue(profile.height(at: 100).isFinite)
    }
}
