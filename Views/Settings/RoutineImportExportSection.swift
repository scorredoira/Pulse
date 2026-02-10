import SwiftUI
import SwiftData

struct RoutineImportExportSection: View {
    @Environment(\.modelContext) private var modelContext
    var fileService: RoutineFileService

    @State private var showImportConfirmation = false

    var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: 8) {
                Button {
                    fileService.exportRoutines(from: modelContext)
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
    }
}
