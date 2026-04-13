# 快速开始指南

5分钟内上手 Ansible 增强技能包！

## 📋 前提条件

### 1. 系统要求
- **操作系统**: Linux, macOS, 或 Windows 10/11
- **内存**: 至少 2GB RAM
- **磁盘空间**: 至少 100MB 可用空间

### 2. 软件依赖
- **Ansible** (会自动安装)
- **Python 3.6+** (会自动检查)
- **WorkBuddy** (可选，但推荐)

## 🚀 安装步骤

### 步骤 1：获取安装包

**方法 A：从朋友处获取**
```bash
# 解压安装包
tar -xzf ansible-enhanced-package.tar.gz
# 或
unzip ansible-enhanced-package.zip
```

**方法 B：从网络下载**
```bash
# 假设安装包在网盘或服务器
curl -L https://example.com/ansible-enhanced-package.tar.gz -o ansible-enhanced-package.tar.gz
tar -xzf ansible-enhanced-package.tar.gz
```

### 步骤 2：运行安装脚本

```bash
# 进入安装包目录
cd ansible-enhanced-package

# 运行跨平台安装脚本
./install/install.sh
```

### 步骤 3：按照提示操作

安装脚本会自动：
1. ✅ 检查系统依赖
2. ✅ 安装 Ansible (如果未安装)
3. ✅ 复制技能文件到 WorkBuddy
4. ✅ 配置智能别名
5. ✅ 创建示例文件

## ✅ 验证安装

安装完成后，**重新打开终端窗口**，然后执行：

```bash
# 查看帮助 - 应该能看到中文帮助信息
ans-help

# 测试 Ansible 是否正常工作
ans-version

# 输出应该类似：
# Ansible 版本信息:
# ansible [core 2.15.0]
#   config file = /home/user/.ansible.cfg
#   ...
```

## 🎯 第一个 Playbook

### 1. 创建测试 Inventory

```bash
# 使用 ans-setup 创建基础环境
ans-setup

# 或手动创建测试文件
cat > ~/ansible-test/inventory.ini << EOF
[local]
localhost ansible_connection=local
EOF
```

### 2. 创建简单 Playbook

```bash
cat > ~/ansible-test/first-test.yml << 'EOF'
---
- name: 我的第一个 Playbook
  hosts: localhost
  connection: local
  
  tasks:
    - name: 显示欢迎信息
      ansible.builtin.debug:
        msg: "🎉 恭喜！Ansible 增强技能包安装成功！"
    
    - name: 显示当前用户
      ansible.builtin.debug:
        msg: "当前用户是 {{ ansible_user_id }}"
    
    - name: 显示系统信息
      ansible.builtin.debug:
        msg: "操作系统: {{ ansible_distribution }} {{ ansible_distribution_version }}"
EOF
```

### 3. 运行 Playbook

```bash
# 进入测试目录
cd ~/ansible-test

# 运行 Playbook
ansp first-test.yml

# 输出应该类似：
# PLAY [我的第一个 Playbook] *******************************************
# TASK [显示欢迎信息] ***************************************************
# ok: [localhost] => {
#     "msg": "🎉 恭喜！Ansible 增强技能包安装成功！"
# }
# ...
```

## 🛠️ 常用命令速查

### 基础命令
```bash
# 查看所有可用命令
ans-help

# 查看 Ansible 版本
ans-version

# 快速配置环境
ans-setup
```

### 主机管理
```bash
# 测试所有主机连通性
ans-ping

# 查看所有主机运行时间
ans-uptime

# 收集主机信息
ans-facts

# 列出所有主机
ans-list
```

### Playbook 操作
```bash
# 检查语法
ans-syntax playbook.yml

# 执行 Dry Run (不实际更改)
ans-check playbook.yml

# 运行 Playbook
ansp playbook.yml

# 调试模式 (详细输出)
ans-debug playbook.yml
```

### 配置管理
```bash
# 查看当前配置
ans-cfg

# 查看 Inventory 结构
ans-inv
```

## 📁 目录结构说明

安装完成后，你的系统会有以下结构：

```
~/.workbuddy/skills/ansible-enhanced/   # 技能文件
~/.ansible-aliases/                     # 别名脚本
~/ansible-examples/                     # 示例文件
~/ansible/                              # 工作目录 (ans-setup 创建)
```

## 🔍 故障排除

### 问题 1：安装后命令不生效
```bash
# 重新加载 shell 配置
source ~/.bashrc      # 如果使用 bash
# 或
source ~/.zshrc       # 如果使用 zsh
# 或
. $PROFILE            # PowerShell
```

### 问题 2：Ansible 未安装
```bash
# 手动安装 Ansible
pip3 install ansible
# 或
brew install ansible      # macOS
# 或
sudo apt install ansible  # Ubuntu/Debian
```

### 问题 3：权限问题
```bash
# 确保安装脚本有执行权限
chmod +x install/install.sh

# 如果使用系统安装，需要管理员权限
sudo ./install/install.sh --system  # Linux/macOS
# 或以管理员身份运行 PowerShell (Windows)
```

## 📚 下一步

完成快速开始后，建议：

1. **学习基础** - 查看 `examples/` 目录中的示例
2. **掌握别名** - 阅读 [别名指南](ALIASES.md)，掌握所有快捷命令
3. **实践项目** - 尝试管理你的服务器或开发环境
4. **深入学习** - 阅读 `docs/` 目录中的完整文档

## 💡 小贴士

- 使用 `ans-help` 随时查看帮助
- `ans-setup` 创建的环境可以直接使用
- 所有别名都有中文说明，输入 `ans-help` 查看
- 遇到问题先检查 `ans-version` 输出是否正常

---

**恭喜！你已经成功安装并运行了第一个 Playbook！**

接下来，探索更多功能或开始你的自动化项目吧！🚀