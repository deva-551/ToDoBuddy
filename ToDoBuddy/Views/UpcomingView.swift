import SwiftUI

struct UpcomingView: View {
    var taskStore: TaskStore
    @State private var newTaskTitle = ""
    @State private var selectedDate = Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Schedule")
                    .font(.title2.bold())
                Spacer()
            }
            .padding()

            Divider()

            addSection

            Divider()

            let scheduledDates = taskStore.futureDates()
            let totalScheduled = scheduledDates.reduce(0) { $0 + taskStore.tasks(for: $1).count }

            if scheduledDates.isEmpty {
                Spacer()
                Text("No scheduled tasks")
                    .foregroundStyle(.secondary)
                Spacer()
            } else {
                if totalScheduled > 1 {
                    HStack {
                        Spacer()
                        Button {
                            taskStore.moveAllScheduledToToday()
                        } label: {
                            Label("Move All to Today", systemImage: "calendar.badge.plus")
                                .font(.caption)
                        }
                        .buttonStyle(.borderless)
                        .foregroundStyle(.blue)
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 4)
                }

                List {
                    ForEach(scheduledDates, id: \.self) { date in
                        Section {
                            ForEach(taskStore.tasks(for: date)) { task in
                                ScheduleTaskRow(
                                    task: task,
                                    onDelete: { taskStore.deleteTask(task) },
                                    onRename: { taskStore.updateTaskTitle(task, newTitle: $0) },
                                    onMoveToToday: { taskStore.rescheduleToToday(task) }
                                )
                            }
                        } header: {
                            Text(formattedDate(date))
                                .font(.headline)
                        }
                    }
                }
                .listStyle(.inset)
            }
        }
    }

    private var addSection: some View {
        HStack {
            if taskStore.addPastTasksEnabled {
                DatePicker("", selection: $selectedDate, displayedComponents: .date)
                    .labelsHidden()
                    .datePickerStyle(.compact)
                    .frame(width: 120)
            } else {
                DatePicker("", selection: $selectedDate, in: tomorrow..., displayedComponents: .date)
                    .labelsHidden()
                    .datePickerStyle(.compact)
                    .frame(width: 120)
            }

            TextField("Task title...", text: $newTaskTitle)
                .textFieldStyle(.roundedBorder)
                .onSubmit(addTask)

            Button(action: addTask) {
                Image(systemName: "plus.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.blue)
            }
            .disabled(newTaskTitle.trimmingCharacters(in: .whitespaces).isEmpty)
            .buttonStyle(.borderless)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }

    private var tomorrow: Date {
        Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: Date())) ?? Date()
    }

    private func addTask() {
        let title = newTaskTitle.trimmingCharacters(in: .whitespaces)
        guard !title.isEmpty else { return }
        taskStore.addTask(title: title, date: taskStore.stringFromDate(selectedDate))
        newTaskTitle = ""
    }

    private func formattedDate(_ dateString: String) -> String {
        taskStore.formattedLongDate(dateString)
    }
}

struct ScheduleTaskRow: View {
    let task: TaskItem
    let onDelete: () -> Void
    let onRename: (String) -> Void
    let onMoveToToday: () -> Void
    @State private var showDeleteAlert = false
    @State private var showEditAlert = false
    @State private var showMoveAlert = false
    @State private var editText = ""

    var body: some View {
        HStack {
            Text(task.title)
            Spacer()
            Button { showMoveAlert = true } label: {
                Text("Move to Today")
                    .font(.caption2)
                    .foregroundStyle(.blue)
            }
            .buttonStyle(.borderless)
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
        .padding(.vertical, 2)
        .alert("Move to Today?", isPresented: $showMoveAlert) {
            Button("Move", action: onMoveToToday)
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("\"\(task.title)\" will be moved to today's tasks.")
        }
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
