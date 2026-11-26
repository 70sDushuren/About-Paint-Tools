#!/usr/bin/env python3
"""
Cloud & CI companion tool for the About-Paint-Tools `GoNext` GitOps Relay.

Subcommands:
  new       Create a validated timestamped order in ops/relay/orders/
  validate  Validate all order files against schema & strict action allowlist
  list      Display chronological order/result pairing table
  pending   Print pending order file paths in chronological order (used by mac_relay.sh)
  wait      Poll origin/main until a specific order's paired result.md arrives
"""
from __future__ import annotations

import argparse
import datetime as dt
import json
import os
import re
import subprocess
import sys
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
RELAY_DIR = ROOT / "ops" / "relay"
ORDERS_DIR = RELAY_DIR / "orders"
RESULTS_DIR = RELAY_DIR / "results"

ALLOWED_ACTIONS = (
    "env-info",
    "build-rust",
    "build-rust-force",
    "xcode-gen",
    "build-mac",
    "build-ipad",
    "build-duo",
    "test-mac",
    "test-ipad",
    "launch-mac",
    "open-xcode",
    "check",
)

ORDER_ID_RE = re.compile(r"^[0-9]{8}-[0-9]{6}_[a-z0-9][a-z0-9-]{1,63}$")
SLUG_RE = re.compile(r"^[a-z0-9][a-z0-9-]{1,63}$")


def validate_order_file(path: Path) -> list[str]:
    errors: list[str] = []
    stem = path.stem
    if not ORDER_ID_RE.match(stem):
        errors.append(
            f"{path.name}: filename must match YYYYMMDD-HHMMSS_<lowercase-slug>.json"
        )
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except Exception as exc:
        return [f"{path.name}: invalid JSON ({exc})"]

    if not isinstance(data, dict):
        return [f"{path.name}: root must be a JSON object"]

    if data.get("schema_version") != 1:
        errors.append(f"{path.name}: schema_version must be 1")

    order_id = data.get("order_id")
    if order_id != stem:
        errors.append(
            f"{path.name}: order_id '{order_id}' must match filename stem '{stem}'"
        )

    for req in ("created_at_utc", "milestone", "title"):
        val = data.get(req)
        if not isinstance(val, str) or not val.strip():
            errors.append(f"{path.name}: missing non-empty string field '{req}'")

    steps = data.get("steps")
    if not isinstance(steps, list) or not steps:
        errors.append(f"{path.name}: 'steps' must be a non-empty list")
    else:
        for idx, step in enumerate(steps):
            if not isinstance(step, dict):
                errors.append(f"{path.name}: steps[{idx}] must be an object")
                continue
            action = step.get("action")
            if action not in ALLOWED_ACTIONS:
                errors.append(
                    f"{path.name}: steps[{idx}].action '{action}' is NOT in security allowlist {ALLOWED_ACTIONS}"
                )
            extra_keys = set(step.keys()) - {"action", "note"}
            if extra_keys:
                errors.append(
                    f"{path.name}: steps[{idx}] contains disallowed keys {sorted(extra_keys)}"
                )

    notify = data.get("notify", True)
    if not isinstance(notify, bool):
        errors.append(f"{path.name}: 'notify' must be a boolean")

    return errors


def list_order_files() -> list[Path]:
    if not ORDERS_DIR.is_dir():
        return []
    return sorted(ORDERS_DIR.glob("*.json"))


def result_path_for(order_id: str) -> Path:
    return RESULTS_DIR / f"{order_id}.result.md"


def parse_result_status(result_path: Path) -> str:
    if not result_path.is_file():
        return "PENDING"
    text = result_path.read_text(encoding="utf-8", errors="replace")
    m = re.search(r"^status:\s*([A-Z_]+)\s*$", text, flags=re.MULTILINE)
    return m.group(1) if m else "DONE"


def cmd_new(args: argparse.Namespace) -> int:
    slug = args.slug.strip().lower()
    if not SLUG_RE.match(slug):
        print(
            f"error: slug '{slug}' must match ^[a-z0-9][a-z0-9-]{{1,63}}$",
            file=sys.stderr,
        )
        return 1

    raw_steps = [s.strip() for s in args.steps.split(",") if s.strip()]
    if not raw_steps:
        print("error: --steps must contain at least one allowed action", file=sys.stderr)
        return 1

    steps = []
    for action in raw_steps:
        if action not in ALLOWED_ACTIONS:
            print(
                f"error: action '{action}' is not in allowlist: {', '.join(ALLOWED_ACTIONS)}",
                file=sys.stderr,
            )
            return 1
        steps.append({"action": action})

    now_utc = dt.datetime.now(dt.timezone.utc)
    ts = args.timestamp or now_utc.strftime("%Y%m%d-%H%M%S")
    order_id = f"{ts}_{slug}"
    if not ORDER_ID_RE.match(order_id):
        print(f"error: invalid order_id '{order_id}'", file=sys.stderr)
        return 1

    ORDERS_DIR.mkdir(parents=True, exist_ok=True)
    out_path = ORDERS_DIR / f"{order_id}.json"
    if out_path.exists():
        print(f"error: order already exists: {out_path}", file=sys.stderr)
        return 1

    payload = {
        "schema_version": 1,
        "order_id": order_id,
        "created_at_utc": now_utc.strftime("%Y-%m-%dT%H:%M:%SZ"),
        "milestone": args.milestone,
        "title": args.title,
        "summary": args.summary or "",
        "steps": steps,
        "notify": not args.no_notify,
    }
    out_path.write_text(
        json.dumps(payload, indent=2, ensure_ascii=False) + "\n", encoding="utf-8"
    )
    errs = validate_order_file(out_path)
    if errs:
        out_path.unlink(missing_ok=True)
        for e in errs:
            print(f"error: {e}", file=sys.stderr)
        return 1

    print(f"OK: Created GoNext order -> {out_path.relative_to(ROOT)}")
    return 0


def cmd_validate(_args: argparse.Namespace) -> int:
    files = list_order_files()
    all_errors: list[str] = []
    for f in files:
        all_errors.extend(validate_order_file(f))
    if all_errors:
        for e in all_errors:
            print(f"FAIL: {e}", file=sys.stderr)
        return 1
    print(f"OK: Validated {len(files)} GoNext relay order(s) against strict allowlist.")
    return 0


def cmd_list(_args: argparse.Namespace) -> int:
    files = list_order_files()
    if not files:
        print("No GoNext orders found in ops/relay/orders/.")
        return 0
    print(f"{'ORDER ID':<42} {'MILESTONE':<10} {'STATUS':<10} TITLE")
    print("-" * 96)
    for f in files:
        data = json.loads(f.read_text(encoding="utf-8"))
        order_id = data.get("order_id", f.stem)
        milestone = data.get("milestone", "-")
        title = data.get("title", "")
        status = parse_result_status(result_path_for(order_id))
        print(f"{order_id:<42} {milestone:<10} {status:<10} {title}")
    return 0


def cmd_pending(_args: argparse.Namespace) -> int:
    for f in list_order_files():
        if not result_path_for(f.stem).is_file():
            print(str(f))
    return 0


def cmd_dump_steps(args: argparse.Namespace) -> int:
    path = Path(args.order_file)
    errs = validate_order_file(path)
    if errs:
        for e in errs:
            print(f"error: {e}", file=sys.stderr)
        return 2
    data = json.loads(path.read_text(encoding="utf-8"))
    for step in data["steps"]:
        print(step["action"])
    return 0


def cmd_meta(args: argparse.Namespace) -> int:
    path = Path(args.order_file)
    data = json.loads(path.read_text(encoding="utf-8"))
    val = data.get(args.field, "")
    if isinstance(val, bool):
        print("true" if val else "false")
    else:
        print(val)
    return 0


def cmd_wait(args: argparse.Namespace) -> int:
    order_id = args.order_id
    branch = args.branch
    deadline = time.time() + args.timeout
    rel_result = f"ops/relay/results/{order_id}.result.md"
    print(
        f"==> Waiting for Mac receipt '{rel_result}' on origin/{branch} "
        f"(timeout={args.timeout}s, interval={args.interval}s)..."
    )
    while True:
        subprocess.run(
            ["git", "fetch", "origin", branch, "--quiet"],
            cwd=ROOT,
            check=False,
        )
        check = subprocess.run(
            ["git", "cat-file", "-e", f"origin/{branch}:{rel_result}"],
            cwd=ROOT,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )
        if check.returncode == 0:
            subprocess.run(
                ["git", "pull", "--rebase", "origin", branch],
                cwd=ROOT,
                check=True,
            )
            res_path = ROOT / rel_result
            print(f"OK: Receipt received -> {rel_result}\n")
            print(res_path.read_text(encoding="utf-8", errors="replace"))
            return 0 if parse_result_status(res_path) == "PASS" else 1

        if time.time() >= deadline:
            print(
                f"TIMEOUT: Receipt '{rel_result}' did not arrive within {args.timeout}s.",
                file=sys.stderr,
            )
            return 124
        time.sleep(args.interval)


def main() -> int:
    parser = argparse.ArgumentParser(description="About-Paint-Tools GoNext Relay Tool")
    sub = parser.add_subparsers(dest="cmd", required=True)

    p_new = sub.add_parser("new", help="Create a new timestamped GoNext order")
    p_new.add_argument("--slug", required=True, help="Lowercase hyphenated slug")
    p_new.add_argument("--milestone", required=True, help="Milestone e.g. v0.2.2")
    p_new.add_argument("--title", required=True, help="Short human-readable title")
    p_new.add_argument("--summary", default="", help="Optional context summary")
    p_new.add_argument(
        "--steps",
        required=True,
        help=f"Comma-separated allowlisted actions ({', '.join(ALLOWED_ACTIONS)})",
    )
    p_new.add_argument("--timestamp", default="", help="Optional YYYYMMDD-HHMMSS override")
    p_new.add_argument("--no-notify", action="store_true", help="Disable macOS notification")
    p_new.set_defaults(func=cmd_new)

    p_val = sub.add_parser("validate", help="Validate all orders against schema & allowlist")
    p_val.set_defaults(func=cmd_validate)

    p_list = sub.add_parser("list", help="List orders and paired receipt status")
    p_list.set_defaults(func=cmd_list)

    p_pend = sub.add_parser("pending", help="Print paths of pending order JSON files")
    p_pend.set_defaults(func=cmd_pending)

    p_steps = sub.add_parser("dump-steps", help="Validate order and print actions line-by-line")
    p_steps.add_argument("order_file")
    p_steps.set_defaults(func=cmd_dump_steps)

    p_meta = sub.add_parser("meta", help="Print a single metadata field from an order JSON")
    p_meta.add_argument("order_file")
    p_meta.add_argument("field")
    p_meta.set_defaults(func=cmd_meta)

    p_wait = sub.add_parser("wait", help="Poll origin until paired result.md arrives")
    p_wait.add_argument("order_id")
    p_wait.add_argument("--branch", default="main")
    p_wait.add_argument("--timeout", type=int, default=300)
    p_wait.add_argument("--interval", type=int, default=15)
    p_wait.set_defaults(func=cmd_wait)

    args = parser.parse_args()
    return args.func(args)


if __name__ == "__main__":
    raise SystemExit(main())
