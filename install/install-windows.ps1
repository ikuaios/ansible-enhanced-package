# Ansible 增强技能安装脚本 (Windows PowerShell)
# 用法: .\install-windows.ps1 [-System] [-User] [-Help]

param(
    [switch]$System,
    [switch]$User,
    [switch]$Help
)

# 颜色定义
$ErrorActionPreference = "Stop"

function Write-Colored {
    param([string]$Text, [string]$Color)
    $colors = @{
        "Red" = "Red"
        "Green" = "Green"
        "Yellow" = "Yellow"
        "Blue" = "Blue"
        "Cyan" = "Cyan"
    }
    if ($colors.ContainsKey($Color)) {
        Write-Host $Text -ForegroundColor $colors[$Color]
    } else {
        Write-Host $Text
    }
}

# 帮助信息
function Show-Help {
    Write-Colored "Ansible 增强技能安装脚本" -Color "Cyan"
    Write-Host ""
    Write-Host "用法: .\install-windows.ps1 [选项]"
    Write-Host ""
    Write-Host "选项:"
    Write-Host "  -User          安装到用户目录 (默认)"
    Write-Host "  -System        安装到系统目录 (需要管理员权限)"
    Write-Host "  -Help          显示此帮助信息"
    Write-Host ""
    Write-Host "功能:"
    Write-Host "  1. 安装 Ansible 增强技能到 WorkBuddy"
    Write-Host "  2. 配置 Ansible 别名和快捷命令"
    Write-Host "  3. 创建示例配置和 Playbook"
    Write-Host "  4. 设置基础环境"
    Write-Host ""
}

# 默认安装目录
$InstallDir = "$env:USERPROFILE\.workbuddy\skills\ansible-enhanced"
$AliasesSrc = Join-Path (Split-Path $MyInvocation.MyCommand.Path) "..\aliases"
$ExamplesSrc = Join-Path (Split-Path $MyInvocation.MyCommand.Path) "..\examples"
$DocsSrc = Join-Path (Split-Path $MyInvocation.MyCommand.Path) "..\docs"

# 检查依赖
function Check-Dependencies {
    Write-Colored "检查依赖..." -Color "Blue"
    
    # 检查 WorkBuddy
    if (-not (Test-Path "$env:USERPROFILE\.workbuddy")) {
        Write-Colored "警告: 未找到 WorkBuddy 目录，可能未安装 WorkBuddy" -Color "Yellow"
        Write-Colored "请先安装 WorkBuddy 再运行此脚本" -Color "Yellow"
        $response = Read-Host "是否继续安装技能？(y/N)"
        if ($response -notmatch "^[Yy]$") {
            exit 1
        }
    }
    
    # 检查 Ansible
    $ansibleInstalled = $false
    try {
        $null = Get-Command ansible -ErrorAction Stop
        $ansibleInstalled = $true
    } catch {
        # Ansible 未安装
    }
    
    if (-not $ansibleInstalled) {
        Write-Colored "警告: 未安装 Ansible" -Color "Yellow"
        Write-Colored "正在尝试安装 Ansible..." -Color "Blue"
        
        # 尝试通过 pip 安装
        try {
            $null = Get-Command pip -ErrorAction Stop
            Write-Colored "通过 pip 安装 Ansible..." -Color "Blue"
            pip install ansible
        } catch {
            try {
                $null = Get-Command pip3 -ErrorAction Stop
                Write-Colored "通过 pip3 安装 Ansible..." -Color "Blue"
                pip3 install ansible
            } catch {
                Write-Colored "错误: 无法自动安装 Ansible" -Color "Red"
                Write-Colored "请手动安装 Ansible:" -Color "Red"
                Write-Host "  1. 安装 Python: https://www.python.org/downloads/"
                Write-Host "  2. 安装 pip: python -m ensurepip --upgrade"
                Write-Host "  3. 安装 Ansible: pip install ansible"
                Write-Host ""
                Write-Colored "或者使用 Chocolatey:" -Color "Yellow"
                Write-Host "  1. 安装 Chocolatey: https://chocolatey.org/install"
                Write-Host "  2. 安装 Ansible: choco install ansible"
                exit 1
            }
        }
        
        # 验证安装
        try {
            $null = Get-Command ansible -ErrorAction Stop
            Write-Colored "Ansible 安装成功" -Color "Green"
        } catch {
            Write-Colored "错误: Ansible 安装失败" -Color "Red"
            exit 1
        }
    } else {
        Write-Colored "✓ Ansible 已安装" -Color "Green"
    }
    
    # 检查 Python
    $pythonInstalled = $false
    try {
        $null = Get-Command python -ErrorAction Stop
        $pythonInstalled = $true
    } catch {
        try {
            $null = Get-Command python3 -ErrorAction Stop
            $pythonInstalled = $true
        } catch {
            # Python 未安装
        }
    }
    
    if (-not $pythonInstalled) {
        Write-Colored "错误: 需要 Python 3.6+" -Color "Red"
        exit 1
    }
    Write-Colored "✓ Python 已安装" -Color "Green"
}

# 安装技能
function Install-Skill {
    Write-Colored "安装 Ansible 增强技能..." -Color "Blue"
    
    # 创建安装目录
    New-Item -ItemType Directory -Path $InstallDir -Force | Out-Null
    New-Item -ItemType Directory -Path "$InstallDir\scripts" -Force | Out-Null
    New-Item -ItemType Directory -Path "$InstallDir\references" -Force | Out-Null
    New-Item -ItemType Directory -Path "$InstallDir\assets" -Force | Out-Null
    
    # 复制技能文件
    Write-Colored "复制技能文件..." -Color "Blue"
    $skillSource = Join-Path (Split-Path $MyInvocation.MyCommand.Path) "..\skill\*"
    Copy-Item -Path $skillSource -Destination $InstallDir -Recurse -Force
    
    Write-Colored "✓ 技能文件已复制到 $InstallDir" -Color "Green"
}

# 配置别名
function Setup-Aliases {
    Write-Colored "配置 Ansible 别名..." -Color "Blue"
    
    $aliasFile = Join-Path $AliasesSrc "ansible-aliases.ps1"
    $profileFile = $PROFILE.CurrentUserAllHosts
    
    # 确保 PowerShell profile 目录存在
    $profileDir = Split-Path $profileFile -Parent
    if (-not (Test-Path $profileDir)) {
        New-Item -ItemType Directory -Path $profileDir -Force | Out-Null
    }
    
    # 检查是否已安装别名
    $aliasContent = Get-Content $aliasFile -Raw
    $profileContent = if (Test-Path $profileFile) { Get-Content $profileFile -Raw } else { "" }
    
    if ($profileContent -match [regex]::Escape($aliasFile)) {
        Write-Colored "✓ 别名已存在于 PowerShell profile" -Color "Yellow"
    } else {
        # 添加别名到 profile
        Add-Content -Path $profileFile -Value "`n# Ansible 增强别名"
        Add-Content -Path $profileFile -Value "if (Test-Path `"$aliasFile`") {"
        Add-Content -Path $profileFile -Value "    . `"$aliasFile`""
        Add-Content -Path $profileFile -Value "}"
        Write-Colored "✓ 别名已添加到 PowerShell profile" -Color "Green"
    }
    
    # 复制别名文件到用户目录
    $userAliasDir = "$env:USERPROFILE\.ansible-aliases"
    New-Item -ItemType Directory -Path $userAliasDir -Force | Out-Null
    Copy-Item -Path $aliasFile -Destination $userAliasDir -Force
    
    # 立即加载别名
    if (Test-Path $aliasFile) {
        . $aliasFile
    }
    
    Write-Colored "✓ 别名配置完成" -Color "Green"
}

# 创建示例文件
function Setup-Examples {
    Write-Colored "创建示例文件..." -Color "Blue"
    
    $examplesDir = "$env:USERPROFILE\ansible-examples"
    
    if (-not (Test-Path $examplesDir)) {
        New-Item -ItemType Directory -Path $examplesDir -Force | Out-Null
        
        # 复制示例文件
        if (Test-Path $ExamplesSrc) {
            Copy-Item -Path "$ExamplesSrc\*" -Destination $examplesDir -Recurse -Force -ErrorAction SilentlyContinue
        }
        
        # 创建基础示例
        $firstPlaybook = Join-Path $examplesDir "first-playbook.yml"
        if (-not (Test-Path $firstPlaybook)) {
            @"
---
- name: 第一个 Playbook 示例
  hosts: localhost
  connection: local
  become: false
  
  tasks:
    - name: 显示系统信息
      ansible.builtin.debug:
        msg: "欢迎使用 Ansible！当前用户是 {{ ansible_user_id }}"
    
    - name: 检查可用内存
      ansible.builtin.command: 
        cmd: systeminfo | findstr /C:"可用物理内存"
        when: ansible_os_family == "Windows"
      register: memory
      ignore_errors: true
    
    - name: 显示内存信息
      ansible.builtin.debug:
        var: memory.stdout
      when: memory is defined and memory.stdout != ""
"@ | Out-File -FilePath $firstPlaybook -Encoding UTF8
        }
        
        $inventoryFile = Join-Path $examplesDir "inventory.ini"
        if (-not (Test-Path $inventoryFile)) {
            @"
# 本地测试组
[local]
localhost ansible_connection=local

# 示例服务器组（取消注释以使用）
#[webservers]
#web01.example.com ansible_host=192.168.1.10 ansible_user=deploy
#web02.example.com ansible_host=192.168.1.11

# 组变量示例
#[webservers:vars]
#http_port=80
#max_clients=200

# 所有主机的通用变量
[all:vars]
ansible_python_interpreter=python
"@ | Out-File -FilePath $inventoryFile -Encoding UTF8
        }
        
        Write-Colored "✓ 示例文件已创建到 $examplesDir" -Color "Green"
    } else {
        Write-Colored "✓ 示例目录已存在，跳过" -Color "Yellow"
    }
}

# 安装完成提示
function Show-Completion {
    Write-Colored "=========================================" -Color "Green"
    Write-Colored "    Ansible 增强技能安装完成！" -Color "Green"
    Write-Colored "=========================================" -Color "Green"
    Write-Host ""
    
    Write-Colored "下一步操作：" -Color "Blue"
    Write-Host "1. 重新打开 PowerShell 或执行: " -NoNewline
    Write-Colored ". `$PROFILE" -Color "Yellow"
    Write-Host "2. 测试安装: " -NoNewline
    Write-Colored "ans-help" -Color "Yellow"
    Write-Host "3. 快速设置环境: " -NoNewline
    Write-Colored "ans-setup" -Color "Yellow"
    Write-Host "4. 查看版本: " -NoNewline
    Write-Colored "ans-version" -Color "Yellow"
    Write-Host ""
    Write-Colored "示例文件位置：" -Color "Blue"
    Write-Colored "  $env:USERPROFILE\ansible-examples\" -Color "Yellow"
    Write-Host ""
    Write-Colored "技能位置：" -Color "Blue"
    Write-Colored "  $InstallDir" -Color "Yellow"
    Write-Host ""
    Write-Colored "文档：" -Color "Blue"
    Write-Colored "  $DocsSrc\" -Color "Yellow"
    Write-Host ""
    Write-Colored "开始你的 Ansible 自动化之旅吧！" -Color "Green"
    Write-Host ""
}

# 主函数
function Main {
    # 解析参数
    if ($Help) {
        Show-Help
        return
    }
    
    if ($System) {
        $InstallDir = "C:\ProgramData\WorkBuddy\skills\ansible-enhanced"
        # 检查管理员权限
        $isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
        if (-not $isAdmin) {
            Write-Colored "错误: 需要管理员权限安装到系统目录" -Color "Red"
            Write-Colored "请以管理员身份运行 PowerShell" -Color "Yellow"
            exit 1
        }
    }
    
    Write-Colored "=========================================" -Color "Blue"
    Write-Colored "    Ansible 增强技能安装程序" -Color "Blue"
    Write-Colored "=========================================" -Color "Blue"
    Write-Host ""
    
    Check-Dependencies
    Install-Skill
    Setup-Aliases
    Setup-Examples
    Show-Completion
}

# 执行主函数
Main @args