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
        CharacterView(currentTaskTitle: taskStore.currentTask?.title, modelName: taskStore.selectedCharacterModel)
            .frame(width: 420, height: 280)
    }
}

// MARK: - Controller

final class FloatingPanelController {
    private let panel: FloatingPanel
    private let taskStore: TaskStore
    private var screenObserver: Any?
    private var screenTracker: Timer?
    private var currentScreenID: CGDirectDisplayID?
    /// When true, the user has dragged the buddy and auto-repositioning is paused
    private var userPositioned = false
    /// Tracks which screen the mouse is on (separate from buddy position)
    private var lastMouseScreenID: CGDirectDisplayID?

    // Drag handling via local event monitor
    private var mouseEventMonitor: Any?
    private var panelMouseDownLocation: NSPoint?
    private var isPanelDragging = false
    private var onCharacterClicked: (() -> Void)?

    init(taskStore: TaskStore, onCharacterClicked: @escaping () -> Void) {
        let panelSize = NSSize(width: 420, height: 280)
        panel = FloatingPanel(size: panelSize)
        self.taskStore = taskStore
        self.onCharacterClicked = onCharacterClicked

        let containerView = NSView(frame: NSRect(origin: .zero, size: panelSize))

        let content = FloatingCharacterContentView(taskStore: taskStore)
        let hostingView = NSHostingView(rootView: content)
        hostingView.frame = NSRect(origin: .zero, size: panelSize)
        hostingView.autoresizingMask = [.width, .height]
        containerView.addSubview(hostingView)

        let overlay = ClickOverlayView(frame: NSRect(origin: .zero, size: panelSize))
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
                let onScreen = NSScreen.screens.contains { NSPointInRect(center, $0.frame) }
                if !onScreen {
                    self.userPositioned = false
                }
            }
            if !self.userPositioned {
                self.moveToActiveScreen(animate: false)
            }
        }
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
                // Only open main window if not dragging AND click-through is disabled
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
        moveToActiveScreen(animate: false)
        panel.orderFront(nil)
        startTrackingActiveScreen()
    }

    // Polls mouse location every second to detect which display is active
    private func startTrackingActiveScreen() {
        screenTracker = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self else { return }

            // Detect if mouse moved to a different display → reset manual positioning
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
        // Use the screen with the focused window, not where the mouse is
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

        // Use the screen with the focused window, not where the mouse is
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
