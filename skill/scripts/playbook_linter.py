#!/usr/bin/env python3
"""
Ansible Playbook Linter - 静态分析工具
检测 Playbook/Role 中的常见反模式和潜在问题

用法:
    python3 playbook_linter.py <playbook_or_role_path> [--format json] [--strict]
    python3 playbook_linter.py playbooks/site.yml
    python3 playbook_linter.py roles/nginx --strict
    python3 playbook_linter.py . --format json > report.json

退出码: 0=通过, 1=有警告, 2=有错误, 4=严重问题 (可叠加)
"""

import argparse
import ast
import json
import os
import re
import sys
from pathlib import Path
from typing import Any

# ─── 严重级别定义 ──────────────────────────────────────
SEVERITY = {
    "info": {"level": 0, "symbol": "ℹ️", "exit_code": 0},
    "warning": {"level": 1, "symbol": "⚠️", "exit_code": 1},
    "error": {"level": 2, "symbol": "❌", "exit_code": 2},
    "critical": {"level": 3, "symbol": "🔴", "exit_code": 4},
}


class Issue:
    """表示一个检测到的问题"""

    def __init__(self, severity: str, rule_id: str, file: str,
                 line: int, message: str, suggestion: str = ""):
        self.severity = severity
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
        sym = SEVERITY.get(self.severity, {}).get("symbol", "?")
        return f"  {sym} [{self.rule_id}] {self.file}:{self.line} | {self.message}"


class PlaybookLinter:
    """Ansible Playbook 静态分析器"""

    def __init__(self, target_path: str, strict: bool = False):
        self.target = Path(target_path).resolve()
        self.strict = strict
        self.issues: list[Issue] = []
        # 统计
        self.stats = {
            "files_scanned": 0,
            "total_issues": 0,
            "by_severity": {k: 0 for k in SEVERITY},
        }

    # ─── 规则检测器 ─────────────────────────────────

    def _check_fqcn(self, filepath: Path, content: str):
        """R001: 检测是否使用了 FQCN（全限定集合名称）"""
        lines = content.split("\n")
        for i, line in enumerate(lines, 1):
            stripped = line.strip()
            # 匹配模块调用模式:  xxx.yyy: 或 xxx:
            if re.match(r"^\s{2,}(ansible\.builtin\.|community\.\w+\.\w+|[\w.]+\.\w+):", stripped):
                continue  # 已经是 FQCN
            # 检测短名称模块调用（缩进 >= 2 且以冒号结尾的模块名）
            match = re.match(r"^(\s{2,})(\w[\w-]*):$", stripped)
            if match and not stripped.startswith("name:") \
                    and not stripped.startswith("- name:") \
                    and not stripped.startswith("#") \
                    and not any(stripped.strip().startswith(kw) for kw in [
                        "when", "with_items", "loop", "tags", "register",
                        "notify", "become", "ignore_errors", "retries",
                        "delay", "until", "changed_when", "failed_when",
                        "delegate_to", "run_once", "connection", "vars",
                        "block", "rescue", "always", "listen",
                    ]):
                module_name = match.group(2)
                # 排除常见的非模块关键字
                skip_keywords = {
                    "block", "rescue", "always", "vars", "pre_tasks",
                    "post_tasks", "handlers", "roles", "tasks",
                    "environment", "args", "loop_control",
                }
                if module_name in skip_keywords or module_name.startswith("_"):
                    continue
                self.issues.append(Issue(
                    severity="warning" if not self.strict else "error",
                    rule_id="R001",
                    file=str(filepath),
                    line=i,
                    message=f"使用短名称模块 '{module_name}'，建议使用 FQCN",
                    suggestion=f"改为 'ansible.builtin.{module_name}' 或 'community.xxx.{module_name}'"
                ))

    def _check_hardcoded_passwords(self, filepath: Path, content: str):
        """S002/S003: 检测硬编码密码和密钥"""
        lines = content.split("\n")
        password_patterns = [
            r"(password\s*[:=]\s*['\"](?![{]|\$ANSIBLE_VAULT)[^'\"]+['\"])",
            r"(api_key\s*[:=]\s*['\"](?![{]|\$ANSIBLE_VAULT)[^'\"]{8,}['\"])",
            r"(secret\s*[:=]\s*['\"](?![{]|\$ANSIBLE_VAULT)[^'\"]{8,}['\"])",
            r"(token\s*[:=]\s*['\"](?![{]|\$ANSIBLE_VAULT)[^'\"]{8,}['\"])",
            r"(private_key\s*[:=]\s*['\"][^-][^'\"]+['\"])",
        ]
        for i, line in enumerate(lines, 1):
            for pattern in password_patterns:
                match = re.search(pattern, line, re.IGNORECASE)
                if match:
                    masked = match.group(1)[:20] + "..."
                    self.issues.append(Issue(
                        severity="critical",
                        rule_id="S002",
                        file=str(filepath),
                        line=i,
                        message=f"检测到可能的硬编码敏感信息: {masked}",
                        suggestion="使用 ansible-vault 加密或引用 vault 变量"
                    ))

    def _check_missing_task_names(self, filepath: Path, content: str):
        """T001: 检测缺少任务名称"""
        lines = content.split("\n")
        prev_line_was_module_call = False
        for i, line in enumerate(lines, 1):
            stripped = line.strip()
            # 模块调用行（缩进>=4 且以模块名: 结尾）
            if re.match(r"^\s{4,}\w[\w.-]+:\s*$", stripped) and \
                    not stripped.startswith("name:"):
                # 检查上一行是否是 name:
                if i >= 2:
                    prev = lines[i - 2].strip()
                    if not prev.startswith("name:"):
                        self.issues.append(Issue(
                            severity="error",
                            rule_id="T001",
                            file=str(filepath),
                            line=i,
                            message=f"任务缺少 'name' 属性: {stripped.rstrip(':')}",
                            suggestion="添加描述性的任务名称，例如 '- name: Install package'"
                        ))

    def _check_become_missing(self, filepath: Path, content: str):
        """P001: 检测需要特权但未使用 become 的操作"""
        privileged_patterns = [
            (r"\byum\b.*state=", "yum 包管理通常需要 root"),
            (r"\bapt\b.*state=", "apt 包管理通常需要 root"),
            (r"\bservice\b.*(started|stopped|restarted)", "服务管理通常需要 root"),
            (r"\bsystemd\b.*state=", "systemd 管理通常需要 root"),
            (r"dest:\s*/(etc|usr/sbin|opt)/", "写入系统目录通常需要 root"),
            (r"path:\s*/etc/", "修改 /etc 通常需要 root"),
        ]
        lines = content.split("\n")
        has_become = False
        become_lines = []
        for i, line in enumerate(lines, 1):
            if re.match(r"^\s*become:\s*(yes|true)\s*$", line):
                has_become = True
                become_lines.append(i)

        if not has_become:
            for i, line in enumerate(lines, 1):
                for pattern, reason in privileged_patterns:
                    if re.search(pattern, line):
                        # 检查是否在 block 内部或已有局部 become
                        context_start = max(0, i - 10)
                        context_block = "\n".join(lines[context_start:i])
                        if "become:" not in context_block:
                            self.issues.append(Issue(
                                severity="warning",
                                rule_id="P001",
                                file=str(filepath),
                                line=i,
                                message=f"可能需要特权提升的操作: {reason}",
                                suggestion="考虑添加 'become: yes' 或确认运行用户有足够权限"
                            ))
                            break

    def _check_changed_when_missing(self, filepath: Path, content: str):
        """C001: command/shell 模块缺少 changed_when 控制"""
        lines = content.split("\n")
        in_command_block = False
        command_indent = 0
        has_changed_when = False

        for i, line in enumerate(lines, 1):
            stripped = line.strip()

            # 检测 command/shell 模块开始
            cmd_match = re.match(
                r"^(\s+)(ansible\.builtin\.(command|shell))\b:", stripped
            )
            if cmd_match:
                in_command_block = True
                command_indent = len(cmd_match.group(1))
                has_changed_when = False
                continue

            if in_command_block:
                current_indent = len(line) - len(line.lstrip())
                # 如果缩进回退到等于或小于 command 的缩进，结束当前命令块
                if stripped and current_indent <= command_indent and not stripped.startswith("-"):
                    if not has_changed_when:
                        self.issues.append(Issue(
                            severity="warning",
                            rule_id="C001",
                            file=str(filepath),
                            line=i - 1,
                            message="command/shell 任务缺少 changed_when 声明",
                            suggestion="添加 'changed_when: false' (只读) 或条件表达式 (写操作)"
                        ))
                    in_command_block = False

                if re.match(r"^\s*changed_when:", stripped):
                    has_changed_when = True

    def _check_ignore_errors_abuse(self, filepath: Path, content: str):
        """E001: 滥用 ignore_errors: true"""
        lines = content.split("\n")
        for i, line in enumerate(lines, 1):
            if re.search(r"ignore_errors:\s*true", line):
                # 检查是否有 failed_when 作为替代
                context_start = max(0, i - 5)
                context_end = min(len(lines), i + 5)
                context = "\n".join(lines[context_start:context_end])
                if "failed_when:" not in context:
                    self.issues.append(Issue(
                        severity="warning",
                        rule_id="E001",
                        file=str(filepath),
                        line=i,
                        message="使用 ignore_errors: true 但没有 failed_when 定义",
                        suggestion="优先使用 failed_when 定义预期失败条件，或解释为何忽略所有错误"
                    ))

    def _check_shell_instead_of_module(self, filepath: Path, content: str):
        """M001: 使用 shell/command 而非专用模块"""
        shell_replacements = {
            r"cmd:\s*\w*(?:cp |copy )": "ansible.builtin.copy",
            r"cmd:\s*\w*(?:mkdir |mkdir -p )": "ansible.builtin.file (state=directory)",
            r"cmd:\s*\w*(?:chmod |chown )": "ansible.builtin.file (mode/owner)",
            r"cmd:\s*\w*(?:cat\s)": "ansible.builtin.copy 或 ansible.builtin.slurp",
            r"cmd:\s*\w*(?:rm\s|remove\s|delete\s)": "ansible.builtin.file (state=absent)",
            r"cmd:\s*\w*(?:systemctl\s|service\s)": "ansible.builtin.service / ansible.builtin.systemd",
            r"cmd:\s*\w*(?:apt-get |apt )": "ansible.builtin.apt",
            r"cmd:\s*\w*(?:yum install|dnf install)": "ansible.builtin.yum / ansible.builtin.dnf",
            r"cmd:\s*\w*(?:pip install)": "ansible.builtin.pip",
            r"cmd:\s*\w*(?:git clone)": "ansible.builtin.git",
            r"cmd:\s*\w*(?:curl\s|- wget\s)": "ansible.builtin.get_url 或 ansible.builtin.uri",
            r"cmd:\s*\w*(?:useradd |usermod |userdel)": "ansible.builtin.user",
            r"cmd:\s*\w*(?:crontab )": "ansible.builtin.cron",
            r"cmd:\s*\w*(?:ln -s)": "ansible.builtin.file (state=link)",
            r"cmd:\s*\w*(?:tar )": "ansible.builtin.unarchive",
            r"cmd:\s*\w*(?:sed\s|i\s)": "ansible.builtin.replace / ansible.builtin.lineinfile",
            r"cmd:\s*\w*(?:touch\s)": "ansible.builtin.file (state=touch)",
        }
        lines = content.split("\n")
        for i, line in enumerate(lines, 1):
            for pattern, replacement in shell_replacements.items():
                if re.search(pattern, line, re.IGNORECASE):
                    self.issues.append(Issue(
                        severity="info",
                        rule_id="M001",
                        file=str(filepath),
                        line=i,
                        message=f"可使用 Ansible 模块替代 shell 命令",
                        suggestion=f"建议替换为: {replacement}"
                    ))

    def _check_no_log_missing(self, filepath: Path, content: str):
        """L001: 处理敏感数据时缺少 no_log"""
        sensitive_indicators = ["password", "secret", "token", "api_key", "private_key"]
        lines = content.split("\n")
        for i, line in enumerate(lines, 1):
            stripped_lower = line.lower()
            for indicator in sensitive_indicators:
                if indicator in stripped_lower and (
                    ":" in line and ("{{" in line or "'" in line or '"' in line)
                ):
                    # 向后搜索 no_log
                    search_range = min(len(lines), i + 8)
                    context = "\n".join(lines[i:search_range])
                    if "no_log" not in context:
                        self.issues.append(Issue(
                            severity="error" if self.strict else "warning",
                            rule_id="L001",
                            file=str(filepath),
                            line=i,
                            message=f"包含敏感信息 ('{indicator}') 但未设置 no_log",
                            suggestion="添加 'no_log: true' 以防止日志泄露敏感信息"
                        ))
                        break

    def _check_untagged_tasks(self, filepath: Path, content: str):
        """G001: 大型 Playbook 中任务缺少标签"""
        task_count = sum(1 for l in content.split("\n") if re.match(r"^\s+- name:", l))
        tagged_count = sum(1 for l in content.split("\n") if re.search(r"^\s+tags:", l))

        if task_count > 5 and tagged_count < task_count * 0.5:
            self.issues.append(Issue(
                severity="info",
                rule_id="G001",
                file=str(filepath),
                line=1,
                message=f"{task_count} 个任务中仅 {tagged_count} 个有 tags ({tagged_count * 100 // task_count}%)",
                suggestion="为任务添加标签以支持选择性执行 (--tags)"
            ))

    # ─── 主分析流程 ─────────────────────────────────

    def scan_file(self, filepath: Path) -> list[Issue]:
        """扫描单个文件"""
        if filepath.suffix not in {".yml", ".yaml"}:
            return []

        try:
            content = filepath.read_text(encoding="utf-8")
        except Exception as e:
            self.issues.append(Issue(
                severity="error",
                rule_id="F000",
                file=str(filepath),
                line=0,
                message=f"无法读取文件: {e}"
            ))
            return []

        self.stats["files_scanned"] += 1

        # 运行所有规则检查
        self._check_fqcn(filepath, content)
        self._check_hardcoded_passwords(filepath, content)
        self._check_missing_task_names(filepath, content)
        self._check_become_missing(filepath, content)
        self._check_changed_when_missing(filepath, content)
        self._check_ignore_errors_abuse(filepath, content)
        self._check_shell_instead_of_module(filepath, content)
        self._check_no_log_missing(filepath, content)
        self._check_untagged_tasks(filepath, content)

        return [i for i in self.issues if i.file == str(filepath)]

    def run(self) -> list[Issue]:
        """执行完整的 lint 扫描"""
        if self.target.is_file():
            self.scan_file(self.target)
        elif self.target.is_dir():
            # 递归查找所有 YAML 文件
            for yaml_file in self.target.rglob("**/*.yml"):
                # 跳过隐藏目录和常见排除路径
                parts = yaml_file.parts
                if any(p.startswith(".") or p in {"node_modules", ".git", "__pycache__"} for p in parts):
                    continue
                self.scan_file(yaml_file)
            for yaml_file in self.target.rglob("**/*.yaml"):
                parts = yaml_file.parts
                if any(p.startswith(".") or p in {"node_modules", ".git", "__pycache__"} for p in parts):
                    continue
                self.scan_file(yaml_file)
        else:
            print(f"❌ 路径不存在: {self.target}", file=sys.stderr)
            sys.exit(1)

        # 更新统计
        for issue in self.issues:
            sev = issue.severity
            self.stats["total_issues"] += 1
            if sev in self.stats["by_severity"]:
                self.stats["by_severity"][sev] += 1

        return self.issues

    def format_report(self, output_format: str = "text") -> str:
        """格式化输出报告"""
        if output_format == "json":
            return json.dumps({
                "target": str(self.target),
                "statistics": self.stats,
                "issues": [i.to_dict() for i in self.issues],
            }, indent=2, ensure_ascii=False)

        # Text 格式
        lines = []
        lines.append(f"\n{'='*70}")
        lines.append(f"  📋 Ansible Playbook Linter 报告")
        lines.append(f"  目标: {self.target}")
        lines.append(f"  扫描文件数: {self.stats['files_scanned']}")
        lines.append(f"  发现问题总数: {self.stats['total_issues']}")
        lines.append(f"{'='*70}")

        # 按严重程度分组显示
        for severity in ["critical", "error", "warning", "info"]:
            group = [i for i in self.issues if i.severity == severity]
            if group:
                sym = SEVERITY[severity]["symbol"]
                lines.append(f"\n{'─'*50}")
                lines.append(f"  {sym} {severity.upper()} ({len(group)} 个)")
                lines.append(f"{'─'*50}")
                for issue in sorted(group, key=lambda x: x.file):
                    lines.append(str(issue))
                    if issue.suggestion:
                        lines.append(f"     💡 {issue.suggestion}")

        lines.append(f"\n{'='*70}")
        summary_parts = []
        for sev, count in self.stats["by_severity"].items():
            if count > 0:
                sym = SEVERITY[sev]["symbol"]
                summary_parts.append(f"  {sym} {sev}: {count}")
        if summary_parts:
            lines.append("  汇总:")
            lines.extend(summary_parts)
        else:
            lines.append("  ✅ 未发现任何问题！代码质量优秀。")
        lines.append(f"{'='*70}\n")

        return "\n".join(lines)


def main():
    parser = argparse.ArgumentParser(
        description="Ansible Playbook 静态分析工具 - 检测反模式和潜在问题",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
规则 ID 说明:
  R001   使用短名称模块（建议用 FQCN）
  S002   硬编码密码/密钥
  T001   任务缺少 name 属性
  P001   可能缺少特权提升 (become)
  C001   command/shell 缺少 changed_when
  E001   滥用 ignore_errors
  M001   可用专用模块替代 shell 命令
  L001   敏感数据缺少 no_log
  G001   任务缺少标签（大型 Playbook）
  F000   文件读取错误
        """,
    )
    parser.add_argument("path", help="Playbook 文件、Role 目录或项目根目录")
    parser.add_argument("--format", "-f", choices=["text", "json"], default="text",
                        help="输出格式 (默认: text)")
    parser.add_argument("--strict", "-s", action="store_true",
                        help="严格模式：将 warning 升级为 error")
    args = parser.parse_args()

    linter = PlaybookLinter(args.path, strict=args.strict)
    issues = linter.run()
    report = linter.format_report(args.format)
    print(report)

    if args.format == "json":
        return 0

    # 根据最高严重程度决定退出码
    exit_code = 0
    for issue in issues:
        code = SEVERITY.get(issue.severity, {}).get("exit_code", 0)
        exit_code = max(exit_code, code)

    return exit_code


if __name__ == "__main__":
    sys.exit(main())
