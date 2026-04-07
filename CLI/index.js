#!/usr/bin/env node

const { Command } = require('commander');
const chalk = require('chalk');
const { exec } = require('child_process');
const { promisify } = require('util');
const execAsync = promisify(exec);
const program = new Command();

const TODO_LIST_NAME = "MenuBarTodo";

// AppleScript 辅助函数
async function runAppleScript(script) {
  try {
    const { stdout } = await execAsync(`osascript -e '${script.replace(/'/g, "'\\''")}'`, { timeout: 10000 });
    return stdout.trim();
  } catch (error) {
    throw new Error(error.stderr || error.message);
  }
}

// 获取待办列表
async function getTodoList() {
  const script = `
    tell application "Reminders"
      try
        set listNames to name of every list
        if listNames contains "${TODO_LIST_NAME}" then
          return "${TODO_LIST_NAME}"
        else
          make new list with properties {name:"${TODO_LIST_NAME}"}
          return "${TODO_LIST_NAME}"
        end if
      on error
        return "${TODO_LIST_NAME}"
      end try
    end tell
  `;
  return await runAppleScript(script);
}

// 添加任务
async function addTask(name, options) {
  try {
    await getTodoList();
    
    let props = `name:"${name.replace(/"/g, '\\"')}"`;
    
    if (options.priority) {
      const priorityMap = { high: 1, medium: 5, low: 9 };
      props += `, priority:${priorityMap[options.priority] || 0}`;
    }
    
    if (options.due) {
      props += `, due date:date "${options.due}"`;
    }
    
    if (options.notes) {
      props += `, body:"${options.notes.replace(/"/g, '\\"')}"`;
    }
    
    const script = `
      tell application "Reminders"
        tell list "${TODO_LIST_NAME}"
          make new reminder with properties {${props}}
        end tell
      end tell
    `;
    
    await runAppleScript(script);
    console.log(chalk.green('✓'), `Added: ${chalk.bold(name)}`);
  } catch (err) {
    console.error(chalk.red('✗'), 'Failed to add task:', err.message);
    process.exit(1);
  }
}

// 列出任务
async function listTasks(options) {
  try {
    await getTodoList();
    
    // 分别获取未完成和已完成的任务
    const incompleteScript = `
      tell application "Reminders"
        tell list "${TODO_LIST_NAME}"
          set incompleteList to {}
          repeat with r in reminders
            if not (completed of r) then
              set rName to name of r
              set rPriority to priority of r
              set rDue to due date of r
              set rId to id of r
              set end of incompleteList to rName & "|" & rPriority & "|" & (rDue as string) & "|" & rId
            end if
          end repeat
          return incompleteList
        end tell
      end tell
    `;
    
    const completedScript = `
      tell application "Reminders"
        tell list "${TODO_LIST_NAME}"
          set completedList to {}
          repeat with r in reminders
            if completed of r then
              set rName to name of r
              set end of completedList to rName
            end if
          end repeat
          return completedList
        end tell
      end tell
    `;
    
    let incompleteResult = '';
    let completedResult = '';
    
    try {
      incompleteResult = await runAppleScript(incompleteScript);
    } catch (e) {
      // 忽略错误
    }
    
    try {
      completedResult = await runAppleScript(completedScript);
    } catch (e) {
      // 忽略错误
    }
    
    const incomplete = incompleteResult ? incompleteResult.split(', ').filter(s => s).map(s => {
      const parts = s.split('|');
      return {
        name: parts[0] || 'Untitled',
        priority: parseInt(parts[1]) || 0,
        dueDate: parts[2] && parts[2] !== 'missing value' ? parts[2] : null,
        id: parts[3] || ''
      };
    }) : [];
    
    const completed = completedResult ? completedResult.split(', ').filter(s => s) : [];
    
    if (incomplete.length === 0 && completed.length === 0) {
      console.log(chalk.gray('No tasks found.'));
      return;
    }
    
    console.log(chalk.bold('\n📋 Todo List\n'));
    
    // 显示未完成的任务
    if (options.completed !== true) {
      if (incomplete.length === 0) {
        console.log(chalk.green('✅ All done!\n'));
      } else {
        incomplete.forEach((r, index) => {
          const num = chalk.gray(`${index + 1}.`);
          const checkbox = '☐';
          
          let priorityIcon = '';
          if (r.priority > 0) {
            priorityIcon = r.priority <= 5 ? chalk.red('🔴 ') : chalk.yellow('🟡 ');
          }
          
          let dueStr = '';
          if (r.dueDate && r.dueDate !== 'missing value') {
            try {
              const dateMatch = r.dueDate.match(/(\d{4})-(\d{2})-(\d{2})/);
              if (dateMatch) {
                const month = dateMatch[2];
                const day = dateMatch[3];
                dueStr = chalk.gray(` [${month}/${day}]`);
              }
            } catch (e) {}
          }
          
          console.log(`${num} ${checkbox} ${priorityIcon}${r.name}${dueStr}`);
        });
        console.log();
      }
    }
    
    // 显示已完成的任务
    if (options.pending !== true && completed.length > 0) {
      console.log(chalk.gray(`✓ Completed (${completed.length}):`));
      completed.forEach(name => {
        console.log(chalk.gray(`  ☑ ${name}`));
      });
    }
    
    console.log(chalk.gray(`\n${incomplete.length} pending, ${completed.length} completed`));
  } catch (err) {
    console.error(chalk.red('✗'), 'Failed to list tasks:', err.message);
    process.exit(1);
  }
}

// 完成任务
async function completeTask(identifier) {
  try {
    await getTodoList();
    
    // 先尝试通过名称查找
    const script = `
      tell application "Reminders"
        tell list "${TODO_LIST_NAME}"
          try
            set r to reminder "${identifier.replace(/"/g, '\\"')}"
            set completed of r to true
            return name of r
          on error
            return "NOT_FOUND"
          end try
        end tell
      end tell
    `;
    
    const result = await runAppleScript(script);
    
    if (result !== 'NOT_FOUND') {
      console.log(chalk.green('✓'), `Completed: ${chalk.bold(result)}`);
      return;
    }
    
    // 尝试通过序号查找
    const index = parseInt(identifier);
    if (!isNaN(index) && index > 0) {
      const indexScript = `
        tell application "Reminders"
          tell list "${TODO_LIST_NAME}"
            set allReminders to reminders whose completed is false
            if ${index} ≤ (count of allReminders) then
              set r to item ${index} of allReminders
              set completed of r to true
              return name of r
            else
              return "NOT_FOUND"
            end if
          end tell
        end tell
      `;
      
      const indexResult = await runAppleScript(indexScript);
      if (indexResult !== 'NOT_FOUND') {
        console.log(chalk.green('✓'), `Completed: ${chalk.bold(indexResult)}`);
        return;
      }
    }
    
    console.error(chalk.red('✗'), 'Task not found:', identifier);
    process.exit(1);
  } catch (err) {
    console.error(chalk.red('✗'), 'Failed to complete task:', err.message);
    process.exit(1);
  }
}

// 删除任务
async function removeTask(identifier) {
  try {
    await getTodoList();
    
    const script = `
      tell application "Reminders"
        tell list "${TODO_LIST_NAME}"
          try
            set r to reminder "${identifier.replace(/"/g, '\\"')}"
            set rName to name of r
            delete r
            return rName
          on error
            return "NOT_FOUND"
          end try
        end tell
      end tell
    `;
    
    const result = await runAppleScript(script);
    
    if (result !== 'NOT_FOUND') {
      console.log(chalk.yellow('✗'), `Deleted: ${chalk.bold(result)}`);
      return;
    }
    
    console.error(chalk.red('✗'), 'Task not found:', identifier);
    process.exit(1);
  } catch (err) {
    console.error(chalk.red('✗'), 'Failed to delete:', err.message);
    process.exit(1);
  }
}

// 清除已完成
async function clearCompleted() {
  try {
    await getTodoList();
    
    const script = `
      tell application "Reminders"
        tell list "${TODO_LIST_NAME}"
          set completedReminders to every reminder whose completed is true
          set countDeleted to count of completedReminders
          repeat with r in completedReminders
            delete r
          end repeat
          return countDeleted
        end tell
      end tell
    `;
    
    const result = await runAppleScript(script);
    console.log(chalk.green('✓'), `Cleared ${result} completed tasks`);
  } catch (err) {
    console.error(chalk.red('✗'), 'Failed to clear:', err.message);
    process.exit(1);
  }
}

// CLI 定义
program
  .name('todo')
  .description('MenuBar Todo CLI - Manage your tasks from command line')
  .version('1.0.0');

program
  .command('add <name>')
  .description('Add a new task')
  .option('-p, --priority <level>', 'Priority: high/medium/low')
  .option('-d, --due <date>', 'Due date (YYYY-MM-DD)')
  .option('-n, --notes <text>', 'Additional notes')
  .action(addTask);

program
  .command('list')
  .alias('ls')
  .description('List all tasks')
  .option('-c, --completed', 'Show only completed')
  .option('-p, --pending', 'Show only pending')
  .action(listTasks);

program
  .command('done <identifier>')
  .alias('complete')
  .description('Mark a task as completed (by name or number)')
  .action(completeTask);

program
  .command('remove <identifier>')
  .alias('rm')
  .description('Delete a task')
  .action(removeTask);

program
  .command('clear')
  .description('Remove all completed tasks')
  .action(clearCompleted);

// 默认显示列表
if (process.argv.length === 2) {
  listTasks({});
} else {
  program.parse();
}
