#!/bin/bash
# Ansible 增强技能包在线安装脚本
# 通过 GitHub 直接安装最新版本
# 用法: curl -sSL https://raw.githubusercontent.com/ikuaios/ansible-enhanced-package/main/install-online.sh | bash

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# GitHub 仓库信息
REPO_OWNER="ikuaios"
REPO_NAME="ansible-enhanced-package"
REPO_URL="https://github.com/${REPO_OWNER}/${REPO_NAME}"
API_URL="https://api.github.com/repos/${REPO_OWNER}/${REPO_NAME}"

# 默认安装选项
INSTALL_METHOD="release"  # release 或 main
VERSION="latest"
INSTALL_DIR="$HOME/.ansible-enhanced-install"

# 显示标题
show_header() {
    echo -e "${BLUE}=========================================${NC}"
    echo -e "${BLUE}   Ansible 增强技能包在线安装程序${NC}"
    echo -e "${BLUE}=========================================${NC}"
    echo ""
}

# 显示帮助
show_help() {
    cat << EOF
Ansible 增强技能包在线安装脚本

通过 GitHub 直接安装最新版本，无需手动下载。

基本用法:
  curl -sSL https://raw.githubusercontent.com/ikuaios/ansible-enhanced-package/main/install-online.sh | bash

选项:
  --stable        安装最新的稳定版本 (默认)
  --latest        安装最新的开发版本 (main 分支)
  --version=<tag> 安装指定版本
  --help          显示此帮助信息

示例:
  # 安装最新稳定版本 (推荐)
  curl -sSL https://raw.githubusercontent.com/ikuaios/ansible-enhanced-package/main/install-online.sh | bash
  
  # 安装指定版本
  curl -sSL https://raw.githubusercontent.com/ikuaios/ansible-enhanced-package/main/install-online.sh | bash -s -- --version=v1.0.0
  
  # 安装开发版本
  curl -sSL https://raw.githubusercontent.com/ikuaios/ansible-enhanced-package/main/install-online.sh | bash -s -- --latest

功能:
  1. 从 GitHub 下载最新版本
  2. 自动解压安装包
  3. 自动检测并安装 Ansible（如未安装）
  4. 安装 Ansible 增强技能到 WorkBuddy
  5. 配置别名和快捷命令
  6. 创建示例配置和 Playbook
  7. 清理临时文件

仓库地址: ${REPO_URL}
文档地址: ${REPO_URL}/tree/main/docs

EOF
}

# 检查依赖
check_dependencies() {
    echo -e "${BLUE}检查依赖...${NC}"
    
    local missing_deps=()
    
    # 检查 curl
    if ! command -v curl &> /dev/null; then
        missing_deps+=("curl")
    fi
    
    # 检查 tar (Linux/macOS)
    if ! command -v tar &> /dev/null; then
        missing_deps+=("tar")
    fi
    
    # 检查 unzip (备用)
    if ! command -v unzip &> /dev/null; then
        echo -e "${YELLOW}警告: 未找到 unzip，如果下载 zip 格式可能需要${NC}"
    fi
    
    if [ ${#missing_deps[@]} -gt 0 ]; then
        echo -e "${RED}错误: 缺少必要的依赖:${NC}"
        for dep in "${missing_deps[@]}"; do
            echo -e "  - ${dep}"
        done
        echo -e "\n${BLUE}请安装缺少的依赖:${NC}"
        
        if command -v apt-get &> /dev/null; then
            echo -e "  sudo apt-get update && sudo apt-get install -y ${missing_deps[*]}"
        elif command -v yum &> /dev/null; then
            echo -e "  sudo yum install -y ${missing_deps[*]}"
        elif command -v brew &> /dev/null; then
            echo -e "  brew install ${missing_deps[*]}"
        else
            echo -e "  请使用系统包管理器安装: ${missing_deps[*]}"
        fi
        exit 1
    fi
    
    echo -e "${GREEN}✓ 依赖检查通过${NC}"
}

# 获取最新版本标签
get_latest_release() {
    echo -e "${BLUE}获取最新版本信息...${NC}"
    
    local latest_tag
    if ! latest_tag=$(curl -s "${API_URL}/releases/latest" | grep -o '"tag_name": "[^"]*"' | cut -d'"' -f4); then
        echo -e "${YELLOW}警告: 无法获取最新版本信息，使用 main 分支${NC}"
        echo "main"
        return 1
    fi
    
    if [ -z "$latest_tag" ]; then
        echo -e "${YELLOW}警告: 未找到发布版本，使用 main 分支${NC}"
        echo "main"
        return 1
    fi
    
    echo -e "${GREEN}✓ 最新版本: ${latest_tag}${NC}"
    echo "$latest_tag"
}

# 下载安装包
download_package() {
    local version="$1"
    local download_url
    
    echo -e "${BLUE}下载安装包...${NC}"
    
    # 创建临时目录
    rm -rf "$INSTALL_DIR"
    mkdir -p "$INSTALL_DIR"
    cd "$INSTALL_DIR"
    
    if [ "$version" = "main" ]; then
        # 下载 main 分支源码
        download_url="${REPO_URL}/archive/refs/heads/main.tar.gz"
        echo -e "${BLUE}下载开发版本 (main 分支)...${NC}"
    else
        # 下载指定版本
        download_url="${REPO_URL}/archive/refs/tags/${version}.tar.gz"
        echo -e "${BLUE}下载版本: ${version}${NC}"
    fi
    
    # 下载压缩包
    echo -e "${BLUE}下载地址: ${download_url}${NC}"
    
    if ! curl -sSL -o package.tar.gz "$download_url"; then
        echo -e "${RED}错误: 下载失败${NC}"
        
        # 尝试备用下载地址 (Release 资源)
        if [ "$version" != "main" ]; then
            echo -e "${BLUE}尝试备用下载地址...${NC}"
            local alt_url="${REPO_URL}/releases/download/${version}/ansible-enhanced-package-privacy-fixed.tar.gz"
            if curl -sSL -o package.tar.gz "$alt_url"; then
                echo -e "${GREEN}✓ 通过备用地址下载成功${NC}"
            else
                echo -e "${RED}错误: 备用地址也下载失败${NC}"
                return 1
            fi
        else
            return 1
        fi
    fi
    
    # 解压
    echo -e "${BLUE}解压安装包...${NC}"
    if ! tar -xzf package.tar.gz --strip-components=1; then
        echo -e "${RED}错误: 解压失败${NC}"
        return 1
    fi
    
    # 检查解压后的文件
    if [ ! -d "install" ] || [ ! -f "install/install.sh" ]; then
        echo -e "${RED}错误: 安装包结构不正确${NC}"
        return 1
    fi
    
    echo -e "${GREEN}✓ 下载解压完成${NC}"
}

# 运行安装脚本
run_installation() {
    echo -e "${BLUE}开始安装...${NC}"
    
    cd "$INSTALL_DIR"
    
    # 检查安装脚本
    if [ ! -f "install/install.sh" ]; then
        echo -e "${RED}错误: 找不到安装脚本${NC}"
        return 1
    fi
    
    # 设置执行权限
    chmod +x install/install.sh
    
    # 传递所有剩余参数给安装脚本
    echo -e "${BLUE}运行标准安装脚本...${NC}"
    echo -e "${YELLOW}=========================================${NC}"
    
    # 运行安装脚本，传递所有参数
    if ! ./install/install.sh "$@"; then
        echo -e "${RED}错误: 安装脚本执行失败${NC}"
        return 1
    fi
    
    echo -e "${YELLOW}=========================================${NC}"
}

# 清理临时文件
cleanup() {
    echo -e "${BLUE}清理临时文件...${NC}"
    
    if [ -d "$INSTALL_DIR" ]; then
        rm -rf "$INSTALL_DIR"
        echo -e "${GREEN}✓ 临时文件已清理${NC}"
    fi
}

# 显示完成信息
show_completion() {
    echo -e "\n${GREEN}=========================================${NC}"
    echo -e "${GREEN}    在线安装完成！${NC}"
    echo -e "${GREEN}=========================================${NC}\n"
    
    echo -e "${BLUE}安装总结:${NC}"
    echo -e "  - 版本: ${VERSION}"
    echo -e "  - 来源: ${REPO_URL}"
    echo -e "  - Ansible: ${GREEN}已安装/已验证${NC}"
    echo -e "  - 临时目录: ${INSTALL_DIR} (已清理)\n"
    
    echo -e "${BLUE}下一步操作:${NC}"
    echo -e "  1. 重新打开终端或执行: ${YELLOW}source ~/.bashrc${NC} (或 ${YELLOW}source ~/.zshrc${NC})"
    echo -e "  2. 测试安装: ${YELLOW}ans-help${NC}"
    echo -e "  3. 查看文档: ${REPO_URL}/tree/main/docs\n"
    
    echo -e "${GREEN}开始你的 Ansible 自动化之旅吧！🚀${NC}"
}

# 主函数
main() {
    show_header
    
    # 解析参数
    while [[ $# -gt 0 ]]; do
        case $1 in
            --help)
                show_help
                exit 0
                ;;
            --stable)
                INSTALL_METHOD="release"
                shift
                ;;
            --latest)
                INSTALL_METHOD="main"
                VERSION="main"
                shift
                ;;
            --version=*)
                VERSION="${1#*=}"
                shift
                ;;
            *)
                # 传递给安装脚本的参数
                break
                ;;
        esac
    done
    
    # 获取版本号
    if [ "$INSTALL_METHOD" = "release" ] && [ "$VERSION" = "latest" ]; then
        local latest_release=$(get_latest_release)
        if [ $? -eq 0 ]; then
            VERSION="$latest_release"
        else
            # 获取最新版本失败，回退到 main
            echo -e "${YELLOW}切换到 main 分支${NC}"
            VERSION="main"
        fi
    fi
    
    echo -e "${BLUE}安装信息:${NC}"
    echo -e "  - 仓库: ${REPO_URL}"
    echo -e "  - 版本: ${VERSION}"
    echo -e "  - 临时目录: ${INSTALL_DIR}"
    echo -e "  - 自动安装 Ansible: ${GREEN}是${NC} (如未安装)\n"
    
    # 检查依赖
    check_dependencies
    
    # 下载安装包
    if ! download_package "$VERSION"; then
        echo -e "${RED}错误: 下载安装包失败${NC}"
        cleanup
        exit 1
    fi
    
    # 运行安装脚本
    if ! run_installation "$@"; then
        echo -e "${RED}错误: 安装过程失败${NC}"
        cleanup
        exit 1
    fi
    
    # 清理
    cleanup
    
    # 显示完成信息
    show_completion
}

# 脚本入口点
if [[ "${BASH_SOURCE[0]}" = "$0" ]]; then
    trap 'echo -e "\n${RED}安装被中断${NC}"; cleanup; exit 1' INT TERM
    main "$@"
fi