import Foundation
import SwiftData
import Observation
#if os(macOS)
import AppKit
#endif

@Observable
@MainActor
final class RoutineFileService {
    var lastError: String?
    var lastSuccess: String?
    private var watchSource: DispatchSourceFileSystemObject?
    private var debounceWork: DispatchWorkItem?
    private var fileDescriptor: Int32 = -1

    // MARK: - Export

    func exportRoutines(from context: ModelContext) {
        do {
            let descriptor = FetchDescriptor<Routine>(sortBy: [SortDescriptor(\Routine.sortOrder)])
            let routines = try context.fetch(descriptor)
            let dtos = routines.map { $0.toDTO() }
            let file = RoutineFile(routines: dtos)

            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(file)

            let dir = Constants.FilePaths.configDirectory
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            try data.write(to: Constants.FilePaths.routinesFile, options: .atomic)
            try data.write(to: Constants.FilePaths.routinesShareFile, options: .atomic)

            lastError = nil
            lastSuccess = "Exported \(routines.count) routine(s)"
        } catch {
            lastError = "Export failed: \(error.localizedDescription)"
        }
    }

    // MARK: - Import

    func importRoutines(into context: ModelContext) {
        do {
            let url = Constants.FilePaths.routinesFile
            guard FileManager.default.fileExists(atPath: url.path) else {
                lastError = "No file found at \(url.path). Export first to create the file."
                return
            }

            let data = try Data(contentsOf: url)
            let file = try JSONDecoder().decode(RoutineFile.self, from: data)

            try validate(file)

            // Collect old image files before deleting routines
            let oldImageFiles = collectImageFiles(from: context)

            // Delete existing routines
            let existing = try context.fetch(FetchDescriptor<Routine>())
            for routine in existing {
                context.delete(routine)
            }

            // Insert new routines
            for (index, dto) in file.routines.enumerated() {
                let routine = dto.toModel(fallbackSortOrder: index)
                context.insert(routine)
            }

            try context.save()

            // Clean up old image files
            deleteImageFiles(oldImageFiles)

            lastError = nil
            lastSuccess = "Imported \(file.routines.count) routine(s)"
        } catch let error as ValidationError {
            lastError = error.message
        } catch {
            lastError = "Import failed: \(error.localizedDescription)"
        }
    }

    // MARK: - Open in Editor (macOS only)

    #if os(macOS)
    func openInEditor(from context: ModelContext) {
        exportRoutines(from: context)
        guard lastError == nil else { return }

        let url = Constants.FilePaths.routinesFile
        NSWorkspace.shared.open(url)

        startWatching(context: context)
    }
    #endif

    // MARK: - Import from URL (iOS file sharing / AirDrop)

    func importRoutines(from url: URL, into context: ModelContext) {
        do {
            let accessing = url.startAccessingSecurityScopedResource()
            defer { if accessing { url.stopAccessingSecurityScopedResource() } }

            let data = try Data(contentsOf: url)
            let file = try JSONDecoder().decode(RoutineFile.self, from: data)

            try validate(file)

            // Collect old image files before deleting routines
            let oldImageFiles = collectImageFiles(from: context)

            let existing = try context.fetch(FetchDescriptor<Routine>())
            for routine in existing {
                context.delete(routine)
            }

            for (index, dto) in file.routines.enumerated() {
                let routine = dto.toModel(fallbackSortOrder: index)
                context.insert(routine)
            }

            try context.save()

            // Clean up old image files
            deleteImageFiles(oldImageFiles)

            lastError = nil
            lastSuccess = "Imported \(file.routines.count) routine(s)"
        } catch let error as ValidationError {
            lastError = error.message
        } catch {
            lastError = "Import failed: \(error.localizedDescription)"
        }
    }

    // MARK: - File Watching

    func startWatching(context: ModelContext) {
        stopWatching()

        let dirURL = Constants.FilePaths.configDirectory
        let dirPath = dirURL.path

        // Ensure directory exists
        try? FileManager.default.createDirectory(at: dirURL, withIntermediateDirectories: true)

        fileDescriptor = open(dirPath, O_EVTONLY)
        guard fileDescriptor >= 0 else { return }

        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fileDescriptor,
            eventMask: .write,
            queue: DispatchQueue.global(qos: .utility)
        )

        source.setEventHandler { [weak self] in
            self?.debounceWork?.cancel()
            let work = DispatchWorkItem { [weak self] in
                Task { @MainActor in
                    self?.importRoutines(into: context)
                }
            }
            self?.debounceWork = work
            DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 0.5, execute: work)
        }

        source.setCancelHandler { [weak self] in
            if let fd = self?.fileDescriptor, fd >= 0 {
                close(fd)
                self?.fileDescriptor = -1
            }
        }

        source.resume()
        watchSource = source
    }

    func stopWatching() {
        debounceWork?.cancel()
        debounceWork = nil
        watchSource?.cancel()
        watchSource = nil
    }

    // MARK: - Image Cleanup

    private func collectImageFiles(from context: ModelContext) -> [String] {
        guard let routines = try? context.fetch(FetchDescriptor<Routine>()) else { return [] }
        return routines.flatMap { $0.exercises.flatMap { $0.imageFileNames } }
    }

    private func deleteImageFiles(_ fileNames: [String]) {
        let imagesDir = Constants.FilePaths.imagesDirectory
        for fileName in fileNames {
            let url = imagesDir.appendingPathComponent(fileName)
            try? FileManager.default.removeItem(at: url)
        }
    }

    static func deleteImageFiles(for exercise: Exercise) {
        let imagesDir = Constants.FilePaths.imagesDirectory
        for fileName in exercise.imageFileNames {
            let url = imagesDir.appendingPathComponent(fileName)
            try? FileManager.default.removeItem(at: url)
        }
    }

    // MARK: - Validation

    private struct ValidationError: Error {
        let message: String
    }

    private func validate(_ file: RoutineFile) throws {
        guard !file.routines.isEmpty else {
            throw ValidationError(message: "File contains no routines.")
        }
        for (i, routine) in file.routines.enumerated() {
            guard !routine.name.trimmingCharacters(in: .whitespaces).isEmpty else {
                throw ValidationError(message: "Routine \(i + 1) has an empty name.")
            }
            for (j, exercise) in routine.exercises.enumerated() {
                guard !exercise.name.trimmingCharacters(in: .whitespaces).isEmpty else {
                    throw ValidationError(message: "Exercise \(j + 1) in \"\(routine.name)\" has an empty name.")
                }
                let isRepBased = (exercise.reps ?? 0) > 0
                if !isRepBased {
                    guard exercise.durationSeconds >= 1 else {
                        throw ValidationError(message: "\"\(exercise.name)\" in \"\(routine.name)\" must have duration >= 1 second.")
                    }
                }
                guard exercise.sets >= 1 else {
                    throw ValidationError(message: "\"\(exercise.name)\" in \"\(routine.name)\" must have sets >= 1.")
                }
            }
        }
    }
}
