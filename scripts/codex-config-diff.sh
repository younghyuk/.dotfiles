#!/usr/bin/env bash
# Compare the live Codex config (~/.codex/config.toml) against the tracked
# template (codex/.codex/config.template.toml), ignoring machine-managed state
# that Codex writes on its own (project trust, hook hashes, marketplace
# timestamps, app-managed mcp servers).
#
# Exit codes: 0 = in sync, 1 = drift found, 2 = error.

set -u

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEMPLATE="$DOTFILES_DIR/codex/.codex/config.template.toml"
LIVE="${1:-$HOME/.codex/config.toml}"

if [[ ! -f "$TEMPLATE" ]]; then
  echo "template missing: $TEMPLATE" >&2
  exit 2
fi
if [[ ! -f "$LIVE" ]]; then
  echo "live config missing: $LIVE" >&2
  exit 2
fi

python3 - "$TEMPLATE" "$LIVE" <<'PY'
import sys
import tomllib

TEMPLATE_PATH, LIVE_PATH = sys.argv[1], sys.argv[2]

# Machine-managed state Codex writes by itself; never compared.
DROP_TOP_LEVEL = {"notify", "projects", "hooks"}
DROP_TABLES = {("mcp_servers", "node_repl"), ("tui", "model_availability_nux")}
DROP_MARKETPLACE_FIELDS = {"last_updated", "last_revision"}


def load(path):
    with open(path, "rb") as f:
        return tomllib.load(f)


def strip(config):
    for key in DROP_TOP_LEVEL:
        config.pop(key, None)
    for parent, child in DROP_TABLES:
        if isinstance(config.get(parent), dict):
            config[parent].pop(child, None)
    marketplaces = config.get("marketplaces")
    if isinstance(marketplaces, dict):
        for name in list(marketplaces):
            entry = marketplaces[name]
            if not isinstance(entry, dict):
                continue
            if entry.get("source_type") == "local":
                del marketplaces[name]
                continue
            for field in DROP_MARKETPLACE_FIELDS:
                entry.pop(field, None)
    return config


def flatten(value, prefix=""):
    if isinstance(value, dict):
        items = {}
        for key, child in value.items():
            path = f"{prefix}.{key}" if prefix else key
            items.update(flatten(child, path))
        return items
    return {prefix: value}


template = flatten(strip(load(TEMPLATE_PATH)))
live = flatten(strip(load(LIVE_PATH)))

only_live = sorted(set(live) - set(template))
only_template = sorted(set(template) - set(live))
changed = sorted(k for k in set(live) & set(template) if live[k] != template[k])

if not (only_live or only_template or changed):
    print("codex config: live and template are in sync")
    sys.exit(0)

if only_live:
    print("only in live config (add to template if intentional):")
    for key in only_live:
        print(f"  + {key} = {live[key]!r}")
if only_template:
    print("only in template (apply to live config, or drop from template):")
    for key in only_template:
        print(f"  - {key} = {template[key]!r}")
if changed:
    print("different values (live vs template):")
    for key in changed:
        print(f"  ~ {key}: {live[key]!r} vs {template[key]!r}")
sys.exit(1)
PY
