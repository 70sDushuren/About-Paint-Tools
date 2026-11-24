#!/usr/bin/env python3
"""
Glossary-aware 5-language sync & Xcode String Catalog (.xcstrings) exporter.

Features:
1. `--sync`: Adds missing keys from canonical sources (`en`, `zh-Hans`) to derived
   targets (`zh-Hant`, `yue-Hant`, `es`) using `i18n/glossary.json` term matching.
   Entries with `"locked": true` (manual UI layout tuning) are NEVER overwritten.
2. `--export-xcstrings`: Exports a deterministic Xcode `Localizable.xcstrings`
   covering `en`, `zh-Hans`, `zh-Hant`, `yue-Hant` (plus `zh-HK` alias for iPadOS
   Hong Kong fallback), and `es`.
3. `--check-xcstrings`: CI check verifying the committed `Localizable.xcstrings`
   is strictly in sync with `i18n/locales/*.json`.
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
LOCALES_DIR = ROOT / "i18n" / "locales"
GLOSSARY_PATH = ROOT / "i18n" / "glossary.json"
DEFAULT_XCSTRINGS = ROOT / "apps" / "ipad" / "Resources" / "Localizable.xcstrings"

SOURCE_LOCALES = ("en", "zh-Hans")
TARGET_LOCALES = ("zh-Hant", "yue-Hant", "es")
ALL_LOCALES = SOURCE_LOCALES + TARGET_LOCALES


def load_json(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))


def save_json(path: Path, data: dict) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def lookup_glossary_seed(source_text: str, source_locale: str, target_locale: str, glossary: dict) -> str:
    for term in glossary.get("terms", []):
        if term.get(source_locale) == source_text and target_locale in term:
            return term[target_locale]
    return source_text


def sync_derived_locales() -> int:
    glossary = load_json(GLOSSARY_PATH)
    en_data = load_json(LOCALES_DIR / "en.json")
    zh_data = load_json(LOCALES_DIR / "zh-Hans.json")

    canonical_keys = list(en_data["strings"].keys())
    added_total = 0

    for loc in TARGET_LOCALES:
        path = LOCALES_DIR / f"{loc}.json"
        target_data = load_json(path)
        preferred = target_data.get("preferred_source", "en")
        src_strings = zh_data["strings"] if preferred == "zh-Hans" else en_data["strings"]
        strings = target_data["strings"]
        changed = False

        for key in canonical_keys:
            if key in strings:
                # Preserve all existing entries; never overwrite locked manual layout tweaks.
                if strings[key].get("locked", False):
                    continue
                continue

            src_entry = src_strings[key]
            seeded = lookup_glossary_seed(src_entry["value"], preferred, loc, glossary)
            new_entry: dict = {
                "value": seeded,
                "status": "needs_review" if seeded == src_entry["value"] else "auto",
                "locked": False,
            }
            if "max_chars" in en_data["strings"][key]:
                new_entry["max_chars"] = en_data["strings"][key]["max_chars"]
            strings[key] = new_entry
            added_total += 1
            changed = True

        if changed:
            # Keep key order aligned with canonical en.json.
            target_data["strings"] = {k: strings[k] for k in canonical_keys if k in strings}
            save_json(path, target_data)

    print(f"Sync complete: {added_total} new key(s) seeded; all locked manual layout overrides preserved.")
    return 0


def build_xcstrings_payload() -> dict:
    catalogs = {loc: load_json(LOCALES_DIR / f"{loc}.json") for loc in ALL_LOCALES}
    en_strings = catalogs["en"]["strings"]

    xc_strings: dict[str, dict] = {}
    for key in sorted(en_strings.keys()):
        localizations: dict[str, dict] = {}
        for loc in ALL_LOCALES:
            entry = catalogs[loc]["strings"][key]
            state = "needs_review" if entry.get("status") == "needs_review" else "translated"
            loc_payload = {
                "stringUnit": {
                    "state": state,
                    "value": entry["value"],
                }
            }
            localizations[loc] = loc_payload

            # Mirror yue-Hant to zh-HK so iPadOS Hong Kong devices seamlessly fall back.
            if loc == "yue-Hant":
                localizations["zh-HK"] = loc_payload

        item: dict = {
            "extractionState": "manual",
            "localizations": localizations,
        }
        if "max_chars" in en_strings[key]:
            item["comment"] = f"Compact UI label budget: max {en_strings[key]['max_chars']} chars"
        xc_strings[key] = item

    return {
        "sourceLanguage": "en",
        "strings": xc_strings,
        "version": "1.0",
    }


def export_xcstrings(out_path: Path) -> int:
    payload = build_xcstrings_payload()
    save_json(out_path, payload)
    print(
        f"Exported {len(payload['strings'])} keys × 6 Apple locale codes "
        f"(en, zh-Hans, zh-Hant, yue-Hant, zh-HK, es) -> {out_path.relative_to(ROOT)}"
    )
    return 0


def check_xcstrings(out_path: Path) -> int:
    if not out_path.exists():
        print(f"ERROR: Missing {out_path.relative_to(ROOT)}. Run --export-xcstrings.", file=sys.stderr)
        return 1
    expected = json.dumps(build_xcstrings_payload(), ensure_ascii=False, indent=2) + "\n"
    actual = out_path.read_text(encoding="utf-8")
    if actual != expected:
        print(
            f"ERROR: {out_path.relative_to(ROOT)} is out of sync with i18n/locales/*.json. "
            f"Run `python3 scripts/i18n_sync.py --export-xcstrings`.",
            file=sys.stderr,
        )
        return 1
    print(f"OK: {out_path.relative_to(ROOT)} is strictly in sync with all 5 locale catalogs.")
    return 0


def main() -> int:
    parser = argparse.ArgumentParser(description="Sync 5-locale catalogs and export Xcode .xcstrings.")
    parser.add_argument("--sync", action="store_true", help="Seed missing keys into derived locales without overwriting locked entries.")
    parser.add_argument("--export-xcstrings", action="store_true", help="Export Localizable.xcstrings for iPadOS.")
    parser.add_argument("--check-xcstrings", action="store_true", help="Verify Localizable.xcstrings matches i18n/locales/*.json.")
    parser.add_argument("--out", type=Path, default=DEFAULT_XCSTRINGS, help="Path to Localizable.xcstrings.")
    args = parser.parse_args()

    if not (args.sync or args.export_xcstrings or args.check_xcstrings):
        parser.print_help()
        return 2

    rc = 0
    if args.sync:
        rc |= sync_derived_locales()
    if args.export_xcstrings:
        rc |= export_xcstrings(args.out)
    if args.check_xcstrings:
        rc |= check_xcstrings(args.out)
    return rc


if __name__ == "__main__":
    raise SystemExit(main())
