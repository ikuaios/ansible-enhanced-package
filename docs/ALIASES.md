# 别名使用指南

Ansible 增强技能包提供了 50+ 个智能别名，极大提升工作效率。

## 📋 别名列表

### 核心命令别名

| 别名 | 对应命令 | 功能描述 | 示例 |
|------|----------|----------|------|
| `ans` | `ansible` | Ansible 核心命令快捷方式 | `ans all -m ping` |
| `ansp` | `ansible-playbook` | Playbook 执行快捷方式 | `ansp site.yml` |
| `ans-vault` | `ansible-vault` | 加密解密敏感数据 | `ans-vault encrypt secrets.yml` |
| `ans-galaxy` | `ansible-galaxy` | 角色管理 | `ans-galaxy install nginx` |
| `ans-config` | `ansible-config` | 配置管理 | `ans-config view` |
| `ans-inventory` | `ansible-inventory` | Inventory 管理 | `ans-inventory --graph` |

### 快捷操作别名

| 别名 | 对应命令 | 功能描述 | 示例 |
|------|----------|----------|------|
| `ans-ping` | `ansible all -m ping` | 测试所有主机连通性 | `ans-ping` |
| `ans-uptime` | `ansible all -a "uptime"` | 查看所有主机运行时间 | `ans-uptime` |
| `ans-facts` | `ansible all -m setup` | 收集所有主机系统信息 | `ans-facts` |
| `ans-list` | `ansible all --list-hosts` | 列出所有主机 | `ans-list` |
| `ans-df` | `ansible all -a "df -h"` | 查看所有主机磁盘空间 | `ans-df` |
| `ans-free` | `ansible all -a "free -h"` | 查看所有主机内存使用 | `ans-free` |

### 语法检查别名

| 别名 | 对应命令 | 功能描述 | 示例 |
|------|----------|----------|------|
| `ans-syntax` | `ansible-playbook --syntax-check` | 检查 Playbook 语法 | `ans-syntax playbook.yml` |
| `ans-check` | `ansible-playbook --check --diff` | 执行 Dry Run (检查变更) | `ans-check playbook.yml` |
| `ans-lint` | `python3 -m ansible.utils.playbook_linter` | 运行 Playbook 静态检查 | `ans-lint playbook.yml` |
| `ans-validate` | `ansible-playbook --syntax-check --check` | 语法检查 + Dry Run | `ans-validate playbook.yml` |

### 配置管理别名

| 别名 | 对应命令 | 功能描述 | 示例 |
|------|----------|----------|------|
| `ans-cfg` | `cat ~/.ansible.cfg` | 查看当前 Ansible 配置 | `ans-cfg` |
| `ans-inv` | `ansible-inventory --graph --vars` | 可视化显示 Inventory 结构 | `ans-inv` |
| `ans-vars` | `ansible-inventory --host` | 查看主机变量 | `ans-vars hostname` |
| `ans-groups` | `ansible-inventory --list` | 列出所有组 | `ans-groups` |

### 调试和日志别名

| 别名 | 对应命令 | 功能描述 | 示例 |
|------|----------|----------|------|
| `ans-debug` | `ansible-playbook -vvvv` | 启用最高详细度输出 | `ans-debug playbook.yml` |
| `ans-dry` | `ansible-playbook --check --diff` | 同 `ans-check` | `ans-dry playbook.yml` |
| `ans-tags` | `ansible-playbook --tags` | 按标签执行 Playbook | `ans-tags "deploy,config" playbook.yml` |
| `ans-skip` | `ansible-playbook --skip-tags` | 跳过指定标签 | `ans-skip "test" playbook.yml` |
| `ans-start` | `ansible-playbook --start-at-task` | 从指定任务开始执行 | `ans-start "Install nginx" playbook.yml` |
| `ans-step` | `ansible-playbook --step` | 交互式逐步执行 | `ans-step playbook.yml` |

### 过滤和限制别名

| 别名 | 对应命令 | 功能描述 | 示例 |
|------|----------|----------|------|
| `ans-limit` | `ansible-playbook --limit` | 限制执行的主机 | `ans-limit "webservers" playbook.yml` |
| `ans-host` | `ansible` | 对单个主机执行命令 | `ans-host web01 -m ping` |
| `ans-group` | `ansible` | 对单个组执行命令 | `ans-group webservers -a "uptime"` |

## 🎯 实用场景

### 场景 1：日常巡检
```bash
# 一键巡检所有服务器
ans-ping        # 检查连通性
ans-uptime      # 查看运行时间
ans-df          # 检查磁盘空间
ans-free        # 检查内存使用
```

### 场景 2：Playbook 开发调试
```bash
# 开发工作流
ans-syntax playbook.yml      # 1. 检查语法
ans-lint playbook.yml        # 2. 静态分析
ans-check playbook.yml       # 3. Dry Run
ansp playbook.yml --tags test # 4. 测试执行
ansp playbook.yml            # 5. 正式执行
```

### 场景 3：故障排查
```bash
# 快速诊断问题
ans-facts                    # 收集系统信息
ans-inv                      # 查看 Inventory 结构
ans-debug playbook.yml       # 详细输出调试
ans-step playbook.yml        # 逐步执行排查
```

### 场景 4：批量操作
```bash
# 批量执行命令
ans all -a "systemctl restart nginx"      # 重启服务
ans webservers -a "apt update && apt upgrade -y"  # 更新系统
ans dbservers -m mysql_user -a "name=app state=present"  # 管理数据库用户
```

## 🔧 自定义函数

除了别名，还提供了实用的自定义函数：

### `ans-help`
显示所有别名和函数的帮助信息。
```bash
ans-help
```

### `ans-setup`
快速配置 Ansible 环境，包括：
- 创建 `~/.ansible.cfg` 配置文件
- 创建基础目录结构
- 创建示例 Inventory 文件
```bash
ans-setup
```

### `ans-version`
显示详细的版本和环境信息：
- Ansible 版本
- Python 版本
- 配置文件状态
- Inventory 状态
```bash
ans-version
```

## ⚙️ 别名管理

### 查看已定义的别名
```bash
# Linux/macOS
alias | grep ans

# Windows PowerShell
Get-Alias | Where-Object {$_.Name -like "ans*"}
```

### 临时禁用别名
```bash
# 在命令前加反斜杠
\ans all -m ping      # 使用原始 ansible 命令
```

### 永久添加自定义别名
```bash
# 添加到 ~/.bashrc 或 ~/.zshrc
alias ans-deploy='ansible-playbook deploy.yml --tags deploy'

# 或使用函数
ans-deploy() {
    ansible-playbook deploy.yml --tags deploy $@
}
```

## 🖥️ 平台差异

### Linux/macOS
- 别名定义在 `~/.bashrc` 或 `~/.zshrc`
- 通过 `source ~/.bashrc` 重新加载
- 文件位置：`~/.ansible-aliases/ansible-aliases.sh`

### Windows
- 别名定义在 PowerShell Profile
- 通过 `. $PROFILE` 重新加载
- 文件位置：`~/.ansible-aliases/ansible-aliases.ps1`

## 🔍 常见问题

### Q: 别名不生效怎么办？
**A:** 重新加载 shell 配置：
```bash
# Linux/macOS (bash)
source ~/.bashrc

# Linux/macOS (zsh)  
source ~/.zshrc

# Windows PowerShell
. $PROFILE
```

### Q: 如何查看某个别名的具体定义？
**A:** 使用 `type` 命令：
```bash
# Linux/macOS
type ans-ping

# Windows PowerShell
Get-Alias ans-ping
```

### Q: 别名和原命令冲突怎么办？
**A:** 使用反斜杠或完整路径：
```bash
# 方法 1: 使用反斜杠
\ansible --version

# 方法 2: 使用完整路径
/usr/bin/ansible --version
```

### Q: 如何卸载别名？
**A:** 编辑 shell 配置文件，删除相关行，或运行：
```bash
# Linux/macOS
sed -i '/ansible-aliases/d' ~/.bashrc

# Windows PowerShell
# 编辑 $PROFILE 文件删除相关行
```

## 💡 使用技巧

1. **Tab 补全**：大多数 shell 支持别名补全，输入 `ans-` 后按 Tab 查看所有选项
2. **组合使用**：别名可以和其他命令组合，如 `ans-ping \| grep UNREACHABLE`
3. **日志记录**：重要操作建议记录日志，如 `ansp deploy.yml \| tee deploy.log`
4. **安全第一**：生产环境使用 `ans-check` 先检查，再执行

## 📚 深入学习

- 查看 `ans-help` 获取最新帮助
- 阅读示例文件 `examples/` 学习实际用法
- 参考 Ansible 官方文档了解底层命令

---

**提示**：安装后立即执行 `ans-help` 查看所有可用别名！