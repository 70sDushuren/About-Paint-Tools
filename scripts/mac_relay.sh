#!/usr/bin/env bash
# Local MacBook Pro `GoNext` Async Relay Runner for About-Paint-Tools.
# Strictly executes ONLY allowlisted actions declared in ops/relay/orders/*.json,
# enforces time/order/failure circuit breakers, and writes paired chronological
# receipts to ops/relay/results/<order_id>.result.md.
# Compatible with macOS default bash 3.2+ and Linux bash 5+.
set -euo pipefail

export PATH="$HOME/.cargo/bin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:$PATH"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
APPLE_DIR="$ROOT/apps/apple"
XCODEPROJ="$APPLE_DIR/MangaStudioApple.xcodeproj"
RESULTS_DIR="$ROOT/ops/relay/results"
REMOTE_PAUSE_FILE="$ROOT/ops/relay/PAUSE"
LOCK_DIR="$ROOT/.git/about-paint-relay.lock"
LOCAL_PAUSE_FILE="$ROOT/.git/about-paint-relay.paused"
WATCH_PID_FILE="$ROOT/.git/about-paint-relay-watch.pid"
AGENT_BUDGET_FILE="$ROOT/.git/about-paint-relay-agent.budget"
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

write_local_pause() {
  local reason="$1"
  {
    echo "paused_utc=$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
    echo "reason=${reason}"
  } > "$LOCAL_PAUSE_FILE"
}

check_pause_gates() {
  if [ -f "$LOCAL_PAUSE_FILE" ]; then
    echo "PAUSED: Local relay pause/circuit-breaker lock is active ($LOCAL_PAUSE_FILE):"
    sed 's/^/  /' "$LOCAL_PAUSE_FILE"
    echo "Run 'make relay-resume' after reviewing to re-enable."
    return 42
  fi
  if [ -f "$REMOTE_PAUSE_FILE" ]; then
    echo "PAUSED: Remote kill switch 'ops/relay/PAUSE' is present in repository."
    sed 's/^/  /' "$REMOTE_PAUSE_FILE"
    return 42
  fi
  return 0
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

LAST_ORDER_STATUS="NONE"

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
    LAST_ORDER_STATUS="FAIL"
    return 1
  fi

  if [ "$dry_run" = "1" ]; then
    echo "[DRY-RUN] Would execute steps:"
    echo "$steps_text" | sed 's/^/  - /'
    LAST_ORDER_STATUS="DRY_RUN"
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

  LAST_ORDER_STATUS="$overall_status"
  if [ "$notify" = "true" ]; then
    notify_macos "About-Paint-Tools GoNext" "${order_id}: ${overall_status} (${total_dur}s)"
  fi
}

cmd_run_once() {
  local no_push=0
  local dry_run=0
  local allow_branch=0
  local single_order=0
  local max_fails=3
  local ignore_pause=0
  while [ "$#" -gt 0 ]; do
    case "$1" in
      --no-push) no_push=1 ;;
      --dry-run) dry_run=1 ;;
      --allow-branch) allow_branch=1 ;;
      --single-order) single_order=1 ;;
      --ignore-pause) ignore_pause=1 ;;
      --max-fails)
        shift
        max_fails="${1:-3}"
        ;;
      *) echo "error: unknown option '$1'" >&2; exit 1 ;;
    esac
    shift
  done

  acquire_lock
  cd "$ROOT"

  if [ "$ignore_pause" != "1" ]; then
    check_pause_gates || return $?
  fi

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

  if [ "$ignore_pause" != "1" ] && [ -f "$REMOTE_PAUSE_FILE" ]; then
    echo "PAUSED: Remote kill switch 'ops/relay/PAUSE' pulled from origin; stopping."
    return 42
  fi

  # Pre-execution circuit-breaker audit (consecutive failures or identical duplicate error loop)
  if [ "$ignore_pause" != "1" ] && [ "$max_fails" -gt 0 ]; then
    set +e
    python3 "$ROOT/scripts/relay_tool.py" guard-check --max-consecutive-failures "$max_fails"
    local guard_rc=$?
    set -e
    if [ "$guard_rc" -eq 42 ]; then
      write_local_pause "Circuit breaker tripped before run (max_fails=${max_fails} or duplicate error loop)"
      notify_macos "GoNext Circuit Breaker Tripped" "Paused automatically after repeated failures. Review results and run 'make relay-resume'."
      return 42
    fi
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

    # Re-check circuit breaker immediately after finishing an order
    if [ "$dry_run" != "1" ] && [ "$max_fails" -gt 0 ]; then
      set +e
      python3 "$ROOT/scripts/relay_tool.py" guard-check --max-consecutive-failures "$max_fails"
      local post_guard_rc=$?
      set -e
      if [ "$post_guard_rc" -eq 42 ]; then
        write_local_pause "Circuit breaker tripped after order ($(basename "$order_file")): repeated failures or duplicate error loop"
        notify_macos "GoNext Auto-Paused (Circuit Breaker)" "Detected repeated failures/loop. Completed last order and paused safely."
        return 42
      fi
    fi

    if [ "$single_order" = "1" ]; then
      break
    fi
  done <<EOF
$pending
EOF
}

cmd_watch() {
  local interval=30
  local max_minutes=60
  local max_orders=10
  local max_fails=3

  while [ "$#" -gt 0 ]; do
    case "$1" in
      --interval)    shift; interval="${1:-30}" ;;
      --max-minutes) shift; max_minutes="${1:-60}" ;;
      --max-orders)  shift; max_orders="${1:-10}" ;;
      --max-fails)   shift; max_fails="${1:-3}" ;;
      *) echo "error: unknown watch option '$1'" >&2; exit 1 ;;
    esac
    shift
  done

  check_pause_gates || exit $?

  local start_epoch deadline_epoch orders_done now_epoch remaining_sec
  start_epoch="$(date +%s)"
  if [ "$max_minutes" -gt 0 ]; then
    deadline_epoch=$((start_epoch + max_minutes * 60))
  else
    deadline_epoch=0
  fi
  orders_done=0

  echo "$$" > "$WATCH_PID_FILE"
  trap 'rm -f "$WATCH_PID_FILE"' EXIT INT TERM

  echo "========================================================================"
  echo "GoNext Auto-Watch Started"
  echo "  Poll Interval : ${interval}s"
  echo "  Time Budget   : ${max_minutes} min (0=unlimited)"
  echo "  Order Budget  : ${max_orders} order(s) (0=unlimited)"
  echo "  Failure Limit : ${max_fails} consecutive FAILs (or 2 identical error loops)"
  echo "  Emergency Stop: Ctrl+C  OR  'make relay-stop'  OR  ops/relay/PAUSE"
  echo "========================================================================"

  while true; do
    # 1. Check local or remote pause before starting any new work
    if ! check_pause_gates; then
      echo "==> Auto-Watch stopped cleanly due to PAUSE/circuit breaker."
      notify_macos "GoNext Auto-Watch Paused" "Stopped cleanly after ${orders_done} order(s). Waiting for your confirmation."
      exit 0
    fi

    # 2. Check wall-clock time budget before starting a new order
    now_epoch="$(date +%s)"
    if [ "$deadline_epoch" -gt 0 ] && [ "$now_epoch" -ge "$deadline_epoch" ]; then
      echo ""
      echo "========================================================================"
      echo "AUTO-STOPPED: Time budget (${max_minutes} min) reached."
      echo "  Orders completed this session : ${orders_done}"
      echo "  All in-flight work finished cleanly. Waiting for your instruction to continue or stop."
      echo "========================================================================"
      notify_macos "GoNext Time Limit Reached" "Completed ${orders_done} order(s) in ${max_minutes}m and paused safely."
      exit 0
    fi

    # 3. Check max-orders budget
    if [ "$max_orders" -gt 0 ] && [ "$orders_done" -ge "$max_orders" ]; then
      echo ""
      echo "========================================================================"
      echo "AUTO-STOPPED: Order count budget (${orders_done}/${max_orders}) reached."
      echo "  Waiting for your instruction to continue or stop."
      echo "========================================================================"
      notify_macos "GoNext Order Limit Reached" "Completed ${orders_done}/${max_orders} order(s) and paused safely."
      exit 0
    fi

    git -C "$ROOT" fetch origin main --quiet || true
    local local_sha remote_sha pending
    local_sha="$(git -C "$ROOT" rev-parse HEAD)"
    remote_sha="$(git -C "$ROOT" rev-parse origin/main 2>/dev/null || echo "$local_sha")"
    pending="$(python3 "$ROOT/scripts/relay_tool.py" pending)"

    if [ "$local_sha" != "$remote_sha" ] || [ -n "$pending" ]; then
      local before_count after_count
      before_count="$(find "$RESULTS_DIR" -maxdepth 1 -name '*.result.md' 2>/dev/null | wc -l | tr -d ' ')"

      echo "==> [$(date +"%H:%M:%S")] New commits or pending orders detected; executing next GoNext order..."
      set +e
      bash "$ROOT/scripts/mac_relay.sh" run-once --single-order --max-fails "$max_fails"
      local run_rc=$?
      set -e

      after_count="$(find "$RESULTS_DIR" -maxdepth 1 -name '*.result.md' 2>/dev/null | wc -l | tr -d ' ')"
      if [ "$after_count" -gt "$before_count" ]; then
        orders_done=$((orders_done + 1))
      fi

      if [ "$run_rc" -eq 42 ]; then
        echo ""
        echo "========================================================================"
        echo "AUTO-STOPPED: Circuit breaker or PAUSE triggered after ${orders_done} order(s)."
        echo "  Inspect ops/relay/results/ and run 'make relay-resume' when ready."
        echo "========================================================================"
        exit 0
      fi

      # Immediately check budgets right after completing the order (graceful finish rule!)
      now_epoch="$(date +%s)"
      if [ "$deadline_epoch" -gt 0 ] && [ "$now_epoch" -ge "$deadline_epoch" ]; then
        echo ""
        echo "========================================================================"
        echo "AUTO-STOPPED: Time budget (${max_minutes} min) expired during last order."
        echo "  Finished last order cleanly (total=${orders_done}) and paused."
        echo "========================================================================"
        notify_macos "GoNext Time Limit Reached" "Finished last order cleanly (${orders_done} total) and paused."
        exit 0
      fi
      if [ "$max_orders" -gt 0 ] && [ "$orders_done" -ge "$max_orders" ]; then
        echo ""
        echo "========================================================================"
        echo "AUTO-STOPPED: Order budget (${orders_done}/${max_orders}) reached."
        echo "  Finished last order cleanly and paused."
        echo "========================================================================"
        notify_macos "GoNext Order Limit Reached" "Completed ${orders_done}/${max_orders} order(s) and paused."
        exit 0
      fi
    fi

    # Sleep without overshooting deadline unnecessarily
    if [ "$deadline_epoch" -gt 0 ]; then
      now_epoch="$(date +%s)"
      remaining_sec=$((deadline_epoch - now_epoch))
      if [ "$remaining_sec" -le 0 ]; then
        continue
      fi
      if [ "$remaining_sec" -lt "$interval" ]; then
        sleep "$remaining_sec"
      else
        sleep "$interval"
      fi
    else
      sleep "$interval"
    fi
  done
}

cmd_agent_tick() {
  # Entrypoint called by macOS launchd. Enforces persisted wall-clock & order-count budgets,
  # finishes at most 1 order per tick, and self-unloads cleanly when a budget/circuit-breaker trips.
  check_pause_gates || exit 0

  local expire_epoch=0 max_orders=0 max_fails=3 orders_done=0 max_minutes=60
  if [ -f "$AGENT_BUDGET_FILE" ]; then
    # shellcheck disable=SC1090
    source "$AGENT_BUDGET_FILE"
  fi

  local now_epoch
  now_epoch="$(date +%s)"
  if [ "$expire_epoch" -gt 0 ] && [ "$now_epoch" -ge "$expire_epoch" ]; then
    write_local_pause "LaunchAgent time budget (${max_minutes} min) expired after ${orders_done} order(s)"
    notify_macos "GoNext Background Agent Paused" "Time limit (${max_minutes}m) reached after ${orders_done} order(s). Re-run 'make relay-install-agent' to continue."
    cmd_uninstall_agent >/dev/null 2>&1 || true
    exit 0
  fi

  if [ "$max_orders" -gt 0 ] && [ "$orders_done" -ge "$max_orders" ]; then
    write_local_pause "LaunchAgent order budget (${orders_done}/${max_orders}) reached"
    notify_macos "GoNext Background Agent Paused" "Completed ${orders_done}/${max_orders} order(s). Re-run 'make relay-install-agent' to continue."
    cmd_uninstall_agent >/dev/null 2>&1 || true
    exit 0
  fi

  local before_count after_count
  before_count="$(find "$RESULTS_DIR" -maxdepth 1 -name '*.result.md' 2>/dev/null | wc -l | tr -d ' ')"

  set +e
  bash "$ROOT/scripts/mac_relay.sh" run-once --single-order --max-fails "$max_fails"
  local rc=$?
  set -e

  after_count="$(find "$RESULTS_DIR" -maxdepth 1 -name '*.result.md' 2>/dev/null | wc -l | tr -d ' ')"
  if [ "$after_count" -gt "$before_count" ]; then
    orders_done=$((orders_done + 1))
    cat > "$AGENT_BUDGET_FILE" <<EOF
expire_epoch=${expire_epoch}
max_minutes=${max_minutes}
max_orders=${max_orders}
max_fails=${max_fails}
orders_done=${orders_done}
EOF
  fi

  if [ "$rc" -eq 42 ]; then
    cmd_uninstall_agent >/dev/null 2>&1 || true
    exit 0
  fi

  # Graceful stop right after finishing the latest order if budget was reached
  now_epoch="$(date +%s)"
  if { [ "$expire_epoch" -gt 0 ] && [ "$now_epoch" -ge "$expire_epoch" ]; } || \
     { [ "$max_orders" -gt 0 ] && [ "$orders_done" -ge "$max_orders" ]; }; then
    write_local_pause "LaunchAgent completed latest order and reached budget (orders=${orders_done}/${max_orders}, max_min=${max_minutes})"
    notify_macos "GoNext Background Agent Finished" "Finished last order cleanly (${orders_done} total) and paused."
    cmd_uninstall_agent >/dev/null 2>&1 || true
  fi
}

cmd_install_agent() {
  if ! is_macos; then
    echo "error: LaunchAgent installation is macOS-only." >&2
    exit 1
  fi
  local interval=60
  local max_minutes=60
  local max_orders=10
  local max_fails=3

  while [ "$#" -gt 0 ]; do
    case "$1" in
      --interval)    shift; interval="${1:-60}" ;;
      --max-minutes) shift; max_minutes="${1:-60}" ;;
      --max-orders)  shift; max_orders="${1:-10}" ;;
      --max-fails)   shift; max_fails="${1:-3}" ;;
      *) interval="$1" ;;
    esac
    shift
  done

  rm -f "$LOCAL_PAUSE_FILE"
  local start_epoch expire_epoch
  start_epoch="$(date +%s)"
  if [ "$max_minutes" -gt 0 ]; then
    expire_epoch=$((start_epoch + max_minutes * 60))
  else
    expire_epoch=0
  fi

  cat > "$AGENT_BUDGET_FILE" <<EOF
expire_epoch=${expire_epoch}
max_minutes=${max_minutes}
max_orders=${max_orders}
max_fails=${max_fails}
orders_done=0
EOF

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
    <string>agent-tick</string>
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
  echo "OK: Installed & started guarded LaunchAgent '${AGENT_LABEL}'."
  echo "    Poll Interval : ${interval}s"
  echo "    Time Budget   : ${max_minutes} min (auto-unloads cleanly when reached)"
  echo "    Order Budget  : ${max_orders} order(s)"
  echo "    Failure Limit : ${max_fails} consecutive FAILs (or duplicate error loop)"
  echo "    Plist         : $AGENT_PLIST"
  echo "    Log           : $AGENT_LOG"
}

cmd_uninstall_agent() {
  if ! is_macos; then
    echo "note: LaunchAgent removal is macOS-only."
    return 0
  fi
  local uid
  uid="$(id -u)"
  launchctl bootout "gui/${uid}/${AGENT_LABEL}" >/dev/null 2>&1 || true
  launchctl unload "$AGENT_PLIST" >/dev/null 2>&1 || true
  rm -f "$AGENT_PLIST" "$AGENT_BUDGET_FILE"
  echo "OK: Uninstalled LaunchAgent '${AGENT_LABEL}'."
}

cmd_stop() {
  write_local_pause "Manually stopped via 'make relay-stop'"
  if [ -f "$WATCH_PID_FILE" ]; then
    local pid
    pid="$(cat "$WATCH_PID_FILE" 2>/dev/null || true)"
    if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
      kill "$pid" 2>/dev/null || true
      echo "Stopped active relay-watch process (PID=${pid})."
    fi
    rm -f "$WATCH_PID_FILE"
  fi
  if is_macos && [ -f "$AGENT_PLIST" ]; then
    cmd_uninstall_agent
  fi
  echo "OK: GoNext Relay is now PAUSED ($LOCAL_PAUSE_FILE). Run 'make relay-resume' when ready."
  notify_macos "GoNext Relay Stopped" "Manual emergency stop activated."
}

cmd_resume() {
  rm -f "$LOCAL_PAUSE_FILE"
  echo "OK: Cleared local pause/circuit-breaker lock."
  if [ -f "$REMOTE_PAUSE_FILE" ]; then
    echo "WARNING: Remote kill switch 'ops/relay/PAUSE' still exists in git. Remove & push it to fully resume."
  fi
}

cmd_status() {
  echo "=== GoNext Relay Orders & Paired Receipts ==="
  python3 "$ROOT/scripts/relay_tool.py" list
  echo ""
  echo "=== Safety Guard & Circuit Breaker Status ==="
  if [ -f "$LOCAL_PAUSE_FILE" ]; then
    echo "Local State  : PAUSED ($LOCAL_PAUSE_FILE)"
    sed 's/^/  /' "$LOCAL_PAUSE_FILE"
  else
    echo "Local State  : ACTIVE (ready)"
  fi
  if [ -f "$REMOTE_PAUSE_FILE" ]; then
    echo "Remote State : PAUSED (ops/relay/PAUSE present)"
  else
    echo "Remote State : ACTIVE"
  fi
  python3 "$ROOT/scripts/relay_tool.py" guard-check --max-consecutive-failures 3 || true
  if [ -f "$WATCH_PID_FILE" ]; then
    local pid
    pid="$(cat "$WATCH_PID_FILE" 2>/dev/null || true)"
    if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
      echo "Watch Loop   : RUNNING (PID=${pid})"
    fi
  fi
  if is_macos; then
    if [ -f "$AGENT_PLIST" ]; then
      echo "LaunchAgent  : INSTALLED ($AGENT_PLIST)"
      if [ -f "$AGENT_BUDGET_FILE" ]; then
        # shellcheck disable=SC1090
        source "$AGENT_BUDGET_FILE"
        local now_ep rem_min
        now_ep="$(date +%s)"
        if [ "${expire_epoch:-0}" -gt 0 ]; then
          rem_min=$(( (expire_epoch - now_ep + 59) / 60 ))
          [ "$rem_min" -lt 0 ] && rem_min=0
          echo "Agent Budget : ${orders_done:-0}/${max_orders:-0} orders | ~${rem_min} min remaining | max_fails=${max_fails:-3}"
        else
          echo "Agent Budget : ${orders_done:-0}/${max_orders:-0} orders | unlimited time | max_fails=${max_fails:-3}"
        fi
      fi
      echo "Log file     : $AGENT_LOG"
    else
      echo "LaunchAgent  : NOT INSTALLED"
    fi
  else
    echo "Host OS      : $(uname -s) (Cloud/Linux mode)"
  fi
}

usage() {
  cat <<'EOF'
About-Paint-Tools Local Mac `GoNext` Relay Runner (scripts/mac_relay.sh)

Usage:
  ./scripts/mac_relay.sh run-once [--no-push] [--dry-run] [--single-order] [--max-fails N]
  ./scripts/mac_relay.sh watch [--interval 30] [--max-minutes 60] [--max-orders 10] [--max-fails 3]
  ./scripts/mac_relay.sh install-agent [--interval 60] [--max-minutes 60] [--max-orders 10] [--max-fails 3]
  ./scripts/mac_relay.sh uninstall-agent
  ./scripts/mac_relay.sh stop
  ./scripts/mac_relay.sh resume
  ./scripts/mac_relay.sh status
EOF
}

cmd="${1:-status}"
if [ "$#" -gt 0 ]; then
  shift
fi

case "$cmd" in
  run-once|gonext)  cmd_run_once "$@" ;;
  watch)            cmd_watch "$@" ;;
  agent-tick)       cmd_agent_tick ;;
  install-agent)    cmd_install_agent "$@" ;;
  uninstall-agent)  cmd_uninstall_agent ;;
  stop)             cmd_stop ;;
  resume)           cmd_resume ;;
  status)           cmd_status ;;
  help|-h|--help)   usage ;;
  *)
    echo "error: unknown relay command '$cmd'" >&2
    usage >&2
    exit 1
    ;;
esac
