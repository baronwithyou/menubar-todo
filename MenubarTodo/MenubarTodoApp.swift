import SwiftUI
import EventKit

// MARK: - NSPanel 子类，允许在 LSUIElement app 中成为 key window
class MenuPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

@main
struct MenubarTodoApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate, ObservableObject {
    var statusItem: NSStatusItem!
    var menuPanel: MenuPanel?
    var eventStore: EKEventStore!
    var reminderList: EKCalendar?
    var timer: Timer?
    var viewModel: TodoViewModel?
    var globalEventMonitor: Any?

    let progressColors: [NSColor] = [
        .systemRed, .systemOrange, .systemYellow,
        .systemGreen, .systemBlue, .systemPurple, .systemPink
    ]

    func applicationDidFinishLaunching(_ notification: Notification) {
        // NSPanel 在 .accessory 模式下也可以成为 key window
        NSApp.setActivationPolicy(.accessory)

        eventStore = EKEventStore()

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        updateStatusIcon()

        requestAccess()

        timer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            self?.refreshData()
        }
    }

    func updateStatusIcon() {
        guard let button = statusItem.button else { return }

        let (completed, total) = getTaskStats()
        let progress = total > 0 ? CGFloat(completed) / CGFloat(total) : 0

        let image = createProgressIcon(completed: completed, total: total, progress: progress)
        image.isTemplate = false
        button.image = image
        button.action = #selector(togglePanel)
        button.target = self
    }

    func createProgressIcon(completed: Int, total: Int, progress: CGFloat) -> NSImage {
        let size = NSSize(width: 22, height: 16)
        let image = NSImage(size: size)
        image.lockFocus()

        let context = NSGraphicsContext.current?.cgContext
        let center = CGPoint(x: 11, y: 8)
        let radius: CGFloat = 6
        let lineWidth: CGFloat = 2.5

        context?.setStrokeColor(NSColor.secondaryLabelColor.withAlphaComponent(0.3).cgColor)
        context?.setLineWidth(lineWidth)
        context?.addArc(center: center, radius: radius, startAngle: 0, endAngle: 2 * .pi, clockwise: false)
        context?.strokePath()

        if total > 0 {
            let colorIndex = min(completed, progressColors.count - 1)
            context?.setStrokeColor(progressColors[colorIndex].cgColor)
            context?.setLineWidth(lineWidth)
            context?.addArc(center: center, radius: radius, startAngle: .pi / 2, endAngle: .pi / 2 - (2 * .pi * progress), clockwise: true)
            context?.strokePath()
        }

        image.unlockFocus()
        return image
    }

    func getTaskStats() -> (completed: Int, total: Int) {
        guard let list = reminderList else { return (0, 0) }

        let predicate = eventStore.predicateForReminders(in: [list])
        var completed = 0
        var total = 0

        let semaphore = DispatchSemaphore(value: 0)
        eventStore.fetchReminders(matching: predicate) { reminders in
            total = reminders?.count ?? 0
            completed = reminders?.filter { $0.isCompleted }.count ?? 0
            semaphore.signal()
        }
        semaphore.wait()

        return (completed, total)
    }

    @objc func togglePanel() {
        if let panel = menuPanel, panel.isVisible {
            closePanel()
        } else {
            showPanel()
        }
    }

    func showPanel() {
        // 复用持久化的 viewModel
        if viewModel == nil {
            viewModel = TodoViewModel(eventStore: eventStore, reminderList: reminderList)
        } else {
            viewModel?.loadReminders()
        }

        guard let button = statusItem.button,
              let buttonWindow = button.window else { return }

        // 计算 panel 位置：菜单栏按钮正下方
        let buttonFrame = button.convert(button.bounds, to: nil)
        let screenFrame = buttonWindow.convertToScreen(buttonFrame)

        let panelWidth: CGFloat = 320
        let panelHeight: CGFloat = 400
        let panelX = screenFrame.midX - panelWidth / 2
        let panelY = screenFrame.minY - panelHeight - 4

        let panelFrame = NSRect(x: panelX, y: panelY, width: panelWidth, height: panelHeight)

        let panel = MenuPanel(
            contentRect: panelFrame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        panel.level = .popUpMenu
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.collectionBehavior = [.canJoinAllSpaces, .transient]
        panel.isMovable = false
        panel.hidesOnDeactivate = false
        panel.worksWhenModal = true

        let hostingView = NSHostingView(rootView: ContentView(viewModel: viewModel!))
        hostingView.wantsLayer = true
        hostingView.layer?.cornerRadius = 12
        hostingView.layer?.masksToBounds = true
        panel.contentView = hostingView

        self.menuPanel = panel

        // 延迟到下一个 run loop，确保菜单栏按钮的点击事件处理完成后再激活
        DispatchQueue.main.async { [weak self, weak panel] in
            guard let self = self, let panel = panel else { return }
            // 临时切换为 regular 策略，让 panel 可以成为 key window，使 SwiftUI TextField 可以获焦
            NSApp.setActivationPolicy(.regular)
            NSApp.activate(ignoringOtherApps: true)
            panel.makeKeyAndOrderFront(nil)
        }

        // 监听点击 panel 外部区域来关闭
        globalEventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            guard let self = self, let panel = self.menuPanel else { return }
            let clickLocation = NSEvent.mouseLocation
            if !panel.frame.contains(clickLocation) {
                self.closePanel()
            }
        }
    }

    func closePanel() {
        menuPanel?.orderOut(nil)
        menuPanel = nil

        if let monitor = globalEventMonitor {
            NSEvent.removeMonitor(monitor)
            globalEventMonitor = nil
        }

        // 关闭后切回 accessory 策略，隐藏 Dock 图标
        NSApp.setActivationPolicy(.accessory)
    }

    func requestAccess() {
        if #available(macOS 14.0, *) {
            eventStore.requestFullAccessToReminders { [weak self] granted, _ in
                if granted {
                    DispatchQueue.main.async {
                        self?.findOrCreateList()
                        self?.refreshData()
                    }
                }
            }
        } else {
            eventStore.requestAccess(to: .reminder) { [weak self] granted, _ in
                if granted {
                    DispatchQueue.main.async {
                        self?.findOrCreateList()
                        self?.refreshData()
                    }
                }
            }
        }
    }

    func findOrCreateList() {
        let lists = eventStore.calendars(for: .reminder)
        reminderList = lists.first { $0.title == "MenuBarTodo" }

        if reminderList == nil {
            let newList = EKCalendar(for: .reminder, eventStore: eventStore)
            newList.title = "MenuBarTodo"
            newList.source = eventStore.defaultCalendarForNewReminders()?.source

            do {
                try eventStore.saveCalendar(newList, commit: true)
                reminderList = newList
            } catch {
                reminderList = eventStore.defaultCalendarForNewReminders()
            }
        }
    }

    func refreshData() {
        updateStatusIcon()
    }
}
