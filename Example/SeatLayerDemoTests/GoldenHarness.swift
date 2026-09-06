import SwiftUI
import UIKit
import XCTest
@testable import SeatLayer

/// Fixed phone canvas every chrome golden is rendered on.
enum GoldenCanvas {
    static let size = CGSize(width: 390, height: 844)
    static let scale: CGFloat = 2
    /// Rendering is not bit-identical across simulator runtimes, so a golden
    /// fails on a visible change rather than on font rasterisation noise.
    static let channelTolerance = 16
    static let allowedDifferingFraction = 0.02
}

@available(iOS 16.0, *)
@MainActor
enum GoldenRenderer {
    /// Renders `view` on the phone canvas in one colour scheme.
    ///
    /// A hosting controller inside a real window is what performs the layout
    /// pass: the chrome contains lazy stacks and UIKit-backed form surfaces,
    /// and `ImageRenderer` leaves both of those blank.
    static func image<Content: View>(
        of view: Content,
        colorScheme: ColorScheme
    ) -> UIImage? {
        let host = ZStack {
            Color(colorScheme == .dark ? UIColor.black : UIColor.white)
            view
        }
        .environment(\.colorScheme, colorScheme)

        let controller = UIHostingController(rootView: host)
        controller.view.frame = CGRect(origin: .zero, size: GoldenCanvas.size)
        controller.view.backgroundColor = colorScheme == .dark ? .black : .white

        let window: UIWindow
        if let scene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first {
            window = UIWindow(windowScene: scene)
            window.frame = CGRect(origin: .zero, size: GoldenCanvas.size)
        } else {
            window = UIWindow(frame: CGRect(origin: .zero, size: GoldenCanvas.size))
        }
        window.overrideUserInterfaceStyle = colorScheme == .dark ? .dark : .light
        window.rootViewController = controller
        window.isHidden = false
        window.makeKeyAndVisible()
        window.layoutIfNeeded()
        // One run-loop turn lets lazy content and async layout settle.
        RunLoop.current.run(until: Date().addingTimeInterval(0.1))
        window.layoutIfNeeded()

        let format = UIGraphicsImageRendererFormat.preferred()
        format.scale = GoldenCanvas.scale
        format.opaque = true
        let image = UIGraphicsImageRenderer(size: GoldenCanvas.size, format: format).image { _ in
            window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
        }
        window.isHidden = true
        window.rootViewController = nil
        return image
    }
}

/// Where the checked-in PNGs live in the working tree. The simulator can read
/// and write the host file system, so recording needs no extra plumbing.
enum GoldenStore {
    static var directory: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .appendingPathComponent("Goldens", isDirectory: true)
    }

    static var isRecording: Bool {
        ProcessInfo.processInfo.environment["SEATLAYER_RECORD_GOLDENS"] == "1"
    }

    static func url(for name: String) -> URL {
        directory.appendingPathComponent("\(name).png", isDirectory: false)
    }
}

/// Raw RGBA pixels for a byte-level comparison that ignores PNG encoder drift.
private func goldenPixels(_ image: UIImage) -> (bytes: [UInt8], width: Int, height: Int)? {
    guard let cgImage = image.cgImage else { return nil }
    let width = cgImage.width
    let height = cgImage.height
    var bytes = [UInt8](repeating: 0, count: width * height * 4)
    guard let context = CGContext(
        data: &bytes,
        width: width,
        height: height,
        bitsPerComponent: 8,
        bytesPerRow: width * 4,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else { return nil }
    context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
    return (bytes, width, height)
}

@available(iOS 16.0, *)
@MainActor
func assertGolden<Content: View>(
    name: String,
    colorScheme: ColorScheme,
    _ view: Content,
    file: StaticString = #filePath,
    line: UInt = #line
) throws {
    let suffix = colorScheme == .dark ? "dark" : "light"
    let key = "\(name)-\(suffix)"
    let rendered = try XCTUnwrap(
        GoldenRenderer.image(of: view, colorScheme: colorScheme),
        "\(key) did not render",
        file: file,
        line: line
    )
    let data = try XCTUnwrap(rendered.pngData(), "\(key) produced no PNG", file: file, line: line)
    let url = GoldenStore.url(for: key)

    guard !GoldenStore.isRecording, FileManager.default.fileExists(atPath: url.path) else {
        try FileManager.default.createDirectory(
            at: GoldenStore.directory,
            withIntermediateDirectories: true
        )
        try data.write(to: url)
        // Recording is a deliberate act, so it never passes silently.
        XCTFail("recorded golden \(key); re-run without recording to verify", file: file, line: line)
        return
    }

    let expected = try XCTUnwrap(
        UIImage(data: try Data(contentsOf: url)),
        "\(key) is not a readable PNG",
        file: file,
        line: line
    )
    let lhs = try XCTUnwrap(goldenPixels(rendered), "\(key) has no pixels", file: file, line: line)
    let rhs = try XCTUnwrap(goldenPixels(expected), "\(key) golden has no pixels", file: file, line: line)

    XCTAssertEqual(lhs.width, rhs.width, "\(key) width changed", file: file, line: line)
    XCTAssertEqual(lhs.height, rhs.height, "\(key) height changed", file: file, line: line)
    guard lhs.width == rhs.width, lhs.height == rhs.height else { return }

    var differing = 0
    for index in stride(from: 0, to: lhs.bytes.count, by: 4) {
        for channel in 0..<4 where abs(
            Int(lhs.bytes[index + channel]) - Int(rhs.bytes[index + channel])
        ) > GoldenCanvas.channelTolerance {
            differing += 1
            break
        }
    }
    let total = Double(lhs.width * lhs.height)
    let fraction = total > 0 ? Double(differing) / total : 0
    XCTAssertLessThanOrEqual(
        fraction,
        GoldenCanvas.allowedDifferingFraction,
        "\(key) differs from its golden in \(Int(fraction * 100))% of pixels",
        file: file,
        line: line
    )
}
