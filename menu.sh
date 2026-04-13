#!/bin/bash
# Ansible 增强技能包交互式管理菜单（增强版）
# 集成在线安装、自动依赖检测、跨平台支持
# 版本: 2.0.0

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m' # No Color

# 安装包根目录
PACKAGE_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALL_DIR="$HOME/.workbuddy/skills/ansible-enhanced"
ALIAS_FILE="$HOME/.ansible-aliases/ansible-aliases.sh"

# GitHub 仓库信息
GITHUB_REPO="ikuaios/ansible-enhanced-package"
GITHUB_URL="https://github.com/$GITHUB_REPO"
ONLINE_INSTALL_URL="https://raw.githubusercontent.com/$GITHUB_REPO/main/install-online.sh"

# 版本信息
VERSION="2.0.0"

# 显示标题
show_header() {
    clear
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║                                                                  ║${NC}"
    echo -e "${CYAN}║           Ansible 增强技能包管理菜单 (v$VERSION)              ║${NC}"
    echo -e "${CYAN}║                     GitHub: $GITHUB_REPO                   ║${NC}"
    echo -e "${CYAN}║                                                                  ║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

# 显示菜单选项
show_menu() {
    echo -e "${BLUE}请选择操作：${NC}"
    echo -e ""
    echo -e "${GREEN}[1]${NC} 安装 Ansible 增强技能包"
    echo -e "${GREEN}[2]${NC} 卸载 Ansible 增强技能包"
    echo -e "${GREEN}[3]${NC} 检查安装状态"
    echo -e "${GREEN}[4]${NC} 快速设置 Ansible 环境"
    echo -e "${GREEN}[5]${NC} 查看技能帮助"
    echo -e "${GREEN}[6]${NC} 运行示例 Playbook"
    echo -e "${GREEN}[7]${NC} 系统信息检查"
    echo -e "${GREEN}[8]${NC} 在线安装（从 GitHub）"
    echo -e "${GREEN}[9]${NC} 更新技能包"
    echo -e "${GREEN}[0]${NC} 退出"
    echo ""
}

# 检查安装状态
check_status() {
    echo -e "${BLUE}检查安装状态...${NC}"
    echo ""
    
    local status_ok=true
    
    # 检查技能目录
    if [ -d "$INSTALL_DIR" ]; then
        echo -e "${GREEN}✓ 技能目录: $INSTALL_DIR${NC}"
        echo -e "  大小: $(du -sh "$INSTALL_DIR" | cut -f1)"
        echo -e "  文件数: $(find "$INSTALL_DIR" -type f | wc -l)"
    else
        echo -e "${RED}✗ 技能目录不存在${NC}"
        status_ok=false
    fi
    
    # 检查别名配置
    local profile_file=""
    local user_shell="$(basename "$SHELL")"
    
    case "$user_shell" in
        zsh)
            profile_file="$HOME/.zshrc"
            ;;
        bash)
            if [ -f "$HOME/.bash_profile" ]; then
                profile_file="$HOME/.bash_profile"
            else
                profile_file="$HOME/.bashrc"
            fi
            ;;
        *)
            profile_file="$HOME/.bashrc"
            ;;
    esac
    
    if [ -f "$profile_file" ] && grep -q "ansible-aliases.sh" "$profile_file" 2>/dev/null; then
        echo -e "${GREEN}✓ 别名已配置在: $profile_file${NC}"
    else
        echo -e "${YELLOW}⚠ 别名未配置${NC}"
        status_ok=false
    fi
    
    # 检查示例目录
    local examples_dir="$HOME/ansible-examples"
    if [ -d "$examples_dir" ]; then
        echo -e "${GREEN}✓ 示例目录: $examples_dir${NC}"
        echo -e "  包含: $(ls "$examples_dir" | wc -l) 个文件"
    else
        echo -e "${YELLOW}⚠ 示例目录不存在${NC}"
    fi
    
    # 检查 Ansible 是否可用
    if command -v ansible &> /dev/null; then
        local ansible_version=$(ansible --version | head -1)
        echo -e "${GREEN}✓ Ansible: $ansible_version${NC}"
    else
        echo -e "${RED}✗ Ansible 未安装${NC}"
        echo -e "${YELLOW}提示: 在线安装将自动安装 Ansible${NC}"
        status_ok=false
    fi
    
    # 检查别名命令
    if command -v ans-help &> /dev/null; then
        echo -e "${GREEN}✓ 别名命令: 可用${NC}"
    else
        echo -e "${YELLOW}⚠ 别名命令: 需要重新加载 shell${NC}"
    fi
    
    echo ""
    if [ "$status_ok" = true ]; then
        echo -e "${GREEN}安装状态: 正常${NC}"
    else
        echo -e "${YELLOW}安装状态: 需要修复${NC}"
    fi
    
    read -p "按回车键继续..."
}

# 快速设置环境
quick_setup() {
    echo -e "${BLUE}快速设置 Ansible 环境...${NC}"
    echo ""
    
    # 创建 ~/.ansible.cfg 如果不存在
    local ansible_cfg="$HOME/.ansible.cfg"
    if [ ! -f "$ansible_cfg" ]; then
        cat > "$ansible_cfg" << EOF
[defaults]
# 禁用主机密钥检查（避免首次连接时的确认提示）
host_key_checking = False

# 自动发现 Python 解释器
interpreter_python = auto

# 默认 inventory 文件
# inventory = ~/ansible-examples/inventory.ini

# 显示详细的执行结果
stdout_callback = yaml

# 连接超时设置
timeout = 30

# 启用缓存
fact_caching = jsonfile
fact_caching_connection = ~/.ansible/cache
fact_caching_timeout = 3600

[privilege_escalation]
# 如果不需要提权，注释掉以下行
# become = True
# become_method = sudo
# become_user = root
# become_ask_pass = False

[ssh_connection]
# SSH 连接优化
ssh_args = -o ControlMaster=auto -o ControlPersist=60s -o ServerAliveInterval=30
control_path = ~/.ssh/ansible-%%r@%%h:%%p
EOF
        echo -e "${GREEN}✓ 已创建默认 Ansible 配置: $ansible_cfg${NC}"
    else
        echo -e "${YELLOW}✓ Ansible 配置文件已存在${NC}"
    fi
    
    # 创建示例目录如果不存在
    local examples_dir="$HOME/ansible-examples"
    if [ ! -d "$examples_dir" ]; then
        mkdir -p "$examples_dir"
        cp -r "$PACKAGE_ROOT/examples/"* "$examples_dir/" 2>/dev/null || true
        echo -e "${GREEN}✓ 已创建示例目录: $examples_dir${NC}"
    fi
    
    # 创建默认 inventory 如果不存在
    local inventory_file="$examples_dir/inventory.ini"
    if [ ! -f "$inventory_file" ]; then
        cat > "$inventory_file" << EOF
# 本地测试组
[local]
localhost ansible_connection=local ansible_python_interpreter=/usr/bin/python3

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
ansible_python_interpreter=/usr/bin/python3
EOF
        echo -e "${GREEN}✓ 已创建默认 inventory: $inventory_file${NC}"
    fi
    
    echo ""
    echo -e "${BLUE}快速设置完成！${NC}"
    echo -e "配置文件: $ansible_cfg"
    echo -e "示例目录: $examples_dir"
    echo ""
    
    # 显示快速命令
    echo -e "${YELLOW}快速命令：${NC}"
    echo -e "  ans-ping          # 测试本地连接"
    echo -e "  ans-list          # 列出所有主机"
    echo -e "  ans-cfg           # 查看当前配置"
    echo -e "  ans-help          # 查看所有命令"
    echo ""
    
    read -p "按回车键继续..."
}

# 查看技能帮助
show_skill_help() {
    echo -e "${BLUE}Ansible 增强技能包帮助${NC}"
    echo ""
    
    cat << EOF
${GREEN}核心功能：${NC}
1. 智能别名系统 - 50+ 实用别名，提高工作效率
2. 中文文档 - 完整的使用指南和示例
3. 跨平台支持 - Linux, macOS, Windows
4. 一键安装 - 自动检测系统，无需手动配置
5. 在线安装 - 直接从 GitHub 安装最新版本
6. 自动依赖安装 - 自动检测并安装 Ansible

${GREEN}常用命令：${NC}
${YELLOW}ans-help${NC}       - 显示所有可用别名
${YELLOW}ans-ping${NC}       - 对所有主机执行 ping 测试
${YELLOW}ans-uptime${NC}     - 查看所有主机运行时间
${YELLOW}ans-list${NC}       - 列出所有主机
${YELLOW}ans-cfg${NC}        - 查看当前 Ansible 配置
${YELLOW}ans-syntax${NC}     - 检查 Playbook 语法
${YELLOW}ans-check${NC}      - 执行 Dry Run (检查变更)
${YELLOW}ans-setup${NC}      - 快速配置 Ansible 环境

${GREEN}文档位置：${NC}
$PACKAGE_ROOT/docs/
   ├── quick-start.md      # 快速入门
   ├── aliases-guide.md    # 别名使用指南
   ├── examples.md         # 示例说明
   └── faq.md              # 常见问题

${GREEN}示例位置：${NC}
$HOME/ansible-examples/
   ├── first-playbook.yml  # 第一个 Playbook
   └── inventory.ini       # 主机清单示例

${GREEN}技能位置：${NC}
$INSTALL_DIR

${GREEN}GitHub 仓库：${NC}
$GITHUB_URL

EOF
    
    read -p "按回车键继续..."
}

# 运行示例 Playbook
run_example() {
    echo -e "${BLUE}运行示例 Playbook...${NC}"
    echo ""
    
    local examples_dir="$HOME/ansible-examples"
    local playbook="$examples_dir/first-playbook.yml"
    
    if [ ! -f "$playbook" ]; then
        echo -e "${YELLOW}示例 Playbook 不存在，正在创建...${NC}"
        quick_setup
    fi
    
    if [ -f "$playbook" ]; then
        echo -e "${GREEN}正在运行: $playbook${NC}"
        echo ""
        
        # 显示 Playbook 内容
        echo -e "${YELLOW}Playbook 内容：${NC}"
        echo "---"
        head -20 "$playbook" | while read line; do
            echo "  $line"
        done
        echo "..."
        echo ""
        
        # 确认运行
        read -p "是否运行此 Playbook？(y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            echo -e "${BLUE}执行中...${NC}"
            echo ""
            
            if command -v ansible-playbook &> /dev/null; then
                ansible-playbook "$playbook" --inventory "$examples_dir/inventory.ini"
            else
                echo -e "${RED}错误: ansible-playbook 命令未找到${NC}"
                echo -e "请确保 Ansible 已正确安装"
            fi
        else
            echo -e "${YELLOW}已取消${NC}"
        fi
    else
        echo -e "${RED}错误: 无法找到示例 Playbook${NC}"
    fi
    
    echo ""
    read -p "按回车键继续..."
}

# 系统信息检查
system_info() {
    echo -e "${BLUE}系统信息检查...${NC}"
    echo ""
    
    echo -e "${YELLOW}操作系统：${NC}"
    uname -a
    
    echo -e "\n${YELLOW}Shell：${NC}"
    echo "$SHELL - $(basename "$SHELL")"
    
    echo -e "\n${YELLOW}Python：${NC}"
    if command -v python3 &> /dev/null; then
        python3 --version
    elif command -v python &> /dev/null; then
        python --version
    else
        echo "未安装"
    fi
    
    echo -e "\n${YELLOW}Ansible：${NC}"
    if command -v ansible &> /dev/null; then
        ansible --version | head -1
    else
        echo "未安装"
    fi
    
    echo -e "\n${YELLOW}WorkBuddy 技能目录：${NC}"
    if [ -d "$HOME/.workbuddy/skills" ]; then
        echo "$HOME/.workbuddy/skills/"
        ls -la "$HOME/.workbuddy/skills/" | grep ansible || echo "  (未找到 Ansible 技能)"
    else
        echo "不存在"
    fi
    
    echo -e "\n${YELLOW}GitHub 仓库状态：${NC}"
    if ping -c 1 -W 1 github.com &> /dev/null; then
        echo -e "${GREEN}✓ GitHub 可访问${NC}"
    else
        echo -e "${YELLOW}⚠ GitHub 无法访问，在线功能不可用${NC}"
    fi
    
    echo -e "\n${YELLOW}磁盘空间：${NC}"
    df -h | grep -E '(/|/home|/Users)' | head -3
    
    echo ""
    read -p "按回车键继续..."
}

# 检测 Ansible 并自动安装
install_ansible_auto() {
    echo -e "${BLUE}检查 Ansible 安装状态...${NC}"
    
    if command -v ansible &> /dev/null; then
        local ansible_version=$(ansible --version | head -1)
        echo -e "${GREEN}✓ Ansible 已安装: $ansible_version${NC}"
        return 0
    fi
    
    echo -e "${YELLOW}⚠ Ansible 未安装，尝试自动安装...${NC}"
    
    local os_type=$(detect_os)
    case "$os_type" in
        linux)
            echo -e "${BLUE}检测到 Linux 系统，尝试安装 Ansible...${NC}"
            
            # 尝试 pip3
            if command -v pip3 &> /dev/null; then
                echo -e "尝试使用 pip3 安装..."
                pip3 install ansible --quiet
                if command -v ansible &> /dev/null; then
                    echo -e "${GREEN}✓ 通过 pip3 安装成功${NC}"
                    return 0
                fi
            fi
            
            # 尝试 apt-get (Debian/Ubuntu)
            if command -v apt-get &> /dev/null; then
                echo -e "尝试使用 apt-get 安装..."
                sudo apt-get update -qq
                sudo apt-get install -y ansible --quiet
                if command -v ansible &> /dev/null; then
                    echo -e "${GREEN}✓ 通过 apt-get 安装成功${NC}"
                    return 0
                fi
            fi
            
            # 尝试 yum (CentOS/RHEL)
            if command -v yum &> /dev/null; then
                echo -e "尝试使用 yum 安装..."
                sudo yum install -y epel-release --quiet
                sudo yum install -y ansible --quiet
                if command -v ansible &> /dev/null; then
                    echo -e "${GREEN}✓ 通过 yum 安装成功${NC}"
                    return 0
                fi
            fi
            ;;
            
        macos)
            echo -e "${BLUE}检测到 macOS 系统，尝试安装 Ansible...${NC}"
            
            # 尝试 pip3
            if command -v pip3 &> /dev/null; then
                echo -e "尝试使用 pip3 安装..."
                pip3 install ansible --quiet
                if command -v ansible &> /dev/null; then
                    echo -e "${GREEN}✓ 通过 pip3 安装成功${NC}"
                    return 0
                fi
            fi
            
            # 尝试 brew
            if command -v brew &> /dev/null; then
                echo -e "尝试使用 brew 安装..."
                brew install ansible --quiet
                if command -v ansible &> /dev/null; then
                    echo -e "${GREEN}✓ 通过 brew 安装成功${NC}"
                    return 0
                fi
            fi
            ;;
            
        *)
            echo -e "${RED}不支持的操作系统: $os_type${NC}"
            ;;
    esac
    
    echo -e "${YELLOW}⚠ 自动安装失败，请手动安装 Ansible${NC}"
    echo -e "安装方法："
    echo -e "  Linux (Debian/Ubuntu): sudo apt-get install ansible"
    echo -e "  Linux (CentOS/RHEL): sudo yum install ansible"
    echo -e "  macOS: brew install ansible 或 pip3 install ansible"
    echo -e "  Windows: pip install ansible"
    echo -e "更多信息请参考: https://docs.ansible.com/ansible/latest/installation_guide/"
    
    read -p "是否继续安装技能包？(y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        return 1
    fi
    
    return 0
}

# 执行本地安装
perform_install_local() {
    echo -e "${BLUE}启动本地安装程序...${NC}"
    echo ""
    
    local install_script="$PACKAGE_ROOT/install/install.sh"
    
    if [ -f "$install_script" ]; then
        echo -e "${GREEN}找到安装脚本: $install_script${NC}"
        echo ""
        
        # 检查 Ansible
        install_ansible_auto
        
        # 显示安装选项
        echo -e "${YELLOW}安装选项：${NC}"
        echo -e "  1) 标准安装（用户目录）"
        echo -e "  2) 系统安装（需要 root 权限）"
        echo -e "  3) 自定义安装"
        echo ""
        
        read -p "请选择安装模式 [1-3]: " install_mode
        
        case $install_mode in
            1)
                echo -e "\n${BLUE}执行标准安装...${NC}"
                chmod +x "$install_script"
                "$install_script" --user
                ;;
            2)
                echo -e "\n${BLUE}执行系统安装...${NC}"
                chmod +x "$install_script"
                "$install_script" --system
                ;;
            3)
                echo -e "\n${BLUE}自定义安装${NC}"
                echo -e "请直接运行: ${YELLOW}$install_script --help${NC}"
                echo -e "查看所有可用选项"
                ;;
            *)
                echo -e "\n${RED}无效选择，返回菜单${NC}"
                read -p "按回车键继续..."
                return
                ;;
        esac
    else
        echo -e "${RED}错误: 安装脚本不存在${NC}"
        read -p "按回车键继续..."
    fi
}

# 执行在线安装
perform_install_online() {
    echo -e "${BLUE}启动在线安装程序...${NC}"
    echo ""
    
    echo -e "${YELLOW}在线安装将：${NC}"
    echo -e "  1. 从 GitHub 下载最新版本"
    echo -e "  2. 自动检测并安装 Ansible（如果未安装）"
    echo -e "  3. 安装 Ansible 增强技能包"
    echo -e "  4. 配置别名和示例"
    echo ""
    
    read -p "是否继续？(y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo -e "${YELLOW}取消在线安装${NC}"
        return
    fi
    
    echo -e "${BLUE}开始在线安装...${NC}"
    echo ""
    
    # 检查网络连接
    echo -e "${YELLOW}检查 GitHub 连接...${NC}"
    if ! ping -c 1 -W 2 github.com &> /dev/null; then
        echo -e "${RED}错误: 无法连接到 GitHub，请检查网络${NC}"
        read -p "按回车键继续..."
        return
    fi
    
    echo -e "${GREEN}✓ GitHub 可访问${NC}"
    echo ""
    
    # 执行在线安装
    echo -e "${BLUE}下载安装脚本...${NC}"
    echo -e "URL: $ONLINE_INSTALL_URL"
    echo ""
    
    if command -v curl &> /dev/null; then
        curl -sSL "$ONLINE_INSTALL_URL" | bash
    elif command -v wget &> /dev/null; then
        wget -q -O - "$ONLINE_INSTALL_URL" | bash
    else
        echo -e "${RED}错误: 需要 curl 或 wget 命令${NC}"
        echo -e "请先安装 curl 或 wget，然后重试"
        read -p "按回车键继续..."
        return
    fi
    
    echo -e "${GREEN}在线安装完成！${NC}"
    echo -e "请重新打开终端或执行: ${YELLOW}source ~/.bashrc${NC} (或 ${YELLOW}source ~/.zshrc${NC})"
    read -p "按回车键继续..."
}

# 执行卸载
perform_uninstall() {
    echo -e "${BLUE}启动卸载程序...${NC}"
    echo ""
    
    local uninstall_script="$PACKAGE_ROOT/install/uninstall-linux-macos.sh"
    
    if [ -f "$uninstall_script" ]; then
        echo -e "${GREEN}找到卸载脚本: $uninstall_script${NC}"
        echo ""
        
        # 显示卸载选项
        echo -e "${RED}警告：卸载将移除 Ansible 增强技能${NC}"
        echo ""
        echo -e "${YELLOW}卸载选项：${NC}"
        echo -e "  1) 安全卸载（询问确认）"
        echo -e "  2) 强制卸载（跳过确认）"
        echo -e "  3) 仅查看要移除的内容"
        echo ""
        
        read -p "请选择卸载模式 [1-3]: " uninstall_mode
        
        case $uninstall_mode in
            1)
                echo -e "\n${BLUE}执行安全卸载...${NC}"
                chmod +x "$uninstall_script"
                "$uninstall_script" --user
                ;;
            2)
                echo -e "\n${RED}执行强制卸载...${NC}"
                chmod +x "$uninstall_script"
                "$uninstall_script" --user --force
                ;;
            3)
                echo -e "\n${YELLOW}检查要移除的内容...${NC}"
                chmod +x "$uninstall_script"
                "$uninstall_script" --user --help
                ;;
            *)
                echo -e "\n${RED}无效选择，返回菜单${NC}"
                read -p "按回车键继续..."
                return
                ;;
        esac
    else
        echo -e "${RED}错误: 卸载脚本不存在${NC}"
        read -p "按回车键继续..."
    fi
}

# 更新技能包
update_skill() {
    echo -e "${BLUE}更新技能包...${NC}"
    echo ""
    
    if ! check_installed; then
        echo -e "${YELLOW}未发现已安装的 Ansible 增强技能包${NC}"
        read -p "是否现在安装？(y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            show_install_menu
        fi
        return
    fi
    
    echo -e "${YELLOW}请选择更新方式：${NC}"
    echo -e "  1) 在线更新（从 GitHub 下载最新版本）"
    echo -e "  2) 本地更新（使用当前目录的安装包）"
    echo -e "  3) 检查更新（仅查看是否有新版本）"
    echo ""
    
    read -p "请选择 [1-3]: " update_mode
    
    case $update_mode in
        1)
            echo -e "\n${BLUE}执行在线更新...${NC}"
            perform_install_online
            ;;
        2)
            echo -e "\n${BLUE}执行本地更新...${NC}"
            echo -e "${YELLOW}注意：本地更新需要先卸载旧版本${NC}"
            read -p "是否继续？(y/N): " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                perform_uninstall
                echo -e "${BLUE}现在重新安装...${NC}"
                perform_install_local
            fi
            ;;
        3)
            echo -e "\n${BLUE}检查更新...${NC}"
            echo -e "${YELLOW}此功能需要网络连接${NC}"
            
            if ping -c 1 -W 2 github.com &> /dev/null; then
                echo -e "${GREEN}✓ GitHub 可访问${NC}"
                echo -e "${BLUE}检查最新版本...${NC}"
                echo -e "本地版本: v$VERSION"
                echo -e "GitHub 仓库: $GITHUB_URL"
                echo -e "请访问 GitHub 查看最新版本"
                echo -e "建议使用在线安装获取最新版本"
            else
                echo -e "${YELLOW}⚠ 无法连接到 GitHub${NC}"
            fi
            read -p "按回车键继续..."
            ;;
        *)
            echo -e "\n${RED}无效选择${NC}"
            ;;
    esac
}

# 安装菜单
show_install_menu() {
    echo -e "${BLUE}请选择安装方式：${NC}"
    echo -e ""
    echo -e "${GREEN}[1]${NC} 本地安装（使用当前目录的安装包）"
    echo -e "${GREEN}[2]${NC} 在线安装（从 GitHub 下载最新版本）"
    echo -e "${GREEN}[0]${NC} 返回主菜单"
    echo ""
    
    read -p "请选择: " install_choice
    
    case $install_choice in
        1)
            perform_install_local
            ;;
        2)
            perform_install_online
            ;;
        0)
            return
            ;;
        *)
            echo -e "\n${RED}无效选择${NC}"
            read -p "按回车键继续..."
            ;;
    esac
}

# 检查是否已安装
check_installed() {
    if [ -d "$INSTALL_DIR" ] && [ -f "$ALIAS_FILE" ]; then
        return 0
    else
        return 1
    fi
}

# 检测操作系统
detect_os() {
    case "$(uname -s)" in
        Linux*)
            echo "linux"
            ;;
        Darwin*)
            echo "macos"
            ;;
        CYGWIN*|MINGW*|MSYS*)
            echo "windows"
            ;;
        *)
            echo "unknown"
            ;;
    esac
}

# 检查是否在正确的目录
check_directory() {
    if [ ! -d "$PACKAGE_ROOT/install" ] || [ ! -d "$PACKAGE_ROOT/skill" ]; then
        echo -e "${RED}错误: 请在安装包根目录运行此脚本${NC}"
        echo -e "当前目录: $PACKAGE_ROOT"
        echo -e "需要的目录结构:"
        echo -e "  ./install/    # 安装脚本"
        echo -e "  ./skill/      # 技能文件"
        echo -e "  ./docs/       # 文档"
        exit 1
    fi
}

# 主菜单循环
main_menu() {
    while true; do
        show_header
        show_menu
        
        read -p "请输入选项 [0-9]: " choice
        
        case $choice in
            1)
                show_install_menu
                ;;
            2)
                perform_uninstall
                ;;
            3)
                check_status
                ;;
            4)
                quick_setup
                ;;
            5)
                show_skill_help
                ;;
            6)
                run_example
                ;;
            7)
                system_info
                ;;
            8)
                perform_install_online
                ;;
            9)
                update_skill
                ;;
            0)
                echo -e "\n${GREEN}感谢使用，再见！${NC}"
                echo ""
                exit 0
                ;;
            *)
                echo -e "\n${RED}无效选项，请重新输入${NC}"
                sleep 1
                ;;
        esac
    done
}

# 检测操作系统
detect_os_and_check() {
    local os_type=$(detect_os)
    
    case "$os_type" in
        linux|macos)
            echo -e "${GREEN}检测到 ${os_type} 系统${NC}"
            ;;
        windows)
            echo -e "${YELLOW}检测到 Windows 系统${NC}"
            echo -e "${YELLOW}注意：在 Windows 上，请使用 Git Bash 或 WSL 运行此脚本${NC}"
            read -p "是否继续？(y/N): " -n 1 -r
            echo
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                exit 0
            fi
            ;;
        unknown)
            echo -e "${YELLOW}警告: 未知操作系统类型${NC}"
            echo -e "继续运行可能遇到兼容性问题"
            read -p "是否继续？(y/N): " -n 1 -r
            echo
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                exit 0
            fi
            ;;
    esac
}

# 主函数
main() {
    # 检查目录
    check_directory
    
    # 检测操作系统
    detect_os_and_check
    
    # 进入主菜单
    main_menu
}

# 执行主函数
main "$@"