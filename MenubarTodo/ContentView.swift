import SwiftUI
import EventKit

// MARK: - Color Extensions
extension Color {
    static let todoRed = Color(NSColor.systemRed)
    static let todoOrange = Color(NSColor.systemOrange)
    static let todoYellow = Color(NSColor.systemYellow)
    static let todoGreen = Color(NSColor.systemGreen)
    static let todoBlue = Color(NSColor.systemBlue)
    static let todoPurple = Color(NSColor.systemPurple)
    static let todoPink = Color(NSColor.systemPink)
}

// MARK: - Task Row View
struct TaskRowView: View {
    let reminder: EKReminder
    let onToggle: () -> Void
    let onDelete: () -> Void
    
    @State private var isHovered = false
    
    var priorityColor: Color {
        switch reminder.priority {
        case 1...4: return .todoRed
        case 5...8: return .todoOrange
        default: return .todoBlue
        }
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // 彩色圆环按钮
            Button(action: onToggle) {
                ZStack {
                    Circle()
                        .stroke(priorityColor, lineWidth: 2)
                        .frame(width: 18, height: 18)
                    
                    if reminder.isCompleted {
                        Circle()
                            .fill(priorityColor)
                            .frame(width: 18, height: 18)
                        
                        Image(systemName: "checkmark")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
            }
            .buttonStyle(PlainButtonStyle())
            .frame(width: 24, height: 24)
            
            // 任务标题
            Text(reminder.title ?? "Untitled")
                .font(.system(size: 14))
                .foregroundColor(reminder.isCompleted ? .secondary : .primary)
                .strikethrough(reminder.isCompleted)
                .lineLimit(1)
            
            Spacer()
            
            // 删除按钮（悬停显示）
            if isHovered {
                Button(action: onDelete) {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                        .frame(width: 20, height: 20)
                }
                .buttonStyle(PlainButtonStyle())
                .transition(.opacity)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
        .background(isHovered ? Color(NSColor.controlBackgroundColor).opacity(0.5) : Color.clear)
        .cornerRadius(6)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
    }
}

// MARK: - Add Task Field
struct AddTaskField: View {
    @Binding var text: String
    let onSubmit: () -> Void
    @FocusState private var isFocused: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "plus")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.secondary)
                .frame(width: 24, height: 24)
            
            TextField("", text: $text)
                .font(.system(size: 14))
                .placeholder(when: text.isEmpty) {
                    Text("Add a new task...")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
                .focused($isFocused)
                .textFieldStyle(PlainTextFieldStyle())
                .onSubmit(onSubmit)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color(NSColor.textBackgroundColor))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isFocused ? Color.accentColor.opacity(0.5) : Color.clear, lineWidth: 2)
        )
        .padding(.horizontal, 16)
        .onAppear {
            isFocused = true
        }
    }
}

// MARK: - Main Content View
struct ContentView: View {
    @ObservedObject var viewModel: TodoViewModel
    @State private var newTaskText = ""
    
    var body: some View {
        VStack(spacing: 0) {
            // 标题区域
            HStack {
                Text("Today")
                    .font(.system(size: 20, weight: .bold))
                
                Spacer()
                
                // 进度指示
                if viewModel.totalCount > 0 {
                    Text("\(viewModel.completedCount)/\(viewModel.totalCount)")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color(NSColor.controlBackgroundColor))
                        .cornerRadius(4)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 12)
            
            // 输入框
            AddTaskField(text: $newTaskText) {
                if !newTaskText.isEmpty {
                    viewModel.addTask(title: newTaskText)
                    newTaskText = ""
                }
            }
            .padding(.bottom, 12)
            
            // 分隔线
            Divider()
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
            
            // 任务列表
            if viewModel.reminders.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "checkmark.circle")
                        .font(.system(size: 32))
                        .foregroundColor(.secondary.opacity(0.5))
                    
                    Text("No tasks for today")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }
                .frame(maxHeight: .infinity)
            } else {
                ScrollView(showsIndicators: false) {
                    LazyVStack(spacing: 2) {
                        ForEach(viewModel.reminders, id: \.calendarItemIdentifier) { reminder in
                            TaskRowView(
                                reminder: reminder,
                                onToggle: { viewModel.toggleReminder(reminder) },
                                onDelete: { viewModel.deleteReminder(reminder) }
                            )
                        }
                    }
                    .padding(.horizontal, 8)
                }
            }
            
            // 底部工具栏
            HStack(spacing: 8) {
                Button(action: { viewModel.openReminders() }) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.up.forward.app")
                            .font(.system(size: 11))
                        Text("Open Reminders")
                            .font(.system(size: 11))
                    }
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                }
                .buttonStyle(PlainButtonStyle())
                
                Spacer()
                
                Button(action: { viewModel.refresh() }) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 11))
                        Text("Refresh")
                            .font(.system(size: 11))
                    }
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color(NSColor.controlBackgroundColor).opacity(0.3))
        }
        .frame(width: 320, height: 400)
        .background(Color(NSColor.windowBackgroundColor))
    }
}

// MARK: - View Model
class TodoViewModel: ObservableObject {
    @Published var reminders: [EKReminder] = []
    @Published var completedCount: Int = 0
    @Published var totalCount: Int = 0
    
    private var eventStore: EKEventStore?
    private var reminderList: EKCalendar?
    
    init(eventStore: EKEventStore?, reminderList: EKCalendar?) {
        self.eventStore = eventStore
        self.reminderList = reminderList
        loadReminders()
    }
    
    func loadReminders() {
        guard let list = reminderList else { return }
        
        let predicate = eventStore?.predicateForReminders(in: [list])
        eventStore?.fetchReminders(matching: predicate!) { [weak self] reminders in
            DispatchQueue.main.async {
                self?.reminders = reminders?.sorted {
                    ($0.isCompleted ? 1 : 0) < ($1.isCompleted ? 1 : 0)
                } ?? []
                self?.updateStats()
            }
        }
    }
    
    func updateStats() {
        totalCount = reminders.count
        completedCount = reminders.filter { $0.isCompleted }.count
    }
    
    func addTask(title: String) {
        guard let list = reminderList else { return }
        
        let reminder = EKReminder(eventStore: eventStore!)
        reminder.title = title
        reminder.calendar = list
        
        do {
            try eventStore?.save(reminder, commit: true)
            loadReminders()
        } catch {
            print("Failed to add task: \(error)")
        }
    }
    
    func toggleReminder(_ reminder: EKReminder) {
        reminder.isCompleted = !reminder.isCompleted
        do {
            try eventStore?.save(reminder, commit: true)
            loadReminders()
        } catch {
            print("Failed to toggle: \(error)")
        }
    }
    
    func deleteReminder(_ reminder: EKReminder) {
        do {
            try eventStore?.remove(reminder, commit: true)
            loadReminders()
        } catch {
            print("Failed to delete: \(error)")
        }
    }
    
    func openReminders() {
        NSWorkspace.shared.open(URL(string: "x-apple-reminderkit://")!)
    }
    
    func refresh() {
        loadReminders()
    }
}

// MARK: - TextField Placeholder Extension
extension View {
    func placeholder<Content: View>(
        when shouldShow: Bool,
        alignment: Alignment = .leading,
        @ViewBuilder placeholder: () -> Content
    ) -> some View {
        ZStack(alignment: alignment) {
            placeholder().opacity(shouldShow ? 1 : 0)
            self
        }
    }
}
