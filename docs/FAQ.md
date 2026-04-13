# 常见问题解答

## 📋 安装问题

### Q1: 安装脚本提示权限不足
**A:** 根据你的需求选择安装方式：
```bash
# 安装到用户目录 (不需要管理员权限)
./install/install.sh --user

# 安装到系统目录 (需要管理员权限)
sudo ./install/install.sh --system  # Linux/macOS
# 或以管理员身份运行 PowerShell (Windows)
```

### Q2: 提示 "command not found: ansible"
**A:** 安装脚本会自动安装 Ansible，如果失败请手动安装：
```bash
# 通用方法
pip3 install ansible

# macOS
brew install ansible

# Ubuntu/Debian
sudo apt update && sudo apt install ansible

# CentOS/RHEL
sudo yum install ansible

# Windows
pip install ansible
```

### Q3: WorkBuddy 未安装，可以安装技能吗？
**A:** 可以，但别名功能可能受限。技能文件会安装到 `~/.workbuddy/skills/`，如果目录不存在会自动创建。等以后安装 WorkBuddy 后可以直接使用。

### Q4: 安装后需要重启电脑吗？
**A:** 不需要重启电脑，但需要**重新打开终端窗口**或重新加载 shell 配置：
```bash
# Linux/macOS
source ~/.bashrc   # 或 source ~/.zshrc

# Windows PowerShell
. $PROFILE
```

## 🚀 使用问题

### Q5: 别名不生效怎么办？
**A:** 按顺序检查：
1. **重新加载配置**：`source ~/.bashrc` 或 `. $PROFILE`
2. **检查安装**：运行 `ans-version` 查看是否安装成功
3. **查看别名**：运行 `alias \| grep ans` 或 `Get-Alias \| grep ans`
4. **检查文件**：确保 `~/.ansible-aliases/` 目录存在

### Q6: 如何卸载别名？
**A:** 编辑 shell 配置文件，删除包含 "ansible-aliases" 的行：
```bash
# Linux/macOS
sed -i '/ansible-aliases/d' ~/.bashrc
sed -i '/ansible-aliases/d' ~/.zshrc

# Windows PowerShell
# 编辑 $PROFILE.CurrentUserAllHosts，删除相关行
```

### Q7: 如何更新到新版本？
**A:** 重新运行安装脚本即可，它会自动覆盖旧版本：
```bash
cd ansible-enhanced-package
./install/install.sh
```

### Q8: 安装后如何测试是否成功？
**A:** 运行以下测试命令：
```bash
ans-help        # 应该显示中文帮助
ans-version     # 应该显示 Ansible 版本
ans-ping        # 应该能 ping 通 localhost
```

## 🔧 配置问题

### Q9: 如何修改默认配置？
**A:** 编辑 `~/.ansible.cfg` 文件：
```bash
# 查看当前配置
ans-cfg

# 编辑配置
nano ~/.ansible.cfg  # 或使用其他编辑器
```

### Q10: 如何设置默认 Inventory？
**A:** 在 `~/.ansible.cfg` 中添加：
```ini
[defaults]
inventory = /path/to/your/inventory.ini
```
或使用环境变量：
```bash
export ANSIBLE_INVENTORY=/path/to/inventory.ini
```

### Q11: 如何为不同项目使用不同配置？
**A:** 使用目录级别的 `ansible.cfg` 或环境变量：
```bash
# 方法1：项目目录中创建 ansible.cfg
cd /path/to/project
echo "[defaults]" > ansible.cfg
echo "inventory = ./inventory.ini" >> ansible.cfg

# 方法2：使用环境变量
export ANSIBLE_CONFIG=/path/to/project/ansible.cfg
```

### Q12: 如何配置 SSH 密钥连接？
**A:** 在 Inventory 文件中指定：
```ini
[webservers]
web01 ansible_host=192.168.1.10 ansible_user=deploy ansible_ssh_private_key_file=~/.ssh/id_rsa
```
或在 `~/.ansible.cfg` 中全局设置：
```ini
[defaults]
private_key_file = ~/.ssh/id_rsa
```

## 🐛 故障排除

### Q13: 运行 Playbook 时报错 "module not found"
**A:** 通常是 Python 环境问题：
```bash
# 检查 Python 路径
ansible all -m setup -a "filter=ansible_python*"

# 在 Inventory 中指定 Python 解释器
[all:vars]
ansible_python_interpreter=/usr/bin/python3
```

### Q14: SSH 连接超时或失败
**A:** 检查网络和 SSH 配置：
```bash
# 测试 SSH 连接
ssh user@host

# 增加超时时间
export ANSIBLE_SSH_TIMEOUT=60
export ANSIBLE_SSH_RETRIES=3

# 在 Inventory 中配置
[all:vars]
ansible_ssh_common_args='-o ConnectTimeout=60 -o ServerAliveInterval=30'
```

### Q15: Windows 主机连接失败
**A:** 确保 WinRM 已正确配置：
```ini
[windows:vars]
ansible_connection=winrm
ansible_winrm_server_cert_validation=ignore
ansible_winrm_transport=ssl
ansible_winrm_port=5986
```
参考：[Ansible Windows 设置指南](https://docs.ansible.com/ansible/latest/user_guide/windows_setup.html)

### Q16: 执行速度慢怎么办？
**A:** 启用优化选项：
```ini
[defaults]
# 启用管道传输
ansible_pipelining=true

# 启用 SSH 连接复用
ansible_ssh_args='-o ControlMaster=auto -o ControlPersist=30m'

# 设置 forks 数量
forks=20
```

## 🔐 安全问题

### Q17: 如何保护密码等敏感信息？
**A:** 使用 Ansible Vault：
```bash
# 加密文件
ans-vault encrypt secrets.yml

# 编辑加密文件
ans-vault edit secrets.yml

# 运行 Playbook 时提供密码
ansp playbook.yml --ask-vault-pass
```

### Q18: Inventory 中的密码如何安全管理？
**A:** 避免明文密码，使用以下方法：
1. **SSH 密钥认证**（推荐）
2. **Vault 加密的变量文件**
3. **环境变量**：`export ANSIBLE_PASSWORD=xxx`
4. **密码管理器集成**

### Q19: 如何安全地分享 Playbook？
**A:** 分享前：
1. 移除硬编码的密码和密钥
2. 使用变量和 Vault
3. 提供示例配置而非真实配置
4. 添加清晰的文档说明

## 📚 学习资源

### Q20: 从哪里开始学习 Ansible？
**A:** 推荐学习路径：
1. **本技能包示例**：`examples/` 目录
2. **官方文档**：https://docs.ansible.com
3. **中文教程**：搜索 "Ansible 中文教程"
4. **实践项目**：从简单的服务器管理开始

### Q21: 如何获取更多示例？
**A:** 
1. 查看 `examples/` 目录中的文件
2. 运行 `ans-galaxy install` 获取社区角色
3. 访问 Ansible Galaxy：https://galaxy.ansible.com
4. 查看 GitHub 上的 Ansible 项目

### Q22: 遇到复杂问题如何解决？
**A:** 求助渠道：
1. **官方文档**：详细且权威
2. **Stack Overflow**：使用 `ansible` 标签
3. **GitHub Issues**：报告 bug 或问题
4. **社区论坛**：中文 Ansible 社区

## 🎯 最佳实践

### Q23: Playbook 编写有什么建议？
**A:** 遵循以下原则：
- **幂等性**：多次执行结果一致
- **模块化**：使用 Roles 组织代码
- **可读性**：清晰的命名和注释
- **可维护性**：变量分离，逻辑清晰
- **可测试性**：包含测试和验证

### Q24: 如何组织大型项目？
**A:** 推荐结构：
```
project/
├── inventory/
│   ├── production/
│   ├── staging/
│   └── development/
├── group_vars/
├── host_vars/
├── roles/
│   ├── common/
│   ├── webserver/
│   └── database/
├── site.yml
└── requirements.yml
```

### Q25: 版本控制有什么建议？
**A:** 
- 使用 Git 管理 Playbook 和 Roles
- 忽略敏感文件：`.vault-password`, `secrets.yml`
- 使用 `.gitignore` 排除临时文件
- 为生产环境打标签

## 🤝 社区和支持

### Q26: 如何报告 bug 或建议？
**A:** 通过以下方式：
1. 联系安装包提供者
2. 提交 Issue 到相关仓库
3. 在社区论坛发帖

### Q27: 如何贡献改进？
**A:** 欢迎贡献：
1. **文档改进**：修复错别字，补充示例
2. **代码优化**：改进脚本和功能
3. **新功能**：添加有用的别名或工具
4. **翻译完善**：改进中文表达

### Q28: 有其他问题找不到答案？
**A:** 尝试：
1. 运行 `ans-help` 查看内置帮助
2. 检查 `docs/` 目录中的文档
3. 搜索错误信息的关键词
4. 向有经验的朋友或同事请教

---

**提示**：遇到问题先运行 `ans-version` 检查环境，然后尝试 `ans-help` 查找相关命令。