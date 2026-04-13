#!/bin/bash
# Ansible 增强别名脚本 (macOS/Linux)
# 将此文件添加到 ~/.bashrc 或 ~/.zshrc: source /path/to/ansible-aliases.sh

# 核心别名
alias ans='ansible'
alias ansp='ansible-playbook'
alias ans-vault='ansible-vault'
alias ans-galaxy='ansible-galaxy'
alias ans-config='ansible-config'

# 快捷操作
alias ans-ping='ansible all -m ping'
alias ans-uptime='ansible all -a "uptime"'
alias ans-facts='ansible all -m setup'
alias ans-list='ansible all --list-hosts'

# 语法检查
alias ans-syntax='ansible-playbook --syntax-check'
alias ans-check='ansible-playbook --check --diff'
alias ans-lint='python3 -m ansible.utils.playbook_linter'

# 配置管理
alias ans-cfg='cat ~/.ansible.cfg 2>/dev/null || echo "No ~/.ansible.cfg found"'
alias ans-inv='ansible-inventory --graph --vars'

# 调试和日志
alias ans-debug='ansible-playbook -vvvv'
alias ans-dry='ansible-playbook --check --diff'
alias ans-tags='ansible-playbook --tags'

# 帮助函数
ans-help() {
    echo "=== Ansible 增强别名帮助 ==="
    echo "核心命令:"
    echo "  ans           - ansible 快捷方式"
    echo "  ansp          - ansible-playbook 快捷方式"
    echo "  ans-vault     - ansible-vault 快捷方式"
    echo "  ans-galaxy    - ansible-galaxy 快捷方式"
    echo "  ans-config    - ansible-config 快捷方式"
    echo ""
    echo "快捷操作:"
    echo "  ans-ping      - 对所有主机执行 ping 测试"
    echo "  ans-uptime    - 查看所有主机运行时间"
    echo "  ans-facts     - 收集所有主机信息"
    echo "  ans-list      - 列出所有主机"
    echo ""
    echo "语法检查:"
    echo "  ans-syntax    - 检查 Playbook 语法"
    echo "  ans-check     - 执行 Dry Run (检查变更)"
    echo "  ans-lint      - 运行 Playbook 检查器"
    echo ""
    echo "配置管理:"
    echo "  ans-cfg       - 查看当前 Ansible 配置"
    echo "  ans-inv       - 可视化显示 Inventory"
    echo ""
    echo "调试:"
    echo "  ans-debug     - 启用最高详细度输出 (-vvvv)"
    echo "  ans-dry       - 同 ans-check"
    echo "  ans-tags      - 按标签执行 Playbook"
    echo ""
    echo "自定义函数:"
    echo "  ans-help      - 显示此帮助信息"
    echo "  ans-setup     - 快速配置 Ansible 环境"
    echo "  ans-version   - 显示 Ansible 版本信息"
}

# 环境设置函数
ans-setup() {
    echo "正在设置 Ansible 环境..."
    
    # 创建基础配置文件
    if [ ! -f ~/.ansible.cfg ]; then
        cat > ~/.ansible.cfg << 'EOF'
[defaults]
# 禁用主机密钥检查（首次连接不需要确认）
host_key_checking = False

# 自动发现 Python 解释器
interpreter_python = auto

# 禁用弃用警告
deprecation_warnings = False

# 设置默认 Inventory 文件
# inventory = ~/ansible/inventory.ini

# 设置默认 Roles 路径
roles_path = ~/.ansible/roles:/usr/share/ansible/roles:/etc/ansible/roles

# 设置默认库路径
library = ~/.ansible/plugins/modules:/usr/share/ansible/plugins/modules

# 启用回调插件
stdout_callback = yaml

# 禁用颜色（在某些终端中更清晰）
# nocolor = 1

[privilege_escalation]
# 默认不提升权限
# become = False
# become_method = sudo
# become_user = root
# become_ask_pass = False
EOF
        echo "已创建 ~/.ansible.cfg"
    else
        echo "~/.ansible.cfg 已存在，跳过创建"
    fi
    
    # 创建基础目录结构
    mkdir -p ~/ansible/{inventory,playbooks,roles,vars,files,templates}
    echo "已创建 Ansible 目录结构: ~/ansible/"
    
    # 创建示例 Inventory
    if [ ! -f ~/ansible/inventory.ini ]; then
        cat > ~/ansible/inventory.ini << 'EOF'
# 本地测试主机
[local]
localhost ansible_connection=local ansible_python_interpreter=/usr/bin/python3

# 示例服务器组
#[webservers]
#web01.example.com ansible_host=192.168.1.10 ansible_user=deploy
#web02.example.com ansible_host=192.168.1.11

#[dbservers]
#db01.example.com ansible_host=192.168.1.20 ansible_user=admin

# 组变量
#[webservers:vars]
#http_port=80
#max_clients=200

#[dbservers:vars]
#mysql_port=3306

# 所有主机的通用变量
#[all:vars]
#ansible_python_interpreter=/usr/bin/python3
#ansible_ssh_private_key_file=~/.ssh/id_rsa
EOF
        echo "已创建示例 Inventory: ~/ansible/inventory.ini"
    fi
    
    echo "环境设置完成！"
    echo "使用 'ans-help' 查看可用命令"
}

# 版本信息函数
ans-version() {
    echo "Ansible 版本信息:"
    ansible --version 2>/dev/null || echo "Ansible 未安装"
    echo ""
    echo "Python 版本:"
    python3 --version 2>/dev/null || python --version 2>/dev/null || echo "Python 未安装"
    echo ""
    echo "环境信息:"
    echo "配置文件: $(ls ~/.ansible.cfg 2>/dev/null || echo '未找到')"
    echo "Inventory: $(ls ~/ansible/inventory.ini 2>/dev/null || echo '未找到')"
}

echo "Ansible 增强别名已加载！输入 'ans-help' 查看帮助。"