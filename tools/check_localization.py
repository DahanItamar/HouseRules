#!/usr/bin/env python3
"""Fail when player-facing text bypasses the English translation catalog."""

from __future__ import annotations

import csv
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
CATALOG = ROOT / "locale" / "en.csv"
SOURCE_ROOTS = (ROOT / "src", ROOT / "data")

KEY_PATTERNS = (
    re.compile(r'\btr\(\s*"([A-Z][A-Z0-9_]*)"'),
    re.compile(r'\bset_status\(\s*"([A-Z][A-Z0-9_]*)"'),
    re.compile(r'\b_show_message\(\s*"([A-Z][A-Z0-9_]*)"'),
    re.compile(r'\bload_failed\.emit\(\s*"([A-Z][A-Z0-9_]*)"'),
    re.compile(r'\bname_key\s*=\s*"([A-Z][A-Z0-9_]*)"'),
    re.compile(r'"title_key"\s*:\s*"([A-Z][A-Z0-9_]*)"'),
    re.compile(r'"(INPUT_[A-Z0-9_]*)"'),
)
TEXT_ASSIGNMENT = re.compile(r'\.text\s*(?:\+)?=\s*"([^"\\]*(?:\\.[^"\\]*)*)"')
SCENE_TEXT = re.compile(r'^\s*text\s*=\s*"(.+)"\s*$')
NONLINGUISTIC = frozenset(" \t\\n|[]?#+·×")


def load_catalog() -> tuple[set[str], list[str]]:
    errors: list[str] = []
    keys: set[str] = set()
    with CATALOG.open(encoding="utf-8-sig", newline="") as handle:
        rows = list(csv.reader(handle))
    if not rows or rows[0] != ["keys", "en"]:
        errors.append("locale/en.csv must start with the exact header: keys,en")
        return keys, errors
    for line_number, row in enumerate(rows[1:], start=2):
        if len(row) != 2:
            errors.append(f"locale/en.csv:{line_number}: expected 2 columns")
            continue
        key, value = row
        if not key or not value:
            errors.append(f"locale/en.csv:{line_number}: key and English value must be non-empty")
        if key in keys:
            errors.append(f"locale/en.csv:{line_number}: duplicate key {key}")
        keys.add(key)
    return keys, errors


def source_files() -> list[Path]:
    files: list[Path] = []
    for source_root in SOURCE_ROOTS:
        files.extend(source_root.rglob("*.gd"))
        files.extend(source_root.rglob("*.tres"))
        files.extend(source_root.rglob("*.tscn"))
    return sorted(set(files))


def collect_references(files: list[Path]) -> tuple[set[str], list[str]]:
    references: set[str] = set()
    errors: list[str] = []
    for path in files:
        text = path.read_text(encoding="utf-8")
        for pattern in KEY_PATTERNS:
            references.update(key for key in pattern.findall(text) if not key.endswith("_"))
        if path.suffix == ".gd":
            for line_number, line in enumerate(text.splitlines(), start=1):
                for match in TEXT_ASSIGNMENT.finditer(line):
                    literal = bytes(match.group(1), "utf-8").decode("unicode_escape")
                    if literal.strip() and not set(literal).issubset(NONLINGUISTIC):
                        relative = path.relative_to(ROOT)
                        errors.append(
                            f'{relative}:{line_number}: literal UI text assignment "{literal}"'
                        )
        elif path.suffix == ".tscn":
            for line_number, line in enumerate(text.splitlines(), start=1):
                if SCENE_TEXT.match(line):
                    relative = path.relative_to(ROOT)
                    errors.append(f"{relative}:{line_number}: literal scene text")

    references.update({f"SYMBOL_{index}" for index in range(6)})
    references.update({"CARD_1", "CARD_11", "CARD_12", "CARD_13"})
    references.update({"WING_HIGH_ROLLER", "WING_VIP"})
    return references, errors


def main() -> int:
    catalog, errors = load_catalog()
    references, source_errors = collect_references(source_files())
    errors.extend(source_errors)
    for key in sorted(references - catalog):
        errors.append(f"missing English translation key: {key}")
    if errors:
        print("Localization check failed:", file=sys.stderr)
        for error in errors:
            print(f"- {error}", file=sys.stderr)
        return 1
    print(f"Localization check passed: {len(catalog)} keys, {len(references)} referenced.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
