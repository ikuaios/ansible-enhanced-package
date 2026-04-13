# Ansible Playbook 实战手册 (Cookbook)

## 1. 常用模式速查

### 1.1 文件与配置管理

```yaml
---
# 复制文件
- name: Copy configuration file
  ansible.builtin.copy:
    src: files/app.conf          # 相对于 playbook/role 的文件
    dest: /etc/app/conf.d/app.conf
    owner: root
    group: root
    mode: '0644'
    backup: yes                  # 变更前自动备份原文件
    force: yes                   # 强制覆盖

# 使用 Jinja2 模板渲染
- name: Deploy templated config
  ansible.builtin.template:
    src: templates/nginx.conf.j2 # Jinja2 模板文件
    dest: /etc/nginx/nginx.conf
    owner: root
    group: root
    mode: '0644'
    validate: nginx -t -c %s     # 部署前验证语法正确性
    backup: yes

# 确保目录存在并设置权限
- name: Create application directory
  ansible.builtin.file:
    path: /opt/myapp/{logs,data,cache}
    state: directory             # directory / file / link / absent / touch
    owner: myappuser
    group: myappgroup
    mode: '0755'

# 创建符号链接
- name: Link current release
  ansible.builtin.file:
    src: /opt/myapp/releases/{{ release_version }}
    dest: /opt/myapp/current
    state: link
    force: true                  # 覆盖已有链接

# 编辑文件中的特定行（行级操作）
- name: Ensure setting in config file
  ansible.builtin.lineinfile:
    path: /etc/sysctl.conf
    regexp: '^net.core.somaxconn='
    line: 'net.core.somaxconn=65535'
    state: present               # present / absent
    backrefs: yes                # 使用正则反向引用
    create: yes                  # 文件不存在时创建

# 编辑文件中块内容（多行操作）
- name: Ensure block in config
  ansible.builtin.blockinfile:
    path: /etc/httpd.conf.d/custom.conf
    marker: "# {mark} ANSIBLE MANAGED BLOCK"
    block: |
      <VirtualHost *:80>
        ServerName example.com
        DocumentRoot /var/www/html
      </VirtualHost>
    state: present

# 查找和替换文件内容
- name: Replace deprecated directive
  ansible.builtin.replace:
    path: /etc/nginx/sites-enabled/default
    regexp: 'server_tokens on;'
    replace: 'server_tokens off;'
    backup: yes
```

### 1.2 包管理与服务管理

```yaml
# === APT (Debian/Ubuntu) ===
- name: Update apt cache and install packages
  ansible.builtin.apt:
    name:
      - nginx
      - python3-pip
      - curl
    state: present              # present / latest / absent / build-deb
    update_cache: yes           # 先更新包缓存
    cache_valid_time: 3600      # 缓存有效时间(秒)
  register: apt_install

- name: Remove unnecessary packages
  ansible.builtin.apt:
    autoremove: yes

# === YUM/DNF (RHEL/CentOS/Fedora) ===
- name: Install EPEL and packages
  ansible.builtin.yum:
    name:
      - https://dl.fedoraproject.org/pub/epel/epel-latest-{{ ansible_distribution_major_version }}.noarch.rpm
      - nginx
      - htop
    state: present
    disable_gpg_check: true     # 对于非仓库源

# === 服务管理通用模式 ===
- name: Ensure service is running and enabled
  ansible.builtin.service:
    name: nginx                 # 或 systemd, docker 容器名等
    state: started              # started / stopped / restarted / reloaded
    enabled: yes                # 开机自启
  when: ansible_service_mgr == "systemd"

# 使用 systemd 模块进行更精细控制
- name: Restart service with systemd
  ansible.builtin.systemd:
    name: myapp.service
    state: restarted
    daemon_reload: yes          # 修改 unit 文件后重新加载
    enabled: yes
    scope: user                 # 用户级别服务
```

### 1.3 用户与权限管理

```yaml
# 创建用户和组
- name: Create application group
  ansible.builtin.group:
    name: appgroup
    system: yes                 # 系统组
    gid: 1000
    state: present

- name: Create application user
  ansible.builtin.user:
    name: appuser
    group: appgroup
    groups: sudo,docker         # 附加组
    shell: /bin/bash
    home: /home/appuser
    create_home: yes
    comment: "Application service account"
    password: "{{ 'secure_password' | password_hash('sha512') }}"
    password_lock: false
    expires: -1                 # 永不过期
    state: present

# 管理 SSH 密钥
- name: Deploy SSH authorized key
  ansible.builtin.authorized_key:
    user: deploy
    key: "ssh-ed25519 AAAAC3NzaC... deploy@workstation"
    state: present
    exclusive: false             # 是否只保留此 key
    manage_dir: yes

# 配置 sudo 权限
- name: Grant sudo without password for deploy user
  ansible.builtin.copy:
    dest: /etc/sudoers.d/deploy-nopasswd
    content: "deploy ALL=(ALL) NOPASSWD: ALL\n"
    mode: '0440'                 # 必须是 0440
    validate: 'visudo -cf %s'    # 语法验证
```

### 1.4 进程与命令执行

```yaml
# 执行命令并捕获输出
- name: Get application version
  ansible.builtin.command:
    cmd: /usr/bin/myapp --version
  register: app_version
  changed_when: false            # 只读命令，不产生变更
  ignore_errors: true

# 使用 shell 进行管道/重定向操作
- name: Generate configuration from template
  ansible.builtin.shell: |
    set -euo pipefail
    cd /opt/myapp
    ./generate_config.py --output /etc/myapp/config.yml \
      --env {{ app_env }} \
      --db-host {{ db_host }}
  args:
    chdir: /opt/myapp            # 工作目录
    creates: /tmp/config.lock   # 文件存在时跳过（幂等性!）
    warn: false                  # 抑制 "Consider using module" 警告

# 使用 expect 处理交互式命令
- name: Run interactive command with expect
  community.general.expect:
    command: /usr/bin/setup-wizard
    responses:
      'Enter username:': '{{ admin_user }}'
      'Enter password:': '{{ admin_pass }}'
      'Confirm (y/n)': 'y'
    echo: yes                    # 显示交互过程
```

### 1.5 Cron 与定时任务

```yaml
# 管理 cron 任务
- name: Set up database backup cron job
  ansible.builtin.cron:
    name: "Daily PostgreSQL backup"
    minute: "0"
    hour: "2"
    day: "*"
    month: "*"
    weekday: "*"                # 每天 02:00 执行
    job: "/usr/local/bin/pg_backup.sh >> /var/log/pg_backup.log 2>&1"
    user: postgres
    state: present
    disabled: no                # 设为 yes 可禁用而不删除

# 特殊时间表达式
- name: Every 5 minutes health check
  ansible.builtin.cron:
    name: "Health check"
    minute: "*/5"               # 每5分钟
    job: "/usr/bin/curl -sf http://localhost:8080/health"

- name: Business hours only check
  ansible.builtin.cron:
    name: "Working hours monitor"
    minute: "0"
    hour: "9-17"
    weekday: "1-5"              # 工作日 9:00-17:00 整点
    job: "/opt/scripts/check.sh"
```

### 1.6 数据库操作

```yaml
# PostgreSQL
- name: Create database and user
  community.postgresql.postgresql_db:
    name: myapp_production
    encoding: UTF-8
    lc_collate: en_US.UTF-8
    lc_ctype: en_US.UTF-8
    template: template0
    state: present
  become: yes
  become_user: postgres

- name: Create DB user with privileges
  community.postgresql.postgresql_user:
    db: myapp_production
    name: myapp_user
    password: "{{ db_password }}"
    priv: "ALL"
    state: present
  become: yes
  become_user: postgres

# MySQL/MariaDB
- name: Create MySQL database
  community.mysql.mysql_db:
    name: myapp
    encoding: utf8mb4
    collation: utf8mb4_unicode_ci
    state: present

- name: Execute SQL script
  community.mysql.mysql_query:
    login_db: myapp
    query:
      - CREATE TABLE IF NOT EXISTS users (
          id INT AUTO_INCREMENT PRIMARY KEY,
          username VARCHAR(255) NOT NULL UNIQUE,
          created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )
    single_transaction: yes
```

### 1.7 Docker 操作

```yaml
# 管理容器
- name: Ensure Docker container running
  community.docker.docker_container:
    name: myapp
    image: myregistry.com/myapp:{{ app_version }}
    state: started
    restart_policy: unless-stopped
    ports:
      - "8080:80"
      - "8443:443"
    env:
      APP_ENV: production
      DB_HOST: "{{ db_host }}"
      DB_PASSWORD: "{{ db_password }}"
    volumes:
      - /data/myapp/logs:/var/log/myapp
      - /data/myapp/data:/var/lib/myapp/data
    networks:
      - name: app_network
    networks_cli_compatible: yes
    pull: always                # 总是拉取最新镜像
    comparisons:
      image: strict             # 严格比较镜像（包括 digest）
    recreate: false             # 不重建已匹配的容器

# 管理 Docker 网络
- name: Create Docker network
  community.docker.docker_network:
    name: app_network
    driver: bridge
    ipam_config:
      - subnet: 172.30.0.0/16
    state: present

# 管理 Docker 镜像
- name: Pull and tag Docker images
  community.docker.docker_image:
    name: myapp
    source: pull
    tag: "{{ app_version }}"
    push: no
    force_source: yes
```

### 1.8 Git 与代码部署

```yaml
- name: Deploy application from git
  ansible.builtin.git:
    repo: https://github.com/org/myapp.git
    dest: /opt/myapp/current
    version: {{ git_branch | default('main') }}
    depth: 1                     # 浅克隆，加速
    force: yes                   # 覆盖本地修改
    key_file: /home/deploy/.ssh/deploy_key
    accept_hostkey: yes
  register: git_deploy
  become_user: deploy

- name: Install Python dependencies
  ansible.builtin.pip:
    requirements: /opt/myapp/current/requirements.txt
    virtualenv: /opt/myapp/venv
    virtualenv_python: python3.11
    state: present

- name: Run database migrations
  ansible.builtin.command:
    cmd: /opt/myapp/venv/bin/python manage.py migrate --noinput
  args:
    chdir: /opt/myapp/current
  environment:
    DJANGO_SETTINGS_MODULE: myapp.settings.production
  when: git_deploy.changed       # 仅在代码变更时执行迁移
  notify: Restart Application
```

## 2. 高级模式

### 2.1 滚动更新（零停机部署）

```yaml
---
- name: Rolling update web servers
  hosts: webservers
  serial:                        # 关键！滚动批次控制
    - 1                          # 第一批：1台（金丝雀）
    - "25%"                      # 第二批：25%
    - "50%"                      # 第三批：50%
  max_failure_percentage: 20     # 失败超过20%则中止
  
  pre_tasks:
    - name: Remove from load balancer
      ansible.builtin.uri:
        url: "http://lb.example.com/remove?host={{ inventory_hostname }}"
        method: POST
      delegate_to: localhost
      run_once: true
      connection: local
  
  tasks:
    - name: Pull new image
      community.docker.docker_container:
        name: myapp
        image: "myapp:{{ new_version }}"
        state: started
        pull: always
      notify: Health Check
  
  post_tasks:
    - name: Add back to load balancer
      ansible.builtin.uri:
        url: "http://lb.example.com/add?host={{ inventory_hostname }}"
        method: POST
      delegate_to: localhost
      run_once: true
      connection: local
  
  handlers:
    - name: Health Check
      ansible.builtin.uri:
        url: "http://localhost:8080/health"
        status_code: 200
      register: health
      until: health.status == 200
      retries: 10
      delay: 5
      listen: Health Check
```

### 2.2 多环境配置管理

```yaml
# 目录结构:
# group_vars/
# ├── all.yml          # 全局变量
# ├── staging.yml      # Staging 环境变量
# └── production.yml   # Production 环境变量
#
# host_vars/
# ├── web01.yml
# └── web02.yml

# group_vars/all.yml
---
app_name: myapp
nginx_worker_processes: auto
monitoring_enabled: true

# group_vars/staging.yml
---
app_env: staging
debug_mode: true
log_level: DEBUG
db_host: staging-db.internal
redis_url: redis://staging-redis:6379

# group_vars/production.yml
---
app_env: production
debug_mode: false
log_level: WARNING
db_host: prod-db-replica.internal
redis_url: redis://prod-redis-cluster:6379
max_connections: 5000

# Playbook 中使用
---
- name: Deploy to {{ app_env | upper }} environment
  hosts: webservers
  vars_files:
    - "vault_{{ app_env }}.yml"  # 加载对应环境的加密变量
  tasks:
    - name: Configure with environment-specific values
      ansible.builtin.template:
        src: app.env.j2
        dest: /etc/myapp/.env
```

### 2.3 Vault 加密敏感数据

```bash
# 创建 vault 密码文件（注意权限！）
echo -n "MySuperSecretVaultPassword123" > .vault_pass
chmod 600 .vault_pass

# 加密单个文件
ansible-vault encrypt secrets.yml --vault-password-file .vault_pass

# 加密字符串（嵌入 YAML）
ansible-vault encrypt_string 'SuperDbPassword456!' --name 'db_password' --vault-password-file .vault_pass
# 输出: db_password: !vault |
#           $ANSIBLE_VAULT;1.2;AES256;...
```
在 Playbook 中使用：
```yaml
# vault_secrets.yml (加密文件)
---
db_password: !vault |
  $ANSIBLE_VAULT;1.2;AES256;623...
api_key: !vault |
  $ANSIBLE_VAULT;1.2;AES256;623...

# playbook.yml
- hosts: dbservers
  vars_files:
    - vault_secrets.yml
  tasks:
    - name: Use decrypted secret
      ansible.builtin.template:
        src: db.conf.j2
        dest: /etc/db.conf
```
运行时解密：
```bash
ansible-playbook site.yml --vault-password-file .vault_pass
# 或者让 Ansible 提示输入密码
ansible-playbook site.yml --ask-vault-pass
```

### 2.4 动态 Include 和条件导入

```yaml
# 根据操作系统加载不同任务
- name: Include OS-specific tasks
  ansible.builtin.include_tasks: "install_{{ ansible_os_family | lower }}.yml"

# 条件包含角色
- name: Include monitoring role conditionally
  ansible.builtin.include_role:
    name: datadog.datadog
  when: monitoring_enabled | default(false) | bool

# 动态任务列表
- name: Process custom modules list
  ansible.builtin.include_tasks: install_module.yml
  loop: "{{ custom_modules }}"
  loop_control:
    loop_var: module_item

# install_module.yml 内容:
---
- name: Install {{ module_item.name }}
  ansible.builtin.pip:
    name: "{{ module_item.name }}"
    version: "{{ module_item.version | default(omit) }}"
    state: present
```

## 3. Jinja2 模板高级技巧

```jinja2
{# templates/app.conf.j2 #}

{% set env_name = app_env | upper %}

# 应用配置 - 环境: {{ env_name }}
[application]
name = {{ app_name }}
environment = {{ app_env }}
debug = {{ debug_mode | default(false) | lower }}

{% if debug_mode %}
log_level = DEBUG
{% else %}
log_level = {{ log_level | default('WARNING') }}
{% endif %}

[database]
host = {{ db_host }}
port = {{ db_port | default(5432) }}
name = {{ db_name }}
pool_size = {% if app_env == 'production' %}20{% else %}5{% endif %}

[cache]
servers = {{ cache_servers | join(',') }}
ttl = {{ cache_ttl | default(300) }}

{% for server in extra_servers %}
[server_{{ loop.index }}]
address = {{ server.host }}
port = {{ server.port | default(8080) }}
weight = {{ server.weight | default(1) }}
enabled = {{ server.enabled | default(true) | lower }}
{% endfor %}

{# 安全输出：避免未定义变量导致错误 #}
optional_value = {{ optional_var | default('not_set') }}
safe_list = {{ my_list | default([]) | to_json }}
safe_dict = {{ my_dict | default({}) | to_json }}
```
