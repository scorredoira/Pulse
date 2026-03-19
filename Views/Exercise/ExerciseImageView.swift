import SwiftUI

struct ExerciseImageView: View {
    let imageFileNames: [String]
    var isAnimating: Bool = true
    var maxImageHeight: CGFloat = 140
    var fillWidth: Bool = false

    @State private var currentIndex: Int = 0
    @State private var rotationTimer: Timer?

    var body: some View {
        let images = Self.loadImages(fileNames: imageFileNames)

        if !images.isEmpty {
            let index = min(currentIndex, images.count - 1)
            #if os(macOS)
            Image(nsImage: images[index])
                .resizable()
                .aspectRatio(contentMode: fillWidth ? .fill : .fit)
                .frame(maxHeight: maxImageHeight)
                .frame(maxWidth: fillWidth ? .infinity : nil)
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: fillWidth ? 0 : 8))
                .animation(.easeInOut(duration: 0.5), value: currentIndex)
                .onAppear { startRotation(count: images.count) }
                .onDisappear { stopRotation() }
            #else
            Image(uiImage: images[index])
                .resizable()
                .aspectRatio(contentMode: fillWidth ? .fill : .fit)
                .frame(maxHeight: maxImageHeight)
                .frame(maxWidth: fillWidth ? .infinity : nil)
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: fillWidth ? 0 : 8))
                .animation(.easeInOut(duration: 0.5), value: currentIndex)
                .onAppear { startRotation(count: images.count) }
                .onDisappear { stopRotation() }
            #endif
        }
    }

    #if os(macOS)
    private static func loadImages(fileNames: [String]) -> [NSImage] {
        let imagesDir = Constants.FilePaths.imagesDirectory
        return fileNames.compactMap { fileName in
            let url = imagesDir.appendingPathComponent(fileName)
            guard let data = try? Data(contentsOf: url) else { return nil }
            return NSImage(data: data)
        }
    }
    #else
    private static func loadImages(fileNames: [String]) -> [UIImage] {
        let imagesDir = Constants.FilePaths.imagesDirectory
        return fileNames.compactMap { fileName in
            let url = imagesDir.appendingPathComponent(fileName)
            guard let data = try? Data(contentsOf: url) else { return nil }
            return UIImage(data: data)
        }
    }
    #endif

    private func startRotation(count: Int) {
        guard count > 1, isAnimating else { return }
        stopRotation()
        rotationTimer = Timer.scheduledTimer(withTimeInterval: 4.0, repeats: true) { _ in
            currentIndex = (currentIndex + 1) % count
        }
    }

    private func stopRotation() {
        rotationTimer?.invalidate()
        rotationTimer = nil
    }
}
