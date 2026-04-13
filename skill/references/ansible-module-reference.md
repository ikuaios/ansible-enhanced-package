# Ansible 模块参考手册

## 1. 内置核心模块 (ansible.builtin.*)

### 1.1 系统模块

| 模块 | 功能 | 关键参数 | 幂等性 |
|------|------|---------|--------|
| `user` | 用户管理 | name, state, group, shell, password, groups, expires | ✅ |
| `group` | 组管理 | name, gid, state, system | ✅ |
| `cron` | 定时任务 | name, minute, hour, job, user, state | ✅ |
| `service` / `systemd` | 服务管理 | name, state, enabled, daemon_reload | ✅ |
| `mount` | 挂载点 | path, src, fstype, opts, state | ✅ |
| `hostname` | 主机名设置 | name, use | ✅ |
| `timezone` | 时区设置 | name | ✅ |
| `selinux` | SELinux 配置 | policy, state | ✅ |
| `firewalld` | 防火墙规则 | service, port, zone, permanent, state | ✅ |
| `iptables` | iptables 规则 | chain, protocol, action, table | ⚠️ |
| `sysctl` | 内核参数 | name, value, sysctl_file, reload | ✅ |
| `reboot` / `reboot` | 重启系统 | msg, connect_timeout, reboot_timeout, pre_reboot_delay | N/A |

### 1.2 文件模块

| 模块 | 功能 | 关键参数 | 幂等性 |
|------|------|---------|--------|
| `copy` | 文件复制 | src, dest, owner, mode, backup, force, content | ✅ (force=yes时) |
| `template` | Jinja2 模板 | src, dest, owner, mode, validate, backup | ✅ (模板内容变更时) |
| `file` | 文件/目录/链接 | path, state, owner, mode, recurse, modification_time | ✅ |
| `lineinfile` | 行编辑文件 | path, regexp, line, backrefs, create, insertafter/before | ✅ |
| `blockinfile` | 块编辑文件 | path, block, marker, create, insertafter/before | ✅ |
| `replace` | 正则替换 | path, regexp, replace, backup, after, before | ✅ |
| `find` | 查找文件 | paths, patterns, file_type, age, size, recurse | ✅ (只读) |
| `stat` | 获取文件属性 | path, follow, get_checksum, mime, attributes | ✅ (只读) |
| `fetch` | 从远程拉取文件 | src, dest, flat, fail_on_missing | ✅ |
| `synchronize` | rsync 同步 | src, dest, delete, archive, compress, exclude | ⚠️ |
| `ini_file` | INI 文件操作 | path, section, option, value, state, no_extra_spaces | ✅ |
| `xml` | XML 文件修改 | xpath, value, attribute, state, pretty_print | ✅ |
| `assemble` | 合并多个文件为单个文件 | src, dest, delimiter, regex, ignore_hidden | ✅ |
| `patch` | 应用补丁文件 | src, basedir, strip, binary | ⚠️ |
| `archive` | 创建压缩包 | path, format, dest, exclusion_patterns | ✅ |
| `unarchive` | 解压压缩包 | src, dest, remote_src, extra_opts, list_files | ✅ |

### 1.3 包管理模块

**APT (Debian/Ubuntu):**
```yaml
ansible.builtin.apt:
  name: package_name          # 或列表 ["pkg1", "pkg2"]
  state: present              # present / latest / absent / build-deb
  update_cache: yes           # apt-get update
  cache_valid_time: 3600
  autoclean: yes              # 清除旧缓存
  autoremove: yes             # 卸载不需要的依赖
  dpkg_options: 'force-confdef,force-confold'
  install_recommends: no      # 不安装推荐包
  default_release: "{{ ansible_distribution_release }}-backports"
```

**YUM/DNF (RHEL/CentOS/Fedora):**
```yaml
ansible.builtin.yum:          # 或 dnf (Fedora/RHEL8+)
  name: package_name
  state: present
  enablerepo: epel-testing    # 启用指定仓库
  disablerepo: '*'             # 禁用所有仓库后仅用 enablerepo
  exclude: ['kernel*']        # 排除特定包
  allow_downgrade: yes        # 允许降级
  security: yes               # 仅安装安全更新
  skip_broken: yes            # 跳过有依赖问题的包
```

**PIP (Python):**
```yaml
ansible.builtin.pip:
  name: package_name          # 或 requirements.txt
  state: present
  version: "2.5.1"            # 指定版本
  virtualenv: /opt/app/venv   # 虚拟环境路径
  virtualenv_command: python3 -m venv
  virtualenv_site_packages: no
  executable: pip3            # 可执行文件名
  break_system_packages: true  # 允许修改系统 Python 包
```

### 1.4 网络 HTTP 模块

```yaml
# GET 请求
- name: Check API health
  ansible.builtin.uri:
    url: https://api.example.com/health
    method: GET
    status_code: [200, 202]
    return_content: yes
    timeout: 30
    validate_certs: yes       # 生产环境建议开启
    headers:
      Authorization: "Bearer {{ api_token }}"
      Content-Type: application/json
  register: health_check

# POST 请求（带 body）
- name: Deploy via API
  ansible.builtin.uri:
    url: https://api.example.com/deploy
    method: POST
    body_format: json
    body:
      version: "{{ app_version }}"
      environment: production
      deployer: ansible
    status_code: [200, 201]
    headers:
      X-API-Key: "{{ api_key }}"

# 下载文件到控制节点
- name: Download artifact
  ansible.builtin.get_url:
    url: https://example.com/artifacts/myapp-{{ version }}.tar.gz
    dest: /tmp/myapp.tar.gz
    mode: '0644'
    checksum: "sha256:abc123..."   # 校验和验证
    timeout: 300                    # 大文件超时
    force: yes                      # 强制重新下载
```

### 1.5 通知与消息

```yaml
# 输出调试信息（开发/排查用）
- name: Show variable content
  ansible.builtin.debug:
    var: my_variable                # 自动格式化输出
    # 或使用 msg:
    # msg: "Value is {{ my_var }}"

# 暂停执行（等待确认）
- name: Pause for manual verification
  ansible.builtin.pause:
    minutes: 5                       # 自动恢复时间
    prompt: "Please verify the configuration above and press Enter"
    seconds: 30                      # 提示前等待秒数

# 断言检查（条件不满足则失败）
- name: Verify critical conditions
  ansible.builtin.assert:
    that:
      - "'production' in group_names or my_result.rc == 0"
      - my_variable is defined
      - my_variable | length > 0
      - ansible_memtotal_mb >= 4096
    fail_msg: "Pre-flight checks failed! Memory < 4GB or variable missing."
    success_msg: "All pre-flight checks passed."

# 失败终止
- name: Fail if condition met
  ansible.builtin.fail:
    msg: "Unsupported configuration detected!"
  when: unsupported_condition | bool

# 输出警告信息（不中断执行）
- name: Emit deprecation warning
  community.general.warn:
    message: "This task is deprecated, please use new_module instead."
```

## 2. 社区常用集合 (Community Collections)

### 2.1 community.general (通用扩展)

```yaml
# Docker Compose 管理
community.docker.docker_compose_v2:
  project_src: /opt/myapp/docker-compose.yml
  state: present                 # present / absent
  build: always                  # 总是构建镜像
  pull: always                   # 总是拉取最新镜像
  services: [web, db]            # 仅启动指定服务

# AWS S3 操作
amazon.aws.s3_object:
  bucket: my-app-artifacts
  object: "releases/{{ app_version }}.tar.gz"
  src: "/tmp/{{ app_version }}.tar.gz"
  mode: put                     # put / get / delete / list / geturl

# HashiVault 密钥读取
community.hashi_vault.vault_read:
  path: secret/data/myapp/db
  auth_method: token
  token: "{{ vault_token }}"
register: vault_secrets

# LDAP 用户管理
community.general.ldap_entry:
  dn: "uid={{ username }},ou=users,dc=example,dc=com"
  objectClass:
    - inetOrgPerson
    - posixAccount
  attributes:
    cn: "{{ full_name }}"
    uidNumber: "{{ uid_number }}"
```

### 2.2 community.docker (Docker 扩展)

| 模块 | 功能 |
|------|------|
| `docker_container` | 容器生命周期管理 |
| `docker_image` | 镜像拉取/构建/推送/删除 |
| `docker_network` | 网络创建/删除 |
| `docker_volume` | 卷管理 |
| `docker_compose_v2` | Compose 编排 |
| `docker_login` | Registry 登录认证 |
| `docker_stack` | Swarm Stack 管理 |
| `docker_swarm_service` | Swarm 服务管理 |
| `docker_host_info` | Docker 宿主机信息收集 |

### 2.3 云服务集合

| 集合 | 用途 | 安装命令 |
|------|------|---------|
| `amazon.aws` | AWS 全栈管理 | `ansible-galaxy collection install amazon.aws` |
| `azure.azcollection` | Azure 资源管理 | `ansible-galaxy collection install azure.azcollection` |
| `google.cloud` | GCP 资源管理 | `ansible-galaxy collection install google.cloud` |
| `openstack.cloud` | OpenStack 管理 | `ansible-galaxy collection install openstack.cloud` |
| `vmware.vmware_rest` | vCenter/vSphere REST API | `ansible-galaxy collection install vmware.vmware_rest` |
| `kubernetes.core` | K8s 资源管理 | `ansible-galaxy collection install kubernetes.core` |

## 3. Lookup 插件参考

```yaml
tasks:
  # 读取文件内容
  - name: Use file contents as variable
    ansible.builtin.debug:
      msg: "{{ lookup('file', '/etc/hostname') }}"

  # 读取环境变量
  - name: Get environment variable
    ansible.builtin.set_fact:
      app_token: "{{ lookup('env', 'APP_TOKEN') }}"

  # 从密码管理器读取
  - name: Read from password store
    ansible.builtin.debug:
      msg: "{{ lookup('passwordstore', 'myapp/db_password length=16') }}"

  # 读取 CSV/INI 文件
  - name: Parse CSV file
    ansible.builtin.set_fact:
      users_data: "{{ lookup('csvfile', 'users.csv delimiter=, col=1') }}"

  # DNS 解析
  - name: Resolve hostname
    ansible.builtin.debug:
      msg: "{{ lookup('dns', 'example.com', 'qtype=CNAME') }}"

  # Redis 查询
  - name: Get key from Redis
    community.general.redis.kv:
      key: "app:config:{{ item }}"
    loop: config_keys

  # AWS 参数存储 / Secrets Manager
  - name: Get parameter from AWS SSM
    amazon.aws.ssm_parameter:
      name: "/myapp/database_url"
      region: us-east-1
      decryption: true

  # Consul KV
  - name: Read from Consul
    ansible.builtin.set_fact:
      consul_value: "{{ lookup('consul_kv', 'config/myapp/url') }}"

  # Git 变量（从 git 仓库获取）
  - name: Get latest git commit hash
    ansible.builtin.set_fact:
      commit_hash: "{{ lookup('pipe', 'git rev-parse HEAD') }}"
    connection: local
    run_once: true
```

## 4. Filter 插件参考

```yaml
tasks:
  - name: Filter examples
    ansible.builtin.debug:
      msg: |
        ===== 字符串过滤器 =====
        lower:     {{ 'HELLO' | lower }}
        upper:     {{ 'hello' | upper }}
        capitalize: {{ 'hello world' | capitalize }}
        trim:      {{ '  hello  ' | trim }}
        split:     {{ 'a,b,c' | split(',') }}
        replace:   {{ 'hello-world' | replace('-', '_') }}
        regex:     {{ 'hello123' | regex_replace('\\d+', '') }}

        ===== 列表过滤器 =====
        sort:      {{ [3,1,2] | sort }}
        unique:    {{ [1,2,2,3] | unique }}
        flatten:   {{ [[1,2],[3,4]] | flatten }}
        map:       {{ [{'x':1},{'x':2}] | map(attribute='x') | list }}
        selectattr:{{ users | selectattr('active', 'equalto', True) | list }}
        rejectattr:{{ items | rejectattr('state', 'defined') | list }}
        min/max:   {{ [5,2,9] | max }} / {{ [5,2,9] | min }}
        first/last:{{ [1,2,3] | first }} / {{ [1,2,3] | last }}
        random:    {{ [1,2,3] | random }}
        shuffle:   {{ [1,2,3] | shuffle | list }}
        length:    {{ [1,2,3] | length }}
        sum:       {{ [1,2,3] | sum }}

        ===== 字典过滤器 =====
        combine:   {{ {'a':1} | combine({'b':2}) }}
        dict2items:{{ {'a':1,'b':2} | dict2items }}
        items2dict:{{ [{'key':'k','value':v}] | items2listdict(key='key',value='value') }}

        ===== 类型转换 =====
        int:       {{ '42' | int }}
        float:     {{ '3.14' | float }}
        string:    {{ 42 | string }}
        bool:      {{ 'yes' | bool }}
        to_json:   {{ my_dict | to_json(indent=2) }}
        to_yaml:   {{ my_dict | to_yaml }}
        to_nice_yaml: {{ my_dict | to_nice_yaml(indent=2) }}
        b64encode: {{ 'hello' | b64encode }}
        b64decode: {{ 'aGVsbG8=' | b64decode }}

        ===== IP 地址 =====
        ipv4:      {{ '192.168.1.1' | ipaddr('address') }}
        network:   {{ '192.168.1.0/24' | ipaddr('network') }}
        netmask:   {{ '192.168.1.0/24' | ipaddr('netmask') }}
        broadcast:{{ '192.168.1.0/24' | ipaddr('broadcast') }}
        hostmask:  {{ '192.168.1.0/24' | ipaddr('hostmask') }}
        size:      {{ '192.168.1.0/24' | ipaddr('num_addresses') }}

        ===== 日期时间 =====
        now_str:   {{ '%Y-%m-%d %H:%M:%S' | strftime() }}
        epoch:     {{ ansible_date_time.epoch | int }}
        ago_7d:    {{ (now().timestamp() - 604800) | strftime('%Y-%m-%d') }}

        ===== JSON/YAML 查询 =====
        jpath:     {{ data | json_query('items[?price>10].name') }}

        ===== 数学运算 =====
        abs:       {{ -5 | abs }}
        round:     {{ 3.14159 | round(2) }}
        pow:       {{ 2 | pow(10) }}
        log:       {{ 1024 | log(2) }}
        root:      {{ 27 | root(3) }}
        base64:    {{ 'data' | b64encode }}
```
