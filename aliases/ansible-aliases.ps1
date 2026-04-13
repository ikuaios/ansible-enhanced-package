# Ansible 增强别名脚本 (Windows PowerShell)
# 将此文件添加到 $PROFILE: .\path\to\ansible-aliases.ps1

# 核心别名
Set-Alias -Name ans -Value ansible
Set-Alias -Name ansp -Value ansible-playbook
Set-Alias -Name ans-vault -Value ansible-vault
Set-Alias -Name ans-galaxy -Value ansible-galaxy
Set-Alias -Name ans-config -Value ansible-config

# 快捷操作函数
function ans-ping { ansible all -m ping }
function ans-uptime { ansible all -a "uptime" }
function ans-facts { ansible all -m setup }
function ans-list { ansible all --list-hosts }

# 语法检查函数
function ans-syntax { ansible-playbook --syntax-check @args }
function ans-check { ansible-playbook --check --diff @args }
function ans-lint { python -m ansible.utils.playbook_linter @args }

# 配置管理函数
function ans-cfg { 
    if (Test-Path ~/.ansible.cfg) {
        Get-Content ~/.ansible.cfg
    } else {
        Write-Host "No ~/.ansible.cfg found"
    }
}

function ans-inv { ansible-inventory --graph --vars @args }

# 调试和日志函数
function ans-debug { ansible-playbook -vvvv @args }
function ans-dry { ansible-playbook --check --diff @args }
function ans-tags { ansible-playbook --tags @args }

# 帮助函数
function ans-help {
    Write-Host "=== Ansible 增强别名帮助 ===" -ForegroundColor Cyan
    Write-Host "核心命令:"
    Write-Host "  ans           - ansible 快捷方式"
    Write-Host "  ansp          - ansible-playbook 快捷方式"
    Write-Host "  ans-vault     - ansible-vault 快捷方式"
    Write-Host "  ans-galaxy    - ansible-galaxy 快捷方式"
    Write-Host "  ans-config    - ansible-config 快捷方式"
    Write-Host ""
    Write-Host "快捷操作:"
    Write-Host "  ans-ping      - 对所有主机执行 ping 测试"
    Write-Host "  ans-uptime    - 查看所有主机运行时间"
    Write-Host "  ans-facts     - 收集所有主机信息"
    Write-Host "  ans-list      - 列出所有主机"
    Write-Host ""
    Write-Host "语法检查:"
    Write-Host "  ans-syntax    - 检查 Playbook 语法"
    Write-Host "  ans-check     - 执行 Dry Run (检查变更)"
    Write-Host "  ans-lint      - 运行 Playbook 检查器"
    Write-Host ""
    Write-Host "配置管理:"
    Write-Host "  ans-cfg       - 查看当前 Ansible 配置"
    Write-Host "  ans-inv       - 可视化显示 Inventory"
    Write-Host ""
    Write-Host "调试:"
    Write-Host "  ans-debug     - 启用最高详细度输出 (-vvvv)"
    Write-Host "  ans-dry       - 同 ans-check"
    Write-Host "  ans-tags      - 按标签执行 Playbook"
    Write-Host ""
    Write-Host "自定义函数:"
    Write-Host "  ans-help      - 显示此帮助信息"
    Write-Host "  ans-setup     - 快速配置 Ansible 环境"
    Write-Host "  ans-version   - 显示 Ansible 版本信息"
}

# 环境设置函数
function ans-setup {
    Write-Host "正在设置 Ansible 环境..." -ForegroundColor Blue
    
    # 创建基础配置文件
    if (-not (Test-Path ~/.ansible.cfg)) {
        @"
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
"@ | Out-File -FilePath ~/.ansible.cfg -Encoding UTF8
        Write-Host "已创建 ~/.ansible.cfg" -ForegroundColor Green
    } else {
        Write-Host "~/.ansible.cfg 已存在，跳过创建" -ForegroundColor Yellow
    }
    
    # 创建基础目录结构
    $ansibleDir = "$env:USERPROFILE\ansible"
    New-Item -ItemType Directory -Path "$ansibleDir\inventory" -Force | Out-Null
    New-Item -ItemType Directory -Path "$ansibleDir\playbooks" -Force | Out-Null
    New-Item -ItemType Directory -Path "$ansibleDir\roles" -Force | Out-Null
    New-Item -ItemType Directory -Path "$ansibleDir\vars" -Force | Out-Null
    New-Item -ItemType Directory -Path "$ansibleDir\files" -Force | Out-Null
    New-Item -ItemType Directory -Path "$ansibleDir\templates" -Force | Out-Null
    Write-Host "已创建 Ansible 目录结构: $ansibleDir\" -ForegroundColor Green
    
    # 创建示例 Inventory
    $inventoryFile = "$ansibleDir\inventory.ini"
    if (-not (Test-Path $inventoryFile)) {
        @"
# 本地测试主机
[local]
localhost ansible_connection=local ansible_python_interpreter=python

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
#ansible_python_interpreter=python
#ansible_ssh_private_key_file=~/.ssh/id_rsa
"@ | Out-File -FilePath $inventoryFile -Encoding UTF8
        Write-Host "已创建示例 Inventory: $inventoryFile" -ForegroundColor Green
    }
    
    Write-Host "环境设置完成！" -ForegroundColor Green
    Write-Host "使用 'ans-help' 查看可用命令" -ForegroundColor Cyan
}

# 版本信息函数
function ans-version {
    Write-Host "Ansible 版本信息:" -ForegroundColor Cyan
    try {
        ansible --version 2>$null
    } catch {
        Write-Host "Ansible 未安装" -ForegroundColor Red
    }
    Write-Host ""
    Write-Host "Python 版本:" -ForegroundColor Cyan
    try {
        python --version 2>$null
    } catch {
        try {
            python3 --version 2>$null
        } catch {
            Write-Host "Python 未安装" -ForegroundColor Red
        }
    }
    Write-Host ""
    Write-Host "环境信息:" -ForegroundColor Cyan
    Write-Host "配置文件: $(if (Test-Path ~/.ansible.cfg) { '已找到' } else { '未找到' })"
    Write-Host "Inventory: $(if (Test-Path ~/ansible/inventory.ini) { '已找到' } else { '未找到' })"
}

Write-Host "Ansible 增强别名已加载！输入 'ans-help' 查看帮助。" -ForegroundColor Green