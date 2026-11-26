#!/usr/bin/env bash
# Local MacBook Pro `GoNext` Async Relay Runner for About-Paint-Tools.
# Strictly executes ONLY allowlisted actions declared in ops/relay/orders/*.json
# and writes paired chronological receipts to ops/relay/results/<order_id>.result.md.
# Compatible with macOS default bash 3.2+ and Linux bash 5+.
set -euo pipefail

export PATH="$HOME/.cargo/bin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:$PATH"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
APPLE_DIR="$ROOT/apps/apple"
XCODEPROJ="$APPLE_DIR/MangaStudioApple.xcodeproj"
RESULTS_DIR="$ROOT/ops/relay/results"
LOCK_DIR="$ROOT/.git/about-paint-relay.lock"
AGENT_LABEL="org.aboutpainttools.mac-relay"
AGENT_PLIST="$HOME/Library/LaunchAgents/${AGENT_LABEL}.plist"
AGENT_LOG="$HOME/Library/Logs/about-paint-tools-relay.log"

is_macos() {
  [ "$(uname -s)" = "Darwin" ]
}

notify_macos() {
  local title="$1"
  local message="$2"
  if is_macos && command -v osascript >/dev/null 2>&1; then
    osascript -e "display notification \"${message//\"/\'}\" with title \"${title//\"/\'}\"" >/dev/null 2>&1 || true
  fi
}

acquire_lock() {
  if ! mkdir "$LOCK_DIR" 2>/dev/null; then
    echo "note: another mac_relay.sh instance is already running ($LOCK_DIR); exiting."
    exit 0
  fi
  trap 'rmdir "$LOCK_DIR" 2>/dev/null || true' EXIT INT TERM
}

run_allowed_action() {
  local action="$1"
  local derived="$APPLE_DIR/DerivedData"

  case "$action" in
    env-info)
      echo "Host      : $(hostname)"
      echo "OS        : $(uname -srm)"
      if is_macos; then
        echo "macOS     : $(sw_vers -productVersion 2>/dev/null || true) ($(sw_vers -buildVersion 2>/dev/null || true))"
        echo "Chip      : $(sysctl -n machdep.cpu.brand_string 2>/dev/null || true)"
        echo "Xcode     : $(xcodebuild -version 2>/dev/null | tr '\n' ' ' || echo 'not installed')"
        echo "XcodeGen  : $(xcodegen --version 2>/dev/null || echo 'not installed')"
      fi
      echo "Rust      : $(rustc --version 2>/dev/null || echo 'not installed')"
      echo "Cargo     : $(cargo --version 2>/dev/null || echo 'not installed')"
      echo "Git HEAD  : $(git -C "$ROOT" rev-parse --short HEAD) ($(git -C "$ROOT" rev-parse --abbrev-ref HEAD))"
      ;;

    build-rust)
      bash "$ROOT/scripts/dev.sh" build-rust
      ;;

    build-rust-force)
      bash "$ROOT/scripts/dev.sh" build-rust --force
      ;;

    xcode-gen)
      bash "$ROOT/scripts/dev.sh" xcode-gen
      ;;

    build-mac)
      if ! is_macos; then
        echo "error: build-mac requires macOS with Xcode" >&2
        return 1
      fi
      [ -d "$XCODEPROJ" ] || bash "$ROOT/scripts/dev.sh" xcode-gen
      xcodebuild \
        -project "$XCODEPROJ" \
        -scheme "MangaStudio-macOS-Touch" \
        -configuration Debug \
        -derivedDataPath "$derived" \
        -destination "platform=macOS,arch=arm64" \
        CODE_SIGNING_ALLOWED=NO \
        build
      ;;

    build-ipad)
      if ! is_macos; then
        echo "error: build-ipad requires macOS with Xcode" >&2
        return 1
      fi
      [ -d "$XCODEPROJ" ] || bash "$ROOT/scripts/dev.sh" xcode-gen
      xcodebuild \
        -project "$XCODEPROJ" \
        -scheme "MangaStudio-iPadOS" \
        -configuration Debug \
        -derivedDataPath "$derived" \
        -destination "generic/platform=iOS Simulator" \
        CODE_SIGNING_ALLOWED=NO \
        build
      ;;

    build-duo)
      if ! is_macos; then
        echo "error: build-duo requires macOS with Xcode" >&2
        return 1
      fi
      [ -d "$XCODEPROJ" ] || bash "$ROOT/scripts/dev.sh" xcode-gen
      xcodebuild \
        -project "$XCODEPROJ" \
        -scheme "MangaStudio-iPhoneDuo" \
        -configuration Debug \
        -derivedDataPath "$derived" \
        -destination "generic/platform=iOS Simulator" \
        CODE_SIGNING_ALLOWED=NO \
        build
      ;;

    test-mac)
      if ! is_macos; then
        echo "error: test-mac requires macOS with Xcode" >&2
        return 1
      fi
      [ -d "$XCODEPROJ" ] || bash "$ROOT/scripts/dev.sh" xcode-gen
      if xcodebuild -project "$XCODEPROJ" -list 2>/dev/null | grep -q "Tests"; then
        xcodebuild \
          -project "$XCODEPROJ" \
          -scheme "MangaStudio-macOS-Touch" \
          -derivedDataPath "$derived" \
          -destination "platform=macOS,arch=arm64" \
          CODE_SIGNING_ALLOWED=NO \
          test
      else
        echo "SKIP: No macOS XCTest target defined in project.yml yet."
      fi
      ;;

    test-ipad)
      if ! is_macos; then
        echo "error: test-ipad requires macOS with Xcode" >&2
        return 1
      fi
      [ -d "$XCODEPROJ" ] || bash "$ROOT/scripts/dev.sh" xcode-gen
      if xcodebuild -project "$XCODEPROJ" -list 2>/dev/null | grep -q "Tests"; then
        xcodebuild \
          -project "$XCODEPROJ" \
          -scheme "MangaStudio-iPadOS" \
          -derivedDataPath "$derived" \
          -destination "generic/platform=iOS Simulator" \
          CODE_SIGNING_ALLOWED=NO \
          test
      else
        echo "SKIP: No iPadOS XCTest target defined in project.yml yet."
      fi
      ;;

    launch-mac)
      if ! is_macos; then
        echo "error: launch-mac requires macOS" >&2
        return 1
      fi
      local app_path="$derived/Build/Products/Debug/MangaStudio-macOS-Touch.app"
      if [ -d "$app_path" ]; then
        open "$app_path"
        echo "Launched: $app_path"
      else
        echo "error: $app_path not found; include build-mac before launch-mac" >&2
        return 1
      fi
      ;;

    open-xcode)
      if ! is_macos; then
        echo "error: open-xcode requires macOS" >&2
        return 1
      fi
      [ -d "$XCODEPROJ" ] || bash "$ROOT/scripts/dev.sh" xcode-gen
      open "$XCODEPROJ"
      echo "Opened: $XCODEPROJ"
      ;;

    check)
      bash "$ROOT/scripts/dev.sh" check
      ;;

    *)
      echo "SECURITY ERROR: Disallowed action '$action' rejected by mac_relay.sh allowlist." >&2
      return 126
      ;;
  esac
}

execute_order() {
  local order_file="$1"
  local no_push="$2"
  local dry_run="$3"

  local order_id milestone title notify
  order_id="$(python3 "$ROOT/scripts/relay_tool.py" meta "$order_file" order_id)"
  milestone="$(python3 "$ROOT/scripts/relay_tool.py" meta "$order_file" milestone)"
  title="$(python3 "$ROOT/scripts/relay_tool.py" meta "$order_file" title)"
  notify="$(python3 "$ROOT/scripts/relay_tool.py" meta "$order_file" notify)"

  echo ""
  echo "========================================================================"
  echo "GoNext Order : $order_id ($milestone)"
  echo "Title        : $title"
  echo "========================================================================"

  local steps_text
  if ! steps_text="$(python3 "$ROOT/scripts/relay_tool.py" dump-steps "$order_file")"; then
    echo "FAIL: Order $order_id failed schema/allowlist validation; aborting." >&2
    return 1
  fi

  if [ "$dry_run" = "1" ]; then
    echo "[DRY-RUN] Would execute steps:"
    echo "$steps_text" | sed 's/^/  - /'
    return 0
  fi

  mkdir -p "$RESULTS_DIR"
  local result_file="$RESULTS_DIR/${order_id}.result.md"
  local tmp_steps_table tmp_logs
  tmp_steps_table="$(mktemp)"
  tmp_logs="$(mktemp)"

  local started_utc start_epoch git_sha host_name os_desc overall_status failed
  started_utc="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
  start_epoch="$(date +%s)"
  git_sha="$(git -C "$ROOT" rev-parse --short HEAD)"
  host_name="$(hostname)"
  os_desc="$(uname -srm)"
  overall_status="PASS"
  failed=0

  local step_num=0
  local action
  while IFS= read -r action; do
    [ -z "$action" ] && continue
    step_num=$((step_num + 1))

    if [ "$failed" = "1" ]; then
      printf "| %d | \`%s\` | SKIPPED | 0s | - |\n" "$step_num" "$action" >> "$tmp_steps_table"
      continue
    fi

    echo "==> [Step $step_num] Running allowlisted action: $action"
    local step_log step_start step_end step_dur rc step_status tail_lines
    step_log="$(mktemp)"
    step_start="$(date +%s)"

    set +e
    run_allowed_action "$action" >"$step_log" 2>&1
    rc=$?
    set -e

    step_end="$(date +%s)"
    step_dur=$((step_end - step_start))

    if [ "$rc" -eq 0 ]; then
      step_status="PASS"
      tail_lines=30
      echo "    -> PASS (${step_dur}s)"
    else
      step_status="FAIL"
      overall_status="FAIL"
      failed=1
      tail_lines=120
      echo "    -> FAIL (exit=$rc, ${step_dur}s)"
    fi

    printf "| %d | \`%s\` | **%s** | %ds | %d |\n" \
      "$step_num" "$action" "$step_status" "$step_dur" "$rc" >> "$tmp_steps_table"

    {
      echo "<details>"
      echo "<summary>Step ${step_num}: <code>${action}</code> — ${step_status} (exit=${rc}, ${step_dur}s)</summary>"
      echo ""
      echo '```text'
      tail -n "$tail_lines" "$step_log"
      echo '```'
      echo "</details>"
      echo ""
    } >> "$tmp_logs"

    rm -f "$step_log"
  done <<EOF
$steps_text
EOF

  local finished_utc end_epoch total_dur
  finished_utc="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
  end_epoch="$(date +%s)"
  total_dur=$((end_epoch - start_epoch))

  {
    echo "---"
    echo "order_id: ${order_id}"
    echo "milestone: ${milestone}"
    echo "status: ${overall_status}"
    echo "host: ${host_name}"
    echo "os: ${os_desc}"
    echo "git_sha: ${git_sha}"
    echo "started_utc: ${started_utc}"
    echo "finished_utc: ${finished_utc}"
    echo "duration_sec: ${total_dur}"
    echo "---"
    echo ""
    echo "# GoNext Result: \`${order_id}\` — **${overall_status}**"
    echo ""
    echo "- **Order**: [\`${order_id}.json\`](../orders/${order_id}.json)"
    echo "- **Title**: ${title}"
    echo "- **Host**: \`${host_name}\` (\`${os_desc}\`) @ \`${git_sha}\`"
    echo "- **Duration**: ${total_dur}s (${started_utc} → ${finished_utc})"
    echo ""
    echo "## Step Summary"
    echo ""
    echo "| # | Action | Status | Duration | Exit Code |"
    echo "| :--- | :--- | :--- | :--- | :--- |"
    cat "$tmp_steps_table"
    echo ""
    echo "## Step Logs (Trimmed)"
    echo ""
    cat "$tmp_logs"
  } > "$result_file"

  rm -f "$tmp_steps_table" "$tmp_logs"
  echo "==> Wrote paired receipt: ops/relay/results/${order_id}.result.md (${overall_status})"

  if [ "$no_push" != "1" ]; then
    cd "$ROOT"
    git add "ops/relay/results/${order_id}.result.md"
    git commit -m "relay(mac): result ${order_id} [${overall_status}]"
    git pull --rebase origin main
    git push origin main
    echo "==> Pushed receipt for ${order_id} to origin/main."
  else
    echo "note: --no-push active; receipt saved locally without committing."
  fi

  if [ "$notify" = "true" ]; then
    notify_macos "About-Paint-Tools GoNext" "${order_id}: ${overall_status} (${total_dur}s)"
  fi
}

cmd_run_once() {
  local no_push=0
  local dry_run=0
  local allow_branch=0
  while [ "$#" -gt 0 ]; do
    case "$1" in
      --no-push) no_push=1 ;;
      --dry-run) dry_run=1 ;;
      --allow-branch) allow_branch=1 ;;
      *) echo "error: unknown option '$1'" >&2; exit 1 ;;
    esac
    shift
  done

  acquire_lock
  cd "$ROOT"

  local branch
  branch="$(git rev-parse --abbrev-ref HEAD)"
  if [ "$allow_branch" != "1" ] && [ "$branch" != "main" ]; then
    echo "error: refusing to run GoNext orders on non-main branch '$branch' (pass --allow-branch to override)." >&2
    exit 1
  fi

  if [ -z "$(git status --porcelain)" ]; then
    echo "==> Pulling latest GoNext orders from origin/main..."
    git pull --rebase origin main
  else
    echo "warning: working tree has uncommitted edits; skipping auto-pull to protect local work." >&2
    git status -s
  fi

  local pending
  pending="$(python3 "$ROOT/scripts/relay_tool.py" pending)"
  if [ -z "$pending" ]; then
    echo "OK: No pending GoNext orders. Everything is up to date."
    return 0
  fi

  local order_file
  while IFS= read -r order_file; do
    [ -z "$order_file" ] && continue
    execute_order "$order_file" "$no_push" "$dry_run"
  done <<EOF
$pending
EOF
}

cmd_watch() {
  local interval=30
  while [ "$#" -gt 0 ]; do
    case "$1" in
      --interval)
        shift
        interval="${1:-30}"
        ;;
      *) echo "error: unknown watch option '$1'" >&2; exit 1 ;;
    esac
    shift
  done

  echo "==> Watching origin/main for GoNext orders every ${interval}s (Ctrl+C to stop)..."
  while true; do
    git -C "$ROOT" fetch origin main --quiet || true
    local local_sha remote_sha pending
    local_sha="$(git -C "$ROOT" rev-parse HEAD)"
    remote_sha="$(git -C "$ROOT" rev-parse origin/main 2>/dev/null || echo "$local_sha")"
    pending="$(python3 "$ROOT/scripts/relay_tool.py" pending)"

    if [ "$local_sha" != "$remote_sha" ] || [ -n "$pending" ]; then
      echo "==> [$(date +"%H:%M:%S")] Detected new commits or pending orders; running GoNext..."
      bash "$ROOT/scripts/mac_relay.sh" run-once || true
    fi
    sleep "$interval"
  done
}

cmd_install_agent() {
  if ! is_macos; then
    echo "error: LaunchAgent installation is macOS-only." >&2
    exit 1
  fi
  local interval="${1:-60}"
  mkdir -p "$HOME/Library/LaunchAgents" "$HOME/Library/Logs"

  cat > "$AGENT_PLIST" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>${AGENT_LABEL}</string>
  <key>ProgramArguments</key>
  <array>
    <string>/bin/bash</string>
    <string>${ROOT}/scripts/mac_relay.sh</string>
    <string>run-once</string>
  </array>
  <key>WorkingDirectory</key>
  <string>${ROOT}</string>
  <key>EnvironmentVariables</key>
  <dict>
    <key>PATH</key>
    <string>${HOME}/.cargo/bin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin</string>
    <key>HOME</key>
    <string>${HOME}</string>
  </dict>
  <key>StartInterval</key>
  <integer>${interval}</integer>
  <key>RunAtLoad</key>
  <true/>
  <key>StandardOutPath</key>
  <string>${AGENT_LOG}</string>
  <key>StandardErrorPath</key>
  <string>${AGENT_LOG}</string>
</dict>
</plist>
EOF

  local uid
  uid="$(id -u)"
  launchctl bootout "gui/${uid}/${AGENT_LABEL}" >/dev/null 2>&1 || true
  if ! launchctl bootstrap "gui/${uid}" "$AGENT_PLIST" 2>/dev/null; then
    launchctl unload "$AGENT_PLIST" >/dev/null 2>&1 || true
    launchctl load "$AGENT_PLIST"
  fi
  echo "OK: Installed & started LaunchAgent '${AGENT_LABEL}' (interval=${interval}s)."
  echo "    Plist : $AGENT_PLIST"
  echo "    Log   : $AGENT_LOG"
}

cmd_uninstall_agent() {
  if ! is_macos; then
    echo "error: LaunchAgent removal is macOS-only." >&2
    exit 1
  fi
  local uid
  uid="$(id -u)"
  launchctl bootout "gui/${uid}/${AGENT_LABEL}" >/dev/null 2>&1 || true
  launchctl unload "$AGENT_PLIST" >/dev/null 2>&1 || true
  rm -f "$AGENT_PLIST"
  echo "OK: Uninstalled LaunchAgent '${AGENT_LABEL}'."
}

cmd_status() {
  echo "=== GoNext Relay Orders & Paired Receipts ==="
  python3 "$ROOT/scripts/relay_tool.py" list
  echo ""
  if is_macos; then
    if [ -f "$AGENT_PLIST" ]; then
      echo "LaunchAgent: INSTALLED ($AGENT_PLIST)"
      echo "Log file   : $AGENT_LOG"
    else
      echo "LaunchAgent: NOT INSTALLED (run 'make relay-install-agent' to enable background polling)"
    fi
  else
    echo "Host OS    : $(uname -s) (Cloud/Linux mode)"
  fi
}

usage() {
  cat <<'EOF'
About-Paint-Tools Local Mac `GoNext` Relay Runner (scripts/mac_relay.sh)

Usage:
  ./scripts/mac_relay.sh run-once [--no-push] [--dry-run]   Pull & execute all pending GoNext orders, push receipts
  ./scripts/mac_relay.sh watch [--interval 30]              Foreground polling loop for automatic execution
  ./scripts/mac_relay.sh install-agent [interval_sec]       Install macOS launchd background LaunchAgent (default 60s)
  ./scripts/mac_relay.sh uninstall-agent                    Remove macOS launchd background LaunchAgent
  ./scripts/mac_relay.sh status                             Show chronological order/result table & agent state
EOF
}

cmd="${1:-status}"
if [ "$#" -gt 0 ]; then
  shift
fi

case "$cmd" in
  run-once|gonext)  cmd_run_once "$@" ;;
  watch)            cmd_watch "$@" ;;
  install-agent)    cmd_install_agent "${1:-60}" ;;
  uninstall-agent)  cmd_uninstall_agent ;;
  status)           cmd_status ;;
  help|-h|--help)   usage ;;
  *)
    echo "error: unknown relay command '$cmd'" >&2
    usage >&2
    exit 1
    ;;
esac
