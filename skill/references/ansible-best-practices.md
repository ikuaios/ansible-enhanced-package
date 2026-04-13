# Ansible 最佳实践与企业级规范

## 1. 编码规范

### 1.1 Playbook 结构标准

```yaml
---
# ══════════════════════════════════════════════
# Playbook: Web Server Configuration
# Description: Configure and deploy nginx web servers
# Author: DevOps Team
# Version: 1.2.0
# Last Updated: 2026-04-13
# ══════════════════════════════════════════════
- name: Configure web servers
  hosts: webservers
  become: yes
  gather_facts: true
  serial: "{{ rollout_batch_size | default('20%') }}"
  max_failure_percentage: 30

  vars:                              # ← Play 级别变量（高优先级）
    nginx_version: "1.24.0"
    worker_processes: auto
    worker_connections: 1024

  vars_files:                        # ← 外部变量文件
    - vars/nginx_defaults.yml
    - "vault_nginx_{{ environment }}.yml"  # ← 环境感知

  pre_tasks:                         # ← 前置检查（必须！）
    - name: Validate target OS
      ansible.builtin.assert:
        that:
          - ansible_os_family == "RedHat" or ansible_os_family == "Debian"
          - ansible_python.version.major >= 3
          - ansible_memtotal_mb >= 2048
        quiet: yes

    - name: Display deployment info
      ansible.builtin.debug:
        msg: |
          ═══════════════════════════════════
          Target:  {{ inventory_hostname }}
          OS:      {{ ansible_distribution }} {{ ansible_distribution_version }}
          CPU:     {{ ansible_processor_vcpus }} cores
          Memory:  {{ ansible_memtotal_mb }} MB
          Version: {{ nginx_version }}
          ═══════════════════════════════════

  tasks:
    # ──── 分组注释 ────
    # === Package Installation ===
    - name: Install nginx package family
      block:
        - name: Install nginx (Debian/Ubuntu)
          ansible.builtin.apt:
            name: "nginx={{ nginx_version }}"
            state: present
            update_cache: yes
          when: ansible_os_family == "Debian"
          tags: [install, nginx]

        - name: Install nginx (RHEL/CentOS)
          ansible.builtin.yum:
            name: "nginx-{{ nginx_version }}"
            state: present
          when: ansible_os_family == "RedHat"
          tags: [install, nginx]

    # === Configuration Deployment ===
    - name: Deploy main configuration
      ansible.builtin.template:
        src: templates/nginx.conf.j2
        dest: /etc/nginx/nginx.conf
        owner: root
        group: root
        mode: '0644'
        validate: 'nginx -t -c %s'
        backup: yes
      notify: Reload Nginx
      tags: [configure, nginx]

    # === Security Hardening ===
    - name: Remove default server tokens
      ansible.builtin.lineinfile:
        path: /etc/nginx/nginx.conf
        regexp: '^\\s*server_tokens'
        line: 'server_tokens off;'
        state: present
      notify: Reload Nginx
      tags: [security]

  post_tasks:                        # ← 后置清理/验证
    - name: Verify nginx is running
      ansible.builtin.command:
        cmd: systemctl is-active nginx
      register: nginx_status
      changed_when: false
      failed_when: nginx_status.stdout != 'active'

    - name: Run smoke tests
      ansible.builtin.uri:
        url: http://localhost/nginx_status
        status_code: [200]
      retries: 5
      delay: 2
      until: uri_result.status == 200

  handlers:
    - name: Reload Nginx
      ansible.builtin.service:
        name: nginx
        state: reloaded
      listen: [Reload Nginx]

    - name: Restart Nginx
      ansible.builtin.service:
        name: nginx
        state: restarted
      listen: [Restart Nginx]
```

### 1.2 命名规范

| 元素 | 规范 | 示例 |
|------|------|------|
| **Playbook 文件** | kebab-case, 动词开头 | `deploy-web-servers.yml`, `setup-monitoring.yml` |
| **Role 名称** | 单个名词, 小写 | `nginx`, `postgresql`, `docker-setup` |
| **变量名** | snake_case | `app_port`, `db_connection_string`, `max_workers` |
| **任务名称** | 动词短语, 首字母大写 | `"Install nginx package"`, `"Deploy configuration file"` |
| **Handler 名称** | 动词+名词, 首字母大写 | `"Restart Nginx"`, `"Reload systemd"` |
| **标签** | 小写, 分类清晰 | `install`, `configure`, `security`, `rollback` |
| **Inventory 组名** | 小写, 语义明确 | `webservers`, `dbservers`, `production` |
| **主机名** | 小写 + FQDN 格式 | `web01.prod.example.com` |

### 1.3 目录结构最佳实践

```
project_root/
├── ansible.cfg                    # 项目级配置（提交到 VCS）
├── inventory/
│   ├── production/
│   │   ├── hosts                  # 生产主机清单
│   │   ├── group_vars/
│   │   │   ├── all.yml
│   │   │   ├── webservers.yml
│   │   │   └── dbservers.yml
│   │   └── host_vars/
│   │       ├── web01.yml
│   │       └── db01.yml
│   ├── staging/
│   │   ├── hosts
│   │   ├── group_vars/
│   │   └── host_vars/
│   └── development/
│       └── ...
├── roles/
│   ├── common/
│   │   ├── tasks/
│   │   ├── handlers/
│   │   ├── defaults/
│   │   ├── vars/
│   │   ├── templates/
│   │   ├── files/
│   │   ├── meta/
│   │   └── README.md
│   ├── nginx/
│   └── monitoring/
├── group_vars/                    # 顶层默认变量（跨环境共享）
├── library/                       # 自定义模块
├── module_utils/                  # 自定义 module utils
├── filter_plugins/                # 自定义过滤器
├── lookup_plugins/                # 自定义 lookup 插件
├── playbooks/                     # 入口 Playbooks
│   ├── site.yml                   # 主入口
│   ├── deploy.yml
│   └── rollback.yml
├── templates/                     # 共享模板
├── files/                          # 共享静态文件
├── scripts/                       # 辅助脚本
├── tests/                         # Molecule 测试
│   └── molecule/
├── docs/                          # 文档
├── .vault-pass                    # Vault 密码文件（⚠️ 不要提交到 VCS!）
├── requirements.yml               # Galaxy 依赖声明
├── .gitignore
└── README.md
```

## 2. 性能优化策略

### 2.1 连接优化

```ini
# ansible.cfg
[defaults]
# SSH 连接管道化（减少连接次数）
pipelining = True

# 使用 SSH multiplexing（复用连接）
# 在 ~/.ssh/config 中配置:
# ControlMaster auto
# ControlPath ~/.ssh/ansible-%r@%h:%p
# ControlPersist 15m

# forks 数量（并行度，根据目标规模调整）
forks = 50

[ssh_connection]
ssh_args = -o ControlMaster=auto -o ControlPersist=600s -o StrictHostKeyChecking=no
control_path = /tmp/ansible-ssh-%h-%p-%r
control_path_dir = /tmp/ansible-ssh-control
timeout = 30
pipelining = True
retries = 3
```

### 2.2 Facts 收集优化

```yaml
# 方式 1: 仅收集必要的 facts
- hosts: all
  gather_facts: no               # 禁用自动收集
  pre_tasks:
    - name: Gather minimal facts
      ansible.builtin.setup:
        gather_subset:           # 只收集需要的子集
          - '!all'               # 先排除全部
          - network              # 仅网络信息
          - virtualization       # 虚拟化信息
      tags: always

# 方式 2: 缓存 facts（大规模环境强烈推荐）
# ansible.cfg
[facts_caching]
driver = jsonfile               # 或 redis, memcached
backend = /tmp/ansible_facts_cache
timeout = 86400                 # 缓存 24 小时

# Redis 后端（多控制节点共享）
# driver = redis
# backend = redis://localhost:6379/0
```

### 2.3 执行策略优化

```yaml
# 场景 A: 无依赖的大批量操作 → free 策略
- name: Batch package installation
  hosts: all
  strategy: free                  # 各主机独立并行
  tasks:
    - name: Install common packages
      ansible.builtin.yum:
        name: "{{ item }}"
        state: present
      loop: "{{ common_packages }}"

# 场景 B: 有序部署 → linear 策略（默认）+ serial 控制
- name: Ordered rolling deployment
  hosts: webservers
  strategy: linear
  serial:
    - 1                           # 第一台（金丝雀）
    - "25%"                       # 第二批
    - "50%"                       # 第三批
  tasks:
    ...

# 场景 C: 超大规模 (>1000 hosts)
- name: Large scale management
  hosts: "{{ target_group }}"
  strategy: free
  order: sorted                   # 按主机名排序执行
  throttle: 20                    # 同时最多 20 个并发任务
  tasks:
    - name: Throttled operation
      ...
```

### 2.4 异步与轮询

```yaml
# 长耗时任务（如系统更新、大数据处理）
- name: Run long-running operation asynchronously
  ansible.builtin.yum:
    name: '*'
    state: latest
    update_cache: yes
  async: 3600                     # 最长运行时间（秒）
  poll: 0                         # 0 = 不轮询，立即返回（fire-and-forget）
  register: yum_update

# 后续检查异步任务结果
- name: Check async job status
  ansible.builtin.async_status:
    jid: "{{ yum_update.ansible_job_id }}"
  register: job_result
  until: job_result.finished
  retries: 120                    # 每 10 秒检查一次，最多 120 次
  delay: 10

# 带超时的健康检查轮询
- name: Wait for service readiness
  ansible.builtin.uri:
    url: http://localhost:8080/health
    status_code: 200
  register: health_check
  until: health_check.status == 200
  retries: 60
  delay: 5
  changed_when: false
```

### 2.5 其他性能技巧

```yaml
# 1. 使用 with_items 的 loop 替代方案（更高效）
- name: Create multiple files efficiently
  ansible.builtin.copy:
    dest: "/etc/app/{{ item.name }}.conf"
    content: "{{ item.content }}"
    mode: '0644'
  loop: "{{ config_files }}"       # 比 with_* 更现代且更快

# 2. 减少不必要的 debug 输出
- name: Verbose output only in debug mode
  ansible.builtin.debug:
    verbosity: 1                  # 仅在 -v 模式下显示
    msg: "Detailed info: {{ complex_var }}"

# 3. 条件跳过未变更的任务
- name: Only run when changes detected
  ansible.builtin.command: /usr/bin/reload-config
  when: config_deploy.changed    # 利用 registered 的 changed 属性

# 4. 使用 delegate_to 和 local_action 减少网络往返
- name: Build artifact locally
  ansible.builtin.command: make release
  args:
    chdir: "{{ playbook_dir }}/../src"
  delegate_to: localhost         # 在本地执行
  run_once: true
  connection: local
  become: false

# 5. 批量模式下的标签过滤
# 运行时: ansible-playbook site.yml --tags "install" --skip-tags "debug"
```

## 3. 安全加固指南

### 3.1 敏感数据管理

```bash
# 1. Vault 密码保护
export ANSIBLE_VAULT_PASSWORD_FILE=~/.vault_pass
chmod 600 ~/.vault_pass
chmod 600 .vault-pass

# 2. 加密字符串嵌入 YAML（无需单独加密文件）
ansible-vault encrypt_string \
  'SuperSecretPassword!' \
  --name 'db_password' \
  --vault-password-file ~/.vault_pass
# 输出复制到 vars 文件中

# 3. 多层 Vault（不同权限访问不同密钥）
# vault_prod.yml - 生产密钥（DBA 权限解密）
# vault_app.yml - 应用密钥（开发者可读）
# vault_infra.yml - 基础设施密钥（运维专用）

# 4. 自动化解密（CI/CD 环境）
# 将 Vault 密码存入 CI secrets，通过环境变量传递：
# export ANSIBLE_VAULT_PASSWORD_FILE=$(mktemp)
# echo "$CI_VAULT_PASSWORD" > $ANSIBLE_VAULT_PASSWORD_FILE
```

### 3.2 SSH 安全配置

```ini
# ansible.cfg
[defaults]
# 禁止明文密码
host_key_checking = True         # 保持启用，预知公钥

# 使用专用的 SSH 密钥
# private_key_file = ~/.ssh/deploy_key
# 不记录敏感变量到日志
no_log = False                   # 由各模块自行控制

[privilege_escalation]
become=True
become_user=root
become_ask_pass=False
become_method=sudo
```

### 3.3 内容安全

```yaml
# 在包含敏感信息的任务中使用 no_log
- name: Process sensitive data
  ansible.builtin.template:
    src: secrets.env.j2
    dest: /opt/app/.env
  no_log: true                   # 日志中隐藏此任务的详细信息

# 使用 password_hash 过滤器而非明文密码
- name: Create user with hashed password
  ansible.builtin.user:
    name: serviceuser
    password: "{{ 'plain_text_password' | password_hash('sha512') }}"
    shell: /sbin/nologin

# 避免在日志中暴露 token/secret
- name: Call secure API
  ansible.builtin.uri:
    url: https://api.internal/endpoint
    headers:
      Authorization: "Bearer {{ api_token }}"
  no_log: true
  register: api_response
  # 如果需要调试，临时移除 no_log 并限制输出范围
```

## 4. 可维护性与测试

### 4.1 Role 设计原则

```yaml
# meta/main.yml - 明确声明依赖和支持矩阵
---
galaxy_info:
  author: Your Name
  description: Brief role description
  license: MIT
  min_ansible_version: 2.15
  platforms:
    - name: EL
      versions: [8, 9]
    - name: Ubuntu
      versions: [jammy, noble]
  galaxy_tags: [category1, category2]

dependencies: []
  # - role: common
  #   vars:
  #     some_param: value
```

### 4.2 Molecule 测试框架

```yaml
# tests/molecule/default/molecule.yml
---
dependency:
  name: galaxy
driver:
  name: docker                  # 或 vagrant, podman, ec2
platforms:
  - name: instance-centos8
    image: geerlingguy/docker-centos8-ansible
    command: /lib/systemd/systemd
    privileged: true
    volumes:
      - /sys/fs/cgroup:/sys/fs/cgroup:rw
    pre_build_image: true
  - name: instance-ubuntu22
    image: geerlingguy/docker-ubuntu2204-ansible
    command: /lib/systemd/systemd
    privileged: true
    volumes:
      - /sys/fs/cgroup:/sys/fs/cgroup:rw
    pre_build_image: true
provisioner:
  name: ansible
  inventory:
    hosts:
      all:
        vars:
          test_mode: true
verifier:
  name: testinfra               # 或 goss, inspec
  options:
    v: 2
lint: |
  yamllint .
  ansible-lint

# tests/test_default.py (testinfra)
import os

def test_nginx_is_installed(host):
    nginx = host.package("nginx")
    assert nginx.is_installed

def test_nginx_running_and_enabled(host):
    service = host.service("nginx")
    assert service.is_running
    assert service.is_enabled

def test_config_file_exists(host):
    config = host.file("/etc/nginx/nginx.conf")
    assert config.exists
    assert config.user == "root"
    assert config.group == "root"

def test_listening_port(host):
    socket = host.socket("tcp://0.0.0.0:80")
    assert socket.is_listening
```

### 4.3 Linting 与质量门禁

```bash
# 安装 linters
pip install ansible-lint yamllint

# 运行 lint
ansible-lint playbooks/site.yml
yamllint .

# .ansible-lint 配置
# .ansible-lint
---
exclude_paths:
  - .git/
  - .cache/
  - tests/

rulesdir: ./rules/
skip_list:                    # 临时忽略的规则
  - role-name                 # 角色命名规则
  - no-changed-when           # changed_when 检查

# 自定义规则
# rules/RequireWhenBlock.yml
---
# 要求所有条件语句使用 block 形式
```

## 5. CI/CD 集成模式

### GitHub Actions 示例

```yaml
# .github/workflows/ansible-test.yml
name: Ansible Test Suite
on:
  push:
    paths:
      - '**.yml'
      - 'roles/**'
  pull_request:

jobs:
  lint:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Set up Python
        uses: actions/setup-python@v5
        with:
          python-version: '3.11'
      - name: Install dependencies
        run: |
          pip install ansible-lint yamllint ansible-core molecule[docker] docker testinfra
      - name: Run linter
        run: |
          ansible-lint .
          yamllint .

  molecule-test:
    needs: lint
    runs-on: ubuntu-latest
    strategy:
      matrix:
        scenario: [default, upgrade]
        platform: [centos8, ubuntu22]
    steps:
      - uses: actions/checkout@v4
      - name: Set up Python
        uses: actions/setup-python@v5
        with:
          python-version: '3.11'
      - name: Install dependencies
        run: |
          pip install ansible-core molecule[docker] testinfra
      - name: Run Molecule tests
        run: molecule test -s ${{ matrix.scenario }}
        env:
          PY_COLORS: '1'

  integration:
    needs: molecule-test
    runs-on: ubuntu-latest
    if: github.ref == 'refs/heads/main'
    steps:
      - uses: actions/checkout@v4
      - name: Deploy to staging
        env:
          ANSIBLE_VAULT_PASSWORD: ${{ secrets.VAULT_PASSWORD }}
        run: |
          echo "$ANSIBLE_VAULT_PASSWORD" > .vault-pass
          ansible-playbook -i inventory/staging/hosts playbooks/deploy.yml \
            --check --diff --extra-vars "environment=staging"
```
