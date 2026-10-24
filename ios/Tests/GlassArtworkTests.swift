import XCTest
@testable import TwilDiary

final class GlassArtworkTests: XCTestCase {
    func testOnlyPublicTMDBArtworkCanBeFetchedAndUsesABoundedThumbnailSize() {
        XCTAssertEqual(GlassArtworkCache.publicArtworkURL("https://image.tmdb.org/t/p/original/example.jpg")?.absoluteString, "https://image.tmdb.org/t/p/w342/example.jpg")
        for path in ["http://image.tmdb.org/t/p/w500/example.jpg", "https://example.test/t/p/w500/example.jpg", "https://user:secret@image.tmdb.org/t/p/w500/example.jpg", "https://image.tmdb.org:8443/t/p/w500/example.jpg", "https://image.tmdb.org/t/p/w500/example.jpg?token=secret", "https://image.tmdb.org/t/p/w500/../../example.jpg", "https://image.tmdb.org/t/p/w500/example.svg"] {
            XCTAssertNil(GlassArtworkCache.publicArtworkURL(path))
        }
    }
    func testDominantSamplingUsesTheMostFrequentColorAndIgnoresLetterboxAndTransparency() {
        let green: [UInt8] = [32, 160, 80, 255], red: [UInt8] = [210, 20, 50, 255]
        let bytes = Array(repeating: green, count: 8).flatMap { $0 } + Array(repeating: red, count: 3).flatMap { $0 }
            + Array(repeating: [UInt8](arrayLiteral: 0, 0, 0, 255), count: 20).flatMap { $0 }
            + Array(repeating: [UInt8](arrayLiteral: 255, 255, 255, 0), count: 20).flatMap { $0 }
        let value = GlassArtworkCache.dominant(bytes)
        XCTAssertEqual(value.0, 32.0 / 255, accuracy: 0.001)
        XCTAssertEqual(value.1, 160.0 / 255, accuracy: 0.001)
        XCTAssertEqual(value.2, 80.0 / 255, accuracy: 0.001)
    }
    func testEmptyAndPartialSamplesHaveADeterministicReadableFallback() {
        let empty = GlassArtworkCache.dominant([]), partial = GlassArtworkCache.dominant([255, 0, 0])
        XCTAssertEqual(empty.0, 0.12); XCTAssertEqual(empty.1, 0.14); XCTAssertEqual(empty.2, 0.18)
        XCTAssertEqual(partial.0, empty.0); XCTAssertEqual(partial.1, empty.1); XCTAssertEqual(partial.2, empty.2)
    }
    func testDominantSamplingTieBreakIsIndependentOfPixelOrder() {
        let a: [UInt8] = [32, 80, 160, 255], b: [UInt8] = [180, 64, 32, 255]
        let first = GlassArtworkCache.dominant(a + b), second = GlassArtworkCache.dominant(b + a)
        XCTAssertEqual(first.0, second.0); XCTAssertEqual(first.1, second.1); XCTAssertEqual(first.2, second.2)
    }
}
