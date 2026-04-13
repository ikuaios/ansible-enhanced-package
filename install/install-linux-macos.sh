#!/bin/bash
# Ansible 增强技能安装脚本 (Linux/macOS)
# 用法: ./install-linux-macos.sh [--user] [--system]

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 默认安装到用户目录
INSTALL_DIR="$HOME/.workbuddy/skills/ansible-enhanced"
ALIASES_SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/aliases"
EXAMPLES_SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/examples"
DOCS_SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/docs"

# 帮助信息
show_help() {
    cat << EOF
Ansible 增强技能安装脚本

用法: $0 [选项]

选项:
  --user          安装到用户目录 (默认: ~/.workbuddy/skills/ansible-enhanced)
  --system        安装到系统目录 (需要root权限)
  --help          显示此帮助信息

功能:
  1. 安装 Ansible 增强技能到 WorkBuddy
  2. 配置 Ansible 别名和快捷命令
  3. 创建示例配置和 Playbook
  4. 设置基础环境

EOF
}

# 检查依赖
check_dependencies() {
    echo -e "${BLUE}检查依赖...${NC}"
    
    # 检查 WorkBuddy
    if [ ! -d "$HOME/.workbuddy" ]; then
        echo -e "${YELLOW}警告: 未找到 WorkBuddy 目录，可能未安装 WorkBuddy${NC}"
        echo -e "${YELLOW}请先安装 WorkBuddy 再运行此脚本${NC}"
        read -p "是否继续安装技能？(y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi
    
    # 检查 Ansible
    if ! command -v ansible &> /dev/null; then
        echo -e "${YELLOW}警告: 未安装 Ansible${NC}"
        echo -e "${BLUE}正在尝试安装 Ansible...${NC}"
        
        if command -v pip3 &> /dev/null; then
            pip3 install ansible
        elif command -v pip &> /dev/null; then
            pip install ansible
        elif command -v apt-get &> /dev/null; then
            sudo apt-get update && sudo apt-get install -y ansible
        elif command -v yum &> /dev/null; then
            sudo yum install -y ansible
        elif command -v brew &> /dev/null; then
            brew install ansible
        else
            echo -e "${RED}错误: 无法自动安装 Ansible${NC}"
            echo -e "请手动安装 Ansible:"
            echo -e "  macOS: brew install ansible"
            echo -e "  Ubuntu/Debian: sudo apt-get install ansible"
            echo -e "  CentOS/RHEL: sudo yum install ansible"
            echo -e "  通用: pip3 install ansible"
            exit 1
        fi
        
        if ! command -v ansible &> /dev/null; then
            echo -e "${RED}错误: Ansible 安装失败${NC}"
            exit 1
        fi
        echo -e "${GREEN}Ansible 安装成功${NC}"
    else
        echo -e "${GREEN}✓ Ansible 已安装${NC}"
    fi
    
    # 检查 Python
    if ! command -v python3 &> /dev/null && ! command -v python &> /dev/null; then
        echo -e "${RED}错误: 需要 Python 3.6+${NC}"
        exit 1
    fi
    echo -e "${GREEN}✓ Python 已安装${NC}"
}

# 安装技能
install_skill() {
    echo -e "${BLUE}安装 Ansible 增强技能...${NC}"
    
    # 创建安装目录
    mkdir -p "$INSTALL_DIR"
    mkdir -p "$INSTALL_DIR/scripts"
    mkdir -p "$INSTALL_DIR/references"
    mkdir -p "$INSTALL_DIR/assets"
    
    # 复制技能文件
    echo -e "${BLUE}复制技能文件...${NC}"
    cp -r "$(dirname "${BASH_SOURCE[0]}")/../skill/"* "$INSTALL_DIR/"
    
    # 设置权限
    chmod +x "$INSTALL_DIR/scripts/"*.py
    
    echo -e "${GREEN}✓ 技能文件已复制到 $INSTALL_DIR${NC}"
}

# 配置别名
setup_aliases() {
    echo -e "${BLUE}配置 Ansible 别名...${NC}"
    
    local alias_file="$ALIASES_SRC/ansible-aliases.sh"
    
    # 检测用户的 shell
    local user_shell="$(basename "$SHELL")"
    local profile_file
    
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
    
    # 检查是否已安装别名
    if grep -q "ansible-aliases.sh" "$profile_file" 2>/dev/null; then
        echo -e "${YELLOW}✓ 别名已存在于 $profile_file${NC}"
    else
        # 添加别名到配置文件
        echo -e "\n# Ansible 增强别名" >> "$profile_file"
        echo "if [ -f \"$alias_file\" ]; then" >> "$profile_file"
        echo "    source \"$alias_file\"" >> "$profile_file"
        echo "fi" >> "$profile_file"
        echo -e "${GREEN}✓ 别名已添加到 $profile_file${NC}"
    fi
    
    # 复制别名文件
    mkdir -p "$HOME/.ansible-aliases"
    cp "$alias_file" "$HOME/.ansible-aliases/"
    
    # 立即加载别名
    if [ -f "$alias_file" ]; then
        source "$alias_file"
    fi
    
    echo -e "${GREEN}✓ 别名配置完成${NC}"
}

# 创建示例文件
setup_examples() {
    echo -e "${BLUE}创建示例文件...${NC}"
    
    local examples_dir="$HOME/ansible-examples"
    
    if [ ! -d "$examples_dir" ]; then
        mkdir -p "$examples_dir"
        cp -r "$EXAMPLES_SRC/"* "$examples_dir/" 2>/dev/null || true
        
        # 创建基础示例
        if [ ! -f "$examples_dir/first-playbook.yml" ]; then
            cat > "$examples_dir/first-playbook.yml" << 'EOF'
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
        cmd: free -h
        when: ansible_os_family == "Debian" or ansible_os_family == "RedHat"
      register: memory
      ignore_errors: true
    
    - name: 显示内存信息
      ansible.builtin.debug:
        var: memory.stdout
      when: memory is defined and memory.stdout != ""
EOF
        fi
        
        if [ ! -f "$examples_dir/inventory.ini" ]; then
            cat > "$examples_dir/inventory.ini" << 'EOF'
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
ansible_python_interpreter=/usr/bin/python3
EOF
        fi
        
        echo -e "${GREEN}✓ 示例文件已创建到 $examples_dir${NC}"
    else
        echo -e "${YELLOW}✓ 示例目录已存在，跳过${NC}"
    fi
}

# 安装完成提示
show_completion() {
    echo -e "\n${GREEN}=========================================${NC}"
    echo -e "${GREEN}    Ansible 增强技能安装完成！${NC}"
    echo -e "${GREEN}=========================================${NC}\n"
    
    echo -e "${BLUE}下一步操作：${NC}"
    echo -e "1. 重新打开终端或执行: ${YELLOW}source ~/.bashrc${NC} (或 ${YELLOW}source ~/.zshrc${NC})"
    echo -e "2. 测试安装: ${YELLOW}ans-help${NC}"
    echo -e "3. 快速设置环境: ${YELLOW}ans-setup${NC}"
    echo -e "4. 查看版本: ${YELLOW}ans-version${NC}"
    echo -e "\n${BLUE}示例文件位置：${NC}"
    echo -e "  ${YELLOW}$HOME/ansible-examples/${NC}"
    echo -e "\n${BLUE}技能位置：${NC}"
    echo -e "  ${YELLOW}$INSTALL_DIR${NC}"
    echo -e "\n${BLUE}文档：${NC}"
    echo -e "  ${YELLOW}$DOCS_SRC/${NC}"
    echo -e "\n${GREEN}开始你的 Ansible 自动化之旅吧！${NC}\n"
}

# 主函数
main() {
    # 解析参数
    for arg in "$@"; do
        case "$arg" in
            --help)
                show_help
                exit 0
                ;;
            --system)
                INSTALL_DIR="/usr/local/share/workbuddy/skills/ansible-enhanced"
                if [ "$(id -u)" -ne 0 ]; then
                    echo -e "${RED}错误: 需要 root 权限安装到系统目录${NC}"
                    exit 1
                fi
                ;;
            --user)
                # 已经是默认值
                ;;
            *)
                echo -e "${RED}未知选项: $arg${NC}"
                show_help
                exit 1
                ;;
        esac
    done
    
    echo -e "${BLUE}=========================================${NC}"
    echo -e "${BLUE}    Ansible 增强技能安装程序${NC}"
    echo -e "${BLUE}=========================================${NC}\n"
    
    check_dependencies
    install_skill
    setup_aliases
    setup_examples
    show_completion
}

# 执行主函数
main "$@"