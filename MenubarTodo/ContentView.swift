import SwiftUI
import EventKit

// MARK: - Todo Item Model（本地模型，用于乐观更新）
struct TodoItem: Identifiable {
    let id: String
    var title: String
    var isCompleted: Bool
    var priority: Int
    let reminder: EKReminder

    init(reminder: EKReminder) {
        self.id = reminder.calendarItemIdentifier
        self.title = reminder.title ?? "Untitled"
        self.isCompleted = reminder.isCompleted
        self.priority = reminder.priority
        self.reminder = reminder
    }

    var priorityColor: Color {
        switch priority {
        case 1...4: return Color(NSColor.systemRed)
        case 5...8: return Color(NSColor.systemOrange)
        default: return Color(NSColor.systemBlue)
        }
    }
}

// MARK: - Task Row View
struct TaskRowView: View {
    let item: TodoItem
    let onToggle: () -> Void
    let onDelete: () -> Void
    let onEdit: (String) -> Void

    @State private var isHovered = false
    @State private var isEditing = false
    @State private var editText = ""
    @FocusState private var isTextFieldFocused: Bool

    var body: some View {
        HStack(spacing: 12) {
            // 彩色圆环 toggle 按钮
            ZStack {
                Circle()
                    .stroke(item.priorityColor, lineWidth: 2)
                    .frame(width: 18, height: 18)

                if item.isCompleted {
                    Circle()
                        .fill(item.priorityColor)
                        .frame(width: 18, height: 18)

                    Image(systemName: "checkmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white)
                }
            }
            .frame(width: 24, height: 24)
            .contentShape(Rectangle())
            .onTapGesture {
                onToggle()
            }

            // 任务标题 - 编辑模式或显示模式
            if isEditing {
                TextField("", text: $editText)
                    .font(.system(size: 14))
                    .focused($isTextFieldFocused)
                    .textFieldStyle(PlainTextFieldStyle())
                    .onSubmit {
                        saveEdit()
                    }
                    .onExitCommand {
                        cancelEdit()
                    }
                    .onChange(of: isTextFieldFocused) { focused in
                        if !focused && isEditing {
                            saveEdit()
                        }
                    }
            } else {
                Text(item.title)
                    .font(.system(size: 14))
                    .foregroundColor(item.isCompleted ? .secondary : .primary)
                    .strikethrough(item.isCompleted)
                    .lineLimit(1)
                    .help(item.title)
                    .onTapGesture(count: 2) {
                        startEditing()
                    }
            }

            Spacer()

            // 删除按钮（悬停显示且非编辑模式）
            if isHovered && !isEditing {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)
                    .frame(width: 20, height: 20)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        onDelete()
                    }
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

    private func startEditing() {
        editText = item.title
        isEditing = true
        isTextFieldFocused = true
    }

    private func saveEdit() {
        let trimmed = editText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty && trimmed != item.title {
            onEdit(trimmed)
        }
        isEditing = false
        editText = ""
    }

    private func cancelEdit() {
        isEditing = false
        editText = ""
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

            TextField("Add a new task...", text: $text)
                .font(.system(size: 14))
                .focused($isFocused)
                .textFieldStyle(PlainTextFieldStyle())
                .onSubmit(onSubmit)
                .accessibilityIdentifier("addTaskTextField")
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

            Divider()
                .padding(.horizontal, 16)
                .padding(.bottom, 8)

            // 任务列表
            if viewModel.items.isEmpty {
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
                        ForEach(viewModel.items) { item in
                            TaskRowView(
                                item: item,
                                onToggle: { viewModel.toggleItem(id: item.id) },
                                onDelete: { viewModel.deleteItem(id: item.id) },
                                onEdit: { newTitle in viewModel.editTask(id: item.id, newTitle: newTitle) }
                            )
                        }
                    }
                    .padding(.horizontal, 8)
                }
            }

            // 底部工具栏
            HStack(spacing: 8) {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.up.forward.app")
                        .font(.system(size: 11))
                    Text("Open Reminders")
                        .font(.system(size: 11))
                }
                .foregroundColor(.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .contentShape(Rectangle())
                .onTapGesture {
                    viewModel.openReminders()
                }

                Spacer()

                HStack(spacing: 4) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 11))
                    Text("Refresh")
                        .font(.system(size: 11))
                }
                .foregroundColor(.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .contentShape(Rectangle())
                .onTapGesture {
                    viewModel.refresh()
                }
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
    @Published var items: [TodoItem] = []
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
        guard let predicate = eventStore?.predicateForReminders(in: [list]) else { return }

        eventStore?.fetchReminders(matching: predicate) { [weak self] reminders in
            DispatchQueue.main.async {
                let sorted = (reminders ?? []).sorted {
                    ($0.isCompleted ? 1 : 0) < ($1.isCompleted ? 1 : 0)
                }
                self?.items = sorted.map { TodoItem(reminder: $0) }
                self?.updateStats()
            }
        }
    }

    func updateStats() {
        totalCount = items.count
        completedCount = items.filter { $0.isCompleted }.count
    }

    func toggleItem(id: String) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }

        // 乐观更新：立即修改本地状态，UI 即时响应
        items[index].isCompleted.toggle()
        updateStats()

        // 异步保存到 EventKit
        let reminder = items[index].reminder
        let newCompletedState = items[index].isCompleted
        if newCompletedState {
            reminder.isCompleted = true
            reminder.completionDate = Date()
        } else {
            reminder.isCompleted = false
            reminder.completionDate = nil
        }

        do {
            try eventStore?.save(reminder, commit: true)
        } catch {
            // 保存失败则回滚本地状态
            items[index].isCompleted = !newCompletedState
            updateStats()
            print("Failed to toggle reminder: \(error)")
        }
    }

    func deleteItem(id: String) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        let reminder = items[index].reminder

        // 乐观更新：立即从列表移除
        items.remove(at: index)
        updateStats()

        do {
            try eventStore?.remove(reminder, commit: true)
        } catch {
            // 删除失败则重新加载
            loadReminders()
            print("Failed to delete reminder: \(error)")
        }
    }

    func addTask(title: String) {
        guard let list = reminderList, let store = eventStore else { return }

        let reminder = EKReminder(eventStore: store)
        reminder.title = title
        reminder.calendar = list

        do {
            try store.save(reminder, commit: true)
            // 乐观更新：立即插入到列表头部
            let newItem = TodoItem(reminder: reminder)
            items.insert(newItem, at: 0)
            updateStats()
        } catch {
            print("Failed to add task: \(error)")
        }
    }

    func openReminders() {
        NSWorkspace.shared.open(URL(string: "x-apple-reminderkit://")!)
    }

    func refresh() {
        loadReminders()
    }

    func editTask(id: String, newTitle: String) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        let reminder = items[index].reminder

        // 乐观更新：立即修改本地状态
        items[index].title = newTitle

        // 异步保存到 EventKit
        reminder.title = newTitle

        do {
            try eventStore?.save(reminder, commit: true)
        } catch {
            // 保存失败则回滚本地状态
            items[index].title = reminder.title ?? "Untitled"
            print("Failed to edit reminder: \(error)")
        }
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
