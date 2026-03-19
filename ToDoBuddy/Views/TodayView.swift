import SwiftUI

struct TodayView: View {
    var taskStore: TaskStore
    @State private var newTaskTitle = ""
    @State private var showCopiedToast = false
    @State private var showMoveAllAlert = false

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                header
                Divider()
                taskList
                Divider()
                addTaskBar
            }
            .alert("Move All to Today?", isPresented: $showMoveAllAlert) {
                Button("Move All", action: { taskStore.moveAllMissedToToday() })
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("All \(taskStore.missedTasks.count) missed tasks will be moved to today.")
            }

            // Toast overlay
            if showCopiedToast {
                VStack {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.white)
                        Text("Copied to clipboard!")
                            .foregroundStyle(.white)
                            .font(.subheadline.bold())
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(Capsule().fill(.green))
                    .shadow(radius: 4)
                    .transition(.move(edge: .top).combined(with: .opacity))

                    Spacer()
                }
                .padding(.top, 8)
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Today's Tasks")
                    .font(.title2.bold())
                Text(formattedToday)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()

            let missedCount = taskStore.missedTasks.count
            if missedCount > 0 {
                Text("\(missedCount) missed")
                    .font(.caption.bold())
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(.red))
            }

            let tasks = taskStore.todayTasks
            let done = tasks.filter(\.isCompleted).count

            if done > 0 {
                Button {
                    copyCompletedTasks()
                } label: {
                    Label("Copy", systemImage: "doc.on.doc")
                        .font(.caption)
                }
                .buttonStyle(.borderless)
            }

            Text("\(done)/\(tasks.count)")
                .font(.title3.monospacedDigit())
                .foregroundStyle(.secondary)
        }
        .padding()
    }

    // MARK: - Task List

    private var taskList: some View {
        Group {
            let missed = taskStore.missedTasks
            let today = taskStore.todayTasks

            if missed.isEmpty && today.isEmpty {
                VStack {
                    Spacer()
                    Text("No tasks yet. Add one below!")
                        .foregroundStyle(.secondary)
                    Spacer()
                }
            } else {
                List {
                    if !missed.isEmpty {
                        Section {
                            ForEach(missed) { task in
                                MissedTaskRowView(
                                    task: task,
                                    dateLabel: friendlyDate(task.date),
                                    onComplete: { taskStore.toggleTask(task) },
                                    onReschedule: { taskStore.rescheduleToToday(task) },
                                    onDelete: { taskStore.deleteTask(task) },
                                    onRename: { taskStore.updateTaskTitle(task, newTitle: $0) }
                                )
                            }
                        } header: {
                            HStack {
                                Label("Missed", systemImage: "exclamationmark.triangle.fill")
                                    .foregroundStyle(.red)
                                    .font(.subheadline.bold())
                                Spacer()
                                if missed.count > 1 {
                                    Button {
                                        showMoveAllAlert = true
                                    } label: {
                                        Text("Move All to Today")
                                            .font(.caption)
                                            .foregroundStyle(.blue)
                                    }
                                    .buttonStyle(.borderless)
                                }
                            }
                        }
                    }

                    Section {
                        ForEach(today) { task in
                            TaskRowView(
                                task: task,
                                onToggle: { taskStore.toggleTask(task) },
                                onDelete: { taskStore.deleteTask(task) },
                                onRename: { taskStore.updateTaskTitle(task, newTitle: $0) }
                            )
                        }
                        .onMove { source, destination in
                            taskStore.moveTasks(for: taskStore.todayString, from: source, to: destination)
                        }
                    } header: {
                        if !missed.isEmpty {
                            Text("Today")
                                .font(.subheadline.bold())
                        }
                    }
                }
                .listStyle(.inset)
            }
        }
    }

    private func friendlyDate(_ dateStr: String) -> String {
        guard let date = taskStore.dateFromString(dateStr) else { return dateStr }
        let cal = Calendar.current
        if cal.isDateInYesterday(date) { return "Yesterday" }
        let days = cal.dateComponents([.day], from: date, to: Date()).day ?? 0
        return "\(days) days ago"
    }

    // MARK: - Add Task

    private var addTaskBar: some View {
        HStack {
            TextField("Add a new task...", text: $newTaskTitle)
                .textFieldStyle(.roundedBorder)
                .onSubmit(addTask)

            Button(action: addTask) {
                Image(systemName: "plus.circle.fill")
                    .font(.title2)
                    .contentShape(Rectangle())
            }
            .disabled(newTaskTitle.trimmingCharacters(in: .whitespaces).isEmpty)
            .buttonStyle(.plain)
        }
        .padding()
    }

    // MARK: - Helpers

    private var formattedToday: String {
        taskStore.formattedToday
    }

    private func addTask() {
        let title = newTaskTitle.trimmingCharacters(in: .whitespaces)
        guard !title.isEmpty else { return }
        taskStore.addTask(title: title, date: taskStore.todayString)
        newTaskTitle = ""
    }

    private func copyCompletedTasks() {
        let completed = taskStore.todayTasks.filter(\.isCompleted)
        let text = completed.enumerated().map { "\($0.offset + 1). \($0.element.title)" }.joined(separator: "\n")
        let header = "Completed tasks - \(formattedToday)"
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString("\(header)\n\(text)", forType: .string)

        withAnimation(.easeInOut(duration: 0.3)) {
            showCopiedToast = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation(.easeInOut(duration: 0.3)) {
                showCopiedToast = false
            }
        }
    }
}

// MARK: - Missed Task Row

struct MissedTaskRowView: View {
    let task: TaskItem
    let dateLabel: String
    let onComplete: () -> Void
    let onReschedule: () -> Void
    let onDelete: () -> Void
    let onRename: (String) -> Void
    @State private var showDeleteAlert = false
    @State private var showRescheduleAlert = false
    @State private var showCompleteAlert = false
    @State private var showEditAlert = false
    @State private var editText = ""

    var body: some View {
        HStack {
            Button { showCompleteAlert = true } label: {
                Image(systemName: "circle")
                    .foregroundStyle(.red)
                    .font(.title3)
            }
            .buttonStyle(.borderless)

            VStack(alignment: .leading, spacing: 1) {
                Text(task.title)
                    .foregroundStyle(.primary)
                Text(dateLabel)
                    .font(.caption2)
                    .foregroundStyle(.red.opacity(0.7))
            }

            Spacer()

            Button {
                editText = task.title
                showEditAlert = true
            } label: {
                Image(systemName: "pencil")
                    .foregroundStyle(.secondary)
                    .font(.caption)
            }
            .buttonStyle(.borderless)
            .opacity(0.6)

            Button { showRescheduleAlert = true } label: {
                Text("Move to Today")
                    .font(.caption2)
                    .foregroundStyle(.blue)
            }
            .buttonStyle(.borderless)

            Button { showDeleteAlert = true } label: {
                Image(systemName: "trash")
                    .foregroundStyle(.red.opacity(0.5))
                    .font(.caption)
            }
            .buttonStyle(.borderless)
            .opacity(0.6)
        }
        .padding(.vertical, 3)
        .contentShape(Rectangle())
        .listRowBackground(Color.red.opacity(0.06))
        .alert("Edit Task", isPresented: $showEditAlert) {
            TextField("Task title", text: $editText)
            Button("Save") {
                let trimmed = editText.trimmingCharacters(in: .whitespaces)
                if !trimmed.isEmpty && trimmed != task.title {
                    onRename(trimmed)
                }
            }
            Button("Cancel", role: .cancel) {}
        }
        .alert("Move to Today?", isPresented: $showRescheduleAlert) {
            Button("Move", action: onReschedule)
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("\"\(task.title)\" will be moved to today's tasks.")
        }
        .alert("Delete Task?", isPresented: $showDeleteAlert) {
            Button("Delete", role: .destructive, action: onDelete)
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("\"\(task.title)\" will be permanently deleted.")
        }
        .alert("Mark as Completed?", isPresented: $showCompleteAlert) {
            Button("Complete", action: onComplete)
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("\"\(task.title)\" will be marked as completed.")
        }
    }
}

// MARK: - Task Row

struct TaskRowView: View {
    let task: TaskItem
    let onToggle: () -> Void
    let onDelete: () -> Void
    let onRename: (String) -> Void
    @State private var showDeleteAlert = false
    @State private var showEditAlert = false
    @State private var editText = ""

    var body: some View {
        HStack {
            Button(action: onToggle) {
                Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(task.isCompleted ? .green : .secondary)
                    .font(.title3)
            }
            .buttonStyle(.borderless)

            Text(task.title)
                .strikethrough(task.isCompleted)
                .foregroundStyle(task.isCompleted ? .secondary : .primary)

            Spacer()

            Button {
                editText = task.title
                showEditAlert = true
            } label: {
                Image(systemName: "pencil")
                    .foregroundStyle(.secondary)
                    .font(.caption)
            }
            .buttonStyle(.borderless)
            .opacity(0.6)

            Button { showDeleteAlert = true } label: {
                Image(systemName: "trash")
                    .foregroundStyle(.red.opacity(0.5))
                    .font(.caption)
            }
            .buttonStyle(.borderless)
            .opacity(0.6)
        }
        .padding(.vertical, 3)
        .contentShape(Rectangle())
        .alert("Edit Task", isPresented: $showEditAlert) {
            TextField("Task title", text: $editText)
            Button("Save") {
                let trimmed = editText.trimmingCharacters(in: .whitespaces)
                if !trimmed.isEmpty && trimmed != task.title {
                    onRename(trimmed)
                }
            }
            Button("Cancel", role: .cancel) {}
        }
        .alert("Delete Task?", isPresented: $showDeleteAlert) {
            Button("Delete", role: .destructive, action: onDelete)
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("\"\(task.title)\" will be permanently deleted.")
        }
    }
}
