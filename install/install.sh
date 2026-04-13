#!/bin/bash
# Ansible 增强技能跨平台安装脚本
# 自动检测操作系统并调用相应的安装脚本

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

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

# 显示标题
show_header() {
    echo -e "${BLUE}=========================================${NC}"
    echo -e "${BLUE}    Ansible 增强技能安装程序${NC}"
    echo -e "${BLUE}=========================================${NC}"
    echo ""
}

# 显示帮助
show_help() {
    cat << EOF
Ansible 增强技能跨平台安装脚本

用法: ./install.sh [选项]

选项:
  --user          安装到用户目录 (默认)
  --system        安装到系统目录 (需要管理员/root权限)
  --help          显示此帮助信息

平台支持:
  - Linux (Ubuntu/Debian/CentOS/RHEL/Fedora)
  - macOS
  - Windows (通过 PowerShell)

功能:
  1. 自动检测操作系统
  2. 安装 Ansible 增强技能到 WorkBuddy
  3. 配置 Ansible 别名和快捷命令
  4. 创建示例配置和 Playbook
  5. 设置基础环境

安装包内容:
  - ansible-expert 技能 (增强版)
  - 跨平台别名配置
  - 示例 Playbook 和 Inventory
  - 中文文档和速查表

EOF
}

# Linux/macOS 安装
install_linux_macos() {
    echo -e "${BLUE}检测到 Linux/macOS 系统${NC}"
    
    local install_script="$(dirname "$0")/install-linux-macos.sh"
    
    if [ ! -f "$install_script" ]; then
        echo -e "${RED}错误: 找不到安装脚本 $install_script${NC}"
        exit 1
    fi
    
    # 传递所有参数
    chmod +x "$install_script"
    "$install_script" "$@"
}

# Windows 安装
install_windows() {
    echo -e "${BLUE}检测到 Windows 系统${NC}"
    
    local install_script="$(dirname "$0")/install-windows.ps1"
    
    if [ ! -f "$install_script" ]; then
        echo -e "${RED}错误: 找不到安装脚本 $install_script${NC}"
        exit 1
    fi
    
    # 检查 PowerShell 是否可用
    if ! command -v pwsh &> /dev/null && ! command -v powershell &> /dev/null; then
        echo -e "${RED}错误: 需要 PowerShell${NC}"
        echo -e "请安装 PowerShell: https://docs.microsoft.com/powershell/"
        exit 1
    fi
    
    echo -e "${YELLOW}正在启动 PowerShell 安装脚本...${NC}"
    
    # 使用 PowerShell 执行
    if command -v pwsh &> /dev/null; then
        # PowerShell Core
        pwsh -ExecutionPolicy Bypass -File "$install_script" "$@"
    else
        # Windows PowerShell
        powershell -ExecutionPolicy Bypass -File "$install_script" "$@"
    fi
}

# 主函数
main() {
    show_header
    
    # 检查是否在安装包目录中
    if [ ! -d "skill" ] && [ ! -d "aliases" ] && [ ! -d "install" ]; then
        echo -e "${YELLOW}警告: 似乎不在安装包目录中${NC}"
        echo -e "${YELLOW}请确保在解压后的目录中运行此脚本${NC}"
        read -p "是否继续？(y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi
    
    # 解析参数
    for arg in "$@"; do
        case "$arg" in
            --help)
                show_help
                exit 0
                ;;
        esac
    done
    
    # 检测操作系统
    local os_type=$(detect_os)
    
    case "$os_type" in
        linux|macos)
            install_linux_macos "$@"
            ;;
        windows)
            install_windows "$@"
            ;;
        *)
            echo -e "${RED}错误: 不支持的操作系统: $(uname -s)${NC}"
            echo -e "${YELLOW}请手动安装:${NC}"
            echo -e "  1. 查看 docs/ 目录中的文档"
            echo -e "  2. 手动复制 skill/ 目录到 WorkBuddy 技能目录"
            echo -e "  3. 参考 aliases/ 目录配置别名"
            exit 1
            ;;
    esac
}

# 执行主函数
main "$@"