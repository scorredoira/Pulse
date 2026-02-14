import SwiftUI
import SwiftData
import PhotosUI

struct RoutineSettingsTab: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Routine.sortOrder) private var routines: [Routine]
    var routineFileService: RoutineFileService

    @State private var selectedRoutine: Routine?
    @State private var isAddingRoutine = false
    @State private var newRoutineName = ""
    @State private var isRenamingRoutine = false
    @State private var renameRoutineName = ""

    // Exercise form state (shared for add & edit)
    @State private var isExerciseSheetPresented = false
    @State private var editingExercise: Exercise?
    @State private var formName = ""
    @State private var formMinutes = 0
    @State private var formSeconds = 30
    @State private var formDescription = ""
    @State private var formIcon = "figure.walk"
    @State private var formSets = 1
    @State private var formRestSeconds = 15
    @State private var formRestAfterSeconds = 0
    @State private var formIsRepBased = false
    @State private var formReps = 0
    @State private var formSecondsPerRep = 5
    @State private var formImageFileNames: [String] = []
    @State private var selectedPhotoItem: PhotosPickerItem?
    #if os(iOS)
    @State private var routineEditMode: EditMode = .inactive
    @State private var exerciseEditMode: EditMode = .inactive
    #endif

    private let iconOptions = [
        "figure.walk", "figure.run", "figure.core.training",
        "figure.flexibility", "figure.strengthtraining.functional",
        "figure.cooldown", "figure.yoga", "figure.dance",
    ]

    private var isEditing: Bool { editingExercise != nil }

    var body: some View {
        mainContent
        .sheet(isPresented: $isAddingRoutine) {
            routineNameSheet(
                title: "New Routine",
                text: $newRoutineName,
                actionLabel: "Add",
                action: addRoutine
            )
        }
        .sheet(isPresented: $isRenamingRoutine) {
            routineNameSheet(
                title: "Rename Routine",
                text: $renameRoutineName,
                actionLabel: "Rename",
                action: applyRenameRoutine
            )
        }
        .sheet(isPresented: $isExerciseSheetPresented) {
            exerciseFormSheet
        }
        #if os(macOS)
        .onAppear {
            selectedRoutine = routines.first
        }
        #endif
    }

    // MARK: - Platform layout

    @ViewBuilder
    private var mainContent: some View {
        #if os(macOS)
        HSplitView {
            routineListPanel
            exercisePanel
        }
        #else
        iOSRoutineList
        #endif
    }

    // MARK: - iOS Routine List (Screen 1)

    #if os(iOS)
    private var iOSRoutineList: some View {
        List {
            ForEach(routines) { routine in
                if routineEditMode == .active {
                    iOSRoutineRow(routine)
                } else {
                    NavigationLink {
                        iOSExerciseEditor(for: routine)
                    } label: {
                        iOSRoutineRow(routine)
                    }
                }
            }
            .onMove { from, to in
                moveRoutines(from: from, to: to)
            }

            if routineEditMode != .active {
                Section {
                    RoutineImportExportSection(fileService: routineFileService)
                }
            }
        }
        .environment(\.editMode, $routineEditMode)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    withAnimation {
                        routineEditMode = routineEditMode == .active ? .inactive : .active
                    }
                } label: {
                    if routineEditMode == .active {
                        Text("Done")
                    } else {
                        Label("Reorder", systemImage: "line.3.horizontal")
                    }
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    isAddingRoutine = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
    }

    private func iOSRoutineRow(_ routine: Routine) -> some View {
        HStack(spacing: 12) {
            Image(systemName: routine.exercises.first?.iconName ?? "figure.walk")
                .font(.title3)
                .foregroundStyle(.accent)
                .frame(width: 32, height: 32)
                .background(Color.accentColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 8, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(routine.name)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(routine.isActive ? .primary : .secondary)
                    if routine.isDefault {
                        Text("Default")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(.accent.opacity(0.1))
                            .clipShape(Capsule())
                    }
                }
                Text(iOSRoutineSubtitle(routine))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Toggle("", isOn: Binding(
                get: { routine.isActive },
                set: { routine.isActive = $0 }
            ))
            .labelsHidden()
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive) {
                deleteRoutine(routine)
            } label: {
                Label("Delete", systemImage: "trash")
            }
            Button {
                selectedRoutine = routine
                renameRoutineName = routine.name
                isRenamingRoutine = true
            } label: {
                Label("Rename", systemImage: "pencil")
            }
            .tint(.orange)
        }
        .contextMenu {
            Button("Rename...") {
                selectedRoutine = routine
                renameRoutineName = routine.name
                isRenamingRoutine = true
            }
            if !routine.isDefault {
                Button("Set as Default") { setAsDefault(routine) }
            }
            Divider()
            Button("Delete", role: .destructive) { deleteRoutine(routine) }
        }
    }

    private func iOSRoutineSubtitle(_ routine: Routine) -> String {
        let count = routine.exercises.count
        if count == 0 { return "No exercises" }
        let duration = TimeFormatting.formatMinutesSeconds(routine.totalDurationSeconds)
        return "\(count) exercise\(count == 1 ? "" : "s") · \(duration) · every \(routine.intervalMinutes)m"
    }

    // MARK: - iOS Exercise Editor (Screen 2)

    private func iOSExerciseEditor(for routine: Routine) -> some View {
        List {
            if exerciseEditMode != .active {
                Section {
                    Stepper(
                        "Interval: \(routine.intervalMinutes) min",
                        value: Binding(
                            get: { routine.intervalMinutes },
                            set: { routine.intervalMinutes = $0 }
                        ),
                        in: Constants.minimumWorkIntervalMinutes...Constants.maximumWorkIntervalMinutes,
                        step: 5
                    )

                    Toggle("Active", isOn: Binding(
                        get: { routine.isActive },
                        set: { routine.isActive = $0 }
                    ))
                } header: {
                    Text("Total: \(TimeFormatting.formatMinutesSeconds(routine.totalDurationSeconds))")
                }
            }

            Section("Exercises") {
                ForEach(routine.sortedExercises, id: \.sortOrder) { exercise in
                    exerciseRow(exercise, in: routine)
                }
                .onMove { from, to in
                    moveExercises(in: routine, from: from, to: to)
                }
            }
        }
        .environment(\.editMode, $exerciseEditMode)
        .navigationTitle(routine.name)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    withAnimation {
                        exerciseEditMode = exerciseEditMode == .active ? .inactive : .active
                    }
                } label: {
                    if exerciseEditMode == .active {
                        Text("Done")
                    } else {
                        Label("Reorder", systemImage: "line.3.horizontal")
                    }
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    selectedRoutine = routine
                    openExerciseForm(exercise: nil)
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .onAppear {
            selectedRoutine = routine
            exerciseEditMode = .inactive
        }
    }
    #endif

    // MARK: - macOS Routine list (left panel)

    private var routineListPanel: some View {
        VStack(alignment: .leading, spacing: 0) {
            List(routines, selection: $selectedRoutine) { routine in
                HStack {
                    Text(routine.name)
                        .foregroundStyle(routine.isActive ? .primary : .secondary)
                    Spacer()
                    if routine.isDefault {
                        Text("Default")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(.accent.opacity(0.1))
                            .clipShape(Capsule())
                    }
                    if !routine.isActive {
                        Text("Off")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(.secondary.opacity(0.1))
                            .clipShape(Capsule())
                    }
                }
                .tag(routine)
                .contextMenu {
                    Button("Rename...") {
                        renameRoutineName = routine.name
                        selectedRoutine = routine
                        isRenamingRoutine = true
                    }
                    if !routine.isDefault {
                        Button("Set as Default") { setAsDefault(routine) }
                    }
                    Divider()
                    Button("Delete", role: .destructive) { deleteRoutine(routine) }
                }
            }
            #if os(macOS)
            .frame(minWidth: 200)
            #endif

            Divider()

            HStack(spacing: 8) {
                Button {
                    isAddingRoutine = true
                } label: {
                    Image(systemName: "plus")
                }

                Button {
                    if let selected = selectedRoutine { deleteRoutine(selected) }
                } label: {
                    Image(systemName: "minus")
                }
                .disabled(selectedRoutine == nil)

                Spacer()

                Button {
                    guard let routine = selectedRoutine else { return }
                    renameRoutineName = routine.name
                    isRenamingRoutine = true
                } label: {
                    Image(systemName: "pencil")
                }
                .disabled(selectedRoutine == nil)
            }
            .controlSize(.regular)
            .buttonStyle(.bordered)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)

            Divider()

            RoutineImportExportSection(fileService: routineFileService)
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
        }
        .onDisappear {
            routineFileService.stopWatching()
        }
    }

    // MARK: - macOS Exercise list (right panel)

    private var exercisePanel: some View {
        VStack {
            if let routine = selectedRoutine {
                exerciseEditor(for: routine)
            } else {
                ContentUnavailableView(
                    "Select a Routine",
                    systemImage: "list.bullet",
                    description: Text("Select a routine to edit its exercises.")
                )
            }
        }
        #if os(macOS)
        .frame(minWidth: 300)
        #endif
    }

    private func exerciseEditor(for routine: Routine) -> some View {
        List {
            Section {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(routine.name)
                            .font(.headline)
                        Text("Total: \(TimeFormatting.formatMinutesSeconds(routine.totalDurationSeconds))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button {
                        openExerciseForm(exercise: nil)
                    } label: {
                        Label("Add Exercise", systemImage: "plus")
                    }
                }

                Stepper(
                    "Interval: \(routine.intervalMinutes) min",
                    value: Binding(
                        get: { routine.intervalMinutes },
                        set: { routine.intervalMinutes = $0 }
                    ),
                    in: Constants.minimumWorkIntervalMinutes...Constants.maximumWorkIntervalMinutes,
                    step: 5
                )

                Toggle("Active", isOn: Binding(
                    get: { routine.isActive },
                    set: { routine.isActive = $0 }
                ))
            }

            Section {
                ForEach(routine.sortedExercises, id: \.sortOrder) { exercise in
                    exerciseRow(exercise, in: routine)
                }
                .onMove { from, to in
                    moveExercises(in: routine, from: from, to: to)
                }
            }
        }
    }

    private func exerciseRow(_ exercise: Exercise, in routine: Routine) -> some View {
        HStack(spacing: 12) {
            Image(systemName: exercise.iconName)
                .font(.title3)
                .frame(width: 28)
                .foregroundStyle(.accent)

            VStack(alignment: .leading, spacing: 2) {
                Text(exercise.name)
                    .font(.body)
                    .fontWeight(.medium)
                Text(exerciseSummary(exercise))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                openExerciseForm(exercise: exercise)
            } label: {
                Image(systemName: "pencil")
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) {
                deleteExercise(exercise, from: routine)
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
        .contextMenu {
            Button("Edit...") { openExerciseForm(exercise: exercise) }
            Divider()
            Button("Move Up") { moveExerciseUp(exercise, in: routine) }
                .disabled(exercise.sortOrder == 0)
            Button("Move Down") { moveExerciseDown(exercise, in: routine) }
                .disabled(exercise.sortOrder >= routine.exercises.count - 1)
            Divider()
            Button("Delete", role: .destructive) { deleteExercise(exercise, from: routine) }
        }
    }

    // MARK: - Routine name sheet (add & rename)

    private func routineNameSheet(title: String, text: Binding<String>, actionLabel: String, action: @escaping () -> Void) -> some View {
        #if os(macOS)
        VStack(spacing: 20) {
            Text(title)
                .font(.headline)

            TextField("Routine name", text: text)
                .textFieldStyle(.roundedBorder)
                .frame(minWidth: 220)

            HStack(spacing: 12) {
                Button("Cancel") {
                    isAddingRoutine = false
                    isRenamingRoutine = false
                }
                .keyboardShortcut(.cancelAction)

                Button(actionLabel) {
                    action()
                    isAddingRoutine = false
                    isRenamingRoutine = false
                }
                .keyboardShortcut(.defaultAction)
                .disabled(text.wrappedValue.isEmpty)
            }
            .controlSize(.regular)
        }
        .padding(24)
        .frame(width: 320)
        #else
        NavigationStack {
            Form {
                TextField("Routine name", text: text)
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        isAddingRoutine = false
                        isRenamingRoutine = false
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(actionLabel) {
                        action()
                        isAddingRoutine = false
                        isRenamingRoutine = false
                    }
                    .disabled(text.wrappedValue.isEmpty)
                }
            }
        }
        #endif
    }

    // MARK: - Exercise form sheet (add & edit)

    private var exerciseFormSheet: some View {
        #if os(macOS)
        exerciseFormContent
            .padding()
            .frame(width: 400, height: 650)
        #else
        NavigationStack {
            exerciseFormContent
                .navigationTitle(isEditing ? "Edit Exercise" : "New Exercise")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") {
                            isExerciseSheetPresented = false
                        }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button(isEditing ? "Save" : "Add") {
                            if isEditing {
                                saveExerciseEdits()
                            } else {
                                addExercise()
                            }
                        }
                        .disabled(formName.isEmpty)
                    }
                }
        }
        #endif
    }

    private var exerciseFormContent: some View {
        VStack(spacing: 0) {
            #if os(macOS)
            Text(isEditing ? "Edit Exercise" : "New Exercise")
                .font(.title3.bold())
                .padding(.top)
            #endif

            Form {
                Section {
                    TextField("Name", text: $formName)
                    TextField("Description", text: $formDescription)
                }

                Section("Timing") {
                    Picker("Mode", selection: $formIsRepBased) {
                        Text("Time").tag(false)
                        Text("Reps").tag(true)
                    }
                    .pickerStyle(.segmented)

                    if formIsRepBased {
                        #if os(macOS)
                        LabeledContent("Reps") {
                            TextField("10", value: $formReps, format: .number)
                                .frame(width: 60)
                                .textFieldStyle(.roundedBorder)
                                .multilineTextAlignment(.center)
                        }
                        LabeledContent("Sec per rep") {
                            TextField("5", value: $formSecondsPerRep, format: .number)
                                .frame(width: 60)
                                .textFieldStyle(.roundedBorder)
                                .multilineTextAlignment(.center)
                        }
                        #else
                        Stepper("Reps: \(formReps)", value: $formReps, in: 1...200)
                        Stepper("Sec per rep: \(formSecondsPerRep)", value: $formSecondsPerRep, in: 1...120)
                        #endif
                        LabeledContent("Total duration") {
                            Text(TimeFormatting.formatMinutesSeconds(max(formReps, 1) * max(formSecondsPerRep, 1)))
                                .foregroundStyle(.secondary)
                        }
                    } else {
                        #if os(macOS)
                        LabeledContent("Minutes") {
                            TextField("0", value: $formMinutes, format: .number)
                                .frame(width: 60)
                                .textFieldStyle(.roundedBorder)
                                .multilineTextAlignment(.center)
                        }
                        LabeledContent("Seconds") {
                            TextField("0", value: $formSeconds, format: .number)
                                .frame(width: 60)
                                .textFieldStyle(.roundedBorder)
                                .multilineTextAlignment(.center)
                        }
                        #else
                        Stepper("Minutes: \(formMinutes)", value: $formMinutes, in: 0...30)
                        Stepper("Seconds: \(formSeconds)", value: $formSeconds, in: 0...59)
                        #endif
                    }
                }

                Section("Sets & Rest") {
                    #if os(macOS)
                    LabeledContent("Sets") {
                        TextField("1", value: $formSets, format: .number)
                            .frame(width: 60)
                            .textFieldStyle(.roundedBorder)
                            .multilineTextAlignment(.center)
                    }
                    #else
                    Stepper("Sets: \(formSets)", value: $formSets, in: 1...20)
                    #endif

                    if formSets > 1 {
                        #if os(macOS)
                        LabeledContent("Rest between sets (sec)") {
                            TextField("15", value: $formRestSeconds, format: .number)
                                .frame(width: 60)
                                .textFieldStyle(.roundedBorder)
                                .multilineTextAlignment(.center)
                        }
                        #else
                        Stepper("Rest between sets: \(formRestSeconds)s", value: $formRestSeconds, in: 1...300, step: 5)
                        #endif
                    }

                    #if os(macOS)
                    LabeledContent("Rest after (sec)") {
                        TextField("0", value: $formRestAfterSeconds, format: .number)
                            .frame(width: 60)
                            .textFieldStyle(.roundedBorder)
                            .multilineTextAlignment(.center)
                    }
                    #else
                    Stepper("Rest after: \(formRestAfterSeconds)s", value: $formRestAfterSeconds, in: 0...300, step: 5)
                    #endif
                }

                Section("Icon") {
                    Picker("Icon", selection: $formIcon) {
                        ForEach(iconOptions, id: \.self) { icon in
                            Image(systemName: icon).tag(icon)
                        }
                    }
                }

                Section("Image") {
                    if !formImageFileNames.isEmpty {
                        ForEach(Array(formImageFileNames.enumerated()), id: \.offset) { index, fileName in
                            HStack {
                                exerciseImageThumbnail(fileName: fileName)
                                Spacer()
                                Button(role: .destructive) {
                                    removeFormImage(at: index)
                                } label: {
                                    Image(systemName: "trash")
                                }
                                .buttonStyle(.bordered)
                            }
                        }
                    }

                    PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                        Label("Add Image", systemImage: "photo.badge.plus")
                    }
                    .onChange(of: selectedPhotoItem) { _, newItem in
                        guard let newItem else { return }
                        Task {
                            await loadAndSavePhoto(from: newItem)
                            selectedPhotoItem = nil
                        }
                    }
                }
            }
            .formStyle(.grouped)

            #if os(macOS)
            HStack(spacing: 12) {
                Button("Cancel") {
                    isExerciseSheetPresented = false
                }
                .keyboardShortcut(.cancelAction)

                Button(isEditing ? "Save" : "Add") {
                    if isEditing {
                        saveExerciseEdits()
                    } else {
                        addExercise()
                    }
                }
                .keyboardShortcut(.defaultAction)
                .disabled(formName.isEmpty)
            }
            .controlSize(.regular)
            .padding(.bottom, 4)
            #endif
        }
    }

    @ViewBuilder
    private func exerciseImageThumbnail(fileName: String) -> some View {
        let url = Constants.FilePaths.imagesDirectory.appendingPathComponent(fileName)
        if let data = try? Data(contentsOf: url) {
            #if os(macOS)
            if let nsImage = NSImage(data: data) {
                Image(nsImage: nsImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxHeight: 80)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            #else
            if let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxHeight: 80)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            #endif
        } else {
            Label(fileName, systemImage: "photo")
                .foregroundStyle(.secondary)
        }
    }

    private func removeFormImage(at index: Int) {
        let fileName = formImageFileNames.remove(at: index)
        let url = Constants.FilePaths.imagesDirectory.appendingPathComponent(fileName)
        try? FileManager.default.removeItem(at: url)
    }

    private func loadAndSavePhoto(from item: PhotosPickerItem) async {
        guard let data = try? await item.loadTransferable(type: Data.self) else { return }
        let imagesDir = Constants.FilePaths.imagesDirectory
        try? FileManager.default.createDirectory(at: imagesDir, withIntermediateDirectories: true)
        let fileName = UUID().uuidString + ".png"
        let fileURL = imagesDir.appendingPathComponent(fileName)
        try? data.write(to: fileURL, options: .atomic)
        await MainActor.run {
            formImageFileNames.append(fileName)
        }
    }

    // MARK: - Actions

    private func openExerciseForm(exercise: Exercise?) {
        if let exercise {
            editingExercise = exercise
            formName = exercise.name
            formMinutes = exercise.durationSeconds / 60
            formSeconds = exercise.durationSeconds % 60
            formDescription = exercise.exerciseDescription
            formIcon = exercise.iconName
            formSets = exercise.sets
            formRestSeconds = exercise.restSeconds
            formRestAfterSeconds = exercise.restAfterSeconds
            formIsRepBased = exercise.reps > 0
            formReps = exercise.reps > 0 ? exercise.reps : 10
            formSecondsPerRep = exercise.secondsPerRep
            formImageFileNames = exercise.imageFileNames
        } else {
            editingExercise = nil
            formName = ""
            formMinutes = 0
            formSeconds = 30
            formDescription = ""
            formIcon = "figure.walk"
            formSets = 1
            formRestSeconds = 15
            formRestAfterSeconds = 0
            formIsRepBased = false
            formReps = 10
            formSecondsPerRep = 5
            formImageFileNames = []
        }
        selectedPhotoItem = nil
        isExerciseSheetPresented = true
    }

    private func addRoutine() {
        guard !newRoutineName.isEmpty else { return }
        let routine = Routine(name: newRoutineName, sortOrder: routines.count)
        modelContext.insert(routine)
        newRoutineName = ""
        selectedRoutine = routine
    }

    private func applyRenameRoutine() {
        guard let routine = selectedRoutine, !renameRoutineName.isEmpty else { return }
        routine.name = renameRoutineName
    }

    private func deleteRoutine(_ routine: Routine) {
        if selectedRoutine == routine { selectedRoutine = nil }
        modelContext.delete(routine)
        reindexRoutines()
    }

    private func setAsDefault(_ routine: Routine) {
        for r in routines { r.isDefault = false }
        routine.isDefault = true
    }

    private func moveRoutines(from source: IndexSet, to destination: Int) {
        var reordered = routines
        reordered.move(fromOffsets: source, toOffset: destination)
        for (index, routine) in reordered.enumerated() {
            routine.sortOrder = index
        }
    }

    private func reindexRoutines() {
        for (index, routine) in routines.enumerated() {
            routine.sortOrder = index
        }
    }

    private func addExercise() {
        guard let routine = selectedRoutine, !formName.isEmpty else { return }

        let reps = formIsRepBased ? max(formReps, 1) : 0
        let secondsPerRep = max(formSecondsPerRep, 1)
        let totalSeconds: Int
        if formIsRepBased {
            totalSeconds = reps * secondsPerRep
        } else {
            totalSeconds = max(formMinutes * 60 + formSeconds, 5)
        }
        let sets = max(formSets, 1)
        let exercise = Exercise(
            name: formName,
            durationSeconds: totalSeconds,
            exerciseDescription: formDescription,
            iconName: formIcon,
            sortOrder: routine.exercises.count,
            sets: sets,
            restSeconds: sets > 1 ? max(formRestSeconds, 1) : 0,
            restAfterSeconds: max(formRestAfterSeconds, 0),
            imageFileNames: formImageFileNames,
            reps: reps,
            secondsPerRep: secondsPerRep
        )
        routine.exercises.append(exercise)
        isExerciseSheetPresented = false
    }

    private func saveExerciseEdits() {
        guard let exercise = editingExercise else { return }

        let reps = formIsRepBased ? max(formReps, 1) : 0
        let secondsPerRep = max(formSecondsPerRep, 1)

        exercise.name = formName
        exercise.reps = reps
        exercise.secondsPerRep = secondsPerRep
        if formIsRepBased {
            exercise.durationSeconds = reps * secondsPerRep
        } else {
            exercise.durationSeconds = max(formMinutes * 60 + formSeconds, 5)
        }
        exercise.exerciseDescription = formDescription
        exercise.iconName = formIcon
        exercise.sets = max(formSets, 1)
        exercise.restSeconds = exercise.sets > 1 ? max(formRestSeconds, 1) : 0
        exercise.restAfterSeconds = max(formRestAfterSeconds, 0)
        exercise.imageFileNames = formImageFileNames

        isExerciseSheetPresented = false
        editingExercise = nil
    }

    private func deleteExercise(_ exercise: Exercise, from routine: Routine) {
        RoutineFileService.deleteImageFiles(for: exercise)
        routine.exercises.removeAll { $0.sortOrder == exercise.sortOrder && $0.name == exercise.name }
        modelContext.delete(exercise)
        reindexExercises(in: routine)
    }

    private func moveExerciseUp(_ exercise: Exercise, in routine: Routine) {
        let sorted = routine.sortedExercises
        guard let index = sorted.firstIndex(where: { $0.sortOrder == exercise.sortOrder }),
              index > 0 else { return }
        sorted[index].sortOrder = index - 1
        sorted[index - 1].sortOrder = index
    }

    private func moveExerciseDown(_ exercise: Exercise, in routine: Routine) {
        let sorted = routine.sortedExercises
        guard let index = sorted.firstIndex(where: { $0.sortOrder == exercise.sortOrder }),
              index < sorted.count - 1 else { return }
        sorted[index].sortOrder = index + 1
        sorted[index + 1].sortOrder = index
    }

    private func moveExercises(in routine: Routine, from source: IndexSet, to destination: Int) {
        var exercises = routine.sortedExercises
        exercises.move(fromOffsets: source, toOffset: destination)
        for (index, exercise) in exercises.enumerated() {
            exercise.sortOrder = index
        }
    }

    private func reindexExercises(in routine: Routine) {
        for (index, exercise) in routine.sortedExercises.enumerated() {
            exercise.sortOrder = index
        }
    }

    private func exerciseSummary(_ exercise: Exercise) -> String {
        var parts: [String] = []
        if exercise.reps > 0 {
            parts.append("\(exercise.reps) reps x \(exercise.secondsPerRep)s")
        } else {
            parts.append(TimeFormatting.formatMinutesSeconds(exercise.durationSeconds))
        }
        if exercise.sets > 1 {
            parts.append("x\(exercise.sets) (\(exercise.restSeconds)s rest)")
        }
        if exercise.restAfterSeconds > 0 {
            parts.append("+ \(exercise.restAfterSeconds)s after")
        }
        return parts.joined(separator: " · ")
    }
}
