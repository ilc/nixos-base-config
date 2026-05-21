"""slime-model: tiny package manager for slime's llama-server GGUFs.

Manages /var/lib/llama-server/registry.json (model metadata) and
/var/lib/llama-server/active (which one is loaded). Generates pi's
models.json from the registry on demand.

Sudo is used internally for writes to /var/lib/llama-server/* and for
systemctl restart. User must be in wheel (NOPASSWD assumed).
"""

from __future__ import annotations

import argparse
import json
import subprocess
import sys
import tempfile
import time
import urllib.request
from pathlib import Path

MODELS_DIR = Path("/var/lib/llama-server/models")
REGISTRY = Path("/var/lib/llama-server/registry.json")
ACTIVE = Path("/var/lib/llama-server/active")
SERVICE = "llama-server.service"
HEALTH_URL = "http://localhost:8000/v1/models"
OWNER = "llama-server:llama-server"


# ----- low-level helpers -----

def sudo(*cmd: str, check: bool = True) -> subprocess.CompletedProcess:
    return subprocess.run(["sudo", *cmd], check=check)


def load_registry() -> dict:
    if not REGISTRY.exists():
        return {}
    text = REGISTRY.read_text().strip()
    if not text:
        return {}
    return json.loads(text)


def save_registry(reg: dict) -> None:
    with tempfile.NamedTemporaryFile("w", delete=False, dir="/tmp", suffix=".json") as f:
        json.dump(reg, f, indent=2, sort_keys=True)
        f.write("\n")
        tmp = Path(f.name)
    sudo("mkdir", "-p", str(REGISTRY.parent))
    sudo("mv", str(tmp), str(REGISTRY))
    sudo("chown", OWNER, str(REGISTRY))
    sudo("chmod", "0644", str(REGISTRY))


def get_active() -> str | None:
    if not ACTIVE.exists():
        return None
    return ACTIVE.read_text().strip() or None


def set_active(name: str) -> None:
    with tempfile.NamedTemporaryFile("w", delete=False, dir="/tmp") as f:
        f.write(name)
        tmp = Path(f.name)
    sudo("mv", str(tmp), str(ACTIVE))
    sudo("chown", OWNER, str(ACTIVE))
    sudo("chmod", "0644", str(ACTIVE))


def wait_for_ready(timeout: int = 180) -> float:
    t0 = time.time()
    while time.time() - t0 < timeout:
        try:
            with urllib.request.urlopen(HEALTH_URL, timeout=2) as r:
                r.read()
            return time.time() - t0
        except Exception:
            time.sleep(2)
    raise TimeoutError(f"service not ready after {timeout}s")


# ----- commands -----

def cmd_list(args: argparse.Namespace) -> None:
    reg = load_registry()
    active = get_active()
    if not reg:
        print("(no models registered)")
        return
    width = max(len(k) for k in reg) + 1
    for name, meta in sorted(reg.items()):
        marker = "*" if name == active else " "
        file_ok = (MODELS_DIR / meta["file"]).exists()
        status = "" if file_ok else "  [file missing]"
        ctx_str = f"ctx={meta.get('ctx', '?')}"
        print(f"{marker} {name:<{width}} {ctx_str:<14} {meta.get('label', '')}{status}")


def cmd_status(args: argparse.Namespace) -> None:
    active = get_active()
    print(f"Active : {active or '(none)'}")
    r = subprocess.run(["systemctl", "is-active", SERVICE], capture_output=True, text=True)
    print(f"Service: {r.stdout.strip()}")
    try:
        with urllib.request.urlopen(HEALTH_URL, timeout=2) as resp:
            data = json.load(resp)
            for m in data.get("data", []):
                meta = m.get("meta", {})
                print(f"Loaded : {m.get('id', '?')} (n_ctx={meta.get('n_ctx', '?')})")
    except Exception as e:
        print(f"Loaded : (not reachable: {e})")


def cmd_register(args: argparse.Namespace) -> None:
    src = Path(args.file)
    if not src.is_absolute():
        src = MODELS_DIR / src
    if not src.exists():
        sys.exit(f"File not found: {src}")
    reg = load_registry()
    if args.name in reg and not args.force:
        sys.exit(f"'{args.name}' already registered. Use --force to overwrite or 'set' to update fields.")
    entry = {
        "file": src.name,
        "ctx": args.ctx,
        "label": args.label or args.name,
    }
    if args.hf_repo:
        entry["hf_repo"] = args.hf_repo
    if args.reasoning:
        entry["reasoning"] = True
    reg[args.name] = entry
    save_registry(reg)
    print(f"Registered {args.name}: {src.name} (ctx={args.ctx})")


def cmd_set(args: argparse.Namespace) -> None:
    reg = load_registry()
    if args.name not in reg:
        sys.exit(f"Unknown model: {args.name}")
    entry = reg[args.name]
    if args.ctx is not None:
        entry["ctx"] = args.ctx
    if args.label is not None:
        entry["label"] = args.label
    if args.reasoning is True:
        entry["reasoning"] = True
    if args.no_reasoning is True:
        entry.pop("reasoning", None)
    reg[args.name] = entry
    save_registry(reg)
    print(f"Updated {args.name}: {entry}")
    if args.name == get_active():
        print(f"(note: '{args.name}' is active; run 'slime-model use {args.name}' to apply new settings)")


def cmd_fetch(args: argparse.Namespace) -> None:
    from huggingface_hub import snapshot_download

    name = args.name
    if name is None:
        # derive default name from repo: "unsloth/Qwen3.6-35B-A3B-MTP-GGUF" → "qwen3.6-35b-a3b-mtp"
        tail = args.repo.split("/")[-1]
        tail = tail.removesuffix("-GGUF").removesuffix("-gguf")
        name = tail.lower()
    if name in load_registry() and not args.force:
        sys.exit(f"'{name}' already registered. Pick a different --name, or use --force.")

    pattern = f"*{args.quant}*"
    label = args.label or name

    cache_root = Path.home() / ".cache" / "slime-model"
    cache_root.mkdir(parents=True, exist_ok=True)

    with tempfile.TemporaryDirectory(dir=cache_root) as tmp:
        print(f"Downloading {args.repo} (pattern: {pattern})...")
        snapshot_download(
            repo_id=args.repo,
            allow_patterns=[pattern],
            local_dir=tmp,
        )
        ggufs = sorted(Path(tmp).rglob("*.gguf"))
        if not ggufs:
            sys.exit(f"No GGUF matched pattern '{pattern}' in {args.repo}")
        if len(ggufs) > 1 and not args.preserve_name:
            sys.exit(f"Multiple GGUFs matched; pass --preserve-name and pick later: {[g.name for g in ggufs]}")
        src = ggufs[0]
        target_name = src.name if args.preserve_name else f"{name}.gguf"
        dst = MODELS_DIR / target_name
        print(f"Installing as {dst}")
        sudo("mkdir", "-p", str(MODELS_DIR))
        sudo("mv", str(src), str(dst))
        sudo("chown", OWNER, str(dst))
        sudo("chmod", "0644", str(dst))

    reg = load_registry()
    entry = {
        "file": target_name,
        "ctx": args.ctx,
        "label": label,
        "hf_repo": args.repo,
        "hf_quant": args.quant,
    }
    if args.reasoning:
        entry["reasoning"] = True
    reg[name] = entry
    save_registry(reg)
    print(f"Registered {name}. Activate with: slime-model use {name}")


def cmd_use(args: argparse.Namespace) -> None:
    reg = load_registry()
    if args.name not in reg:
        sys.exit(f"Unknown model: {args.name}. Try: slime-model list")
    path = MODELS_DIR / reg[args.name]["file"]
    if not path.exists():
        sys.exit(f"Model file missing: {path}")
    set_active(args.name)
    print(f"Active = {args.name}, restarting service...")
    sudo("systemctl", "restart", SERVICE)
    try:
        elapsed = wait_for_ready()
        print(f"Ready in {elapsed:.1f}s")
    except TimeoutError as e:
        sys.exit(f"Service didn't come up: {e}\nCheck journalctl -u {SERVICE}")


def cmd_remove(args: argparse.Namespace) -> None:
    reg = load_registry()
    if args.name not in reg:
        sys.exit(f"Unknown model: {args.name}")
    if args.name == get_active():
        sys.exit(f"Cannot remove active model '{args.name}'. Switch first with 'slime-model use OTHER'.")
    file_name = reg[args.name]["file"]
    del reg[args.name]
    save_registry(reg)
    print(f"Unregistered {args.name}")
    if args.purge:
        path = MODELS_DIR / file_name
        if path.exists():
            sudo("rm", str(path))
            print(f"Deleted {path}")


def cmd_gen_pi_config(args: argparse.Namespace) -> None:
    reg = load_registry()
    models = []
    for name, meta in sorted(reg.items()):
        m = {
            "id": name,
            "name": meta.get("label", name),
            "contextWindow": meta["ctx"],
            "maxTokens": 16384,
        }
        if meta.get("reasoning"):
            m["reasoning"] = True
        models.append(m)
    cfg = {
        "providers": {
            "slime": {
                "baseUrl": args.base_url,
                "api": "openai-completions",
                "apiKey": "unused",
                "compat": {
                    "supportsDeveloperRole": False,
                    "thinkingFormat": "qwen-chat-template",
                },
                "models": models,
            },
        },
    }
    out = json.dumps(cfg, indent=2) + "\n"
    if args.out:
        Path(args.out).write_text(out)
        print(f"Wrote {args.out}", file=sys.stderr)
    else:
        sys.stdout.write(out)


# ----- argparse wiring -----

def main() -> None:
    p = argparse.ArgumentParser(prog="slime-model",
                                description="Manage slime's llama-server model lineup.")
    sub = p.add_subparsers(dest="cmd", required=True)

    sub.add_parser("list", help="list registered models")
    sub.add_parser("status", help="show active model and service state")

    pr = sub.add_parser("register", help="register an existing GGUF (already in models dir)")
    pr.add_argument("file", help="filename in /var/lib/llama-server/models or absolute path")
    pr.add_argument("--name", required=True)
    pr.add_argument("--ctx", type=int, default=65536)
    pr.add_argument("--label")
    pr.add_argument("--hf-repo", help="optional HF repo for provenance")
    pr.add_argument("--reasoning", action="store_true")
    pr.add_argument("--force", action="store_true", help="overwrite existing entry")

    ps = sub.add_parser("set", help="update metadata on a registered model")
    ps.add_argument("name")
    ps.add_argument("--ctx", type=int)
    ps.add_argument("--label")
    ps.add_argument("--reasoning", action="store_true")
    ps.add_argument("--no-reasoning", action="store_true")

    pf = sub.add_parser("fetch", help="download from HF and register")
    pf.add_argument("repo", help="HF repo, e.g. unsloth/foo-GGUF")
    pf.add_argument("--quant", default="Q4_K_M")
    pf.add_argument("--name", help="registry name (defaults to repo-derived)")
    pf.add_argument("--ctx", type=int, default=65536)
    pf.add_argument("--label")
    pf.add_argument("--reasoning", action="store_true")
    pf.add_argument("--preserve-name",
                    action="store_true", help="keep HF's filename instead of <name>.gguf")
    pf.add_argument("--force", action="store_true")

    pu = sub.add_parser("use", help="switch active model and restart service")
    pu.add_argument("name")

    pr2 = sub.add_parser("remove", help="unregister model (and optionally delete file)")
    pr2.add_argument("name")
    pr2.add_argument("--purge", action="store_true", help="also delete the GGUF file")

    pg = sub.add_parser("gen-pi-config", help="emit pi models.json from registry")
    pg.add_argument("--base-url", default="http://slime:8000/v1")
    pg.add_argument("--out", help="write to file instead of stdout")

    args = p.parse_args()
    handlers = {
        "list": cmd_list,
        "status": cmd_status,
        "register": cmd_register,
        "set": cmd_set,
        "fetch": cmd_fetch,
        "use": cmd_use,
        "remove": cmd_remove,
        "gen-pi-config": cmd_gen_pi_config,
    }
    handlers[args.cmd](args)


if __name__ == "__main__":
    main()
