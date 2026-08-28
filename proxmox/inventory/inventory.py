#!/usr/bin/env python3

import json
import subprocess
import sys
from pathlib import Path

TOFU_ROOT = Path(__file__).resolve().parent.parent.parent / "infra"
STATES = ["core", "compute"]


def tofu_output(state: str) -> dict:
    result = subprocess.run(
        ["tofu", "output", "-json", "ansible_inventory"],
        cwd=TOFU_ROOT / state,
        capture_output=True,
        text=True,
        check=True,
    )

    return json.loads(result.stdout)


def get_inventory() -> dict:
    hosts = {}

    for state in STATES:
        state_hosts = tofu_output(state)

        for hostname, config in state_hosts.items():
            if hostname in hosts:
                raise RuntimeError(
                    f"Duplicate host '{hostname}' found in state '{state}'"
                )

            hosts[hostname] = config

    inventory = {
        "_meta": {
            "hostvars": {}
        },
        "all": {
            # uncomment if you want to have
            # "hosts": list(hosts.keys()),
            "children": []
        }
    }

    for hostname, config in hosts.items():
        groups = config.pop("groups", [])
        vars = config.pop("vars", {})

        inventory["_meta"]["hostvars"][hostname] = config

        for group in groups:
            if group not in inventory:
                inventory[group] = {
                    "hosts": []
                }

            inventory[group]["hosts"].append("host_" + hostname)
            inventory[group]["vars"] = vars

            if group not in inventory["all"]["children"]:
                inventory["all"]["children"].append(group)

    return inventory


def main():
    if "--list" in sys.argv:
        print(json.dumps(get_inventory(), indent=2))
    elif "--host" in sys.argv:
        print("{}")
    else:
        print(json.dumps(get_inventory(), indent=2))


if __name__ == "__main__":
    main()
