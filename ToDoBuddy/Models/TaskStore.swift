import Foundation
import SwiftUI

@Observable
final class TaskStore {
    static let shared = TaskStore()

    var tasks: [TaskItem] = []

    var selectedCharacterModel: String = UserDefaults.standard.string(forKey: "selectedCharacter") ?? "none" {
        didSet { UserDefaults.standard.set(selectedCharacterModel, forKey: "selectedCharacter") }
    }

    var undoFromHistoryEnabled: Bool = UserDefaults.standard.bool(forKey: "undoFromHistoryEnabled") {
        didSet { UserDefaults.standard.set(undoFromHistoryEnabled, forKey: "undoFromHistoryEnabled") }
    }

    var addPastTasksEnabled: Bool = UserDefaults.standard.bool(forKey: "addPastTasksEnabled") {
        didSet { UserDefaults.standard.set(addPastTasksEnabled, forKey: "addPastTasksEnabled") }
    }

    var clickThroughEnabled: Bool = UserDefaults.standard.bool(forKey: "clickThroughEnabled") {
        didSet { UserDefaults.standard.set(clickThroughEnabled, forKey: "clickThroughEnabled") }
    }

    var buddyHideMinutes: Int = {
        let v = UserDefaults.standard.integer(forKey: "buddyHideMinutes")
        return v > 0 ? v : 5
    }() {
        didSet { UserDefaults.standard.set(buddyHideMinutes, forKey: "buddyHideMinutes") }
    }

    private(set) var buddyHidden = false
    private var buddyHiddenUntil: Date?
    private var buddyHideTimer: Timer?

    // MARK: - Date Rollover Detection

    /// Stored date string that triggers UI updates when the day changes
    var currentDateString: String

    /// Set to true when day changes and there are incomplete tasks from previous days
    var showDateChangeAlert = false

    /// Number of incomplete tasks from previous days (for the date change alert)
    var dateChangeIncompleteCount = 0

    private var dateCheckTimer: Timer?
    private var dayChangeObserver: Any?
    private var wakeObserver: Any?

    private let fileURL: URL

    private init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appDir = appSupport.appendingPathComponent("TaskBuddy")
        try? FileManager.default.createDirectory(at: appDir, withIntermediateDirectories: true)
        fileURL = appDir.appendingPathComponent("tasks.json")
        currentDateString = Self.dateFormatter.string(from: Date())
        load()
        setupDateChangeDetection()
    }

    // MARK: - Date Helpers

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    var todayString: String {
        currentDateString
    }

    func dateFromString(_ s: String) -> Date? {
        Self.dateFormatter.date(from: s)
    }

    func stringFromDate(_ d: Date) -> String {
        Self.dateFormatter.string(from: d)
    }

    private static let longDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .long
        return f
    }()

    func formattedLongDate(_ dateString: String) -> String {
        guard let date = dateFromString(dateString) else { return dateString }
        return Self.longDateFormatter.string(from: date)
    }

    var formattedToday: String {
        Self.longDateFormatter.string(from: Date())
    }

    // MARK: - Queries

    var todayTasks: [TaskItem] {
        tasks.filter { $0.date == todayString }
            .sorted { $0.sortOrder < $1.sortOrder }
    }

    /// Incomplete tasks from past dates (missed/overdue)
    var missedTasks: [TaskItem] {
        let today = todayString
        return tasks.filter { $0.date < today && !$0.isCompleted }
            .sorted { $0.date > $1.date } // most recent missed first
    }

    var currentTask: TaskItem? {
        // Missed tasks get highest priority
        if let missed = missedTasks.first { return missed }
        return todayTasks.first { !$0.isCompleted }
    }

    func tasks(for date: String) -> [TaskItem] {
        tasks.filter { $0.date == date }
            .sorted { $0.sortOrder < $1.sortOrder }
    }

    func pastDates() -> [String] {
        let today = todayString
        return Array(Set(tasks.map(\.date)).filter { $0 < today }).sorted(by: >)
    }

    func futureDates() -> [String] {
        let today = todayString
        return Array(Set(tasks.map(\.date)).filter { $0 > today }).sorted()
    }

    // MARK: - Mutations

    func addTask(title: String, date: String) {
        let maxOrder = tasks.filter { $0.date == date }.map(\.sortOrder).max() ?? -1
        tasks.append(TaskItem(title: title, date: date, sortOrder: maxOrder + 1))
        save()
    }

    func toggleTask(_ task: TaskItem) {
        guard let i = tasks.firstIndex(where: { $0.id == task.id }) else { return }
        tasks[i].isCompleted.toggle()
        tasks[i].completedAt = tasks[i].isCompleted ? Date() : nil
        save()
    }

    func updateTaskTitle(_ task: TaskItem, newTitle: String) {
        guard let i = tasks.firstIndex(where: { $0.id == task.id }) else { return }
        tasks[i].title = newTitle
        save()
    }

    func deleteTask(_ task: TaskItem) {
        tasks.removeAll { $0.id == task.id }
        save()
    }

    func rescheduleToToday(_ task: TaskItem) {
        guard let i = tasks.firstIndex(where: { $0.id == task.id }) else { return }
        let maxOrder = tasks.filter { $0.date == todayString }.map(\.sortOrder).max() ?? -1
        tasks[i].date = todayString
        tasks[i].sortOrder = maxOrder + 1
        save()
    }

    func moveTasks(for date: String, from source: IndexSet, to destination: Int) {
        var dateTasks = tasks(for: date)
        dateTasks.move(fromOffsets: source, toOffset: destination)
        for (i, task) in dateTasks.enumerated() {
            if let idx = tasks.firstIndex(where: { $0.id == task.id }) {
                tasks[idx].sortOrder = i
            }
        }
        save()
    }

    // MARK: - Buddy Visibility

    func hideBuddy() {
        buddyHidden = true
        let interval = Double(buddyHideMinutes) * 60
        buddyHiddenUntil = Date().addingTimeInterval(interval)
        buddyHideTimer?.invalidate()
        buddyHideTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: false) { [weak self] _ in
            DispatchQueue.main.async {
                self?.showBuddy()
            }
        }
    }

    func showBuddy() {
        buddyHidden = false
        buddyHiddenUntil = nil
        buddyHideTimer?.invalidate()
        buddyHideTimer = nil
    }

    // MARK: - Date Rollover

    private func setupDateChangeDetection() {
        // System notification fires at midnight
        dayChangeObserver = NotificationCenter.default.addObserver(
            forName: .NSCalendarDayChanged,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleDateChange()
        }

        // Also check on wake from sleep (day might have changed while asleep)
        wakeObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleDateChange()
        }

        // Backup: check every 60 seconds in case notifications are missed
        dateCheckTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            self?.handleDateChange()
        }
    }

    private func handleDateChange() {
        let newDate = Self.dateFormatter.string(from: Date())
        guard newDate != currentDateString else { return }

        currentDateString = newDate

        // Check for incomplete tasks from previous days
        let missed = missedTasks
        if !missed.isEmpty {
            dateChangeIncompleteCount = missed.count
            showDateChangeAlert = true
        }
    }

    func moveAllScheduledToToday() {
        let today = todayString
        var maxOrder = tasks.filter { $0.date == today }.map(\.sortOrder).max() ?? -1
        for i in tasks.indices {
            if tasks[i].date > today {
                maxOrder += 1
                tasks[i].date = today
                tasks[i].sortOrder = maxOrder
            }
        }
        save()
    }

    func moveAllMissedToToday() {
        let today = todayString
        var maxOrder = tasks.filter { $0.date == today }.map(\.sortOrder).max() ?? -1
        for i in tasks.indices {
            if tasks[i].date < today && !tasks[i].isCompleted {
                maxOrder += 1
                tasks[i].date = today
                tasks[i].sortOrder = maxOrder
            }
        }
        save()
    }

    // MARK: - Data Management

    func deleteAllData() {
        tasks.removeAll()
        save()
    }

    func populateDummyData() {
        let calendar = Calendar.current
        let today = Date()

        let dummyEntries: [(String, Int, Bool)] = [
            // 3 days ago — sprint wrap-up
            ("Fix Auto Layout crash on iPad rotation", -3, true),
            ("Write unit tests for NetworkManager", -3, true),
            ("Submit build to TestFlight", -3, true),
            ("Update release notes for v2.3.1", -3, false),
            // 2 days ago — code review & bugs
            ("Review PR: SwiftUI navigation refactor", -2, true),
            ("Fix Core Data migration crash", -2, true),
            ("Update CocoaPods dependencies", -2, true),
            ("Profile memory leaks in image cache", -2, false),
            // Yesterday — feature work
            ("Implement dark mode for settings screen", -1, true),
            ("Add Codable conformance to User model", -1, true),
            ("Debug push notification payload issue", -1, false),
            ("Sketch out onboarding flow wireframes", -1, true),
            // Today — active sprint tasks
            ("Daily standup at 10am", 0, true),
            ("Fix TableView cell reuse bug", 0, false),
            ("Integrate REST API for user profiles", 0, false),
            ("Write snapshot tests for HomeView", 0, false),
            ("Code review: async/await migration PR", 0, false),
            // Tomorrow — planned work
            ("Implement pull-to-refresh on feed", 1, false),
            ("Add accessibility labels to checkout flow", 1, false),
            ("Pair programming: Core Data stack refactor", 1, false),
            ("Update Xcode to latest release", 1, false),
            // 2 days out — upcoming sprint
            ("Set up CI pipeline for UI tests", 2, false),
            ("Migrate analytics SDK to v5", 2, false),
            ("Design custom UICollectionView layout", 2, false),
            // 4 days out — backlog
            ("Investigate SwiftUI performance on older devices", 4, false),
            ("Write tech spec for offline sync feature", 4, false),
            ("Refactor networking layer to use async/await", 4, false),
        ]

        for (title, dayOffset, completed) in dummyEntries {
            let date = calendar.date(byAdding: .day, value: dayOffset, to: today)!
            let dateStr = stringFromDate(date)
            let maxOrder = tasks.filter { $0.date == dateStr }.map(\.sortOrder).max() ?? -1
            var task = TaskItem(title: title, date: dateStr, sortOrder: maxOrder + 1)
            if completed {
                task.isCompleted = true
                task.completedAt = date
            }
            tasks.append(task)
        }
        save()
    }

    // MARK: - Persistence

    private func load() {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return }
        guard let data = try? Data(contentsOf: fileURL),
              let decoded = try? JSONDecoder().decode([TaskItem].self, from: data) else { return }
        tasks = decoded
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(tasks) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}
