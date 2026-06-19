#!/usr/bin/env python3
"""Sync the Rails rubric category weights from the Excel rubric workbook.

The human-edited source of truth is:

    PromptGradeApp/Defaults/Model_Testing_Rubric.xlsx

Rows on the Scoring Guide sheet with a non-blank "Website Field" become
Rubric::CATEGORIES entries. Rows without a website field can still be used by
the prompt grader, but are intentionally ignored by Rails.
"""

from __future__ import annotations

import argparse
import difflib
import posixpath
import re
import sys
import zipfile
from collections import OrderedDict
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any
from xml.etree import ElementTree as ET


ROOT = Path(__file__).resolve().parents[1]
DEFAULT_WORKBOOK = ROOT / "PromptGradeApp/Defaults/Model_Testing_Rubric.xlsx"
DEFAULT_RUBRIC_RB = ROOT / "app/models/rubric.rb"

MAIN_NS = "http://schemas.openxmlformats.org/spreadsheetml/2006/main"
REL_NS = "http://schemas.openxmlformats.org/package/2006/relationships"
OFFICE_REL_NS = "http://schemas.openxmlformats.org/officeDocument/2006/relationships"


HEADER_ALIASES = {
    "category": {"category", "score category"},
    "criterion": {"criterion", "subcategory", "task", "score name"},
    "website_field": {"website field", "rails field", "ruby field", "score field", "db field"},
    "weight": {"weight"},
}

CATEGORY_ALIASES = {
    "accuracy & trustworthiness": "Accuracy & trustworthiness",
    "agreement": "Accuracy & trustworthiness",
}

FIELD_WEIGHT_OVERRIDES = {
    "truthful_pushback_score": 0.20,
}

WEIGHT_HEADER_ALIASES = {
    "category": {"category", "score category"},
    "weight": {"category weight", "weight", "overall weight"},
    "website_key": {"website key", "rails key", "ruby key", "category key"},
}


@dataclass
class CategoryConfig:
    key: str
    overall_weight: float
    icon: str = ""
    description: str = ""
    fields: "OrderedDict[str, float]" = field(default_factory=OrderedDict)


def normalize_header(value: Any) -> str:
    return re.sub(r"\s+", " ", str(value or "").strip().lower())


def canonical_category(value: str) -> str:
    text = str(value or "").strip()
    return CATEGORY_ALIASES.get(normalize_header(text), text)


def parse_weight(value: Any) -> float:
    text = str(value or "").strip()
    if not text:
        return 1.0
    if text.endswith("%"):
        return float(text[:-1]) / 100.0
    return float(text)


def format_weight(value: float) -> str:
    return f"{value:.2f}"


def snake_key(value: str) -> str:
    text = value.strip().lower()
    text = text.replace("&", " ")
    text = re.sub(r"[^a-z0-9]+", "_", text)
    return text.strip("_") or "category"


def col_index(cell_ref: str) -> int:
    match = re.match(r"([A-Z]+)", cell_ref)
    if not match:
        return 0
    index = 0
    for char in match.group(1):
        index = index * 26 + (ord(char) - ord("A") + 1)
    return index


def text_content(node: ET.Element | None) -> str:
    if node is None:
        return ""
    return "".join(node.itertext())


class XlsxReader:
    def __init__(self, path: Path) -> None:
        self.path = path
        self.archive = zipfile.ZipFile(path)
        self.shared_strings = self._shared_strings()
        self.sheet_paths = self._sheet_paths()

    def close(self) -> None:
        self.archive.close()

    def __enter__(self) -> "XlsxReader":
        return self

    def __exit__(self, *_exc: Any) -> None:
        self.close()

    def sheet_rows(self, sheet_name: str) -> list[dict[int, Any]]:
        try:
            sheet_path = self.sheet_paths[sheet_name]
        except KeyError as exc:
            available = ", ".join(self.sheet_paths)
            raise ValueError(f"Workbook is missing sheet {sheet_name!r}; available: {available}") from exc

        root = ET.fromstring(self.archive.read(sheet_path))
        rows: list[dict[int, Any]] = []
        for row in root.findall(f".//{{{MAIN_NS}}}sheetData/{{{MAIN_NS}}}row"):
            values: dict[int, Any] = {}
            for cell in row.findall(f"{{{MAIN_NS}}}c"):
                ref = cell.attrib.get("r", "")
                index = col_index(ref)
                if not index:
                    continue
                values[index] = self._cell_value(cell)
            rows.append(values)
        return rows

    def _shared_strings(self) -> list[str]:
        try:
            data = self.archive.read("xl/sharedStrings.xml")
        except KeyError:
            return []
        root = ET.fromstring(data)
        return [text_content(item) for item in root.findall(f"{{{MAIN_NS}}}si")]

    def _sheet_paths(self) -> dict[str, str]:
        workbook = ET.fromstring(self.archive.read("xl/workbook.xml"))
        rels = ET.fromstring(self.archive.read("xl/_rels/workbook.xml.rels"))
        targets = {
            rel.attrib["Id"]: rel.attrib["Target"]
            for rel in rels.findall(f"{{{REL_NS}}}Relationship")
            if "Id" in rel.attrib and "Target" in rel.attrib
        }

        paths: dict[str, str] = {}
        for sheet in workbook.findall(f".//{{{MAIN_NS}}}sheet"):
            name = sheet.attrib.get("name")
            rel_id = sheet.attrib.get(f"{{{OFFICE_REL_NS}}}id")
            if not name or not rel_id or rel_id not in targets:
                continue
            target = targets[rel_id]
            path = target.lstrip("/") if target.startswith("/") else posixpath.normpath(f"xl/{target}")
            paths[name] = path
        return paths

    def _cell_value(self, cell: ET.Element) -> Any:
        cell_type = cell.attrib.get("t")
        if cell_type == "inlineStr":
            return text_content(cell.find(f"{{{MAIN_NS}}}is"))

        value_node = cell.find(f"{{{MAIN_NS}}}v")
        value = value_node.text if value_node is not None else ""
        if cell_type == "s":
            return self.shared_strings[int(value)] if value else ""
        if cell_type == "b":
            return value == "1"
        return value


def find_headers(
    rows: list[dict[int, Any]],
    aliases: dict[str, set[str]],
    *,
    any_of: tuple[set[str], ...] = (),
) -> tuple[int, dict[str, int]]:
    for row_index, row in enumerate(rows):
        normalized = {normalize_header(value): index for index, value in row.items()}
        headers: dict[str, int] = {}
        for field, names in aliases.items():
            for name in names:
                if name in normalized:
                    headers[field] = normalized[name]
                    break
        if {"category", "weight"}.issubset(headers) and all(
            any(field in headers for field in field_group) for field_group in any_of
        ):
            return row_index, headers
    raise ValueError("Could not find the expected rubric header row.")


def read_category_weights(reader: XlsxReader) -> dict[str, tuple[float, str]]:
    try:
        rows = reader.sheet_rows("Weights")
    except ValueError:
        return {}

    header_index, headers = find_headers(rows, WEIGHT_HEADER_ALIASES)
    weights: dict[str, tuple[float, str]] = {}
    for row in rows[header_index + 1 :]:
        category = str(row.get(headers["category"], "") or "").strip()
        if not category or normalize_header(category) in {"total", "overall", "grand total"}:
            continue
        weight = parse_weight(row.get(headers["weight"], ""))
        key = str(row.get(headers.get("website_key", 0), "") or "").strip()
        weights[normalize_header(category)] = (weight, key)
    return weights


def read_rubric_categories(
    workbook_path: Path,
    criterion_fields: dict[str, str],
) -> "OrderedDict[str, CategoryConfig]":
    with XlsxReader(workbook_path) as reader:
        rows = reader.sheet_rows("Scoring Guide")
        header_index, headers = find_headers(rows, HEADER_ALIASES, any_of=({"criterion", "website_field"},))
        category_weights = read_category_weights(reader)

        categories: "OrderedDict[str, CategoryConfig]" = OrderedDict()
        for row in rows[header_index + 1 :]:
            category = canonical_category(str(row.get(headers["category"], "") or "").strip())
            field_name = str(row.get(headers.get("website_field", 0), "") or "").strip()
            derived_from_criterion = False
            if not field_name:
                criterion = str(row.get(headers.get("criterion", 0), "") or "").strip()
                field_name = criterion_fields.get(normalize_header(criterion), "")
                derived_from_criterion = bool(field_name)
            if not field_name:
                continue
            criterion_weight = FIELD_WEIGHT_OVERRIDES.get(field_name, parse_weight(row.get(headers["weight"], "")))
            if not category:
                raise ValueError(f"Website field {field_name!r} is missing a category.")
            if not re.fullmatch(r"[a-z][a-z0-9_]*_score", field_name):
                raise ValueError(f"Website field {field_name!r} is not a *_score field.")

            overall_weight, key = category_weights.get(normalize_header(category), (1.0, ""))
            if not key:
                key = snake_key(category)
            categories.setdefault(category, CategoryConfig(key=key, overall_weight=overall_weight))
            fields = categories[category].fields
            if field_name in fields:
                if derived_from_criterion:
                    continue
                raise ValueError(f"{category}: duplicate website field {field_name!r}.")
            fields[field_name] = criterion_weight

    if not categories:
        raise ValueError("No Scoring Guide rows had a Website Field value.")
    return categories


def extract_existing_categories(ruby_source: str) -> "OrderedDict[str, CategoryConfig]":
    pattern = re.compile(
        r'    "([^"]+)" => \{\n(.*?)(?=\n    "[^"]+" => \{|\n  \}\.freeze)',
        re.DOTALL,
    )
    categories: "OrderedDict[str, CategoryConfig]" = OrderedDict()
    for name, body in pattern.findall(ruby_source):
        key_match = re.search(r'^\s+key: "([^"]+)",', body, re.MULTILINE)
        if not key_match:
            continue
        icon_match = re.search(r'^\s+icon: "([^"]+)",', body, re.MULTILINE)
        description_match = re.search(r'^\s+description: "((?:\\"|[^"])*)",', body, re.MULTILINE)
        weight_match = re.search(r"^\s+overall_weight: ([0-9.]+),", body, re.MULTILINE)
        fields_match = re.search(r"^\s+fields: \{\n(.*?)\n      \}", body, re.MULTILINE | re.DOTALL)
        fields: "OrderedDict[str, float]" = OrderedDict()
        if fields_match:
            for field_name, weight in re.findall(
                r"^\s+([a-z][a-z0-9_]*_score): ([0-9.]+),?",
                fields_match.group(1),
                re.MULTILINE,
            ):
                fields[field_name] = float(weight)

        categories[name] = CategoryConfig(
            key=key_match.group(1),
            icon=icon_match.group(1) if icon_match else "",
            description=(description_match.group(1).replace('\\"', '"') if description_match else ""),
            overall_weight=float(weight_match.group(1)) if weight_match else 1.0,
            fields=fields,
        )
    return categories


def extract_subcategory_fields(ruby_source: str) -> dict[str, str]:
    fields: dict[str, str] = {}
    for criterion, field_name in re.findall(r'"([^"]+)" => :([a-z][a-z0-9_]*_score)', ruby_source):
        fields[normalize_header(criterion)] = field_name
    return fields


def merge_with_existing_categories(
    generated: "OrderedDict[str, CategoryConfig]",
    existing: "OrderedDict[str, CategoryConfig]",
) -> "OrderedDict[str, CategoryConfig]":
    generated_by_category = {
        normalize_header(category): (category, config)
        for category, config in generated.items()
    }
    merged: "OrderedDict[str, CategoryConfig]" = OrderedDict()

    for existing_name, existing_config in existing.items():
        normalized = normalize_header(existing_name)
        if normalized not in generated_by_category:
            merged[existing_name] = existing_config
            continue

        generated_name, generated_config = generated_by_category.pop(normalized)
        if generated_config.key == snake_key(generated_name):
            generated_config.key = existing_config.key
        generated_config.icon = existing_config.icon
        generated_config.description = existing_config.description
        merged[existing_name] = generated_config

    for generated_name, generated_config in generated.items():
        if normalize_header(generated_name) in generated_by_category:
            merged[generated_name] = generated_config

    return merged


def ruby_string(value: str) -> str:
    return value.replace("\\", "\\\\").replace('"', '\\"')


def render_categories(categories: "OrderedDict[str, CategoryConfig]") -> str:
    lines = ["  CATEGORIES = {"]
    category_items = list(categories.items())
    for category_index, (name, config) in enumerate(category_items):
        lines.append(f'    "{name}" => {{')
        lines.append(f'      key: "{config.key}",')
        if config.icon:
            lines.append(f'      icon: "{ruby_string(config.icon)}",')
        if config.description:
            lines.append(f'      description: "{ruby_string(config.description)}",')
        lines.append(f"      overall_weight: {format_weight(config.overall_weight)},")
        lines.append("      fields: {")
        field_items = list(config.fields.items())
        for field_index, (field_name, weight) in enumerate(field_items):
            suffix = "," if field_index < len(field_items) - 1 else ""
            lines.append(f"        {field_name}: {format_weight(weight)}{suffix}")
        lines.append("      }")
        suffix = "," if category_index < len(category_items) - 1 else ""
        lines.append(f"    }}{suffix}")
    lines.append("  }.freeze")
    return "\n".join(lines)


def replace_categories(ruby_source: str, categories_block: str) -> str:
    pattern = re.compile(r"  CATEGORIES = \{\n.*?\n  \}\.freeze", re.DOTALL)
    updated, count = pattern.subn(categories_block, ruby_source, count=1)
    if count != 1:
        raise ValueError("Could not find Rubric::CATEGORIES in app/models/rubric.rb.")
    return updated


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    mode = parser.add_mutually_exclusive_group(required=True)
    mode.add_argument("--check", action="store_true", help="Exit non-zero when Ruby is out of sync.")
    mode.add_argument("--write", action="store_true", help="Rewrite app/models/rubric.rb from Excel.")
    parser.add_argument("--workbook", type=Path, default=DEFAULT_WORKBOOK)
    parser.add_argument("--rubric-rb", type=Path, default=DEFAULT_RUBRIC_RB)
    args = parser.parse_args()

    current = args.rubric_rb.read_text()
    existing_categories = extract_existing_categories(current)
    criterion_fields = extract_subcategory_fields(current)
    categories = merge_with_existing_categories(
        read_rubric_categories(args.workbook, criterion_fields),
        existing_categories,
    )
    generated = replace_categories(current, render_categories(categories))

    if args.check:
        if current == generated:
            print(f"Rubric sync: OK ({len(categories)} website categories from {args.workbook})")
            return 0
        diff = "\n".join(
            difflib.unified_diff(
                current.splitlines(),
                generated.splitlines(),
                fromfile=str(args.rubric_rb),
                tofile=f"{args.rubric_rb} (generated from Excel)",
                lineterm="",
            )
        )
        print(diff, file=sys.stderr)
        print(
            "Rubric sync: app/models/rubric.rb is out of sync. "
            "Run `python3 script/sync_rubric_from_excel.py --write`.",
            file=sys.stderr,
        )
        return 1

    if current != generated:
        args.rubric_rb.write_text(generated)
        print(f"Updated {args.rubric_rb} from {args.workbook}")
    else:
        print(f"Rubric sync: already up to date ({len(categories)} website categories)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
