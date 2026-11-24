#!/usr/bin/env python3
"""
Zero-dependency validator for Creative Project File Framework V1.0 (CPFF v1.0).

Usage:
    python3 scripts/prj_validate.py <path/to/ProjectFolder>

Checks:
1. Locates `<ProjectName>.prj` (exact same-name match first, or unique root `*.prj` fallback).
2. Validates XML well-formedness, namespace (`urn:about-paint-tools:cpff:1.0`), and `schemaVersion="1.0"`.
3. Verifies all referenced declaration, bible, outline, edition, dictionary, locale, and chapter paths exist.
4. Verifies dialogue key parity across all declared work locales (`en`, `zh-Hans`, `zh-Hant`, `yue-Hant`, `es`)
   and ensures `locked` / `status` metadata & `maxChars` budgets are valid.
5. Verifies every bubble `dialogueKey` in `chapters/*/script/script.xml` exists in canonical dialogue locales.
6. Verifies GitHub/GitLab Git LFS rules in `.gitattributes` when `lfsEnabled="true"`.
"""

from __future__ import annotations

import sys
import xml.etree.ElementTree as ET
from pathlib import Path

NS_URI = "urn:about-paint-tools:cpff:1.0"
NS = {"c": NS_URI}
VALID_LINE_STATUSES = {"source", "auto", "tuned", "needs_review"}
VALID_CREATIVE_ENGINES = {"manga-only", "novel-only", "dual-novel-manga"}
VALID_NOVEL_ILLUSTRATION_MODES = {"none", "manga-pick", "novel-custom", "hybrid"}
VALID_PROSE_STATUSES = {"human_authoritative", "drafting", "locked"}


def resolve_prj_file(project_dir: Path) -> tuple[Path | None, str | None, str | None]:
    expected = project_dir / f"{project_dir.name}.prj"
    if expected.is_file():
        return expected, "exact", None

    candidates = sorted(project_dir.glob("*.prj"))
    if len(candidates) == 1:
        warn = (
            f"Folder '{project_dir.name}' does not match '{candidates[0].name}'; "
            f"using unique root .prj fallback (Git clone rename tolerance)."
        )
        return candidates[0], "fallback", warn
    if len(candidates) == 0:
        return None, None, f"No .prj manifest found in {project_dir}"
    return None, None, f"Ambiguous multiple .prj files in {project_dir}: {[p.name for p in candidates]}"


def check_rel_path(base: Path, rel: str | None, label: str, errors: list[str], expect_dir: bool = False) -> Path | None:
    if not rel or not rel.strip():
        errors.append(f"Missing required path attribute for {label}")
        return None
    if rel.startswith("/") or ".." in Path(rel).parts:
        errors.append(f"Path for {label} must be a safe relative POSIX path: '{rel}'")
        return None
    target = base / rel
    if expect_dir:
        if not target.is_dir():
            errors.append(f"Missing directory for {label}: {rel}")
            return None
    else:
        if not target.is_file():
            errors.append(f"Missing file for {label}: {rel}")
            return None
    return target


def check_ai_sandbox_path(
    ch_dir: Path, rel: str | None, label: str, errors: list[str], expect_dir: bool = False
) -> Path | None:
    """Enforces the hard isolation red line: AI bridge outputs MUST stay strictly under ai_assist/."""
    if not rel or not rel.strip():
        errors.append(f"Missing required AI bridge path for {label}")
        return None
    parts = Path(rel).parts
    if rel.startswith("/") or ".." in parts or not parts or parts[0] != "ai_assist":
        errors.append(
            f"AI isolation violation for {label}: path '{rel}' escapes 'ai_assist/' "
            f"(AI bridges must NEVER write into novel/prose/ or manuscript/)."
        )
        return None
    return check_rel_path(ch_dir, rel, label, errors, expect_dir=expect_dir)


def validate_project(project_dir: Path) -> tuple[list[str], list[str]]:
    errors: list[str] = []
    warnings: list[str] = []

    if not project_dir.is_dir():
        return [f"Project path is not a directory: {project_dir}"], warnings

    prj_path, mode, msg = resolve_prj_file(project_dir)
    if prj_path is None:
        return [msg or "Unable to resolve .prj file"], warnings
    if mode == "fallback" and msg:
        warnings.append(msg)

    try:
        tree = ET.parse(prj_path)
    except ET.ParseError as exc:
        return [f"Invalid XML in {prj_path.name}: {exc}"], warnings

    root = tree.getroot()
    if root.tag != f"{{{NS_URI}}}CreativeProject":
        errors.append(f"Root element must be <CreativeProject xmlns=\"{NS_URI}\">, got {root.tag}")
    if root.attrib.get("schemaVersion") != "1.0":
        errors.append(f"Unsupported schemaVersion: {root.attrib.get('schemaVersion')}")
    if not root.attrib.get("id"):
        errors.append("Missing required 'id' attribute on <CreativeProject>")

    # 1. Metadata
    meta = root.find("c:Metadata", NS)
    if meta is None:
        errors.append("Missing <Metadata> section")
    else:
        if not meta.findall("c:Title", NS):
            errors.append("<Metadata> must include at least one <Title>")
        engines_el = meta.find("c:CreativeEngines", NS)
        if engines_el is not None:
            engines_val = (engines_el.text or "").strip()
            if engines_val not in VALID_CREATIVE_ENGINES:
                errors.append(
                    f"Invalid <CreativeEngines> value '{engines_val}'; expected one of {sorted(VALID_CREATIVE_ENGINES)}"
                )

    # 2. Declarations
    decl = root.find("c:Declarations", NS)
    if decl is None:
        errors.append("Missing <Declarations> section")
    else:
        for tag, req in [("License", True), ("FormatSpec", True), ("FanworkPolicy", True), ("AiDisclosure", False)]:
            el = decl.find(f"c:{tag}", NS)
            if el is None:
                if req:
                    errors.append(f"Missing required <Declarations>/< {tag} >")
            else:
                check_rel_path(project_dir, el.attrib.get("src"), f"Declarations/{tag}", errors)
        for readme in decl.findall("c:Readme", NS):
            check_rel_path(project_dir, readme.attrib.get("src"), "Declarations/Readme", errors)

    # 3. Localization (Work Content Dictionary & Dialogue Locales)
    canonical_dialogue_keys: set[str] = set()
    loc_section = root.find("c:Localization", NS)
    if loc_section is None:
        errors.append("Missing <Localization> section")
    else:
        dict_el = loc_section.find("c:Dictionary", NS)
        if dict_el is not None:
            dict_path = check_rel_path(project_dir, dict_el.attrib.get("src"), "Localization/Dictionary", errors)
            if dict_path:
                try:
                    ET.parse(dict_path)
                except ET.ParseError as exc:
                    errors.append(f"Invalid XML in dictionary {dict_path.name}: {exc}")

        locale_els = loc_section.findall("c:SourceLocales/c:Locale", NS) + loc_section.findall(
            "c:TargetLocales/c:Locale", NS
        )
        locale_keys_map: dict[str, set[str]] = {}
        for loc_el in locale_els:
            code = loc_el.attrib.get("code", "?")
            loc_path = check_rel_path(project_dir, loc_el.attrib.get("src"), f"Locale[{code}]", errors)
            if not loc_path:
                continue
            try:
                loc_root = ET.parse(loc_path).getroot()
            except ET.ParseError as exc:
                errors.append(f"Invalid XML in locale {code}: {exc}")
                continue
            keys: set[str] = set()
            for line in loc_root.findall("c:Line", NS):
                key = line.attrib.get("key")
                status = line.attrib.get("status")
                locked = line.attrib.get("locked")
                text = (line.text or "").strip()
                if not key:
                    errors.append(f"[{code}] <Line> missing 'key'")
                    continue
                if not text:
                    errors.append(f"[{code}] Line '{key}' has empty text")
                if status not in VALID_LINE_STATUSES:
                    errors.append(f"[{code}] Line '{key}' has invalid status '{status}'")
                if locked not in {"true", "false"}:
                    errors.append(f"[{code}] Line '{key}' must set locked='true'|'false'")
                max_chars = line.attrib.get("maxChars")
                if max_chars is not None and len(text) > int(max_chars):
                    errors.append(
                        f"[{code}] Line '{key}' exceeds bubble maxChars ({len(text)} > {max_chars})"
                    )
                keys.add(key)
            locale_keys_map[code] = keys

        if "en" in locale_keys_map and "zh-Hans" in locale_keys_map:
            if locale_keys_map["en"] != locale_keys_map["zh-Hans"]:
                errors.append("Canonical work locales 'en' and 'zh-Hans' have mismatched dialogue keys")
            canonical_dialogue_keys = locale_keys_map["en"]
            for code, kset in locale_keys_map.items():
                if kset != canonical_dialogue_keys:
                    missing = sorted(canonical_dialogue_keys - kset)
                    extra = sorted(kset - canonical_dialogue_keys)
                    errors.append(f"Work locale '{code}' key mismatch (missing={missing}, extra={extra})")

    # 4. Editions
    editions = root.find("c:Editions", NS)
    if editions is None or not editions.findall("c:Edition", NS):
        errors.append("Missing <Editions> entries")
    else:
        for ed in editions.findall("c:Edition", NS):
            ed_id = ed.attrib.get("id", "?")
            ed_path = check_rel_path(project_dir, ed.attrib.get("config"), f"Edition[{ed_id}]", errors)
            if ed_path:
                try:
                    ed_root = ET.parse(ed_path).getroot()
                    ill_policy = ed_root.find("c:IllustrationPolicy", NS)
                    if ill_policy is not None:
                        ill_mode = ill_policy.attrib.get("mode")
                        if ill_mode not in VALID_NOVEL_ILLUSTRATION_MODES:
                            errors.append(
                                f"Edition[{ed_id}] invalid IllustrationPolicy mode '{ill_mode}'"
                            )
                except ET.ParseError as exc:
                    errors.append(f"Invalid XML in edition {ed_id}: {exc}")

    # 5. StoryStructure & Chapters
    story = root.find("c:StoryStructure", NS)
    if story is None:
        errors.append("Missing <StoryStructure> section")
    else:
        outline = story.find("c:Outline", NS)
        if outline is not None:
            check_rel_path(project_dir, outline.attrib.get("synopsis"), "Outline/synopsis", errors)
            check_rel_path(project_dir, outline.attrib.get("toc"), "Outline/toc", errors)
        bible = story.find("c:Bible", NS)
        if bible is not None:
            check_rel_path(project_dir, bible.attrib.get("world"), "Bible/world", errors)
            check_rel_path(project_dir, bible.attrib.get("continuity"), "Bible/continuity", errors)

        for ch in story.findall("c:Chapters/c:Chapter", NS):
            cid = ch.attrib.get("id", "?")
            ch_path = check_rel_path(project_dir, ch.attrib.get("src"), f"Chapter[{cid}]", errors)
            if not ch_path:
                continue
            ch_dir = ch_path.parent
            try:
                ch_root = ET.parse(ch_path).getroot()
            except ET.ParseError as exc:
                errors.append(f"Invalid XML in {ch_path}: {exc}")
                continue
            for sc in ch_root.findall("c:Scenes/c:Scene", NS):
                check_rel_path(ch_dir, sc.attrib.get("src"), f"Chapter[{cid}]/Scene", errors)
            script_el = ch_root.find("c:Script", NS)
            if script_el is not None:
                script_path = check_rel_path(ch_dir, script_el.attrib.get("src"), f"Chapter[{cid}]/Script", errors)
                if script_path:
                    try:
                        sc_root = ET.parse(script_path).getroot()
                        for bubble in sc_root.findall(".//c:Bubble", NS):
                            dkey = bubble.attrib.get("dialogueKey")
                            if canonical_dialogue_keys and dkey not in canonical_dialogue_keys:
                                errors.append(
                                    f"Chapter[{cid}] bubble references unknown dialogueKey '{dkey}'"
                                )
                    except ET.ParseError as exc:
                        errors.append(f"Invalid XML in {script_path}: {exc}")

            # Dual-Engine Novel Prose & Illustrations (independent human final)
            novel_el = ch_root.find("c:Novel", NS)
            if novel_el is not None:
                for prose in novel_el.findall("c:Prose", NS):
                    lang = prose.attrib.get("lang", "?")
                    p_status = prose.attrib.get("status")
                    p_locked = prose.attrib.get("locked")
                    if p_status not in VALID_PROSE_STATUSES:
                        errors.append(f"Chapter[{cid}]/Novel/Prose[{lang}] invalid status '{p_status}'")
                    if p_locked not in {"true", "false"}:
                        errors.append(f"Chapter[{cid}]/Novel/Prose[{lang}] must set locked='true'|'false'")
                    check_rel_path(ch_dir, prose.attrib.get("src"), f"Chapter[{cid}]/Novel/Prose[{lang}]", errors)
                ill_el = novel_el.find("c:Illustrations", NS)
                if ill_el is not None:
                    ill_mode = ill_el.attrib.get("mode", "hybrid")
                    if ill_mode not in VALID_NOVEL_ILLUSTRATION_MODES:
                        errors.append(f"Chapter[{cid}]/Novel/Illustrations invalid mode '{ill_mode}'")
                    check_rel_path(
                        ch_dir,
                        ill_el.attrib.get("dir"),
                        f"Chapter[{cid}]/Novel/Illustrations",
                        errors,
                        expect_dir=True,
                    )

            for page in ch_root.findall("c:Pages/c:Page", NS):
                check_rel_path(ch_dir, page.attrib.get("storyboardDir"), f"Chapter[{cid}]/storyboardDir", errors, expect_dir=True)
                check_rel_path(ch_dir, page.attrib.get("manuscriptDir"), f"Chapter[{cid}]/manuscriptDir", errors, expect_dir=True)

            ai = ch_root.find("c:AiAssist", NS)
            if ai is not None:
                cq = ai.find("c:CompletionQueue", NS)
                if cq is not None:
                    check_ai_sandbox_path(ch_dir, cq.attrib.get("src"), f"Chapter[{cid}]/CompletionQueue", errors)
                rp = ai.find("c:ReviewPins", NS)
                if rp is not None:
                    check_ai_sandbox_path(ch_dir, rp.attrib.get("src"), f"Chapter[{cid}]/ReviewPins", errors)

                m2n = ai.find("c:MangaToNovelBridge", NS)
                if m2n is not None:
                    if m2n.attrib.get("role") != "ai_reference_only":
                        errors.append(
                            f"Chapter[{cid}]/MangaToNovelBridge must enforce role='ai_reference_only', "
                            f"got '{m2n.attrib.get('role')}'"
                        )
                    meta_path = check_ai_sandbox_path(
                        ch_dir, m2n.attrib.get("meta"), f"Chapter[{cid}]/MangaToNovelBridge/meta", errors
                    )
                    if meta_path:
                        try:
                            m_root = ET.parse(meta_path).getroot()
                            if m_root.attrib.get("role") != "ai_reference_only":
                                errors.append(f"{meta_path.name} must declare role='ai_reference_only'")
                        except ET.ParseError as exc:
                            errors.append(f"Invalid XML in {meta_path}: {exc}")
                    check_ai_sandbox_path(
                        ch_dir, m2n.attrib.get("draft"), f"Chapter[{cid}]/MangaToNovelBridge/draft", errors
                    )

                n2m = ai.find("c:NovelToMangaBridge", NS)
                if n2m is not None:
                    if n2m.attrib.get("role") != "ai_reference_only":
                        errors.append(
                            f"Chapter[{cid}]/NovelToMangaBridge must enforce role='ai_reference_only', "
                            f"got '{n2m.attrib.get('role')}'"
                        )
                    meta_path = check_ai_sandbox_path(
                        ch_dir, n2m.attrib.get("meta"), f"Chapter[{cid}]/NovelToMangaBridge/meta", errors
                    )
                    if meta_path:
                        try:
                            m_root = ET.parse(meta_path).getroot()
                            if m_root.attrib.get("role") != "ai_reference_only":
                                errors.append(f"{meta_path.name} must declare role='ai_reference_only'")
                        except ET.ParseError as exc:
                            errors.append(f"Invalid XML in {meta_path}: {exc}")
                    sb_path = check_ai_sandbox_path(
                        ch_dir,
                        n2m.attrib.get("storyboard"),
                        f"Chapter[{cid}]/NovelToMangaBridge/storyboard",
                        errors,
                    )
                    if sb_path:
                        try:
                            sb_root = ET.parse(sb_path).getroot()
                            if sb_root.attrib.get("role") != "ai_reference_only":
                                errors.append(f"{sb_path.name} must declare role='ai_reference_only'")
                        except ET.ParseError as exc:
                            errors.append(f"Invalid XML in {sb_path}: {exc}")

    # 6. Git / Git LFS compatibility check
    repo = root.find("c:Repository", NS)
    if repo is not None and repo.attrib.get("lfsEnabled") == "true":
        gitattributes = project_dir / ".gitattributes"
        if not gitattributes.is_file():
            errors.append("Repository declares lfsEnabled='true' but .gitattributes is missing")
        else:
            ga_text = gitattributes.read_text(encoding="utf-8")
            for required_glob in ("*.mnga", "*.psd"):
                if required_glob not in ga_text or "filter=lfs" not in ga_text:
                    errors.append(f".gitattributes must track '{required_glob}' with Git LFS (filter=lfs)")

    return errors, warnings


def main() -> int:
    if len(sys.argv) != 2:
        print("Usage: python3 scripts/prj_validate.py <path/to/ProjectFolder>", file=sys.stderr)
        return 2

    target = Path(sys.argv[1]).resolve()
    errors, warnings = validate_project(target)

    for w in warnings:
        print(f"WARN: {w}")
    if errors:
        print(f"CPFF v1.0 validation FAILED for {target.name}:", file=sys.stderr)
        for err in errors:
            print(f"  - {err}", file=sys.stderr)
        return 1

    print(
        f"OK: Validated CPFF v1.0 creative project '{target.name}' "
        f"(XML, declarations, 5-locale dialogue, editions, dual-engine novel/manga & AI isolation, Git LFS)."
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
