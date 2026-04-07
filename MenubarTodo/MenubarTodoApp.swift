import SwiftUI
import EventKit

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
    var popover: NSPopover!
    var eventStore: EKEventStore!
    var reminderList: EKCalendar?
    var timer: Timer?
    
    let progressColors: [NSColor] = [
        .systemRed, .systemOrange, .systemYellow,
        .systemGreen, .systemBlue, .systemPurple, .systemPink
    ]
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        eventStore = EKEventStore()
        
        // 设置状态栏
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        updateStatusIcon()
        
        // 创建 Popover
        popover = NSPopover()
        popover.contentSize = NSSize(width: 320, height: 400)
        popover.behavior = .transient
        popover.animates = true
        
        // 请求权限
        requestAccess()
        
        // 定时刷新
        timer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { _ in
            self.refreshData()
        }
    }
    
    func updateStatusIcon() {
        guard let button = statusItem.button else { return }
        
        let (completed, total) = getTaskStats()
        let progress = total > 0 ? CGFloat(completed) / CGFloat(total) : 0
        
        let image = createProgressIcon(completed: completed, total: total, progress: progress)
        image.isTemplate = false
        button.image = image
        button.action = #selector(togglePopover)
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
        
        // 背景圆环
        context?.setStrokeColor(NSColor.secondaryLabelColor.withAlphaComponent(0.3).cgColor)
        context?.setLineWidth(lineWidth)
        context?.addArc(center: center, radius: radius, startAngle: 0, endAngle: 2 * .pi, clockwise: false)
        context?.strokePath()
        
        // 进度圆环
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
    
    @objc func togglePopover() {
        if popover.isShown {
            popover.close()
        } else {
            showPopover()
        }
    }
    
    func showPopover() {
        let viewModel = TodoViewModel(eventStore: eventStore, reminderList: reminderList)
        let contentView = ContentView(viewModel: viewModel)
        
        popover.contentViewController = NSHostingController(rootView: contentView)
        
        if let button = statusItem.button {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        }
    }
    
    func requestAccess() {
        if #available(macOS 14.0, *) {
            eventStore.requestFullAccessToReminders { [weak self] granted, error in
                if granted {
                    DispatchQueue.main.async {
                        self?.findOrCreateList()
                        self?.refreshData()
                    }
                }
            }
        } else {
            eventStore.requestAccess(to: .reminder) { [weak self] granted, error in
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
            reminderList = EKCalendar(for: .reminder, eventStore: eventStore)
            reminderList?.title = "MenuBarTodo"
            reminderList?.source = eventStore.defaultCalendarForNewReminders()?.source
            
            do {
                try eventStore.saveCalendar(reminderList!, commit: true)
            } catch {
                reminderList = eventStore.defaultCalendarForNewReminders()
            }
        }
    }
    
    func refreshData() {
        updateStatusIcon()
    }
}
