#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Ansible Custom Module/Plugin Scaffold Generator

Generates production-ready scaffolding for Ansible custom modules,
plugins (filter/lookup/inventory/callback), and Molecule test skeletons.

Usage:
    python3 module_generator.py deploy_app --type action
    python3 module_generator.py json_pretty --type filter
    python3 module_generator.py aws_instances --type inventory
    python3 module_generator.py slack_notify --type callback
"""

import argparse
import os
from pathlib import Path
from datetime import datetime


MODULE_TEMPLATES = {
    "action": {"description": "Action Module"},
    "filter": {"description": "Filter Plugin"},
    "lookup": {"description": "Lookup Plugin"},
    "inventory": {"description": "Inventory Plugin"},
    "callback": {"description": "Callback Plugin"},
}


def generate_action_module(name, output_dir):
    """Generate Action module scaffold with Molecule tests."""
    files = []
    
    mod_lines = []
    mod_lines.append("#!/usr/bin/python3")
    mod_lines.append("# -*- coding: utf-8 -*-")
    mod_lines.append("")
    mod_lines.append("DOCUMENTATION = r\"\"\"")
    mod_lines.append("---")
    mod_lines.append("module: %s" % name)
    mod_lines.append("short_description: Custom %s module" % name)
    mod_lines.append("description:")
    mod_lines.append("     Auto-generated module scaffold")
    mod_lines.append("options:")
    mod_lines.append("  name:")
    mod_lines.append("    description: Resource name")
    mod_lines.append("    required: true")
    mod_lines.append("    type: str")
    mod_lines.append("  state:")
    mod_lines.append("    description: Desired state")
    mod_lines.append("    choices: [present, absent]")
    mod_lines.append("    default: present")
    mod_lines.append("    type: str")
    mod_lines.append("\"\"\"")
    mod_lines.append("")
    mod_lines.append("EXAMPLES = r\"\"\"")
    mod_lines.append("- name: Manage resource")
    mod_lines.append("  %s:" % name)
    mod_lines.append("    name: my_resource")
    mod_lines.append("    state: present")
    mod_lines.append("\"\"\"")
    mod_lines.append("")
    mod_lines.append("RETURN = r\"\"\"")
    mod_lines.append("name:")
    mod_lines.append("  description: Resource name")
    mod_lines.append("  type: str")
    mod_lines.append("  returned: always")
    mod_lines.append("changed:")
    mod_lines.append("  description: Whether changes were made")
    mod_lines.append("  type: bool")
    mod_lines.append("  returned: always")
    mod_lines.append("\"\"\"")
    mod_lines.append("")
    mod_lines.append("from ansible.module_utils.basic import AnsibleModule")
    mod_lines.append("")
    mod_lines.append("")
    mod_lines.append("def main():")
    mod_lines.append("    module_args = dict(")
    mod_lines.append("        name=dict(type=str, required=True),")
    mod_lines.append("        state=dict(type=str, default=\"present\", choices=[\"present\", \"absent\"]),")
    mod_lines.append("    )")
    mod_lines.append("    module = AnsibleModule(")
    mod_lines.append("        argument_spec=module_args,")
    mod_lines.append("        supports_check_mode=True,")
    mod_lines.append("    )")
    mod_lines.append("")
    mod_lines.append("    result = {\"changed\": False}")
    mod_lines.append("    name_param = module.params[\"name\"]")
    mod_lines.append("    desired_state = module.params[\"state\"]")
    mod_lines.append("")
    mod_lines.append("    # TODO: Implement business logic here")
    mod_lines.append("    if desired_state == \"absent\":")
    mod_lines.append("        # TODO: Delete logic")
    mod_lines.append("        result[\"changed\"] = True")
    mod_lines.append("    else:")
    mod_lines.append("        # TODO: Create/update logic")
    mod_lines.append("        result[\"changed\"] = True")
    mod_lines.append("")
    mod_lines.append("    result[\"name\"] = name_param")
    mod_lines.append("    module.exit_json(**result)")
    mod_lines.append("")
    mod_lines.append("")
    mod_lines.append("if __name__ == \"__main__\":")
    mod_lines.append("    main()")

    mod_code = "\n".join(mod_lines)
    mod_path = output_dir / ("%s.py" % name)
    mod_path.write_text(mod_code, encoding="utf-8")
    files.append(mod_path)

    # Molecule test skeleton
    molecule_dir = output_dir / "tests" / "molecule" / "default"
    molecule_dir.mkdir(parents=True, exist_ok=True)
    
    converge_yml = """---
- name: Converge
  hosts: all
  tasks:
    - name: Apply role
      include_role:
        name: %s
""" % name
    
    verify_yml = """---
- name: Verify
  hosts: all
  tasks:
"""
    
    verify_py = """import os


def test_%s_module(host):
    \"\"\"Verify the %s module works.\"\"\"
    res = host.ansible(\"%s\", {\"name\": \"test_item\", \"state\": \"present\"})
    assert res is not None
""" % (name, name, name)

    (molecule_dir / "converge.yml").write_text(converge_yml, encoding="utf-8")
    (molecule_dir / "verify.yml").write_text(verify_yml, encoding="utf-8")
    (molecule_dir / ("test_%s.py" % name)).write_text(verify_py, encoding="utf-8")
    files.extend([molecule_dir / "converge.yml", molecule_dir / "verify.yml"])
    
    return files


def generate_filter_plugin(name, output_dir):
    """Generate Filter plugin scaffold."""
    lines = [
        "#!/usr/bin/python3",
        "# -*- coding: utf-8 -*-",
        "",
        "class FilterModule(object):",
        '    """Custom Jinja2 filters for %s."""' % name,
        "",
        "    def filters(self):",
        "        return {%s: self.do_%s}" % (name, name),
        "",
        "    def do_%s(self, value, **kwargs):" % name,
        '        """Filter description."""',
        "        # TODO: Implement filter logic",
        "        if isinstance(value, list):",
        "            return [{item: True} for item in value]",
        "        return value",
    ]
    
    code = "\n".join(lines)
    filepath = output_dir / f"{name}.py"
    filepath.write_text(code, encoding="utf-8")
    return [filepath]


def generate_lookup_plugin(name, output_dir):
    """Generate Lookup plugin scaffold."""
    lines = [
        "#!/usr/bin/python3",
        "# -*- coding: utf-8 -*-",
        "",
        "from ansible.plugins.lookup import LookupBase",
        "",
        "",
        "class LookupModule(LookupBase):",
        '    """Custom lookup plugin: %s."""' % name,
        "",
        "    def run(self, terms, variables=None, **kwargs):",
        '        """Execute lookup operation."""',
        "        results = []",
        "        for term in terms:",
        "            # TODO: Implement actual lookup logic",
        "            results.append(term)",
        "        return results",
    ]
    
    code = "\n".join(lines)
    filepath = output_dir / f"{name}.py"
    filepath.write_text(code, encoding="utf-8")
    return [filepath]


def generate_inventory_plugin(name, output_dir):
    """Generate Inventory plugin scaffold."""
    
    doc_content = """plugin: %s
short_description: Dynamic inventory for %s
description:
 - Auto-generated inventory plugin
options:
  api_url:
    description: API endpoint URL
    required: true
    type: str
  cache_timeout:
    description: Cache timeout in seconds
    required: false
    default: 600
    type: int
author:
 - auto-generated
""" % (name, name)

    example_content = """# inventory.%s.yml
plugin: %s
api_url: https://api.example.com/v1/hosts
cache_timeout: 300
""" % (name, name)

    py_content = """#!/usr/bin/python3
# -*- coding: utf-8 -*-

from ansible.plugins.inventory import BaseInventoryPlugin

DISPLAY = __import__("ansible.utils.display", fromlist=["Display"]).Display()


class InventoryModule(BaseInventoryPlugin):
    NAME = "%s"

    def verify_file(self, path):
        valid = super().verify_file(path)
        if valid:
            valid = path.endswith(("%s.yml", "%s.yaml")) and "%s" in path
            if valid:
                DISPLAY.vv("Valid inventory source: %%s" %% path)
        return valid

    def parse(self, inventory, loader, path, cache=True):
        super().parse(inventory, loader, path, cache)
        self._read_config_data(path)

        # TODO: Fetch data from your source API
        data = {
            "_meta": {
                "hostvars": {}
            },
            "all": {
                "children": {
                    "group1": {
                        "hosts": {},
                        "vars": {}
                    }
                },
                "vars": {}
            }
        }

        # TODO: Populate inventory with real data
        self.inventory.add_group("all")

    def _build_cache_key(self, path):
        return "inv_%s_%%s" %% (self.NAME.replace("-", "_"), hash(path))
""" % (name, name, name, name)

    doc_path = output_dir / ("%s.%s.yml" % (name, name))
    doc_path.write_text(doc_content, encoding="utf-8")
    
    ex_path = output_dir / ("inventory.%s.yml.example" % name)
    ex_path.write_text(example_content, encoding="utf-8")
    
    py_path = output_dir / f"{name}.py"
    py_path.write_text(py_content, encoding="utf-8")
    
    return [doc_path, ex_path, py_path]


def generate_callback_plugin(name, output_dir):
    """Generate Callback plugin scaffold."""
    lines = [
        "#!/usr/bin/python3",
        "# -*- coding: utf-8 -*-",
        "",
        "from datetime import datetime, timezone",
        "from ansible.plugins.callback import CallbackBase",
        "",
        "",
        "class CallbackModule(CallbackBase):",
        "    CALLBACK_VERSION = 2.0",
        '    CALLBACK_TYPE = "stdout"',
        '    CALLBACK_NAME = "%s"' % name,
        "    CALLBACK_NEEDS_WHITELIST = False",
        "",
        "    def v2_playbook_on_start(self, playbook):",
        "        self.start_time = datetime.now(timezone.utc).timestamp()",
        '        self._display.banner("[%s] Playbook Started")' % name.upper(),
        "",
        "    def v2_playbook_on_stats(self, stats):",
        '        self._display.banner("Playbook Complete")',
        "        for h in sorted(stats.keys()):",
        "            s = stats[h]",
        '            print("  %-20s ok=%-6d changed=%-8d unreachable=%-4d failed=%-4d" % (',
        '                  h, s.get("ok",0), s.get("changed",0), s.get("unreachable",0), s.get("failed",0)))',
        "",
        "    def v2_runner_on_ok(self, result):",
        "        h = result._host.name",
        "        t = result._task.name or result._task.action",
        '        if result._result.get("changed"):',
        '            print("  [CHANGED] %s :: %s" % (h, t))',
        "        else:",
        '            print("  [OK]      %s :: %s" % (h, t))',
        "",
        "    def v2_runner_on_failed(self, result, ignore_errors=False):",
        "        h = result._host.name",
        "        t = result._task.name or result._task.action",
        '        e = str(result._result.get("msg", ""))[:80]',
        '        print("  [FAILED]  %s :: %s" % (h, t))',
        '        print("       -> %s" % e)',
        "",
        "    def v2_runner_on_unreachable(self, result):",
        '        print("  [UNREACHABLE] %s" % result._host.name)',
        "",
        "    def v2_runner_on_skipped(self, result):",
        "        h = result._host.name",
        "        t = result._task.name or result._task.action",
        '        r = result._result.get("skip_reason", "")',
        '        m = "  [SKIPPED]  %s :: %s" % (h, t)',
        "        if r:",
        '            m += " - %s" % r',
        "        print(m)",
    ]

    code = "\n".join(lines)
    filepath = output_dir / f"{name}.py"
    filepath.write_text(code, encoding="utf-8")
    return [filepath]


def main():
    parser = argparse.ArgumentParser(
        description="Ansible Custom Module/Plugin Scaffold Generator",
    )
    parser.add_argument("name", help="Module/plugin name (snake_case)")
    parser.add_argument("--type", "-t", choices=list(MODULE_TEMPLATES.keys()),
                        default="action", help="Type to generate (default: action)")
    parser.add_argument("--output-dir", "-o", help="Output directory")

    args = parser.parse_args()

    if args.output_dir:
        output_dir = Path(args.output_dir).resolve()
    else:
        output_dir = Path.cwd()
        type_map = {
            "action": "library",
            "filter": "plugins/filter",
            "lookup": "plugins/lookup",
            "inventory": "plugins/inventory",
            "callback": "plugins/callback",
        }
        output_dir = output_dir / type_map[args.type]

    output_dir.mkdir(parents=True, exist_ok=True)

    info = MODULE_TEMPLATES[args.type]
    sep = "=" * 60
    print("\n%s" % sep)
    print("  Ansible %s Generator" % info["description"])
    print("  Name: %s" % args.name)
    print("  Type: %s" % args.type)
    print("  Output: %s" % output_dir)
    print("%s\n" % sep)

    generators = {
        "action": generate_action_module,
        "filter": generate_filter_plugin,
        "lookup": generate_lookup_plugin,
        "inventory": generate_inventory_plugin,
        "callback": generate_callback_plugin,
    }

    created = generators[args.type](args.name, output_dir)

    print("Success! Created %d file(s):\n" % len(created))
    for f in created:
        rel = f.relative_to(output_dir.parent)
        sz = f.stat().st_size
        print("  %s (%d bytes)" % (rel, sz))

    print("\nNext steps:")
    print("  1. Edit generated code and implement business logic")
    print("  2. Test with Molecule: cd tests/molecule/default && molecule test")
    if args.type != "action":
        print("  3. Place plugins in the right directory:")
        print("     Project-level: plugins/%s/" % args.type)
        print("     Global-level: ~/.ansible/plugins/%s/" % args.type)


if __name__ == "__main__":
    main()
