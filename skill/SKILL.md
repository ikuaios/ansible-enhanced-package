---
name: ansible-expert
description: >
  Ansible 自动化平台专家技能。当用户需要编写/调试 Ansible Playbooks、理解 Ansible 架构、
  开发自定义模块、配置 Inventory、使用 Roles/Collections、排查执行问题、设计自动化工作流、
  或任何与 Ansible 相关的 IT 自动化任务时使用此技能。触发词：Ansible、Playbook、YAML 自动化、
  配置管理、基础设施编排、ansible-playbook、Role、Inventory、模块开发、IT automation。
---

# Ansible Expert Skill

精通 Ansible IT 自动化平台的专家级技能，涵盖架构原理、Playbook 编写、模块开发、故障排查和企业级最佳实践。

## 核心能力矩阵

| 能力领域 | 支持程度 | 说明 |
|---------|---------|------|
| Playbook 编写与调试 | ★★★★★ | 完整的 YAML 编写、调试、优化 |
| 模块开发 | ★★★★☆ | 自定义模块、Module Utils 使用 |
| 架构设计与咨询 | ★★★★★ | 执行引擎、插件系统深度理解 |
| Roles & Collections | ★★★★★ | 角色设计、集合组织、Galaxy 发布 |
| 故障排查 | ★★★★★ | 连接问题、幂等性失败、性能瓶颈 |
| 企业集成 | ★★★★☆ | AWX/Tower、CI/CD 集成、Vault |
| 网络自动化 | ★★★★☆ | 网络设备模块、持续合规 |
| 云资源编排 | ★★★★☆ | AWS/Azure/GCP 集合 |

## 触发场景

**直接触发（必须加载）：**
- 用户提到 "Ansible"、"Playbook"、"ansible-playbook"、"ansible.cfg"
- 用户要求编写/调试/优化 YAML 格式的自动化脚本
- 用户询问配置管理、IT 自动化工具选型
- 用户提到 "Inventory"、"Role"、"Handler"、"Task"、"Module"
- 用户需要 SSH 无代理批量操作服务器
- 用户想了解或参与 ansible/ansible 开源项目

**间接触发（建议加载）：**
- 基础设施即代码 (IaC) 相关讨论
- DevOps/CI/CD 流水线中的部署环节
- 批量服务器配置与管理需求
- Terraform + Ansible 混合架构设计
- 配置漂移检测与修复

## 工作流程

### Phase 1: 需求分析 (30 秒)
1. 明确用户目标：新写 / 调试 / 重构 / 学习？
2. 了解环境：目标 OS、网络条件、规模（几台 vs 几千台）
3. 识别约束：权限、Python 版本、网络策略

### Phase 2: 参考资料加载
根据具体任务类型，按需加载 references 目录下的详细文档：
- **架构理解** → `references/ansible-core-concepts.md`
- **Playbook 编写** → `references/ansible-playbook-cookbook.md`
- **模块参考** → `references/ansible-module-reference.md`
- **最佳实践** → `references/ansible-best-practices.md`
- **故障排查** → `references/ansible-troubleshooting.md`

> ⚠️ 不要一次性加载所有 references！只加载当前任务相关的文件。

### Phase 3: 方案设计
1. 设计 Inventory 结构（静态 / 动态 / 混合）
2. 规划 Role 层次和依赖关系
3. 选择合适的执行策略（linear / free / serial）
4. 定义变量优先级方案

### Phase 4: 实现与验证
1. 编写 Playbook / Role / Module
2. 应用编码规范（见 Best Practices）
3. 提供 `--check --diff` Dry Run 步骤
4. 编写测试用例（Molecule 推荐模式）

### Phase 5: 输出交付
- 提供完整的、可直接运行的代码
- 包含注释解释关键决策点
- 附带运行命令和预期输出说明
- 标注潜在风险点和注意事项

## 关键规范速查

### FQCN 使用规范
始终使用全限定集合名称（FQCN）：

```yaml
# ✅ 正确
ansible.builtin.copy:
ansible.builtin.yum:
community.docker.docker_container:

# ❌ 已废弃（但仍可用）
copy:
yum:
```

### 幂等性检查清单
每个自定义模块必须实现：
```python
# 1. 获取当前状态
current_state = get_current_state()

# 2. 对比期望状态
if current_state == desired_state:
    module.exit_json(changed=False, msg="Already in desired state")

# 3. 执行变更
apply_change()

# 4. 返回结果
module.exit_json(changed=True, msg="State changed")
```

### 变量优先级（从低到高）
```
role defaults < inventory group_vars/all 
< inventory group_vars/group < inventory host_vars
< playbook vars < host facts < play vars
< task vars < block vars < role params
< extra vars (--extra-vars, 最高的!)
```

### 常用命令速查
```bash
# 语法检查
ansible-playbook --syntax-check site.yml

# Dry Run（不会实际执行变更）
ansible-playbook --check --diff site.yml

# 指定标签执行
ansible-playbook --tags "deploy,config" site.yml

# 从指定 task 开始
ansible-playbook --start-at-task "Install nginx" site.yml

# 限制目标主机
ansible-playbook --limit "webservers" site.yml

# 增加详细输出 (-vvv 更详细)
ansible-playbook -v site.yml

# 加密/解密 Vault 文件
ansible-vault encrypt secrets.yml
ansible-vault view secrets.yml
```

## 脚本工具

技能包含以下可执行脚本（位于 `scripts/`）：

### 1. `playbook_linter.py`
Playbook 静态分析工具，检查常见反模式：
- 未使用的变量
- 缺少 become 的特权操作
- 硬编码密码（未使用 vault）
- 幂等性问题预警

用法：
```bash
python3 scripts/playbook_linter.py path/to/playbook.yml
```

### 2. `inventory_validator.py`
Inventory 文件格式校验器：
- INI/YAML 语法检查
- 主机连通性预检
- 变量重复检测
- 组嵌套循环检测

用法：
```bash
python3 scripts/inventory_validator.py hosts.ini --check-connectivity
```

### 3. `module_generator.py`
自定义模块脚手架生成器：
- 生成标准模块模板
- 包含 AnsibleModule 初始化代码
- 自动生成参数规格
- 生成 Molecule 测试骨架

用法：
```bash
python3 scripts/module_generator.py my_custom_module --type action
```

## 质量标准

所有输出的 Ansible 代码必须满足：

- [ ] **FQCN 合规**: 所有模块调用使用全限定名
- [ ] **幂等安全**: 可重复执行且结果一致
- [ ] **命名规范**: 任务名使用描述性的动词短语
- [ ] **错误处理**: 合理使用 block/rescue/always
- [ ] **文档完整**: Role 包含 README.md 和 meta/main.yml
- [ ] **安全加固**: 敏感数据走 ansible-vault
- [ ] **可测试性**: 提供 Molecule 测试或示例 inventory
