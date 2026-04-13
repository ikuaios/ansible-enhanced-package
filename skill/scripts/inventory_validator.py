#!/usr/bin/env python3
"""
Ansible Inventory Validator - Inventory 文件格式校验器
支持 INI/YAML 格式的静态/动态 Inventory 校验

用法:
    python3 inventory_validator.py <inventory_path> [--check-connectivity] [--format json] [--user USER] [--key KEY]
    python3 inventory_validator.py hosts.ini
    python3 inventory_validator.py inventory/ --check-connectivity --user deploy
    python3 inventory_validator.py inventory/aws_ec2.yml --format json
"""

import argparse
import ipaddress
import json
import os
import re
import socket
import subprocess
import sys
from pathlib import Path
from typing import Any


class Issue:
    """表示一个检测到的问题"""

    def __init__(self, severity: str, rule_id: str, file: str,
                 line: int, message: str, suggestion: str = ""):
        self.severity = severity  # error / warning / info
        self.rule_id = rule_id
        self.file = file
        self.line = line
        self.message = message
        self.suggestion = suggestion

    def to_dict(self) -> dict[str, Any]:
        return {
            "severity": self.severity,
            "rule_id": self.rule_id,
            "file": self.file,
            "line": self.line,
            "message": self.message,
            "suggestion": self.suggestion,
        }

    def __str__(self) -> str:
        sym = {"error": "❌", "warning": "⚠️", "info": "ℹ️"}.get(self.severity, "?")
        return f"  {sym} [{self.rule_id}] {self.file}:{self.line} | {self.message}"


class InventoryValidator:
    """Inventory 文件校验器"""

    # 常见的主机名正则
    HOSTNAME_PATTERN = re.compile(
        r"^(?=.{1,253}$)(?!-)[A-Za-z0-9-]{1,63}(?<!-)(\.[A-Za-z0-9-]{1,63}(?<!-))*$"
    )
    IP_PATTERN = re.compile(
        r"^(\d{1,3}\.){3}\d{1,3}$|^([0-9a-fA-F]{0,4}:){2,7}[0-9a-fA-F]{0,4}$"
    )

    def __init__(self, target: Path, check_connectivity: bool = False,
                 user: str = None, key_file: str = None):
        self.target = target.resolve()
        self.check_connectivity = check_connectivity
        self.user = user or os.environ.get("ANSIBLE_REMOTE_USER", "root")
        self.key_file = key_file or os.environ.get("ANSIBLE_PRIVATE_KEY_FILE")
        self.issues: list[Issue] = []
        self.stats = {
            "files_scanned": 0,
            "total_hosts": 0,
            "total_groups": 0,
            "connectivity_ok": 0,
            "connectivity_fail": 0,
            "by_severity": {"error": 0, "warning": 0, "info": 0},
        }
        # 收集到的主机和组
        self.hosts: dict[str, dict] = {}   # hostname -> {file, line, groups, vars}
        self.groups: dict[str, set] = {}    # group_name -> set of hostnames

    def _add_issue(self, severity: str, rule_id: str, file: str,
                   line: int, msg: str, suggestion: str = ""):
        issue = Issue(severity, rule_id, file, line, msg, suggestion)
        self.issues.append(issue)
        self.stats["by_severity"][severity] += 1

    # ─── INI 格式解析 ──────────────────────────────

    def _parse_ini(self, filepath: Path) -> tuple[list[dict], list[Issue]]:
        """解析 INI 格式的 inventory 文件"""
        content = filepath.read_text(encoding="utf-8")
        lines = content.split("\n")
        entries = []
        current_group = None

        for i, raw_line in enumerate(lines, 1):
            line = raw_line.strip()
            if not line or line.startswith("#") or line.startswith(";"):
                continue

            # 组声明 [groupname]
            group_match = re.match(r"^\[([^\]]+)\]$", line)
            if group_match:
                group_name = group_match.group(1)
                # 检查特殊组标签
                if ":" in group_name:
                    parent_type = group_name.split(":")[1]
                    valid_parents = {"vars", "children"}
                    if parent_type not in valid_parents and not group_name.endswith(":vars"):
                        self._add_issue("warning", "I002", str(filepath), i,
                                        f"未知的组修饰符: {group_name}",
                                        f"有效的组修饰符: {', '.join(valid_parents)}")
                    elif group_name.endswith(":vars"):
                        current_group = "__vars__"
                        continue
                    else:
                        current_group = group_name
                        continue
                current_group = group_name
                if group_name not in self.groups:
                    self.groups[group_name] = set()
                self.stats["total_groups"] += 1
                continue

            # 主机定义或变量赋值
            var_match = re.match(r"^(\w[\w-]*)\s*=\s*(.+)$", line)
            if var_match and current_group == "__vars__":
                continue  # 组变量，跳过

            host_match = re.match(r"^([\w.\-]+)(?:\s+(.+))?$", line)
            if host_match and current_group and current_group != "__vars__":
                hostname = host_match.group(1)
                extra = host_match.group(2) or ""

                # 验证主机名格式
                if not (self.HOSTNAME_PATTERN.match(hostname) or self.IP_PATTERN.match(hostname)):
                    self._add_issue("error", "I001", str(filepath), i,
                                    f"无效的主机名格式: {hostname}",
                                    "使用合法的 FQDN 或 IP 地址")

                # 解析主机变量
                host_vars = {}
                if extra:
                    for token in extra.split():
                        kv_match = re.match(r"(\w[\w-]*)=(.+)", token)
                        if kv_match:
                            host_vars[kv_match.group(1)] = kv_match.group(2)

                entry = {
                    "hostname": hostname,
                    "group": current_group,
                    "line": i,
                    "file": str(filepath),
                    "vars": host_vars,
                }
                entries.append(entry)
                self.hosts[hostname] = {
                    **entry,
                    "groups": set(),
                }
                self.groups.setdefault(current_group, set()).add(hostname)
                self.stats["total_hosts"] += 1

                # 检查 ansible_host 变量（IP 格式）
                if "ansible_host" in host_vars:
                    host_ip = host_vars["ansible_host"]
                    try:
                        ipaddress.ip_address(host_ip)
                    except ValueError:
                        self._add_issue("error", "I003", str(filepath), i,
                                        f"ansible_host 不是有效 IP: {host_ip}")

        return entries, []

    def _parse_yaml_inventory(self, filepath: Path) -> tuple[list[dict], list[Issue]]:
        """解析 YAML 格式的 inventory"""
        try:
            import yaml
        except ImportError:
            self._add_issue("error", "Y001", str(filepath), 0,
                            "无法导入 PyYAML 库",
                            "安装: pip install pyyaml")
            return [], []

        content = filepath.read_text(encoding="utf-8")
        try:
            data = yaml.safe_load(content)
        except yaml.YAMLError as e:
            self._add_issue("error", "Y002", str(filepath), 0,
                            f"YAML 解析错误: {e}")
            return [], []

        if not isinstance(data, dict):
            self._add_issue("error", "Y003", str(filepath), 0,
                            "Inventory YAML 根元素必须是字典")
            return [], []

        entries = []
        all_group = data.get("all", data)
        
        # 递归处理组
        def process_group(group_data: dict, group_name: str, parent_groups: list = None):
            if parent_groups is None:
                parent_groups = []
            
            hosts_data = group_data.get("hosts", {})
            if isinstance(hosts_data, dict):
                for hostname, host_config in hosts_data.items():
                    config = host_config if isinstance(host_config, dict) else {}
                    entries.append({
                        "hostname": hostname,
                        "group": group_name,
                        "line": 0,  # YAML 行号需要更复杂的追踪
                        "file": str(filepath),
                        "vars": config,
                    })
                    self.hosts[hostname] = {
                        "hostname": hostname,
                        "group": group_name,
                        "line": 0,
                        "file": str(filepath),
                        "vars": config,
                        "groups": set(parent_groups + [group_name]),
                    }
                    self.groups.setdefault(group_name, set()).add(hostname)
                    self.stats["total_hosts"] += 1
                    
                    if "ansible_host" in config:
                        try:
                            ipaddress.ip_address(config["ansible_host"])
                        except ValueError:
                            self._add_issue("error", "I003", str(filepath), 0,
                                            f"ansible_host 不是有效 IP: {config['ansible_host']}")

            children = group_data.get("children", {})
            if isinstance(children, dict):
                for child_name, child_data in children.items():
                    self.stats["total_groups"] += 1
                    process_group(child_data, child_name, parent_groups + [group_name])

        # 处理顶层
        if isinstance(all_group, dict):
            # 处理 vars
            if "vars" in all_group:
                pass
            
            # 处理 children 和 hosts
            for key in ("hosts", "children"):
                if key == "hosts":
                    process_group(all_group, "all")
                elif key in all_group and isinstance(all_group[key], dict):
                    for child_name, child_data in all_group[key].items():
                        self.stats["total_groups"] += 1
                        process_group(child_data, child_name, ["all"])

        return entries, []

    def _detect_format(self, filepath: Path) -> str:
        """检测文件格式"""
        content = filepath.read_text(encoding="utf-8").strip()
        if content.startswith("---") or content.startswith("{"):
            return "yaml"
        return "ini"

    # ─── 连通性检查 ──────────────────────────────

    def _check_connectivity(self, hostname: str) -> bool:
        """检查单个主机的 SSH 连通性"""
        cmd = [
            "ssh", "-o", "BatchMode=yes",
            "-o", "ConnectTimeout=5",
            "-o", "StrictHostKeyChecking=accept-new",
        ]
        if self.key_file:
            cmd.extend(["-i", self.key_file])
        cmd.append(f"{self.user}@{hostname}")
        cmd.append("echo CONNECTED")

        try:
            result = subprocess.run(
                cmd, capture_output=True, text=True, timeout=10
            )
            return result.returncode == 0 and "CONNECTED" in result.stdout
        except subprocess.TimeoutExpired:
            return False
        except Exception:
            return False

    def _resolve_hostname(self, hostname: str) -> str | None:
        """DNS 解析"""
        # 如果是 ansible_host 变量中定义的 IP，直接返回
        host_info = self.hosts.get(hostname, {})
        ansible_host = host_info.get("vars", {}).get("ansible_host")
        if ansible_host:
            return ansible_host

        try:
            return socket.gethostbyname(hostname)
        except socket.gaierror:
            return None

    # ─── 高级检查 ────────────────────────────────

    def _check_duplicate_hosts(self):
        """检测重复主机定义"""
        seen_files: dict[str, list[str]] = {}
        for hostname, info in self.hosts.items():
            fname = info.get("file", "")
            seen_files.setdefault(hostname, []).append(fname)

        for hostname, files in seen_files.items():
            if len(files) > 1:
                unique_files = list(set(files))
                self._add_issue("warning", "D001", unique_files[0], 0,
                                f"主机 '{hostname}' 在多个文件中定义: {', '.join(unique_files)}",
                                "合并为单一定义或确认是否有意为之（如环境覆盖）")

    def _check_circular_group_deps(self):
        """检测组嵌套循环依赖（简化版）"""
        visited = set()
        path = []

        def visit(group: str) -> bool:
            if group in path:
                cycle_start = path.index(group)
                cycle = path[cycle_start:] + [group]
                self._add_issue("error", "G001", "", 0,
                                f"检测到循环的组嵌套: {' → '.join(cycle)}",
                                "移除循环引用中的一个以打破循环")
                return True
            if group in visited:
                return False
            path.append(group)
            visited.add(group)
            return False

        for group in list(self.groups.keys()):
            visit(group)
            path.clear()

    def _check_orphaned_hosts(self):
        """检测不属于任何组的主机"""
        for hostname in self.hosts:
            groups_with_host = [g for g, h in self.groups.items() if hostname in h]
            if not groups_with_host:
                self._add_issue("info", "O001",
                                self.hosts[hostname].get("file", ""),
                                self.hosts[hostname].get("line", 0),
                                f"主机 '{hostname}' 不属于任何组",
                                "考虑将其添加到一个有意义的组中")

    def _check_empty_groups(self):
        """检测空组"""
        for group, members in self.groups.items():
            if not members and not group.endswith(":vars"):
                # 检查是否是父组
                is_parent = any(group in other for other in self.groups if ":" in other)
                if not is_parent:
                    self._add_issue("info", "E001", "", 0,
                                    f"组 '{group}' 为空且没有子组",
                                    "添加主机或删除空组定义")

    def _check_undefined_variables(self, content_lines: list[str], filepath: str):
        """检测可能未定义的变量引用"""
        var_pattern = re.compile(r"\{\{\s*(\w[\w.]*)\s*\}\}")
        defined_vars: set[str] = set()
        referenced_vars: dict[str, int] = {}

        for i, line in enumerate(content_lines, 1):
            stripped = line.strip()
            # 跟踪已定义的变量
            var_def = re.match(r"^(\w[\w_-]*)\s*:", stripped)
            if var_def:
                defined_vars.add(var_def.group(1))

            # 跟踪被引用的变量
            for match in var_pattern.finditer(line):
                var_name = match.group(1)
                # 排除 Ansible 内置变量
                builtin_patterns = {
                    "ansible_", "inventory_", "group_names", "groups",
                    "hostvars", "playbook_dir", "role_path", "role_name",
                    "item", "inventory_hostname", "omit", "default",
                    "vars", "environment", "lookup", "defined",
                }
                if not any(var_name.startswith(p) for p in builtin_patterns):
                    referenced_vars[var_name] = i

        # 报告未定义但被引用的变量（仅限非内置）
        for var, line_num in referenced_vars.items():
            if var not in defined_vars:
                # 可能是来自 group_vars/host_vars 的变量，仅提示
                self._add_issue("info", "V001", filepath, line_num,
                                f"变量 '{{{{ {var} }}}}' 可能在本地未定义",
                                f"确认该变量在 group_vars/host_vars 或 defaults 中已定义")

    # ─── 主流程 ──────────────────────────────────

    def scan(self) -> list[Issue]:
        """执行完整的校验扫描"""
        if self.target.is_file():
            self._scan_single_file(self.target)
        elif self.target.is_dir():
            for item in self.target.rglob("*"):
                if item.is_file() and item.suffix in {".ini", ".yml", ".yaml"}:
                    # 跳过隐藏文件和目录
                    if any(p.startswith(".") or p in {"node_modules", ".git", "__pycache__"}
                           for p in item.parts):
                        continue
                    self._scan_single_file(item)
        else:
            print(f"❌ 路径不存在: {self.target}", file=sys.stderr)
            sys.exit(1)

        # 运行高级检查
        self._check_duplicate_hosts()
        self._check_circular_group_deps()
        self._check_orphaned_hosts()
        self._check_empty_groups()

        # 连通性检查
        if self.check_connectivity and self.hosts:
            self._perform_connectivity_check()

        return self.issues

    def _scan_single_file(self, filepath: Path):
        """扫描单个文件"""
        try:
            content = filepath.read_text(encoding="utf-8")
        except Exception as e:
            self._add_issue("error", "F000", str(filepath), 0, f"无法读取文件: {e}")
            return

        self.stats["files_scanned"] += 1
        fmt = self._detect_format(filepath)

        if fmt == "ini":
            self._parse_ini(filepath)
        elif fmt == "yaml":
            self._parse_yaml_inventory(filepath)

        # 变量检查（对 INI 格式的原始内容）
        if fmt == "ini":
            self._check_undefined_variables(content.split("\n"), str(filepath))

    def _perform_connectivity_check(self):
        """执行连通性预检"""
        import concurrent.futures

        print(f"\n🔍 正在检查 {len(self.hosts)} 台主机的 SSH 连通性...\n")

        with concurrent.futures.ThreadPoolExecutor(max_workers=10) as executor:
            future_to_host = {
                executor.submit(self._check_connectivity, hn): hn
                for hn in self.hosts
            }
            for future in concurrent.futures.as_completed(future_to_host):
                hostname = future_to_host[future]
                try:
                    ok = future.result()
                    if ok:
                        self.stats["connectivity_ok"] += 1
                        print(f"  ✅ {hostname} — 已连接")
                    else:
                        self.stats["connectivity_fail"] += 1
                        resolved = self._resolve_hostname(hostname)
                        reason = f"(DNS: {'✅ ' + resolved if resolved else '❌ 无法解析'})"
                        print(f"  ❌ {hostname} — 连接失败 {reason}")
                        self._add_issue("error", "C001", 
                                        self.hosts.get(hostname, {}).get("file", ""),
                                        self.hosts.get(hostname, {}).get("line", 0),
                                        f"SSH 连接失败: {hostname}", reason)
                except Exception as e:
                    self._add_issue("error", "C001", str(self.hosts.get(hostname, {}).get("file", "")), 0,
                                    f"连接检查异常: {hostname}: {e}")

    def format_report(self, output_format: str = "text") -> str:
        """生成报告"""
        if output_format == "json":
            return json.dumps({
                "target": str(self.target),
                "statistics": self.stats,
                "hosts_count": len(self.hosts),
                "groups_count": len(self.groups),
                "issues": [i.to_dict() for i in self.issues],
            }, indent=2, ensure_ascii=False, default=str)

        lines = []
        lines.append(f"\n{'='*70}")
        lines.append(f"  📋 Ansible Inventory Validator 报告")
        lines.append(f"  目标: {self.target}")
        lines.append(f"  文件数: {self.stats['files_scanned']}")
        lines.append(f"  主机总数: {len(self.hosts)}")
        lines.append(f"  组总数: {len(self.groups)}")
        if self.check_connectivity:
            lines.append(f"  连通性: ✅ {self.stats['connectivity_ok']} / ❌ {self.stats['connectivity_fail']}")
        lines.append(f"{'='*70}")

        # 显示主机列表
        if self.hosts:
            lines.append(f"\n📡 发现的主机:")
            for gname, members in sorted(self.groups.items()):
                if members:
                    lines.append(f"  📁 {gname} ({len(members)} 台)")
                    for h in sorted(members)[:20]:  # 最多显示 20 个
                        info = self.hosts.get(h, {})
                        vcount = len(info.get("vars", {}))
                        var_str = f" ({vcount} 个变量)" if vcount > 0 else ""
                        lines.append(f"     • {h}{var_str}")
                    if len(members) > 20:
                        lines.append(f"     ... 还有 {len(members) - 20} 台")

        # 问题列表
        for sev in ["error", "warning", "info"]:
            group = [i for i in self.issues if i.severity == sev]
            if group:
                sym = {"error": "❌", "warning": "⚠️", "info": "ℹ️"}[sev]
                lines.append(f"\n{'─'*50}")
                lines.append(f"  {sym} {sev.upper()} ({len(group)} 个)")
                lines.append(f"{'─'*50}")
                for issue in sorted(group, key=lambda x: (x.file, x.line)):
                    lines.append(str(issue))
                    if issue.suggestion:
                        lines.append(f"     💡 {issue.suggestion}")

        lines.append(f"\n{'='*70}")
        total_issues = sum(self.stats["by_severity"].values())
        if total_issues == 0:
            lines.append("  ✅ 校验通过！Inventory 结构正确。")
        else:
            parts = [f"  {sym} {s}: {c}" for s, c in self.stats["by_severity"].items() if c]
            sym_map = {"error": "❌", "warning": "⚠️", "info": "ℹ️"}
            lines.extend(parts)
        lines.append(f"{'='*70}\n")

        return "\n".join(lines)


def main():
    parser = argparse.ArgumentParser(
        description="Ansible Inventory 文件校验器",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
规则 ID 说明:
  I001   无效主机名/IP 格式
  I002   未知的组修饰符
  I003   无效的 ansible_host IP
  Y001   缺少 PyYAML 库
  Y002   YAML 语法错误
  Y003   YAML 根元素类型错误
  D001   主机重复定义
  G001   循环的组嵌套
  O001   孤儿主机（无所属组）
  E001   空组定义
  V001   可能未定义的变量
  C001   SSH 连接失败
  F000   文件读取错误
        """,
    )
    parser.add_argument("path", help="Inventory 文件或包含 Inventory 文件的目录")
    parser.add_argument("--check-connectivity", "-c", action="store_true",
                        help="执行 SSH 连通性预检")
    parser.add_argument("--format", "-f", choices=["text", "json"], default="text")
    parser.add_argument("--user", "-u", help="SSH 用户名 (默认: ANSIBLE_REMOTE_USER 或 root)")
    parser.add_argument("--key", "-k", help="SSH 私钥路径")
    args = parser.parse_args()

    validator = InventoryValidator(
        Path(args.path),
        check_connectivity=args.check_connectivity,
        user=args.user,
        key_file=args.key,
    )
    issues = validator.scan()
    report = validator.format_report(args.format)
    print(report)

    errors = sum(1 for i in issues if i.severity == "error")
    return min(errors, 1)  # 0=通过, 1=有错误


if __name__ == "__main__":
    sys.exit(main())
