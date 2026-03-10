import SwiftUI

struct HistoryView: View {
    var taskStore: TaskStore
    @State private var showCopiedToast = false
    @State private var taskToUndo: TaskItem?
    @State private var showUndoConfirmation = false

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                HStack {
                    Text("History")
                        .font(.title2.bold())
                    Spacer()
                }
                .padding()

                Divider()

                let pastDates = taskStore.pastDates()

                if pastDates.isEmpty {
                    Spacer()
                    Text("No past tasks yet")
                        .foregroundStyle(.secondary)
                    Spacer()
                } else {
                    List {
                        ForEach(pastDates, id: \.self) { date in
                            Section {
                                ForEach(taskStore.tasks(for: date)) { task in
                                    HistoryTaskRow(
                                        task: task,
                                        undoEnabled: taskStore.undoFromHistoryEnabled,
                                        onUndo: {
                                            taskToUndo = task
                                            showUndoConfirmation = true
                                        },
                                        onRename: { taskStore.updateTaskTitle(task, newTitle: $0) }
                                    )
                                }
                            } header: {
                                HStack {
                                    Text(formattedDate(date))
                                        .font(.headline)
                                    Spacer()
                                    Button {
                                        copyCompletedTasks(for: date)
                                    } label: {
                                        Label("Copy Tasks", systemImage: "doc.on.doc")
                                            .font(.caption)
                                    }
                                    .buttonStyle(.borderless)
                                }
                            }
                        }
                    }
                    .listStyle(.inset)
                }
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
        .alert(taskToUndo?.isCompleted == true ? "Mark as Incomplete?" : "Mark as Completed?", isPresented: $showUndoConfirmation) {
            Button("Confirm") {
                if let task = taskToUndo {
                    taskStore.toggleTask(task)
                }
                taskToUndo = nil
            }
            Button("Cancel", role: .cancel) {
                taskToUndo = nil
            }
        } message: {
            if let task = taskToUndo {
                Text("\"\(task.title)\" will be marked as \(task.isCompleted ? "incomplete" : "completed").")
            }
        }
    }

    private func copyCompletedTasks(for date: String) {
        let completed = taskStore.tasks(for: date).filter(\.isCompleted)
        let text = completed.enumerated().map { "\($0.offset + 1). \($0.element.title)" }.joined(separator: "\n")
        let header = "Completed tasks - \(formattedDate(date))"
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

    private func formattedDate(_ dateString: String) -> String {
        guard let date = taskStore.dateFromString(dateString) else { return dateString }
        let f = DateFormatter()
        f.dateStyle = .long
        return f.string(from: date)
    }
}

struct HistoryTaskRow: View {
    let task: TaskItem
    let undoEnabled: Bool
    let onUndo: () -> Void
    let onRename: (String) -> Void
    @State private var showEditAlert = false
    @State private var editText = ""

    var body: some View {
        HStack {
            if undoEnabled {
                Button(action: onUndo) {
                    Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(task.isCompleted ? .green : .orange)
                }
                .buttonStyle(.borderless)
            } else {
                Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(task.isCompleted ? .green : .orange)
            }

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
        }
        .padding(.vertical, 2)
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
    }
}
