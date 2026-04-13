# Ansible 增强技能包

[![Platform](https://img.shields.io/badge/平台-Linux%20%7C%20macOS%20%7C%20Windows-blue.svg)](https://www.ansible.com)
[![License](https://img.shields.io/badge/许可证-MIT-green.svg)](LICENSE)
[![中文文档](https://img.shields.io/badge/文档-中文-orange.svg)](docs/)

> 专为中文用户优化的 Ansible 增强技能包，让自动化运维更简单、更高效！

## ✨ 特性

- **🚀 一键安装/在线安装** - 支持在线安装和本地安装，**自动检测并安装 Ansible**，跨平台支持 Linux/macOS/Windows
- **🎯 智能别名** - 50+ 实用别名和快捷命令，提升工作效率
- **📚 中文文档** - 完整的中文说明、示例和最佳实践
- **🔧 增强技能** - 基于 ansible-expert 技能的增强版，包含代码生成器和检查器
- **🛡️ 安全可靠** - 已通过安全审计，适合生产环境使用
- **🤝 社区友好** - 专为英文不好的朋友设计，降低学习门槛

## 📦 安装包内容

```
ansible-enhanced-package/
├── skill/              # 增强版 Ansible 技能
│   ├── scripts/        # 实用脚本工具
│   ├── references/     # 参考文档
│   └── SKILL.md        # 技能描述
├── aliases/           # 跨平台别名配置
│   ├── ansible-aliases.sh     # Linux/macOS 别名
│   └── ansible-aliases.ps1    # Windows PowerShell 别名
├── examples/          # 实用示例
│   ├── first-playbook.yml     # 第一个 Playbook
│   ├── inventory.ini          # Inventory 示例
│   └── more-examples/         # 更多示例
├── docs/              # 中文文档
│   ├── QUICK-START.md        # 快速开始
│   ├── EXAMPLES.md           # 示例详解
│   ├── ALIASES.md            # 别名指南
│   └── FAQ.md                # 常见问题
├── install/           # 安装脚本
│   ├── install.sh            # 跨平台主脚本
│   ├── install-linux-macos.sh # Linux/macOS 脚本
│   ├── install-windows.ps1   # Windows 脚本
│   └── install-online.sh     # 在线安装脚本
└── LICENSE            # MIT 许可证
```

## 🚀 快速安装

### 方法一：在线安装（最新版）

无需下载安装包，直接从 GitHub 安装最新版本：

> **💡 智能安装**：在线安装脚本会自动检测并安装 Ansible（如未安装），无需手动安装依赖。

```bash
# 安装最新稳定版本（推荐）
curl -sSL https://raw.githubusercontent.com/ikuaios/ansible-enhanced-package/main/install-online.sh | bash

# 安装指定版本
curl -sSL https://raw.githubusercontent.com/ikuaios/ansible-enhanced-package/main/install-online.sh | bash -s -- --version=v1.0.0

# 安装开发版本（main 分支）
curl -sSL https://raw.githubusercontent.com/ikuaios/ansible-enhanced-package/main/install-online.sh | bash -s -- --latest
```

### 方法二：一键安装（本地包）

```bash
# 1. 下载安装包并解压
# 2. 进入解压后的目录
cd ansible-enhanced-package

# 3. 运行安装脚本
./install/install.sh
```

### 方法三：分步安装

```bash
# Linux/macOS
./install/install-linux-macos.sh

# Windows (以管理员身份运行 PowerShell)
.\install\install-windows.ps1
```

### 方法四：交互式菜单安装

如果已经下载了安装包，可以使用交互式菜单进行安装和管理：

```bash
# 进入安装包目录
cd ansible-enhanced-package

# 运行交互式菜单
./menu.sh
```

**交互式菜单功能**：
- 📥 安装（支持本地和在线两种方式）
- 🗑️ 卸载（安全/强制/预览三种模式）
- 🔍 检查安装状态和系统信息
- ⚙️ 快速设置 Ansible 环境
- 📚 查看帮助文档和示例
- 🔄 更新技能包（支持在线更新）
- 🚀 运行示例 Playbook

## 📖 快速开始

安装完成后，打开新终端窗口，尝试以下命令：

```bash
# 查看帮助
ans-help

# 快速设置环境
ans-setup

# 查看版本信息
ans-version

# 测试连接
ans-ping

# 检查语法
ans-syntax examples/first-playbook.yml
```

## 🔧 核心功能

### 1. 智能别名系统

安装后自动配置 50+ 实用别名：

| 别名 | 功能 | 示例 |
|------|------|------|
| `ans` | ansible 快捷方式 | `ans all -m ping` |
| `ansp` | ansible-playbook 快捷方式 | `ansp site.yml` |
| `ans-ping` | 对所有主机 ping 测试 | `ans-ping` |
| `ans-syntax` | 检查 Playbook 语法 | `ans-syntax playbook.yml` |
| `ans-check` | 执行 Dry Run | `ans-check playbook.yml` |
| `ans-lint` | 代码检查 | `ans-lint playbook.yml` |

### 2. 增强技能特性

- **Playbook 检查器** - 静态分析，发现潜在问题
- **Inventory 验证器** - 检查 Inventory 文件格式和连通性
- **模块生成器** - 快速生成自定义模块脚手架
- **中文参考文档** - 核心概念、最佳实践、故障排查

### 3. 示例代码库

包含从入门到进阶的完整示例：
- 基础 Playbook 编写
- 角色(Role)组织
- 变量管理
- 条件判断和循环
- 错误处理和调试

## 🎯 适用场景

- **初学者学习** - 中文文档和示例，降低学习门槛
- **团队协作** - 统一的别名和配置，提高团队效率
- **生产环境** - 安全可靠，通过安全审计
- **跨平台运维** - 支持 Linux/Windows/macOS 混合环境
- **CI/CD 集成** - 自动化部署和配置管理

## 📚 文档目录

详细文档请查看 `docs/` 目录：

- [快速开始指南](docs/QUICK-START.md) - 5分钟上手
- [示例详解](docs/EXAMPLES.md) - 从基础到进阶
- [别名使用指南](docs/ALIASES.md) - 所有别名详解
- [常见问题](docs/FAQ.md) - 疑难解答

## 🤝 贡献指南

欢迎贡献代码、文档或提出建议！

1. Fork 本仓库
2. 创建特性分支 (`git checkout -b feature/AmazingFeature`)
3. 提交更改 (`git commit -m 'Add some AmazingFeature'`)
4. 推送到分支 (`git push origin feature/AmazingFeature`)
5. 创建 Pull Request

## 📄 许可证

本项目采用 MIT 许可证 - 详见 [LICENSE](LICENSE) 文件。

## 🙏 致谢

- 基于 ansible-expert 技能增强开发
- 感谢所有贡献者和用户的支持
- 特别为英文不好的朋友优化

## 📞 支持与反馈

遇到问题？需要帮助？

1. 查看 [FAQ](docs/FAQ.md) 寻找答案
2. 检查示例代码 `examples/` 目录
3. 提交 Issue 或讨论

---

**开始你的 Ansible 自动化之旅吧！🚀**

> 提示：安装后记得执行 `ans-help` 查看所有可用命令！