# Ansible 核心概念与架构

## 1. 架构总览

### 控制节点 (Control Node)
- 运行 Ansible 的机器
- 安装 Python 3.10+ (Ansible 2.15+)
- 通过 SSH (Linux) / WinRM (Windows) 连接受管节点

### 受管节点 (Managed Nodes)
- 被管理的目标设备
- **无需安装 Agent**（核心特性）
- 需要 Python（Linux）或 PowerShell（Windows）
- 仅需 SSH 服务（Linux）或 WinRM（Windows）

### 执行流程
```
用户输入 CLI 命令
       ↓
CLI 解析参数 → 构建上下文
       ↓
加载 ansible.cfg 配置
       ↓
解析 Inventory → 构建主机列表
       ↓
解析 Playbook YAML → 构建 Task 对象
       ↓
Executor 按策略调度任务
       ↓
连接插件建立会话 (SSH/WinRM)
       ↓
推送模块代码到临时目录 → 执行 → JSON 结果返回
       ↓
回调插件处理输出 → 清理临时文件
       ↓
输出最终摘要 (ok/changed/failed/skipped/rescued)
```

## 2. 核心概念详解

### 2.1 Inventory（清单）

定义目标主机的数据源，支持三种形式：

**静态 INI 格式：**
```ini
[webservers]
web01.example.com ansible_host=192.168.1.10 ansible_user=deploy
web02.example.com ansible_host=192.168.1.11
web03.example.com

[dbservers]
db01.example.com db_var=primary

[all:vars]
ansible_python_interpreter=/usr/bin/python3
environment=production

[webservers:vars]
nginx_version=1.24
max_connections=1024

[production:children]
webservers
dbservers
```

**YAML 格式：**
```yaml
all:
  vars:
    ansible_python_interpreter: /usr/bin/python3
  children:
    webservers:
      hosts:
        web01.example.com:
          ansible_host: 192.168.1.10
        web02.example.com:
          ansible_host: 192.168.1.11
      vars:
        nginx_version: 1.24
    dbservers:
      hosts:
        db01.example.com:
          db_var: primary
```

**动态 Inventory（脚本/API）：**
```bash
#!/bin/bash
# 动态 inventory 必须支持 --list 和 --host <hostname> 参数
if [ "$1" == "--list" ]; then
  echo '{
    "_meta": {
      "hostvars": {
        "web01": {"ansible_host": "10.0.0.1"}
      }
    },
    "webservers": {"hosts": ["web01", "web02"]},
    "dbservers": {"hosts": ["db01"]}
  }'
elif [ "$1" == "--host" ]; then
  echo '{"ansible_host": "10.0.0.1"}'
fi
```
使用：
```bash
ansible-playbook -i ./dynamic_inventory.py site.yml
```

### 2.2 Playbook（剧本）

声明式的自动化编排文件，采用 YAML 格式：

```yaml
---
- name: Complete deployment playbook  # Play 名称
  hosts: webservers                    # 目标主机/组
  become: yes                          # 权限提升 (sudo)
  become_method: sudo                  # 提权方式
  gather_facts: yes                    # 收集系统事实
  any_errors_fatal: true               # 任一失败即终止
  max_failure_percentage: 30           # 最大失败容忍比例
  serial: "30%"                        # 滚动更新批次大小
  pre_tasks:                           # 前置任务
    - name: Pre-flight check
      ansible.builtin.fail:
        msg: "Unsupported OS"
      when: ansible_distribution != 'Ubuntu'
  tasks:                               # 主任务列表
    - name: Ensure package is installed  # 任务名（必须！）
      ansible.builtin.apt:              # 模块调用 (FQCN)
        name: nginx                     # 模块参数
        state: present
      register: install_result           # 注册变量
      notify: Restart Nginx             # 触发 Handler
      tags:                             # 标签（用于选择性执行）
        - install
        - nginx
      when: ansible_os_family == "Debian"  # 条件判断
      ignore_errors: false               # 错误处理
      retries: 3                         # 重试次数
      delay: 5                           # 重试间隔(秒)
      until: install_result.rc == 0      # 重试条件
  
  post_tasks:                          # 后置任务
    - name: Cleanup temp files
      ansible.builtin.file:
        path: /tmp/ansible-deploy
        state: absent

  handlers:                            # 处理器（仅在被 notify 时触发）
    - name: Restart Nginx
      ansible.builtin.service:
        name: nginx
        state: restarted
      listen:                          # 可被多个 notify 共享
        - Restart Nginx
        - Reload Nginx

  roles:                               # 引用 Roles
    - role: common                     # 简单引用
    - { role: nginx, port: 8080, tags: ['web'] }  # 带参数和标签
    
- name: Configure databases            # 同一个 Playbook 可以包含多个 Play
  hosts: dbservers
  tasks:
    - name: Install PostgreSQL
      ansible.builtin.yum:
        name: postgresql
        state: present
```

### 2.3 Tasks（任务）深度语法

#### 条件判断 (when)
```yaml
tasks:
  # 基本条件
  - name: Install on RedHat family
    ansible.builtin.yum:
      name: httpd
      state: present
    when: ansible_os_family == "RedHat"

  # 多条件组合 (and/or/not)
  - name: Deploy config
    ansible.builtin.template:
      src: app.conf.j2
      dest: /etc/app.conf
    when:
      - ansible_distribution == "Ubuntu"
      - ansible_distribution_major_version | int >= 22
      - "'database' in group_names"
      - my_var is defined
      - my_var | length > 0

  # 条件包含
  - name: Include optional tasks
    ansible.builtin.include_tasks:
      file: extra.yml
    when: enable_extra | default(false) | bool
```

#### 循环 (loop / with_*)
```yaml
tasks:
  # 标准列表循环
  - name: Create multiple users
    ansible.builtin.user:
      name: "{{ item }}"
      state: present
    loop:
      - alice
      - bob
      - charlie

  # 字典列表循环
  - name: Create users with attributes
    ansible.builtin.user:
      name: "{{ item.name }}"
      groups: "{{ item.groups }}"
      shell: "/bin/{{ item.shell }}"
    loop:
      - { name: alice, groups: 'wheel', shell: bash }
      - { name: bob, groups: 'docker', shell: zsh }

  # 字典循环
  - name: Set permissions
    ansible.builtin.file:
      path: "/opt/{{ item.key }}"
      mode: "{{ item.value }}"
    loop: "{{ lookup('dict', my_permissions_dict) }}"
    loop_control:
      label: "{{ item.key }}"  # 减少日志噪音

  # 带索引的循环
  - name: Print with index
    ansible.builtin.debug:
      msg: "Index {{ idx }}: {{ svc }}"
    loop: "{{ services }}"
    loop_control:
      index_var: idx
      extended: yes  # 提供 item 变量外还提供 idx

  # 循环 + 条件
  - name: Install packages selectively
    ansible.builtin.yum:
      name: "{{ item.name }}"
      state: present
    loop: "{{ packages }}"
    when: item.install | default(true) | bool
    loop_control:
      label: "{{ item.name }}"

  # until 重试循环（轮询等待）
  - name: Wait for service to be ready
    ansible.builtin.uri:
      url: "http://localhost:8080/health"
      status_code: 200
    register: health_check
    until: health_check.status == 200
    retries: 30
    delay: 5
```

#### 错误处理 (block/rescue/always)
```yaml
tasks:
  - name: Safe operation with error handling
    block:
      - name: Attempt risky change
        ansible.builtin.command: /usr/bin/make-some-change
      - name: Verify change
        ansible.builtin.assert:
          that:
            - verify_result.rc == 0
          fail_msg: "Verification failed!"
    rescue:
      - name: Rollback changes
        ansible.builtin.command: /usr/bin/rollback
      - name: Send alert
        ansible.builtin.uri:
          url: "https://alerts.example.com/ansible-failure"
          method: POST
          body: '{"playbook": "deploy.yml", "task": "make-some-change"}'
          body_format: json
    always:
      - name: Cleanup temp resources
        ansible.builtin.file:
          path: /tmp/ansible-tmp
          state: absent
```

#### 注册与条件变更检测 (register + changed_when / failed_when)
```yaml
tasks:
  - name: Run custom command and capture output
    ansible.builtin.shell: |
      cat /etc/myapp/config.yml | grep version
    register: config_output
    changed_when: false  # 此命令不产生实际变更
    ignore_errors: true   # 即使 grep 没找到也不算失败

  - name: Use registered variable
    ansible.builtin.debug:
      msg:
        - "stdout: {{ config_output.stdout }}"
        - "stderr: {{ config_output.stderr }}"
        - "rc: {{ config_output.rc }}"
        - "stdout_lines: {{ config_output.stdout_lines }}"

  # 自定义变更判定逻辑
  - name: Check if config needs update
    ansible.builtin.command: diff -u /tmp/new.conf /etc/current.conf
    register: diff_result
    failed_when: diff_result.rc > 1  # rc=1 表示有差异（正常），rc=2 表示错误
    changed_when: diff_result.rc == 1  # 有差异才算 changed
```

### 2.4 Variables（变量）完整指南

**定义位置：**
```yaml
# Role defaults (最低优先级)
roles/myrole/defaults/main.yml:
  nginx_worker_processes: auto
  nginx_keepalive_timeout: 65

# Role vars (较高优先级)
roles/myrole/vars/main.yml:
  nginx_conf_path: /etc/nginx/nginx.conf

# Playbook vars:
vars:
  app_name: myapp
  app_version: "{{ lookup('env', 'APP_VERSION') | default('1.0.0') }}"

# Host vars:
host_vars/web01.example.com.yml:
  server_id: 1

# Group vars:
group_vars/webservers.yml:
  cluster_name: web-tier

# Extra vars (最高优先级):
# --extra-vars "app_env=staging" 或 -e @env_vars.json
```

**Jinja2 过滤器速查：**
```yaml
tasks:
  - name: Variable filters demo
    ansible.builtin.debug:
      msg: |
        Default:     {{ my_var | default('fallback_value') }}
        Type check:  {{ my_var is string }}
        List ops:    {{ my_list | sort | unique | join(', ') }}
        String ops:  {{ my_str | lower | trim | regex_replace('_', '-') }}
        Math:        {{ [1,2,3] | sum }}  {{ 100 * 0.9 | round(1) }}
        Date:        {{ '%Y-%m-%d' | strftime(ansible_date_time.epoch) }}
        Dict:        {{ my_dict | combine(new_dict, recursive=true) }}
        Path:        {{ '/etc/nginx/conf.d' | basename }}
        B64 encode:  {{ my_secret | b64encode }}
        Password:    {{ 'mypassword' | password_hash('sha512') }}
        Random:      {{ 9999 | random }}
        JSON query:  {{ api_response | json_query('items[*].name') }}
        Network:     {{ '10.0.0.1' | ipaddr('address') }}
        File glob:   {{ lookup('fileglob', '/var/logs/*.log') | list }}
```

### 2.5 Roles（角色）结构规范

```
myrole/
├── README.md                # 角色文档（必须!）
├── meta/
│   └── main.yml             # 元数据、依赖、支持平台
├── defaults/
│   └── main.yml             # 默认变量（可覆盖，最低优先级）
├── vars/
│   └── main.yml             # 角色内部变量（不应被覆盖）
├── tasks/
│   ├── main.yml             # 入口任务（必须!）
│   ├── install.yml          # 子任务文件
│   ├── configure.yml
│   └── ...
├── handlers/
│   └── main.yml             # Handlers 列表
├── templates/               # Jinja2 模板 (*.j2)
│   └── app.conf.j2
├── files/                   # 静态文件
│   └── policy.xml
├── library/                 # 角色专属模块
├── module_utils/            # 角色专属 module utils
├── lookup_plugins/          # 角色专属 lookup 插件
├── tests/                   # 测试
│   ├── inventory
│   └── test.yml
└── docs/                    # 额外文档
```

**meta/main.yml 示例：**
```yaml
---
galaxy_info:
  author: Your Name
  description: Nginx configuration role
  company: MyCompany
  license: MIT
  min_ansible_version: 2.15
  platforms:
    - name: EL
      versions:
        - 8
        - 9
    - name: Ubuntu
      versions:
        - jammy
        - noble
  galaxy_tags:
    - nginx
    - webserver
    - reverse-proxy

dependencies: []  # 角色依赖列表
  # - role: common
  #   vars:
  #     some_var: value
```

## 3. 插件系统详解

### 3.1 连接插件 (Connection Plugins)

| 插件 | 用途 | 参数示例 |
|------|------|---------|
| `ssh` | 标准 Linux SSH 连接 | `ansible_connection: ssh` |
| `local` | 本地执行 | `ansible_connection: local` |
| `docker` | Docker 容器内执行 | `ansible_connection: docker` |
| `kubectl` | K8s Pod 内执行 | `ansible_connection: kubectl` |
| `winrm` | Windows 远程管理 | `ansible_connection: winrm` |
| `community.network.netconf` | 网络设备 NETCONF | `ansible_connection: netconf` |

### 3.2 策略插件 (Strategy Plugins)

| 策略 | 行为 | 适用场景 |
|------|------|---------|
| **linear** (默认) | 所有主机完成当前 task 后才进入下一个 | 大多数场景，有序部署 |
| **free** | 各主机独立按顺序执行所有 tasks | 无依赖的批量操作 |
| **debug** | 单步调试模式 | 故障排查 |
| **host_pinned** | 每个主机一个 worker | 大规模集群 |

使用：
```yaml
- name: Parallel deployment
  hosts: all
  strategy: free  # 或在 ansible.cfg 中配置
  tasks:
    ...
```

### 3.3 回调插件 (Callback Plugins)

常用回调插件：
```ini
# ansible.cfg
[defaults]
callback_enabled = profile_tasks,timer,json  # 启用多个回调

# 可用的内置回调:
# profile_tasks  - 显示每个任务的耗时
# timer          - 显示总运行时间
# json           - 输出 JSON 格式结果
# yaml           - 输出 YAML 格式结果
# slack          - 发送通知到 Slack
# mail           - 发送邮件通知
# jabber         - 即时消息通知
# log_plays      - 记录到日志文件
# tree           - 按主机保存结果到文件树
```

## 4. Facts 系统

### 内置 Facts 分类
```bash
# 查看所有收集的 facts
ansible webservers -m setup  # 或 ansible.builtin.gather_facts

# 常用 fact 类别:
# ansible_distribution        - 发行版名称 (Ubuntu, CentOS)
# ansible_distribution_version - 版本号 (22.04, 8)
# ansible_os_family            - OS 家族 (Debian, RedHat)
# ansible_fqdn                 - 完全限定域名
# ansible_default_ipv4.address - 主 IP 地址
# ansible_memtotal_mb          - 总内存 MB
# ansible_processor_vcpus      - CPU 核心数
# ansible_all_ipv4_addresses   - 所有 IPv4 地址
# ansible_mounts               - 挂载点信息
# ansible_lvm                  - LVM 信息
# ansible_services             - 服务状态 (需启用)
# ansible_pkg_mgr              - 包管理器 (yum/apt)
```

### 自定义 Facts
```bash
# 在目标主机上创建
sudo mkdir -p /etc/ansible/facts.d
sudo tee /etc/ansible/facts.d/app.fact << 'EOF'
{
  "app_version": "2.5.1",
  "app_environment": "production",
  "deploy_date": "2026-04-13"
}
EOF
```
Playbook 中访问：`{{ ansible_local.app.app_version }}`

### 自定义 Fact 模块
```python
#!/usr/bin/python3
"""Custom fact module example"""
import json
import os
from datetime import datetime

def get_app_facts():
    return {
        "app_custom_fact": True,
        "last_config_update": os.pathmtime('/etc/app/config.yml'),
        "current_timestamp": datetime.utcnow().isoformat()
    }

if __name__ == '__main__':
    print(json.dumps({"ansible_facts": get_app_facts()}, indent=2))
```
