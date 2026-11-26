#!/usr/bin/env python3
"""
Cloud & CI companion tool for the About-Paint-Tools `GoNext` GitOps Relay.

Subcommands:
  new          Create a validated timestamped order in ops/relay/orders/
  validate     Validate all order files against schema & strict action allowlist
  list         Display chronological order/result pairing table
  pending      Print pending order file paths in chronological order (used by mac_relay.sh)
  dump-steps   Validate an order and print allowlisted actions line-by-line
  meta         Read a single metadata field from an order JSON
  guard-check  Audit recent receipts for consecutive failures, duplicate error loops,
               order-count cap, or remote PAUSE kill switch (exit 42 when tripped)
  wait         Poll origin/main until a specific order's paired result.md arrives,
               bounded strictly by --timeout and --max-polls
"""
from __future__ import annotations

import argparse
import datetime as dt
import hashlib
import json
import re
import subprocess
import sys
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
RELAY_DIR = ROOT / "ops" / "relay"
ORDERS_DIR = RELAY_DIR / "orders"
RESULTS_DIR = RELAY_DIR / "results"
PAUSE_FILE = RELAY_DIR / "PAUSE"

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


def list_result_files() -> list[Path]:
    if not RESULTS_DIR.is_dir():
        return []
    return sorted(RESULTS_DIR.glob("*.result.md"))


def result_path_for(order_id: str) -> Path:
    return RESULTS_DIR / f"{order_id}.result.md"


def parse_result_status(result_path: Path) -> str:
    if not result_path.is_file():
        return "PENDING"
    text = result_path.read_text(encoding="utf-8", errors="replace")
    m = re.search(r"^status:\s*([A-Z_]+)\s*$", text, flags=re.MULTILINE)
    return m.group(1) if m else "DONE"


def extract_failure_signature(result_path: Path) -> str:
    """Extracts a stable fingerprint of the failing step + key error lines for duplicate-loop detection."""
    text = result_path.read_text(encoding="utf-8", errors="replace")
    failed_step = re.search(
        r"^\|\s*\d+\s*\|\s*`([^`]+)`\s*\|\s*\*\*FAIL\*\*\s*\|\s*[^|]+\|\s*(\d+)\s*\|",
        text,
        flags=re.MULTILINE,
    )
    action = failed_step.group(1) if failed_step else "unknown"
    exit_code = failed_step.group(2) if failed_step else "unknown"

    # Extract concise diagnostic error lines from the failing details block, stripping volatile timestamps/paths.
    error_lines: list[str] = []
    for line in text.splitlines():
        low = line.lower()
        if any(tok in low for tok in ("error:", "undefined symbols", "build failed", "panic", "fatal:", "security error")):
            cleaned = re.sub(r"\d{4}-\d{2}-\d{2}[T ]\d{2}:\d{2}:\d{2}(\.\d+)?Z?", "<TS>", line.strip())
            cleaned = re.sub(r"0x[0-9a-fA-F]+", "<HEX>", cleaned)
            cleaned = re.sub(r"/Users/[^/\s]+", "/Users/<USER>", cleaned)
            error_lines.append(cleaned)
    core = "\n".join(error_lines[-5:]) if error_lines else f"{action}:{exit_code}"
    digest = hashlib.sha256(f"{action}|{exit_code}|{core}".encode("utf-8")).hexdigest()[:12]
    return f"{action}(exit={exit_code}):{digest}"


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
    if PAUSE_FILE.exists():
        print("\n[PAUSED] Remote kill switch ops/relay/PAUSE is active.")
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


def cmd_guard_check(args: argparse.Namespace) -> int:
    """Audits relay receipts for circuit-breaker triggers (exit 42 if tripped)."""
    reasons: list[str] = []
    if PAUSE_FILE.exists():
        pause_note = PAUSE_FILE.read_text(encoding="utf-8", errors="replace").strip()
        reasons.append(f"REMOTE_PAUSE: ops/relay/PAUSE is present ({pause_note or 'no reason'})")

    results = list_result_files()
    if args.since_order:
        results = [r for r in results if r.name.replace(".result.md", "") >= args.since_order]

    total_in_scope = len(results)
    if args.max_orders > 0 and total_in_scope >= args.max_orders:
        reasons.append(
            f"MAX_ORDERS_REACHED: processed {total_in_scope} >= limit {args.max_orders}"
        )

    consecutive_failures = 0
    recent_fail_sigs: list[str] = []
    for r in reversed(results):
        st = parse_result_status(r)
        if st == "FAIL":
            consecutive_failures += 1
            if len(recent_fail_sigs) < 2:
                recent_fail_sigs.append(extract_failure_signature(r))
        else:
            break

    if args.max_consecutive_failures > 0 and consecutive_failures >= args.max_consecutive_failures:
        reasons.append(
            f"MAX_CONSECUTIVE_FAILURES: {consecutive_failures} consecutive FAIL receipts "
            f"(limit={args.max_consecutive_failures})"
        )

    duplicate_loop = (
        args.detect_duplicate_error
        and len(recent_fail_sigs) >= 2
        and recent_fail_sigs[0] == recent_fail_sigs[1]
    )
    if duplicate_loop:
        reasons.append(
            f"DUPLICATE_ERROR_LOOP: last 2 consecutive failures have identical error signature "
            f"'{recent_fail_sigs[0]}'"
        )

    summary = {
        "tripped": bool(reasons),
        "remote_paused": PAUSE_FILE.exists(),
        "total_results_in_scope": total_in_scope,
        "consecutive_failures": consecutive_failures,
        "recent_fail_signatures": recent_fail_sigs,
        "reasons": reasons,
    }

    if args.json:
        print(json.dumps(summary, indent=2, ensure_ascii=False))
    else:
        if reasons:
            print("CIRCUIT_BREAKER_TRIPPED:")
            for reason in reasons:
                print(f"  - {reason}")
        else:
            print(
                f"GUARD_OK: results_in_scope={total_in_scope}, "
                f"consecutive_failures={consecutive_failures}/{args.max_consecutive_failures}, "
                f"remote_paused=false"
            )

    return 42 if reasons else 0


def cmd_wait(args: argparse.Namespace) -> int:
    order_id = args.order_id
    branch = args.branch
    start_ts = time.time()
    deadline = start_ts + args.timeout
    max_polls = args.max_polls if args.max_polls > 0 else max(1, (args.timeout + args.interval - 1) // args.interval)
    rel_result = f"ops/relay/results/{order_id}.result.md"
    print(
        f"==> Waiting for Mac receipt '{rel_result}' on origin/{branch} "
        f"(timeout={args.timeout}s, max_polls={max_polls}, interval={args.interval}s)..."
    )
    poll = 0
    while True:
        poll += 1
        if PAUSE_FILE.exists():
            print("PAUSED: ops/relay/PAUSE detected; aborting wait immediately.", file=sys.stderr)
            return 42

        subprocess.run(
            ["git", "fetch", "origin", branch, "--quiet"],
            cwd=ROOT,
            check=False,
        )
        # Check if remote added ops/relay/PAUSE
        remote_pause = subprocess.run(
            ["git", "cat-file", "-e", f"origin/{branch}:ops/relay/PAUSE"],
            cwd=ROOT,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )
        if remote_pause.returncode == 0:
            print("PAUSED: remote ops/relay/PAUSE detected on origin; stopping wait.", file=sys.stderr)
            return 42

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
            print(f"OK: Receipt received after {int(time.time() - start_ts)}s (poll {poll}/{max_polls}) -> {rel_result}\n")
            print(res_path.read_text(encoding="utf-8", errors="replace"))
            return 0 if parse_result_status(res_path) == "PASS" else 1

        if poll >= max_polls or time.time() >= deadline:
            print(
                f"TIMEOUT: Receipt '{rel_result}' did not arrive within {args.timeout}s "
                f"({poll}/{max_polls} polls). Pausing automatically for user confirmation.",
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

    p_guard = sub.add_parser(
        "guard-check",
        help="Check circuit-breaker rules (consecutive failures, duplicate error loop, order cap, PAUSE)",
    )
    p_guard.add_argument("--since-order", default="", help="Only count receipts with order_id >= this value")
    p_guard.add_argument("--max-orders", type=int, default=0, help="Max receipts allowed in scope (0=unlimited)")
    p_guard.add_argument("--max-consecutive-failures", type=int, default=3, help="Max trailing FAIL streak")
    p_guard.add_argument(
        "--no-duplicate-error-check",
        dest="detect_duplicate_error",
        action="store_false",
        default=True,
        help="Disable immediate trip on 2 identical consecutive failure signatures",
    )
    p_guard.add_argument("--json", action="store_true", help="Output JSON summary")
    p_guard.set_defaults(func=cmd_guard_check)

    p_wait = sub.add_parser("wait", help="Poll origin until paired result.md arrives")
    p_wait.add_argument("order_id")
    p_wait.add_argument("--branch", default="main")
    p_wait.add_argument("--timeout", type=int, default=300)
    p_wait.add_argument("--interval", type=int, default=15)
    p_wait.add_argument("--max-polls", type=int, default=0, help="Max poll iterations (0=auto from timeout/interval)")
    p_wait.set_defaults(func=cmd_wait)

    args = parser.parse_args()
    return args.func(args)


if __name__ == "__main__":
    raise SystemExit(main())
