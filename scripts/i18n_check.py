#!/usr/bin/env python3
"""
CI validator for About-Paint-Tools 5-language localization & bilingual documentation.

Checks:
1. Dual canonical sources (`en`, `zh-Hans`) and target locales (`zh-Hant`, `yue-Hant`, `es`) exist.
2. 100% key parity across all 5 locale catalogs.
3. Non-empty string values and valid `status` / `locked` metadata.
4. Exact placeholder parity (e.g., `{count}`, `{percent}`, `{px}`) against `en.json`.
5. `max_chars` UI layout budget enforcement (protects narrow iPad Split View & Spanish labels).
6. 1:1 mirror parity between `docs/en/` and `docs/zh-CN/`.
"""

from __future__ import annotations

import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
LOCALES_DIR = ROOT / "i18n" / "locales"
DOCS_EN_DIR = ROOT / "docs" / "en"
DOCS_ZH_DIR = ROOT / "docs" / "zh-CN"

SOURCE_LOCALES = ("en", "zh-Hans")
TARGET_LOCALES = ("zh-Hant", "yue-Hant", "es")
ALL_LOCALES = SOURCE_LOCALES + TARGET_LOCALES
VALID_STATUSES = {"source", "auto", "tuned", "needs_review"}
PLACEHOLDER_RE = re.compile(r"\{[a-zA-Z0-9_]+\}")


def extract_placeholders(text: str) -> set[str]:
    return set(PLACEHOLDER_RE.findall(text))


def validate_locales() -> list[str]:
    errors: list[str] = []
    catalogs: dict[str, dict] = {}

    for loc in ALL_LOCALES:
        path = LOCALES_DIR / f"{loc}.json"
        if not path.exists():
            errors.append(f"Missing locale catalog: {path.relative_to(ROOT)}")
            continue
        try:
            data = json.loads(path.read_text(encoding="utf-8"))
        except json.JSONDecodeError as exc:
            errors.append(f"Invalid JSON in {path.relative_to(ROOT)}: {exc}")
            continue
        if "strings" not in data or not isinstance(data["strings"], dict):
            errors.append(f"Missing 'strings' object in {path.relative_to(ROOT)}")
            continue
        catalogs[loc] = data["strings"]

    if "en" not in catalogs or "zh-Hans" not in catalogs:
        return errors

    en_keys = set(catalogs["en"].keys())
    zh_keys = set(catalogs["zh-Hans"].keys())
    if en_keys != zh_keys:
        missing_zh = sorted(en_keys - zh_keys)
        missing_en = sorted(zh_keys - en_keys)
        if missing_zh:
            errors.append(f"zh-Hans missing canonical keys from en: {missing_zh}")
        if missing_en:
            errors.append(f"en missing canonical keys from zh-Hans: {missing_en}")

    canonical_keys = en_keys & zh_keys

    for loc, strings in catalogs.items():
        loc_keys = set(strings.keys())
        missing = sorted(canonical_keys - loc_keys)
        extra = sorted(loc_keys - canonical_keys)
        if missing:
            errors.append(f"[{loc}] Missing keys: {missing}")
        if extra:
            errors.append(f"[{loc}] Extra unknown keys: {extra}")

        for key in sorted(canonical_keys & loc_keys):
            entry = strings[key]
            en_entry = catalogs["en"][key]
            val = entry.get("value")
            status = entry.get("status")
            locked = entry.get("locked")

            if not isinstance(val, str) or not val.strip():
                errors.append(f"[{loc}] Key '{key}' has empty or non-string value")
                continue
            if status not in VALID_STATUSES:
                errors.append(f"[{loc}] Key '{key}' has invalid status '{status}'")
            if not isinstance(locked, bool):
                errors.append(f"[{loc}] Key '{key}' must have boolean 'locked' flag")

            expected_ph = extract_placeholders(en_entry["value"])
            actual_ph = extract_placeholders(val)
            if expected_ph != actual_ph:
                errors.append(
                    f"[{loc}] Key '{key}' placeholder mismatch: expected {sorted(expected_ph)}, got {sorted(actual_ph)}"
                )

            max_chars = en_entry.get("max_chars") or entry.get("max_chars")
            if isinstance(max_chars, int) and len(val) > max_chars:
                errors.append(
                    f"[{loc}] Key '{key}' exceeds UI max_chars budget ({len(val)} > {max_chars}): '{val}'"
                )

    return errors


def validate_bilingual_docs() -> list[str]:
    errors: list[str] = []
    if not (ROOT / "README.md").exists():
        errors.append("Missing root README.md (English)")
    if not (ROOT / "README.zh-CN.md").exists():
        errors.append("Missing root README.zh-CN.md (Simplified Chinese)")
    if not (ROOT / "LICENSE").exists():
        errors.append("Missing MIT LICENSE file")

    en_docs = {p.name for p in DOCS_EN_DIR.glob("*.md")} if DOCS_EN_DIR.exists() else set()
    zh_docs = {p.name for p in DOCS_ZH_DIR.glob("*.md")} if DOCS_ZH_DIR.exists() else set()

    if not en_docs:
        errors.append("docs/en/ has no markdown documents")
    if not zh_docs:
        errors.append("docs/zh-CN/ has no markdown documents")
    if en_docs != zh_docs:
        only_en = sorted(en_docs - zh_docs)
        only_zh = sorted(zh_docs - en_docs)
        if only_en:
            errors.append(f"docs/zh-CN/ missing mirrored files: {only_en}")
        if only_zh:
            errors.append(f"docs/en/ missing mirrored files: {only_zh}")

    return errors


def main() -> int:
    errors = validate_locales() + validate_bilingual_docs()
    if errors:
        print("i18n & bilingual docs check FAILED:", file=sys.stderr)
        for err in errors:
            print(f"  - {err}", file=sys.stderr)
        return 1

    en_count = len(json.loads((LOCALES_DIR / "en.json").read_text(encoding="utf-8"))["strings"])
    doc_count = len(list(DOCS_EN_DIR.glob("*.md")))
    print(
        f"OK: Verified {len(ALL_LOCALES)} locales ({', '.join(ALL_LOCALES)}) × {en_count} keys "
        f"with placeholder & max_chars budgets, plus {doc_count} mirrored EN/zh-CN docs."
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
