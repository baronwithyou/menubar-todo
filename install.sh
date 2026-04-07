#!/bin/bash

set -e

echo "📝 Installing MenuBar Todo..."

# 获取脚本所在目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 1. 安装 CLI 工具
echo "📦 Installing CLI tool..."
cd "$SCRIPT_DIR/CLI"
npm install
npm link

# 2. 编译菜单栏应用
echo "🔨 Building menu bar app..."
cd "$SCRIPT_DIR/MenubarTodo"

# 创建 app bundle
mkdir -p MenubarTodo.app/Contents/MacOS
mkdir -p MenubarTodo.app/Contents/Resources

# 复制 Info.plist
cp Info.plist MenubarTodo.app/Contents/

# 编译 Swift 代码
echo "Compiling Swift code..."
swiftc -o MenubarTodo.app/Contents/MacOS/MenubarTodo \
    -framework Cocoa \
    -framework EventKit \
    MenubarTodo.swift

# 3. 安装到 Applications
echo "📂 Installing to Applications..."
cp -R MenubarTodo.app /Applications/

# 4. 添加到登录项
echo "🔧 Adding to login items..."
osascript <<EOF
tell application "System Events"
    make login item at end with properties {path:"/Applications/MenubarTodo.app", hidden:false}
end tell
EOF

echo ""
echo "✅ Installation complete!"
echo ""
echo "Usage:"
echo "  • Menu bar app: Launch 'MenubarTodo' from Applications"
echo "  • CLI commands:"
echo "    todo add 'Task name'          # Add task"
echo "    todo list                     # List tasks"
echo "    todo done 'Task name'         # Complete task"
echo "    todo clear                    # Clear completed"
echo ""
echo "OpenClaw integration:"
echo "  openclaw agent --message 'Add todo: Review PR'"
echo ""
