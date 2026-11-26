.DEFAULT_GOAL := help

.PHONY: help sync sync-force build-rust xcode run-mac run-ipad run-duo check push status \
        gonext relay-watch relay-status relay-install-agent relay-uninstall-agent relay-stop relay-resume

# Default safety budgets for automated GoNext watch / background LaunchAgent
INTERVAL   ?= 30
MAX_MIN    ?= 60
MAX_ORDERS ?= 10
MAX_FAILS  ?= 3

help:
	@./scripts/dev.sh help
	@echo ""
	@echo "Make shortcuts:"
	@echo "  make sync                      Pull + incremental Rust XCFramework + XcodeGen + open Xcode"
	@echo "  make sync-force                Same as 'make sync', forcing a full Rust XCFramework rebuild"
	@echo "  make build-rust                Incremental 3-slice Rust XCFramework build (or cargo build on Linux)"
	@echo "  make xcode                     Regenerate apps/apple/MangaStudioApple.xcodeproj from project.yml"
	@echo "  make run-mac                   Build & launch MangaStudio-macOS-Touch on My Mac"
	@echo "  make run-ipad                  Build MangaStudio-iPadOS for iOS Simulator"
	@echo "  make run-duo                   Build MangaStudio-iPhoneDuo for iOS Simulator"
	@echo "  make check                     Run full CI & S4 Tri-App integration gates locally"
	@echo "  make push MSG=\"feat: ...\"      Run 'make check', commit, pull --rebase, and push to origin"
	@echo "  make status                    Show git status and XCFramework freshness"
	@echo ""
	@echo "Cloud <-> Local Mac GoNext Relay (Guarded Auto-Mode):"
	@echo "  make gonext                    Fixed command: pull & run pending GoNext orders, push paired results"
	@echo "  make relay-status              Show order/result log, pause/circuit-breaker state & remaining budget"
	@echo "  make relay-watch [MAX_MIN=60 MAX_ORDERS=10 MAX_FAILS=3 INTERVAL=30]"
	@echo "                                 Guarded foreground auto-watch (finishes active order & stops at limit)"
	@echo "  make relay-install-agent [MAX_MIN=60 MAX_ORDERS=10 MAX_FAILS=3 INTERVAL=60]"
	@echo "                                 Install guarded macOS launchd background agent (auto-unloads at limit)"
	@echo "  make relay-stop                Emergency stop: halt watch/agent & lock local relay until resumed"
	@echo "  make relay-resume              Clear local pause/circuit-breaker lock to re-enable GoNext"
	@echo "  make relay-uninstall-agent     Remove macOS launchd background LaunchAgent"

sync:
	@./scripts/dev.sh sync

sync-force:
	@./scripts/dev.sh sync --force-rust

build-rust:
	@./scripts/dev.sh build-rust

xcode:
	@./scripts/dev.sh xcode-gen

run-mac:
	@./scripts/dev.sh run mac

run-ipad:
	@./scripts/dev.sh run ipad

run-duo:
	@./scripts/dev.sh run duo

check:
	@./scripts/dev.sh check

push:
	@./scripts/dev.sh push "$(MSG)"

status:
	@./scripts/dev.sh status

gonext:
	@./scripts/mac_relay.sh run-once --max-fails "$(MAX_FAILS)"

relay-status:
	@./scripts/mac_relay.sh status

relay-watch:
	@./scripts/mac_relay.sh watch --interval "$(INTERVAL)" --max-minutes "$(MAX_MIN)" --max-orders "$(MAX_ORDERS)" --max-fails "$(MAX_FAILS)"

relay-install-agent:
	@./scripts/mac_relay.sh install-agent --interval "$(if $(filter 30,$(INTERVAL)),60,$(INTERVAL))" --max-minutes "$(MAX_MIN)" --max-orders "$(MAX_ORDERS)" --max-fails "$(MAX_FAILS)"

relay-uninstall-agent:
	@./scripts/mac_relay.sh uninstall-agent

relay-stop:
	@./scripts/mac_relay.sh stop

relay-resume:
	@./scripts/mac_relay.sh resume
