# 📝 MenuBar Todo

一个 macOS 菜单栏待办事项应用，与 Apple Reminders 同步，提供 CLI 工具支持。

## 特性

- 🍎 **菜单栏集成** - 常驻菜单栏，随时查看和标记任务
- ☑️ **复选框交互** - 点击即可标记完成/未完成
- 🔄 **Apple Reminders 同步** - 数据存储在系统原生提醒中
- 💻 **CLI 工具** - 完整的命令行操作支持
- 🔗 **OpenClaw 集成** - 支持通过 OpenClaw 添加任务

## 安装

### 方式一：只安装 CLI 工具（推荐）

如果你只需要命令行工具（比如配合 OpenClaw 使用），只需要三步：

```bash
cd ~/code/menubar-todo/CLI
npm install
npm link
```

完成后 `todo` 命令就会全局可用。

### 方式二：完整安装（菜单栏应用 + CLI）

如果你想要菜单栏图标 + CLI，运行完整安装脚本：

```bash
cd ~/code/menubar-todo
chmod +x install.sh
./install.sh
```

这会：
1. 安装 CLI 工具并链接到全局
2. 编译 Swift 菜单栏应用
3. 安装到 `/Applications/`
4. 添加到登录项（自动启动）

**注意**：首次运行菜单栏应用时，需要授权终端访问 Reminders 的权限。

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

CLI 安装后，`todo` 命令全局可用。OpenClaw 可以直接通过 `exec` 调用：

```bash
todo add "下午3点开会"
todo list
todo done "代码审查"
```

无需额外配置。直接告诉 OpenClaw：
- "添加一个待办：xxx"
- "查看待办"
- "标记 xxx 为完成"

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
