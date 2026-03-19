import SwiftUI

// MARK: - Floating Panel (NSPanel subclass)

final class FloatingPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    init(size: NSSize) {
        super.init(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        isFloatingPanel = true
        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        isMovableByWindowBackground = false
        ignoresMouseEvents = false
    }
}

// MARK: - Transparent overlay for hit testing

final class ClickOverlayView: NSView {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func hitTest(_ point: NSPoint) -> NSView? {
        return frame.contains(point) ? self : nil
    }

    override func mouseDown(with event: NSEvent) {}
    override func mouseDragged(with event: NSEvent) {}
    override func mouseUp(with event: NSEvent) {}
}

// MARK: - SwiftUI wrapper hosted in the panel

struct FloatingCharacterContentView: View {
    var taskStore: TaskStore

    var body: some View {
        Group {
            if taskStore.selectedCharacterModel == "none" {
                TaskOnlyFloatingView(taskTitle: taskStore.currentTask?.title)
            } else {
                CharacterView(currentTaskTitle: taskStore.currentTask?.title, modelName: taskStore.selectedCharacterModel)
                    .frame(width: 220, height: 280)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.clear)
    }
}

// MARK: - Task-Only Floating View (No Animation mode)

struct TaskOnlyFloatingView: View {
    let taskTitle: String?

    private let creamBg = Color(red: 0.98, green: 0.92, blue: 0.78)
    private let brownBorder = Color(red: 0.68, green: 0.52, blue: 0.30)
    private let brownText = Color(red: 0.32, green: 0.20, blue: 0.08)

    var body: some View {
        Text(taskTitle ?? "All done!")
            .font(.system(size: 13, weight: .bold))
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .foregroundColor(brownText)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .frame(minWidth: 100)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(creamBg)
                    .shadow(color: .black.opacity(0.15), radius: 3, y: 2)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(brownBorder, lineWidth: 2)
            )
            .padding(12)
    }
}

// MARK: - Panel Sizes

private let characterPanelSize = NSSize(width: 220, height: 280)
private let taskOnlyPanelWidth: CGFloat = 280

// MARK: - Controller

final class FloatingPanelController {
    private let panel: FloatingPanel
    private let taskStore: TaskStore
    private var screenObserver: Any?
    private var screenTracker: Timer?
    private var currentScreenID: CGDirectDisplayID?
    private var userPositioned = false
    private var lastMouseScreenID: CGDirectDisplayID?
    private var currentCharacterMode: String?
    private var lastTaskTitle: String?

    // Drag handling via local event monitor
    private var mouseEventMonitor: Any?
    private var panelMouseDownLocation: NSPoint?
    private var isPanelDragging = false
    private var onCharacterClicked: (() -> Void)?

    init(taskStore: TaskStore, onCharacterClicked: @escaping () -> Void) {
        let initialSize: NSSize
        if taskStore.selectedCharacterModel == "none" {
            initialSize = Self.measureTaskOnlySize(taskTitle: taskStore.currentTask?.title)
        } else {
            initialSize = characterPanelSize
        }
        panel = FloatingPanel(size: initialSize)
        self.taskStore = taskStore
        self.onCharacterClicked = onCharacterClicked
        self.currentCharacterMode = taskStore.selectedCharacterModel

        let containerView = NSView(frame: NSRect(origin: .zero, size: initialSize))

        let content = FloatingCharacterContentView(taskStore: taskStore)
        let hostingView = NSHostingView(rootView: content)
        hostingView.frame = NSRect(origin: .zero, size: initialSize)
        hostingView.autoresizingMask = [.width, .height]
        containerView.addSubview(hostingView)

        let overlay = ClickOverlayView(frame: NSRect(origin: .zero, size: initialSize))
        overlay.autoresizingMask = [.width, .height]
        containerView.addSubview(overlay, positioned: .above, relativeTo: hostingView)

        panel.contentView = containerView

        setupMouseEventMonitor()

        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            if self.userPositioned {
                let center = NSPoint(x: self.panel.frame.midX, y: self.panel.frame.midY)
                let onScreen = NSScreen.screens.contains { $0.frame.contains(center) }
                if !onScreen {
                    self.userPositioned = false
                }
            }
            if !self.userPositioned {
                self.moveToActiveScreen(animate: false)
            }
        }
    }

    // MARK: - Dynamic Panel Sizing

    private func updatePanelSizeIfNeeded() {
        let mode = taskStore.selectedCharacterModel
        let taskTitle = taskStore.currentTask?.title

        let modeChanged = mode != currentCharacterMode
        let titleChanged = mode == "none" && taskTitle != lastTaskTitle

        guard modeChanged || titleChanged else { return }
        currentCharacterMode = mode
        lastTaskTitle = taskTitle

        let newSize: NSSize
        if mode == "none" {
            newSize = Self.measureTaskOnlySize(taskTitle: taskTitle)
        } else {
            newSize = characterPanelSize
        }

        // Keep bottom-right corner anchored when resizing
        let oldFrame = panel.frame
        let newOrigin = NSPoint(
            x: oldFrame.maxX - newSize.width,
            y: oldFrame.minY
        )
        panel.setFrame(NSRect(origin: newOrigin, size: newSize), display: true)

        // Force reposition on next cycle
        currentScreenID = nil
        if !userPositioned {
            moveToActiveScreen(animate: false)
        }
    }

    private static func measureTaskOnlySize(taskTitle: String?) -> NSSize {
        // Measure at the fixed target width so text wraps correctly
        // and the height accounts for multi-line content
        let content = TaskOnlyFloatingView(taskTitle: taskTitle)
            .frame(width: taskOnlyPanelWidth)
        let measureView = NSHostingView(rootView: content)
        let fitting = measureView.fittingSize
        return NSSize(
            width: taskOnlyPanelWidth,
            height: max(fitting.height, 60)
        )
    }

    // MARK: - Mouse Event Monitor (handles click vs drag)

    private func setupMouseEventMonitor() {
        mouseEventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .leftMouseDragged, .leftMouseUp]) { [weak self] event in
            guard let self else { return event }
            guard event.window === self.panel else { return event }

            switch event.type {
            case .leftMouseDown:
                self.panelMouseDownLocation = NSEvent.mouseLocation
                self.isPanelDragging = false
                return event

            case .leftMouseDragged:
                if !self.isPanelDragging {
                    guard let start = self.panelMouseDownLocation else { return event }
                    let current = NSEvent.mouseLocation
                    if abs(current.x - start.x) > 3 || abs(current.y - start.y) > 3 {
                        self.isPanelDragging = true
                        self.userPositioned = true
                    }
                }
                if self.isPanelDragging {
                    var origin = self.panel.frame.origin
                    origin.x += event.deltaX
                    origin.y -= event.deltaY
                    self.panel.setFrameOrigin(origin)
                }
                return event

            case .leftMouseUp:
                let wasDragging = self.isPanelDragging
                self.isPanelDragging = false
                self.panelMouseDownLocation = nil
                if !wasDragging && !self.taskStore.clickThroughEnabled {
                    self.onCharacterClicked?()
                }
                return event

            default:
                return event
            }
        }
    }

    // MARK: - Reset Position

    func resetPosition() {
        userPositioned = false
        currentScreenID = nil
        moveToActiveScreen(animate: false)
    }

    func show() {
        updatePanelSizeIfNeeded()
        moveToActiveScreen(animate: false)
        panel.orderFront(nil)
        startTrackingActiveScreen()
    }

    private func startTrackingActiveScreen() {
        screenTracker = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self else { return }

            self.updatePanelSizeIfNeeded()
            self.detectScreenSwitch()

            if self.taskStore.buddyHidden {
                if self.panel.isVisible { self.panel.orderOut(nil) }
            } else {
                if !self.panel.isVisible {
                    self.currentScreenID = nil
                    self.moveToActiveScreen(animate: false)
                    self.panel.orderFront(nil)
                } else {
                    self.moveToActiveScreen(animate: true)
                }
            }
        }
    }

    private func detectScreenSwitch() {
        guard let activeScreen = NSScreen.main else { return }

        let screenID = activeScreen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID
        if let screenID {
            if let last = lastMouseScreenID, screenID != last, userPositioned {
                userPositioned = false
                currentScreenID = nil
            }
            lastMouseScreenID = screenID
        }
    }

    private func moveToActiveScreen(animate: Bool) {
        if userPositioned { return }

        guard let activeScreen = NSScreen.main else { return }

        let screenID = activeScreen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID
        if let screenID, screenID == currentScreenID { return }
        currentScreenID = screenID

        let visible = activeScreen.visibleFrame
        let size = panel.frame.size
        let x = visible.maxX - size.width - 16
        let y = visible.minY
        let newFrame = NSRect(origin: NSPoint(x: x, y: y), size: size)

        if animate {
            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = 0.4
                ctx.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                panel.animator().setFrame(newFrame, display: true)
            }
        } else {
            panel.setFrame(newFrame, display: true)
        }
    }

    deinit {
        screenTracker?.invalidate()
        if let observer = screenObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        if let monitor = mouseEventMonitor {
            NSEvent.removeMonitor(monitor)
        }
    }
}
