import SwiftUI

struct SettingsView: View {
    var taskStore: TaskStore
    @State private var showDeleteConfirmation = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Choose Character")
                    .font(.title2.bold())
                    .padding(.horizontal)

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    ForEach(CharacterOption.allOptions) { option in
                        CharacterOptionCard(
                            option: option,
                            isSelected: taskStore.selectedCharacterModel == option.id
                        ) {
                            taskStore.selectedCharacterModel = option.id
                        }
                    }
                }
                .padding(.horizontal)

                Divider()
                    .padding(.horizontal)

                VStack(alignment: .leading, spacing: 8) {
                    Text("Task Options")
                        .font(.title2.bold())

                    Toggle(isOn: Bindable(taskStore).undoFromHistoryEnabled) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Toggle from History")
                                .font(.body)
                            Text("Allow toggling tasks between completed and incomplete in history")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .toggleStyle(.switch)

                    Toggle(isOn: Bindable(taskStore).addPastTasksEnabled) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Add Past Tasks")
                                .font(.body)
                            Text("Allow adding tasks to past dates in the Schedule tab")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .toggleStyle(.switch)
                }
                .padding(.horizontal)

                Divider()
                    .padding(.horizontal)

                VStack(alignment: .leading, spacing: 8) {
                    Text("Character Options")
                        .font(.title2.bold())

                    Toggle(isOn: Bindable(taskStore).clickThroughEnabled) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Click Through Character")
                                .font(.body)
                            Text("When enabled, clicking the buddy won't open the app. You can still drag to reposition.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .toggleStyle(.switch)

                    Divider()

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Hide Buddy")
                            .font(.body)

                        HStack(spacing: 12) {
                            Text("\(taskStore.buddyHideMinutes) min")
                                .font(.body.monospacedDigit().bold())
                                .frame(width: 50, alignment: .trailing)
                            Slider(value: Binding(
                                get: { Double(taskStore.buddyHideMinutes) },
                                set: { taskStore.buddyHideMinutes = Int($0) }
                            ), in: 1...60, step: 1)
                        }

                        if taskStore.buddyHidden {
                            HStack {
                                Label("Buddy is hidden", systemImage: "eye.slash")
                                    .foregroundStyle(.orange)
                                Spacer()
                                Button("Show Now") {
                                    taskStore.showBuddy()
                                }
                            }
                        } else {
                            Button {
                                taskStore.hideBuddy()
                            } label: {
                                Label("Hide Now", systemImage: "eye.slash")
                            }
                        }
                    }
                }
                .padding(.horizontal)

                Divider()
                    .padding(.horizontal)

                VStack(alignment: .leading, spacing: 8) {
                    Text("Data")
                        .font(.title2.bold())

                    HStack(spacing: 12) {
                        Button {
                            taskStore.populateDummyData()
                        } label: {
                            Label("Populate Dummy Data", systemImage: "text.badge.plus")
                        }

                        Button(role: .destructive) {
                            showDeleteConfirmation = true
                        } label: {
                            Label("Delete All Data", systemImage: "trash")
                        }
                    }
                }
                .padding(.horizontal)
            }
            .padding(.top)
        }
        .alert("Delete All Data?", isPresented: $showDeleteConfirmation) {
            Button("Delete", role: .destructive) {
                taskStore.deleteAllData()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will permanently delete all your tasks. This action cannot be undone.")
        }
    }

}

struct CharacterOptionCard: View {
    let option: CharacterOption
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            VStack(spacing: 8) {
                Image(systemName: option.icon)
                    .font(.system(size: 28))
                    .foregroundStyle(isSelected ? .white : .primary)

                Text(option.displayName)
                    .font(.headline)
                    .foregroundStyle(isSelected ? .white : .primary)

                Text(option.description)
                    .font(.caption)
                    .foregroundStyle(isSelected ? .white.opacity(0.8) : .secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? Color.accentColor : Color(nsColor: .controlBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.accentColor : Color.gray.opacity(0.3), lineWidth: isSelected ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
    }
}
