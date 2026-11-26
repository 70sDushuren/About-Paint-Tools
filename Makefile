.DEFAULT_GOAL := help

.PHONY: help sync sync-force build-rust xcode run-mac run-ipad run-duo check push status \
        gonext relay-watch relay-status relay-install-agent relay-uninstall-agent

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
	@echo "Cloud <-> Local Mac GoNext Relay:"
	@echo "  make gonext                    Fixed command: pull & run pending GoNext orders, push paired results"
	@echo "  make relay-status              Show chronological GoNext order/result table & LaunchAgent state"
	@echo "  make relay-watch               Foreground polling loop (every 30s) for automatic GoNext execution"
	@echo "  make relay-install-agent       Install macOS launchd background LaunchAgent (every 60s)"
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
	@./scripts/mac_relay.sh run-once

relay-status:
	@./scripts/mac_relay.sh status

relay-watch:
	@./scripts/mac_relay.sh watch

relay-install-agent:
	@./scripts/mac_relay.sh install-agent

relay-uninstall-agent:
	@./scripts/mac_relay.sh uninstall-agent
