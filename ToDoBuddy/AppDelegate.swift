import SwiftUI
import UserNotifications

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var floatingController: FloatingPanelController!
    private var mainWindow: NSWindow?
    private var reminderTimer: Timer?

    // MARK: - Lifecycle

    func applicationWillFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupStatusItem()

        floatingController = FloatingPanelController(
            taskStore: TaskStore.shared,
            onCharacterClicked: { [weak self] in
                self?.showMainWindow()
            }
        )
        floatingController.show()

        UNUserNotificationCenter.current().delegate = self
        requestNotificationPermission()
        startReminderTimer()
    }

    func applicationWillTerminate(_ notification: Notification) {
        reminderTimer?.invalidate()
    }

    // MARK: - Status Item

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "checkmark.circle.fill", accessibilityDescription: "TaskBuddy")
        }
        let menu = NSMenu()
        menu.delegate = self
        statusItem.menu = menu
    }

    // MARK: - Main Window

    @objc func hideBuddyAction() {
        TaskStore.shared.hideBuddy()
    }

    @objc func showBuddyAction() {
        TaskStore.shared.showBuddy()
    }

    @objc func resetBuddyPositionAction() {
        floatingController.resetPosition()
    }

    @objc func showMainWindow() {
        if mainWindow == nil {
            let hostingView = NSHostingView(rootView: MainWindowView(taskStore: TaskStore.shared))
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 520, height: 620),
                styleMask: [.titled, .closable, .miniaturizable, .resizable],
                backing: .buffered,
                defer: false
            )
            window.title = "TaskBuddy"
            window.contentView = hostingView
            window.center()
            window.setFrameAutosaveName("TaskBuddyMain")
            window.isReleasedWhenClosed = false
            window.minSize = NSSize(width: 400, height: 500)
            mainWindow = window
        }

        mainWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    // MARK: - Notifications

    private func requestNotificationPermission() {
        Task {
            try? await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound, .badge])
        }
    }

    private func startReminderTimer() {
        reminderTimer = Timer.scheduledTimer(withTimeInterval: 30 * 60, repeats: true) { [weak self] _ in
            self?.sendReminder()
        }
    }

    private func sendReminder() {
        guard let task = TaskStore.shared.currentTask else { return }
        let content = UNMutableNotificationContent()
        content.title = "TaskBuddy"
        content.body = "Current task: \(task.title)"
        content.sound = .default
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }
}

// MARK: - NSMenuDelegate

extension AppDelegate: NSMenuDelegate {
    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()

        let taskTitle = TaskStore.shared.currentTask?.title ?? "No tasks for today"
        let taskItem = NSMenuItem(title: taskTitle, action: nil, keyEquivalent: "")
        taskItem.isEnabled = false
        menu.addItem(taskItem)

        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Open TaskBuddy", action: #selector(showMainWindow), keyEquivalent: "o"))

        if TaskStore.shared.buddyHidden {
            menu.addItem(NSMenuItem(title: "Show Buddy", action: #selector(showBuddyAction), keyEquivalent: ""))
        } else {
            menu.addItem(NSMenuItem(title: "Hide Buddy (\(TaskStore.shared.buddyHideMinutes) min)", action: #selector(hideBuddyAction), keyEquivalent: ""))
            menu.addItem(NSMenuItem(title: "Reset Buddy Position", action: #selector(resetBuddyPositionAction), keyEquivalent: ""))
        }

        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
    }
}

// MARK: - UNUserNotificationCenterDelegate

extension AppDelegate: UNUserNotificationCenterDelegate {
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        showMainWindow()
    }
}
