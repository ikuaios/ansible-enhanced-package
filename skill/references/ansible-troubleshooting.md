# Ansible 故障排查指南

## 1. 常见错误速查表

### 1.1 连接类问题

| 错误信息 | 可能原因 | 解决方案 |
|---------|---------|---------|
| `Unable to make a connection` | SSH 服务未启动/防火墙/网络不通 | 检查 `ssh -v user@host`, 确认端口 22 开放 |
| `Authentication failure` | 密码/密钥/权限问题 | 检查 `~/.ssh/authorized_keys`, 尝试 `ssh-copy-id` |
| `Host key verification failed` | 首次连接或主机 key 变更 | `ssh-keyscan -H host >> ~/.ssh/known_hosts` 或设置 `host_key_checking=False` |
| `Permission denied (publickey)` | 私钥不匹配或无权限 | 确认私钥文件权限 `chmod 600 id_rsa` |
| `Timeout (12s)` | SSH 连接超时 | 增加 `ansible_timeout` 或检查 DNS 解析 |
| `UNREACHABLE! => ...` | 网络不可达 | ping 测试, 检查安全组/防火墙规则 |
| `paramiko: No existing session` | SSH pipelining 问题 | 设置 `pipelining = False` 或使用 ssh 连接插件 |

**SSH 连接调试步骤：**
```bash
# 步骤 1: 手动 SSH 测试
ssh -vvv deploy@target-host

# 步骤 2: 使用 ansible 自带调试
ansible webservers -m ping -vvv

# 步骤 3: 检查 SSH 配置
cat ~/.ssh/config
# Host target-*
#   User deploy
#   IdentityFile ~/.ssh/deploy_key
#   ForwardAgent yes
#   StrictHostKeyChecking accept-new

# 步骤 4: 测试 Ansible 连接（不执行任何操作）
ansible wehosts -m ansible.builtin.setup --limit one_host -vvv
```

### 1.2 权限类问题

| 错误信息 | 嘎因 | 解决方案 |
|---------|------|---------|
| `sudo: no tty present and no askpass program` | 需要 sudo 但无法交互 | 在 ansible.cfg 中配置 `become_ask_pass=False` + NOPASSWD sudo |
| `sorry, user is not in sudoers file` | 用户无 sudo 权限 | visudo 添加用户到 wheel/sudo 组 |
| `Permission denied when trying to connect to the Docker daemon socket` | 非 root 用户无 docker 权限 | 将用户加入 docker 组 |
| `Failed to lock apt for exclusive operation` | 另一个进程正在用 apt | 杀死占用进程或等待 |
| `Operation not permitted` | SELinux/AppArmor 阻止 | 临时关闭或调整安全上下文 |

```yaml
# 正确的 become 配置示例:
- hosts: all
  become: yes
  become_method: sudo          # 或 su, doas, pbrun, pfexec, runas, dzdo
  become_user: root            # 切换到的目标用户
  become_flags: '-H -S'        # 传递给 become 方法的额外参数
  # 注意：如果目标机器需要密码，需要：
  # 1) ansible.cfg: become_ask_pass=True
  # 2) 或运行时: --ask-become-pass (-K)
```

### 1.3 模块与参数问题

| 错误信息 | 原因 | 解决方案 |
|---------|------|---------|
| `module not found` | 模块不存在或路径错误 | 检查 FQCN，确认集合已安装 `ansible-galaxy collection list` |
| `Unsupported parameters for module` | 参数名拼写错误或版本不兼容 | 查阅模块文档确认正确参数名 |
| `this module requires Python > X` | 目标主机 Python 版本过低 | 升级 Python 或使用 `ansible_python_interpreter` |
| `argument 'src' is of type` | 参数类型不匹配 | 确保字符串/列表/字典类型正确 |
| `One or more undefined variables` | 引用了未定义变量 | 使用 `default()` 过滤器或 `| default(omit)` 跳过 |

### 1.4 YAML 语法问题

| 错误 | 原因 | 修复 |
|------|------|------|
| `mapping values are not allowed in this context` | 冒号后缺少空格 | 确保 `key: value` 格式 |
| `did not find expected key` | 缩进不一致 | 统一使用空格缩进（不用 Tab） |
| `could not define condition` | `when` 条件格式错误 | 检查 Jinja2 表达式语法 |
| `inconsistent indentation` | 混用 Tab 和空格 | 编辑器显示空白字符，统一为空格 |

### 1.5 性能相关

| 症状 | 原因 | 解决方案 |
|------|------|---------|
| 执行非常慢 | Facts 收集耗时 | 缓存 facts 或限制 gather_subset |
| 大规模超时 | forks 太高导致资源耗尽 | 降低 forks 或使用 free 策略 |
| 内存占用过高 | 大量模块传输 | 启用 pipelining，优化连接复用 |
| 某个 task 卡住 | 同步阻塞操作 | 改为 async/poll 异步模式 |

## 2. 排查方法论

### Step 1: 增加输出详细度
```bash
# 一级：基础调试
ansible-playbook site.yml -v

# 二级：更多细节（推荐用于排查）
ansible-playbook site.yml -vv

# 三级：完整调试信息（含连接详情和模块代码）
ansible-playbook site.yml -vvv

# 四级：连接级调试（含 SSH 协议细节）
ansible-playbook site.yml -vvvv
```

### Step 2: 限定目标范围
```bash
# 只在一台机器上测试
ansible-playbook site.yml --limit web01.example.com

# 用正则匹配
ansible-playbook site.yml --limit "web*"

# 从失败的主机继续
ansible-playbook site.yml --limit @/path/to/retry/hostfile
```

### Step 3: Dry Run 模式
```bash
# 预览变更但不实际执行（最安全的排查方式）
ansible-playbook site.yml --check --diff

# 结合标签定位特定任务
ansible-playbook site.yml --check --diff --tags configure --limit web01
```

### Step 4: 单步执行
```bash
# 从指定任务开始
ansible-playbook site.yml --start-at-task "Install nginx"

# 结合 step 模式（每个任务前暂停确认）
ansible-playbook site.yml --step
```

### Step 5: 直接在目标主机上调试
```bash
# 收集目标主机的详细信息（替代 gather_facts）
ansible webservers -m setup -a "filter=ansible_*"

# 收集特定子集的 facts
ansible webservers -m setup -a "gather_subset=network,virtualization"

# 直接执行 ad-hoc 命令测试连通性
ansible webservers -m ping

# 测试特定模块是否可用
ansible localhost -m copy -a "content='test' dest=/tmp/test" -c local
```

## 3. 特定场景故障排除

### 3.1 幂等性失效排查

**症状**: 多次执行结果不同，每次都报告 `changed`

```yaml
# 排查方法：添加 verbose 输出对比变更前后状态
- name: Debug current state before change
  ansible.builtin.stat:
    path: /etc/myapp/config.yml
  register: before_stat

- name: The problematic task
  my_custom.module:
    path: /etc/myapp/config.yml
  register: task_result

- name: Debug state after change
  ansible.builtin.stat:
    path: /etc/myapp/config.yml
  register: after_stat

- name: Compare states
  ansible.builtin.debug:
    msg: |
      Changed: {{ task_result.changed }}
      Before checksum: {{ before_stat.checksum }}
      After checksum: {{ after_stat.checksum }}
```

**常见原因及修复：**
```yaml
# 原因 1: 文件包含动态内容（时间戳、随机数等）
# → 修复：模板中使用固定值或条件渲染
{{ ansible_date_time.iso8601 }}  # ❌ 每次不同
{{ app_deploy_timestamp }}       # ✅ 固定的部署时间戳

# 原因 2: 模块本身不支持幂等性
# → 修复：添加 changed_when 手动控制
- name: Run non-idempotent command
  ansible.builtin.shell: some-command
  register: cmd_result
  changed_when: "'updated' in cmd_result.stdout"
  failed_when: cmd_result.rc != 0

# 原因 3: 文件权限每次被重置
# → 修复：确保 owner/mode 与目标一致，或使用 mode: preserve
```

### 3.2 Handler 未触发

**症状**: 任务报告 `changed` 且有 `notify`，但 Handler 不执行

```yaml
# 排查清单:

# 1. 检查 notify 名称是否完全匹配（区分大小写！）
notify: Restart Nginx     # 必须与 handler 的 name 完全一致
# handler:
#   - name: Restart Nginx  # ✅ 匹配
#   - name: restart nginx  # ❌ 不匹配！

# 2. 检查 handler 作用域
# handlers 定义在 role 中只能被同 role 的 tasks notify
# 全局 handlers 需要定义在 playbook 层级

# 3. 检查 --tags 是否排除了 handlers
# ansible-playbook site.yml --tags install  # handlers 不会运行！
# 解决: 加上 tagged 或 always 标签
handlers:
  - name: Restart Nginx
    ansible.builtin.service:
      name: nginx
      state: reloaded
    tags: [always]           # ✅ 强制始终包含

# 4. 使用 listen 替代直接名称匹配（推荐模式）
tasks:
  - notify: Nginx config changed  # 通用通知名
handlers:
  - name: Restart Nginx
    listen: Nginx config changed  # 监听通用通知
  - name: Reload Nginx
    listen: Nginx config changed  # 同一通知触发多个 handler
```

### 3.3 变量优先级混乱

```yaml
# 调试方法：使用 var_debug 插件查看所有变量
- name: Show all variables for debugging
  community.general.var_debug:
    verbosity: 2              # 仅在 -vv 模式下显示
    complexity: advanced      # 显示完整的合并过程

# 或使用内置 debug 查看特定变量
- name: Debug variable precedence
  ansible.builtin.debug:
    msg: |
      Role defaults: {{ myvar_default | default('UNDEFINED') }}
      Play vars: {{ myvar_play | default('UNDEFINED') }}
      Extra vars: {{ myvar_extra | default('UNDEFINED') }}
      Final resolved value: {{ myvar }}

# 查看所有已定义变量的来源
ansible webservers -m debug -a "var=hostvars[inventory_hostname]" | jq .
```

### 3.4 大型 Playbook 性能瓶颈

```bash
# 诊断工具：

# 1. 启用 profile_tasks 回调查看每个任务的耗时
# ansible.cfg:
[defaults]
callback_enabled = profile_tasks,timer

# 输出示例:
# ────────────────────────────────────────────
# Thursday 13 April 2026  14:30:15 +0800 (0:00:01.237)       0:00:02.123 *********
# ────────────────────────────────────────────
# Play ──────────────────────────────────────────────────────────
# ──────────────────────────────────────── all ─────────────────────────────────────────
# Friday 13 April 2026  14:30:16 +0800 (0:00:00.934)       0:00:03.057 ********
# ok: [web01] => (item=nginx) ...
# ---------------------------------------------------------
# Gather Facts --------------------------------------------------- 12.45s
# Install packages ---------------------------------------------- 45.20s  ← 🔴 瓶颈!
# Deploy configuration ------------------------------------------- 0.89s
# Reload service ------------------------------------------------- 1.23s

# 2. 使用 ANSIBLE_PROFILE 环境变量获取详细性能数据
ANSIBLE_PROFILE=uppercase ansible-playbook site.yml

# 3. 使用 cProfile 分析 Ansible 自身性能
python -m cProfile -o ansprofile.stats $(which ansible-playbook) site.yml
```

### 3.5 Windows 目标主机问题

```ini
# ansible.cfg 中 Windows 相关配置
[defaults]
executable = C:\Python311\python.exe

[winrm]
# Windows 连接基本配置
# transport: ntlm / kerberos / credssp / basic
# port: 5986 (HTTPS) / 5985 (HTTP)

# PowerShell 版本要求 >= 5.1
# Configure Remoting script (在目标 Windows 上以管理员身份运行):
# https://raw.githubusercontent.com/ansible/ansible/devel/examples/scripts/ConfigureRemotingForAnsible.ps1
```

```powershell
# Windows 侧常见修复:
# 1. 启用 WinRM
Enable-PSRemoting -Force
winrm quickconfig -force

# 2. 配置基本认证
winrm set winrm/config/service/auth @{Basic="true"}
winrm set winrm/config/service @{AllowUnencrypted="true"}  # 仅测试环境!

# 3. 配置最大内存
winrm set winrm/config/winrs @{MaxMemoryPerShellMB="1024"}

# 4. 添加防火墙例外
New-NetFirewallRule -DisplayName "Ansible WinRM" -Direction Inbound -LocalPort 5986 -Protocol TCP -Action Allow

# 5. 验证 WinRM 可用
Test-WSMan -ComputerName localhost
```

## 4. 日志分析技巧

### 4.1 启用日志记录

```ini
# ansible.cfg
[defaults]
log_path = /var/log/ansible.log    # 或 ~/.ansible/log/ansible.log
# 日志级别默认为 INFO

# 环境变量方式:
export ANSIBLE_LOG_PATH=~/ansible-debug.log
```

### 4.2 关键日志模式搜索

```bash
# 搜索连接失败
grep -i "unreachable\|failed to connect\|authentication" ansible.log

# 搜索权限问题
grep -i "permission denied\|sudo\|become" ansible.log

# 搜索超时问题
grep -i "timeout\|timed out" ansible.log

# 搜索模块加载问题
grep -i "module.*not found\|cannot import\|importerror" ansible.log

# 按时间范围筛选
grep "2026-04-13 14:[23][0-5]" ansible.log
```

## 5. 应急处理手册

### 场景：生产环境部署失败回滚

```bash
# 1. 立即停止当前执行 (Ctrl+C)

# 2. 检查当前状态（哪些主机已经变更）
ansible-playbook site.yml --list-hosts --list-tasks

# 3. 回滚到上一个已知良好版本
git checkout stable-release-20260412

# 4. 运行 rollback playbook（应预先准备好！）
ansible-playbook playbooks/rollback.yml \
  --extra-vars "target_version=v2.19.3" \
  --limit webservers

# 5. 回滚后验证
ansible webservers -m uri -a "url=http://localhost/health status_code=200"

# 6. 记录事故
echo "$(date): Rollback executed due to deployment failure" >> CHANGELOG.md
```
