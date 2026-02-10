import SwiftUI
import SwiftData

struct RoutineSettingsTab: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var routines: [Routine]
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

    private let iconOptions = [
        "figure.walk", "figure.run", "figure.core.training",
        "figure.flexibility", "figure.strengthtraining.functional",
        "figure.cooldown", "figure.yoga", "figure.dance",
    ]

    private var isEditing: Bool { editingExercise != nil }

    var body: some View {
        splitContent
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
        .onAppear {
            selectedRoutine = routines.first
        }
    }

    @ViewBuilder
    private var splitContent: some View {
        #if os(macOS)
        HSplitView {
            routineListPanel
            exercisePanel
        }
        #else
        NavigationSplitView {
            routineListPanel
        } detail: {
            exercisePanel
        }
        #endif
    }

    // MARK: - Routine list (left panel)

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
            .frame(minWidth: 200)

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

    // MARK: - Exercise list (right panel)

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
        .frame(minWidth: 300)
    }

    private func exerciseEditor(for routine: Routine) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: Spacing.sm) {
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

                Divider()

                HStack(spacing: Spacing.lg) {
                    HStack(spacing: 6) {
                        Text("Interval:")
                        Stepper(
                            "\(routine.intervalMinutes) min",
                            value: Binding(
                                get: { routine.intervalMinutes },
                                set: { routine.intervalMinutes = $0 }
                            ),
                            in: Constants.minimumWorkIntervalMinutes...Constants.maximumWorkIntervalMinutes,
                            step: 5
                        )
                    }

                    Spacer()

                    Toggle("Active", isOn: Binding(
                        get: { routine.isActive },
                        set: { routine.isActive = $0 }
                    ))
                    .toggleStyle(.switch)
                }
            }
            .padding(.horizontal)
            .padding(.top)

            List {
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
                HStack(spacing: 4) {
                    Text(TimeFormatting.formatMinutesSeconds(exercise.durationSeconds))
                    if exercise.sets > 1 {
                        Text("x\(exercise.sets)")
                            .fontWeight(.medium)
                        Text("(\(exercise.restSeconds)s rest)")
                    }
                    if exercise.restAfterSeconds > 0 {
                        Text("+ \(exercise.restAfterSeconds)s after")
                    }
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
            }

            Spacer()

            HStack(spacing: 6) {
                Button {
                    openExerciseForm(exercise: exercise)
                } label: {
                    Image(systemName: "pencil")
                }

                Button(role: .destructive) {
                    deleteExercise(exercise, from: routine)
                } label: {
                    Image(systemName: "trash")
                }
            }
            .buttonStyle(.bordered)
            .controlSize(.regular)
        }
        .padding(.vertical, 4)
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
    }

    // MARK: - Exercise form sheet (add & edit)

    private var exerciseFormSheet: some View {
        VStack(spacing: 20) {
            Text(isEditing ? "Edit Exercise" : "New Exercise")
                .font(.title3.bold())

            Form {
                TextField("Name", text: $formName)

                LabeledContent("Duration") {
                    HStack(spacing: 8) {
                        TextField("0", value: $formMinutes, format: .number)
                            .frame(width: 60)
                            .textFieldStyle(.roundedBorder)
                            .multilineTextAlignment(.center)
                        Text("min")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .frame(width: 30, alignment: .leading)

                        TextField("0", value: $formSeconds, format: .number)
                            .frame(width: 60)
                            .textFieldStyle(.roundedBorder)
                            .multilineTextAlignment(.center)
                        Text("sec")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .frame(width: 30, alignment: .leading)
                    }
                }

                LabeledContent("Sets") {
                    HStack(spacing: 8) {
                        TextField("1", value: $formSets, format: .number)
                            .frame(width: 60)
                            .textFieldStyle(.roundedBorder)
                            .multilineTextAlignment(.center)
                        Text("x")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                }

                if formSets > 1 {
                    LabeledContent("Rest between sets") {
                        HStack(spacing: 8) {
                            TextField("15", value: $formRestSeconds, format: .number)
                                .frame(width: 60)
                                .textFieldStyle(.roundedBorder)
                                .multilineTextAlignment(.center)
                            Text("sec")
                                .font(.callout)
                                .foregroundStyle(.secondary)
                                .frame(width: 30, alignment: .leading)
                        }
                    }
                }

                LabeledContent("Rest after exercise") {
                    HStack(spacing: 8) {
                        TextField("0", value: $formRestAfterSeconds, format: .number)
                            .frame(width: 60)
                            .textFieldStyle(.roundedBorder)
                            .multilineTextAlignment(.center)
                        Text("sec")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .frame(width: 30, alignment: .leading)
                    }
                }

                TextField("Description", text: $formDescription)

                Picker("Icon", selection: $formIcon) {
                    ForEach(iconOptions, id: \.self) { icon in
                        Label(icon, systemImage: icon).tag(icon)
                    }
                }
            }
            .formStyle(.grouped)

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
        }
        .padding()
        .frame(width: 400, height: 520)
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
        }
        isExerciseSheetPresented = true
    }

    private func addRoutine() {
        guard !newRoutineName.isEmpty else { return }
        let routine = Routine(name: newRoutineName)
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
    }

    private func setAsDefault(_ routine: Routine) {
        for r in routines { r.isDefault = false }
        routine.isDefault = true
    }

    private func addExercise() {
        guard let routine = selectedRoutine, !formName.isEmpty else { return }

        let totalSeconds = max(formMinutes * 60 + formSeconds, 5)
        let sets = max(formSets, 1)
        let exercise = Exercise(
            name: formName,
            durationSeconds: totalSeconds,
            exerciseDescription: formDescription,
            iconName: formIcon,
            sortOrder: routine.exercises.count,
            sets: sets,
            restSeconds: sets > 1 ? max(formRestSeconds, 1) : 0,
            restAfterSeconds: max(formRestAfterSeconds, 0)
        )
        routine.exercises.append(exercise)
        isExerciseSheetPresented = false
    }

    private func saveExerciseEdits() {
        guard let exercise = editingExercise else { return }

        exercise.name = formName
        exercise.durationSeconds = max(formMinutes * 60 + formSeconds, 5)
        exercise.exerciseDescription = formDescription
        exercise.iconName = formIcon
        exercise.sets = max(formSets, 1)
        exercise.restSeconds = exercise.sets > 1 ? max(formRestSeconds, 1) : 0
        exercise.restAfterSeconds = max(formRestAfterSeconds, 0)

        isExerciseSheetPresented = false
        editingExercise = nil
    }

    private func deleteExercise(_ exercise: Exercise, from routine: Routine) {
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
}
