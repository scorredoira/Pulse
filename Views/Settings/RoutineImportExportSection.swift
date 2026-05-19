import SwiftUI
import SwiftData
#if os(iOS)
import UIKit
#endif

struct RoutineImportExportSection: View {
    @Environment(\.modelContext) private var modelContext
    var fileService: RoutineFileService

    @State private var showImportConfirmation = false
    #if os(iOS)
    @State private var shareItem: ShareItem?
    #endif

    var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: 8) {
                Button {
                    fileService.exportRoutines(from: modelContext)
                    #if os(iOS)
                    if fileService.lastError == nil {
                        shareItem = ShareItem(url: Constants.FilePaths.routinesShareFile)
                    }
                    #endif
                } label: {
                    Label("Export", systemImage: "square.and.arrow.up")
                }

                Button {
                    showImportConfirmation = true
                } label: {
                    Label("Import", systemImage: "square.and.arrow.down")
                }

                #if os(macOS)
                Button {
                    fileService.openInEditor(from: modelContext)
                } label: {
                    Label("Edit in Editor", systemImage: "pencil.and.outline")
                }
                #endif
            }
            .controlSize(.small)
            .buttonStyle(.bordered)

            if let error = fileService.lastError {
                Text(error)
                    .font(.caption2)
                    .foregroundStyle(.red)
                    .lineLimit(2)
            } else if let success = fileService.lastSuccess {
                Text(success)
                    .font(.caption2)
                    .foregroundStyle(.green)
                    .lineLimit(1)
            }
        }
        .confirmationDialog(
            "Replace all routines?",
            isPresented: $showImportConfirmation,
            titleVisibility: .visible
        ) {
            Button("Replace All", role: .destructive) {
                fileService.importRoutines(into: modelContext)
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will delete all existing routines and replace them with the ones from the JSON file.")
        }
        #if os(iOS)
        .sheet(item: $shareItem) { item in
            ActivityView(url: item.url)
        }
        #endif
    }
}

#if os(iOS)
private struct ShareItem: Identifiable {
    let id = UUID()
    let url: URL
}

private struct ActivityView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [url], applicationActivities: nil)
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}
#endif
