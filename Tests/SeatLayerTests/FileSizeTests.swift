import XCTest

/// Keeps every source file small enough that one component lives in one file.
/// The cap is what makes parallel work on the picker chrome possible at all.
final class FileSizeTests: XCTestCase {
    private static let lineLimit = 1_500

    func testEverySourceFileStaysUnderTheLineCap() throws {
        let sources = FileSizeTests.packageRoot.appendingPathComponent("Sources")
        let enumerator = try XCTUnwrap(
            FileManager.default.enumerator(
                at: sources,
                includingPropertiesForKeys: [.isRegularFileKey]
            )
        )

        var offenders: [String] = []
        var inspected = 0
        for case let url as URL in enumerator where url.pathExtension == "swift" {
            let contents = try String(contentsOf: url, encoding: .utf8)
            let lines = contents.split(separator: "\n", omittingEmptySubsequences: false).count
            inspected += 1
            if lines > FileSizeTests.lineLimit {
                offenders.append("\(url.lastPathComponent): \(lines) lines")
            }
        }

        XCTAssertGreaterThan(inspected, 0, "no Swift sources were inspected")
        XCTAssertTrue(
            offenders.isEmpty,
            "files over the \(FileSizeTests.lineLimit)-line cap: "
                + offenders.sorted().joined(separator: ", ")
        )
    }

    private static var packageRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()  // SeatLayerTests
            .deletingLastPathComponent()  // Tests
            .deletingLastPathComponent()  // package root
    }
}
