# 📝 MenuBar Todo

一个 macOS 菜单栏待办事项应用，与 Apple Reminders 同步，提供 CLI 工具支持。

## 特性

- 🍎 **菜单栏集成** - 常驻菜单栏，随时查看和标记任务
- ☑️ **复选框交互** - 点击即可标记完成/未完成
- 🔄 **Apple Reminders 同步** - 数据存储在系统原生提醒中
- 💻 **CLI 工具** - 完整的命令行操作支持
- 🔗 **OpenClaw 集成** - 支持通过 OpenClaw 添加任务

## 安装

```bash
cd menubar-todo
chmod +x install.sh
./install.sh
```

## 使用

### 菜单栏应用

- 点击菜单栏 📝 图标查看待办列表
- 点击 ☑️/☐ 标记任务完成状态
- 点击 "➕ Add Task..." 添加新任务
- 点击 "📊 Open Reminders" 打开系统提醒应用

### CLI 命令

```bash
# 添加任务
todo add "完成代码审查"
todo add "重要会议" -p high -d 2026-04-08
todo add "学习新技术" -n "AI 相关"

# 查看列表
todo list
todo list --pending
todo list --completed

# 完成任务
todo done "完成代码审查"
todo done 1  # 按序号完成

# 删除任务
todo remove "任务名称"

# 清除已完成
todo clear
```

### OpenClaw 集成

在 OpenClaw 配置中添加：

```json
{
  "tools": {
    "custom": {
      "todo": {
        "command": "todo",
        "description": "Manage todo list"
      }
    }
  }
}
```

然后可以通过 OpenClaw 对话直接操作：
- "帮我添加一个待办：下午3点开会"
- "查看今天的待办"
- "标记代码审查为完成"

## 文件结构

```
menubar-todo/
├── MenubarTodo/           # Swift 菜单栏应用
│   ├── MenubarTodo.swift
│   └── Info.plist
├── CLI/                   # Node.js CLI 工具
│   ├── index.js
│   └── package.json
├── install.sh             # 安装脚本
└── README.md
```

## 技术栈

- **菜单栏应用**: Swift + AppKit + EventKit
- **CLI 工具**: Node.js + Commander.js
- **数据存储**: Apple Reminders (系统原生)

## 许可证

MIT
