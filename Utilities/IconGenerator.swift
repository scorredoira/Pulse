import SwiftUI
import AppKit

struct AppIconView: View {
    let size: CGFloat

    var body: some View {
        ZStack {
            // Background gradient
            RoundedRectangle(cornerRadius: size * 0.22, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color.teal, Color.teal.opacity(0.8), Color.cyan],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            // Timer arc at 75%
            Circle()
                .trim(from: 0, to: 0.75)
                .stroke(
                    Color.white.opacity(0.3),
                    style: StrokeStyle(lineWidth: size * 0.06, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .frame(width: size * 0.6, height: size * 0.6)

            // Runner icon
            Image(systemName: "figure.run")
                .font(.system(size: size * 0.32, weight: .semibold))
                .foregroundStyle(.white)
        }
        .frame(width: size, height: size)
    }
}

enum IconGenerator {
    struct IconSize {
        let points: Int
        let scale: Int
        var pixels: Int { points * scale }
        var filename: String { "icon_\(points)x\(points)@\(scale)x.png" }
    }

    static let sizes: [IconSize] = [
        IconSize(points: 16, scale: 1),
        IconSize(points: 16, scale: 2),
        IconSize(points: 32, scale: 1),
        IconSize(points: 32, scale: 2),
        IconSize(points: 128, scale: 1),
        IconSize(points: 128, scale: 2),
        IconSize(points: 256, scale: 1),
        IconSize(points: 256, scale: 2),
        IconSize(points: 512, scale: 1),
        IconSize(points: 512, scale: 2),
    ]

    @MainActor
    static func generateIcons(to directory: URL) {
        for iconSize in sizes {
            let pixelSize = CGFloat(iconSize.pixels)
            let renderer = ImageRenderer(content: AppIconView(size: pixelSize))
            renderer.scale = 1.0

            guard let cgImage = renderer.cgImage else {
                print("[IconGenerator] Failed to render \(iconSize.filename)")
                continue
            }

            let bitmapRep = NSBitmapImageRep(cgImage: cgImage)
            bitmapRep.size = NSSize(width: pixelSize, height: pixelSize)

            guard let pngData = bitmapRep.representation(using: .png, properties: [:]) else {
                print("[IconGenerator] Failed to create PNG for \(iconSize.filename)")
                continue
            }

            let fileURL = directory.appendingPathComponent(iconSize.filename)
            do {
                try pngData.write(to: fileURL)
                print("[IconGenerator] Generated \(iconSize.filename) (\(iconSize.pixels)px)")
            } catch {
                print("[IconGenerator] Failed to write \(iconSize.filename): \(error)")
            }
        }

        // Generate Contents.json
        let contents = generateContentsJSON()
        let contentsURL = directory.appendingPathComponent("Contents.json")
        do {
            try contents.write(to: contentsURL, atomically: true, encoding: .utf8)
            print("[IconGenerator] Generated Contents.json")
        } catch {
            print("[IconGenerator] Failed to write Contents.json: \(error)")
        }
    }

    private static func generateContentsJSON() -> String {
        var images: [[String: String]] = []
        for iconSize in sizes {
            images.append([
                "filename": iconSize.filename,
                "idiom": "mac",
                "scale": "\(iconSize.scale)x",
                "size": "\(iconSize.points)x\(iconSize.points)"
            ])
        }

        let json: [String: Any] = [
            "images": images,
            "info": [
                "author": "xcode",
                "version": 1
            ]
        ]

        guard let data = try? JSONSerialization.data(withJSONObject: json, options: [.prettyPrinted, .sortedKeys]),
              let string = String(data: data, encoding: .utf8) else {
            return "{}"
        }
        return string
    }
}
