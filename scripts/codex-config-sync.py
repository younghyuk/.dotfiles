#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = ["tomlkit==0.13.3"]
# ///
"""Reconcile portable Codex settings while preserving machine-managed state."""

from __future__ import annotations

import argparse
import os
import shutil
import stat
import sys
import tempfile
from collections.abc import MutableMapping
from copy import deepcopy
from pathlib import Path
from typing import Any

from tomlkit import dumps, parse, table
from tomlkit.container import Container

# Codex/App-owned values are intentionally not copied between machines.
PRESERVE_TOP_LEVEL = (
    "notify",
    "projects",
    "hooks",
    "notice",
    "shell_environment_policy",
)
PRESERVE_MCP_SERVERS = ("node_repl", "computer-use")
PRESERVE_TUI_KEYS = ("model_availability_nux",)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--template", type=Path, required=True)
    parser.add_argument("--live", type=Path, required=True)
    parser.add_argument(
        "--check",
        action="store_true",
        help="report drift without changing the live config",
    )
    return parser.parse_args()


def load_document(path: Path) -> Container:
    try:
        return parse(path.read_text(encoding="utf-8"))
    except Exception as error:  # tomlkit exposes several parse error subclasses
        raise RuntimeError(f"invalid TOML: {path}: {error}") from error


def ensure_table(document: Container, key: str) -> MutableMapping[str, Any]:
    current = document.get(key)
    if current is None:
        document[key] = table()
        current = document[key]
    if not isinstance(current, MutableMapping):
        raise TypeError(f"expected table at {key}")
    return current


def preserve_machine_state(template: Container, live: Container) -> Container:
    result = deepcopy(template)

    for key in PRESERVE_TOP_LEVEL:
        if key in live:
            result[key] = deepcopy(live[key])

    live_marketplaces = live.get("marketplaces")
    if isinstance(live_marketplaces, MutableMapping):
        local_entries = {
            name: entry
            for name, entry in live_marketplaces.items()
            if isinstance(entry, MutableMapping) and entry.get("source_type") == "local"
        }
        if local_entries:
            target = ensure_table(result, "marketplaces")
            for name, entry in local_entries.items():
                target[name] = deepcopy(entry)

    live_mcp_servers = live.get("mcp_servers")
    if isinstance(live_mcp_servers, MutableMapping):
        target = ensure_table(result, "mcp_servers")
        for name in PRESERVE_MCP_SERVERS:
            if name in live_mcp_servers:
                target[name] = deepcopy(live_mcp_servers[name])

    live_tui = live.get("tui")
    if isinstance(live_tui, MutableMapping):
        preserved = [key for key in PRESERVE_TUI_KEYS if key in live_tui]
        if preserved:
            target = ensure_table(result, "tui")
            for key in preserved:
                target[key] = deepcopy(live_tui[key])

    return result


def flatten(value: Any, prefix: str = "") -> dict[str, Any]:
    if isinstance(value, dict):
        flattened: dict[str, Any] = {}
        for key, child in value.items():
            path = f"{prefix}.{key}" if prefix else str(key)
            flattened.update(flatten(child, path))
        return flattened
    return {prefix: value}


def report_drift(expected: Container, actual: Container) -> None:
    expected_flat = flatten(expected.unwrap())
    actual_flat = flatten(actual.unwrap())
    expected_keys = set(expected_flat)
    actual_keys = set(actual_flat)

    print("codex config drift detected:")
    for key in sorted(expected_keys - actual_keys):
        print(f"  add:    {key}")
    for key in sorted(actual_keys - expected_keys):
        print(f"  remove: {key}")
    for key in sorted(expected_keys & actual_keys):
        if expected_flat[key] != actual_flat[key]:
            print(f"  change: {key}")


def atomic_write(path: Path, content: str, mode: int) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    descriptor, temporary_name = tempfile.mkstemp(
        prefix=f".{path.name}.", suffix=".tmp", dir=path.parent
    )
    temporary = Path(temporary_name)
    try:
        with os.fdopen(descriptor, "w", encoding="utf-8") as handle:
            handle.write(content)
        os.chmod(temporary, mode)
        os.replace(temporary, path)
    finally:
        if temporary.exists():
            temporary.unlink()


def main() -> int:
    args = parse_args()
    if not args.template.is_file():
        print(f"template missing: {args.template}", file=sys.stderr)
        return 2

    try:
        template = load_document(args.template)
        if args.live.exists():
            live = load_document(args.live)
            expected = preserve_machine_state(template, live)
        else:
            live = None
            expected = deepcopy(template)
    except (RuntimeError, TypeError) as error:
        print(error, file=sys.stderr)
        return 2

    if live is not None and expected.unwrap() == live.unwrap():
        print("codex config: live and template are in sync")
        return 0

    if args.check:
        if live is None:
            print(f"codex config missing: {args.live}")
        else:
            report_drift(expected, live)
        return 1

    mode = 0o600
    if live is not None:
        mode = stat.S_IMODE(args.live.stat().st_mode)
        backup = args.live.with_name(f"{args.live.name}.before-dotfiles-sync.bak")
        shutil.copy2(args.live, backup)
        os.chmod(backup, mode)
        print(f"codex config backup: {backup}")

    rendered = dumps(expected)
    if not rendered.endswith("\n"):
        rendered += "\n"
    atomic_write(args.live, rendered, mode)
    print(f"codex config synchronized: {args.live}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
