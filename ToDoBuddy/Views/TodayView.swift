import SwiftUI

struct TodayView: View {
    var taskStore: TaskStore
    @State private var newTaskTitle = ""

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            taskList
            Divider()
            addTaskBar
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
                            Label("Missed", systemImage: "exclamationmark.triangle.fill")
                                .foregroundStyle(.red)
                                .font(.subheadline.bold())
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
        let f = DateFormatter()
        f.dateStyle = .long
        return f.string(from: Date())
    }

    private func addTask() {
        let title = newTaskTitle.trimmingCharacters(in: .whitespaces)
        guard !title.isEmpty else { return }
        taskStore.addTask(title: title, date: taskStore.todayString)
        newTaskTitle = ""
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
