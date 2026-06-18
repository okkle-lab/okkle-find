#!/usr/bin/env python3
"""Run the model prompt-test workbook against configured chat models.

The runner intentionally uses a conservative, portable API surface:
OpenAI-compatible /chat/completions endpoints via urllib, plus openpyxl for
reading and writing the workbook-derived outputs.
"""

from __future__ import annotations

import argparse
import base64
import csv
import datetime as dt
import difflib
import json
import mimetypes
import os
import re
import sys
import time
import traceback
import urllib.error
import urllib.request
import uuid
from dataclasses import dataclass
from pathlib import Path
from typing import Any, Iterable

try:
    from openpyxl import Workbook, load_workbook
    from openpyxl.styles import Alignment, Font, PatternFill
    from openpyxl.utils import get_column_letter
except ImportError as exc:  # pragma: no cover - exercised by user environment
    print(
        "Missing dependency: openpyxl. Install it with "
        "`python3 -m pip install openpyxl`.",
        file=sys.stderr,
    )
    raise SystemExit(2) from exc


HEADER_ALIASES = {
    "test_id": ["TESTID", "Test ID", "TestID", "Test Id", "ID"],
    "category": ["Category"],
    "criterion": ["Criterion"],
    "weight": ["Weight"],
    "eval_method": ["Eval Method", "Type", "Test Type", "Prompt Type", "Output Type"],
    "applies_to": ["Applies To"],
    "prompt": ["Prompt", "Benchmark Prompt"],
    "input_material": [
        "Additional source information",
        "Additional Source Information",
        "Additional Source Info",
        "Source Information",
        "Input Material",
    ],
}

REQUIRED_PROMPT_FIELDS = {"test_id", "prompt"}
OPTIONAL_PROMPT_DEFAULTS = {
    "category": "",
    "criterion": "",
    "weight": 1.0,
    "eval_method": "",
    "applies_to": "",
    "input_material": "",
}
MODEL_HEADER_ALIASES = {
    "key": ["Model Key", "Key", "ID", "Model ID Key", "model_id_string"],
    "name": ["Model Name", "Name", "Display Name", "name"],
    "model": [
        "OpenRouter Model ID",
        "API Model ID",
        "Provider Model ID",
        "Model ID",
        "Model",
        "Provider Model",
        "API Model",
        "model_id_string",
    ],
    "product": ["Product", "Tool", "Tool Name", "tool_name"],
    "provider": ["Provider", "Provider Key"],
    "provider_type": ["Provider Type", "Type"],
    "base_url": ["Base URL", "Endpoint", "API Base URL"],
    "api_key_env": ["API Key Env", "API Key Environment Variable", "Key Env"],
    "capabilities": ["Capabilities", "Capability", "Mode"],
    "enabled": ["Enabled", "Run", "Include"],
}
REQUIRED_MODEL_FIELDS = {"model"}
MANUAL_PROMPT_MARKERS = ("reviewer assessment",)
IMAGE_EDIT_PROMPT_MARKERS = (
    "replace ",
    "edit ",
    "modify ",
    "change ",
    "remove ",
    "retouch ",
    "restore ",
    "recolor ",
)
CSV_COLUMNS = [
    "run_id",
    "timestamp",
    "model_key",
    "model_name",
    "provider",
    "provider_model",
    "test_id",
    "category",
    "criterion",
    "weight",
    "eval_method",
    "prompt_source",
    "input_source",
    "output_type",
    "response",
    "output_files",
    "output_urls",
    "score",
    "reasoning",
    "latency_seconds",
    "usage",
    "error",
]


@dataclass(frozen=True)
class PromptTest:
    row_number: int
    test_id: str
    category: str
    criterion: str
    weight: float
    eval_method: str
    applies_to: str
    prompt: str
    input_material: str
    prompt_source: str = "cell"
    input_source: str = "cell"


@dataclass
class SkippedTest:
    test_id: str
    category: str
    criterion: str
    eval_method: str
    reason: str


class CreditLimitError(RuntimeError):
    """Provider says the account/key cannot afford the requested call."""


class RateLimitError(RuntimeError):
    """Provider rejected the request because a rate or usage limit was hit."""


def clean_text(value: Any) -> str:
    if value is None:
        return ""
    return str(value).strip()


def normalized(value: str) -> str:
    return value.strip().lower().replace("—", "-").replace("–", "-")


def normalized_header(value: str) -> str:
    return re.sub(r"[^a-z0-9]+", "", value.strip().lower())


def image_id(test_id: str) -> bool:
    value = test_id.strip().upper()
    return value.startswith(("IG", "IMG", "IMAGE"))


def evidence_id(test_id: str) -> bool:
    value = test_id.strip().upper()
    return value.startswith(("P&", "E"))


def is_image_test(test: PromptTest) -> bool:
    category = normalized(test.category)
    eval_method = normalized(test.eval_method)
    return (
        category == "image generation"
        or "image" in eval_method
        or image_id(test.test_id)
    )


def is_image_edit_test(test: PromptTest) -> bool:
    if not is_image_test(test):
        return False
    criterion = normalized(test.criterion)
    eval_method = normalized(test.eval_method)
    prompt = normalized(test.prompt)
    return (
        criterion == "image editing"
        or "image edit" in eval_method
        or prompt.startswith(IMAGE_EDIT_PROMPT_MARKERS)
    )


def parse_weight(value: Any) -> float:
    if value is None or value == "":
        return 1.0
    try:
        return float(value)
    except (TypeError, ValueError):
        return 1.0


def load_json(path: Path) -> dict[str, Any]:
    with path.open("r", encoding="utf-8") as handle:
        return json.load(handle)


def default_config() -> dict[str, Any]:
    return {
        "providers": {
            "openrouter": {
                "type": "openai_compatible",
                "base_url": "https://openrouter.ai/api/v1",
                "api_key_env": "OPENROUTER_API_KEY",
                "extra_headers": {"X-Title": "AI Finder Model Evaluation"},
            },
            "openai": {
                "type": "openai_compatible",
                "base_url": "https://api.openai.com/v1",
                "api_key_env": "OPENAI_API_KEY",
                "max_tokens_param": "max_completion_tokens",
            },
            "openai_images": {
                "type": "openai_image_generation",
                "base_url": "https://api.openai.com/v1",
                "api_key_env": "OPENAI_API_KEY",
                "request": {
                    "image_count": 1,
                    "size": "1024x1024",
                    "timeout_seconds": 180,
                },
            },
        },
        "request": {
            "temperature": 0.2,
            "max_tokens": 1800,
            "timeout_seconds": 120,
            "retries": 2,
            "sleep_seconds": 0.5,
        },
        "models": [],
        "judge": {"enabled": False},
    }


def truthy(value: Any, default: bool = True) -> bool:
    text = clean_text(value).lower()
    if not text:
        return default
    return text in {"1", "true", "yes", "y", "run", "include", "enabled"}


def parse_capabilities(value: Any, provider: str, provider_type: str) -> list[str]:
    text = clean_text(value)
    if text:
        parts = re.split(r"[,;/|]+", text)
        capabilities = [normalized(part) for part in parts if clean_text(part)]
        if "both" in capabilities:
            return ["text", "image"]
        return capabilities
    if provider_type == "openai_image_generation" or "image" in normalized(provider):
        return ["image"]
    return ["text"]


def looks_like_audio_model(product: str, name: str, model_id: str) -> bool:
    haystack = normalized(" ".join([product, name, model_id]))
    return (
        "whisper" in haystack
        or model_id in {"large-v3", "large-v3-turbo", "small", "tiny"}
    )


def looks_like_openai_text_model(product: str, name: str, model_id: str) -> bool:
    haystack = normalized(" ".join([product, name, model_id]))
    return (
        "chatgpt" in haystack
        or "openai" in haystack
        or model_id.startswith(("gpt-", "o1", "o3", "o4"))
        or model_id.startswith("openai/")
    )


def openai_api_model_id(model_id: str) -> str:
    return model_id.removeprefix("openai/")


def unique_key(base: str, used: set[str]) -> str:
    root = safe_filename(base).lower() or "model"
    key = root
    index = 2
    while key in used:
        key = f"{root}-{index}"
        index += 1
    used.add(key)
    return key


def model_cell(ws: Any, row_number: int, columns: dict[str, int], field: str) -> Any:
    column = columns.get(field)
    return ws.cell(row_number, column).value if column else ""


def header_column_positions(ws: Any, header_row: int, aliases: list[str]) -> list[int]:
    values = [clean_text(cell.value) for cell in ws[header_row]]
    normalized_values = {
        normalized_header(value): index + 1
        for index, value in enumerate(values)
        if value
    }

    positions: list[int] = []
    for alias in aliases:
        column = normalized_values.get(normalized_header(alias))
        if column and column not in positions:
            positions.append(column)
    return positions


def first_non_empty_cell(ws: Any, row_number: int, columns: Iterable[int]) -> str:
    for column in columns:
        value = clean_text(ws.cell(row_number, column).value)
        if value:
            return value
    return ""


def workbook_defaults_to_openai(
    ws: Any,
    header_row: int,
    columns: dict[str, int],
    direct_model_columns: list[int],
    model_columns: list[int],
) -> bool:
    has_candidate = False
    for row_number in range(header_row + 1, ws.max_row + 1):
        provider = clean_text(model_cell(ws, row_number, columns, "provider"))
        provider_type = clean_text(model_cell(ws, row_number, columns, "provider_type"))
        capabilities_cell = model_cell(ws, row_number, columns, "capabilities")
        if provider or provider_type or clean_text(capabilities_cell):
            continue

        direct_model_id = first_non_empty_cell(ws, row_number, direct_model_columns)
        any_model_id = first_non_empty_cell(ws, row_number, model_columns)
        model_id = direct_model_id or any_model_id
        if not model_id:
            continue

        has_candidate = True
        name = clean_text(model_cell(ws, row_number, columns, "name"))
        product = clean_text(model_cell(ws, row_number, columns, "product"))
        if not looks_like_openai_text_model(product, name, model_id):
            return False

    return has_candidate


def read_model_workbook(models_path: Path, base_config: dict[str, Any]) -> dict[str, Any]:
    wb = load_workbook(models_path, data_only=True)
    ws = wb[wb.sheetnames[0]]
    header_row, columns = find_header_row(ws, MODEL_HEADER_ALIASES, REQUIRED_MODEL_FIELDS)
    config = dict(base_config)
    config["providers"] = dict(base_config.get("providers", {}))
    config["models"] = []

    model_columns = header_column_positions(ws, header_row, MODEL_HEADER_ALIASES["model"])
    direct_model_columns = header_column_positions(ws, header_row, ["model_id_string"])
    default_text_provider = (
        "openai"
        if workbook_defaults_to_openai(
            ws, header_row, columns, direct_model_columns, model_columns
        )
        else "openrouter"
    )

    used_keys: set[str] = set()
    for row_number in range(header_row + 1, ws.max_row + 1):
        provider = clean_text(model_cell(ws, row_number, columns, "provider"))
        provider_type = clean_text(model_cell(ws, row_number, columns, "provider_type"))
        capabilities_cell = model_cell(ws, row_number, columns, "capabilities")
        raw_model_id = clean_text(model_cell(ws, row_number, columns, "model"))
        direct_model_id = first_non_empty_cell(ws, row_number, direct_model_columns)
        model_id = raw_model_id
        if not model_id and (provider or provider_type or clean_text(capabilities_cell)):
            model_id = first_non_empty_cell(ws, row_number, model_columns)
        if not model_id:
            continue

        name = clean_text(model_cell(ws, row_number, columns, "name")) or model_id
        product = clean_text(model_cell(ws, row_number, columns, "product"))
        if not clean_text(capabilities_cell) and looks_like_audio_model(product, name, model_id):
            capabilities = ["audio"]
        else:
            capabilities = parse_capabilities(capabilities_cell, provider, provider_type)
        if not provider:
            provider = "openai_images" if "image" in capabilities else default_text_provider
        if provider == "openai" and direct_model_id:
            model_id = direct_model_id
        if provider == "openai":
            model_id = openai_api_model_id(model_id)

        base_url = clean_text(model_cell(ws, row_number, columns, "base_url"))
        api_key_env = clean_text(model_cell(ws, row_number, columns, "api_key_env"))
        if base_url or api_key_env or provider_type:
            provider_config = dict(config["providers"].get(provider, {}))
            if provider_type:
                provider_config["type"] = provider_type
            elif "type" not in provider_config:
                provider_config["type"] = (
                    "openai_image_generation"
                    if "image" in capabilities
                    else "openai_compatible"
                )
            if base_url:
                provider_config["base_url"] = base_url
            if api_key_env:
                provider_config["api_key_env"] = api_key_env
            config["providers"][provider] = provider_config

        explicit_key = clean_text(model_cell(ws, row_number, columns, "key"))
        key = unique_key(explicit_key or name or model_id, used_keys)
        enabled = truthy(model_cell(ws, row_number, columns, "enabled"), default=True)
        config["models"].append(
            {
                "key": key,
                "name": name,
                "provider": provider,
                "model": model_id,
                "capabilities": capabilities,
                "enabled": enabled,
            }
        )

    if not config["models"]:
        raise ValueError("The models spreadsheet did not contain any model rows.")
    return config


def find_header_row(
    ws: Any,
    aliases: dict[str, list[str]],
    required_fields: set[str],
    max_scan_rows: int = 20,
) -> tuple[int, dict[str, int]]:
    for row_number in range(1, min(ws.max_row, max_scan_rows) + 1):
        values = [clean_text(cell.value) for cell in ws[row_number]]
        normalized_values = {
            normalized_header(value): index + 1
            for index, value in enumerate(values)
            if value
        }

        positions: dict[str, int] = {}
        for field, field_aliases in aliases.items():
            for alias in field_aliases:
                normalized_alias = normalized_header(alias)
                if normalized_alias in normalized_values:
                    positions[field] = normalized_values[normalized_alias]
                    break

        if required_fields.issubset(positions.keys()):
            return row_number, positions

    required = ", ".join(sorted(required_fields))
    raise ValueError(f"Could not find a header row containing: {required}")


def cell_value(ws: Any, row_number: int, columns: dict[str, int], field: str) -> Any:
    column = columns.get(field)
    if not column:
        return OPTIONAL_PROMPT_DEFAULTS.get(field, "")
    return ws.cell(row_number, column).value


def read_prompt_library(
    workbook_path: Path,
    sheet_name: str,
    inherit_shorthand: bool,
) -> list[PromptTest]:
    wb = load_workbook(workbook_path, data_only=True)
    if sheet_name not in wb.sheetnames:
        if sheet_name == "Test Prompts":
            sheet_name = wb.sheetnames[0]
        else:
            raise ValueError(
                f"Sheet {sheet_name!r} not found. Available sheets: {', '.join(wb.sheetnames)}"
            )

    ws = wb[sheet_name]
    header_row, columns = find_header_row(ws, HEADER_ALIASES, REQUIRED_PROMPT_FIELDS)
    tests: list[PromptTest] = []
    last_prompt = ""
    last_input = ""

    for row_number in range(header_row + 1, ws.max_row + 1):
        test_id = clean_text(ws.cell(row_number, columns["test_id"]).value)
        if not test_id:
            continue

        prompt = clean_text(cell_value(ws, row_number, columns, "prompt"))
        input_material = clean_text(cell_value(ws, row_number, columns, "input_material"))
        prompt_source = "cell"
        input_source = "cell"

        if inherit_shorthand and not prompt and last_prompt:
            prompt = last_prompt
            prompt_source = "inherited"
        if inherit_shorthand and input_material == "^" and last_input:
            input_material = last_input
            input_source = "inherited"

        if clean_text(ws.cell(row_number, columns["prompt"]).value):
            last_prompt = prompt
        if input_material and input_source == "cell" and input_material != "^":
            last_input = input_material

        category = clean_text(cell_value(ws, row_number, columns, "category"))
        criterion = clean_text(cell_value(ws, row_number, columns, "criterion"))
        eval_method = clean_text(cell_value(ws, row_number, columns, "eval_method"))
        if not eval_method and image_id(test_id):
            eval_method = "Prompt - Image"
        elif not eval_method:
            eval_method = "Prompt - Text"
        if not category and image_id(test_id):
            category = "Image Generation"
        elif not category:
            category = "Text"

        tests.append(
            PromptTest(
                row_number=row_number,
                test_id=test_id,
                category=category,
                criterion=criterion,
                weight=parse_weight(cell_value(ws, row_number, columns, "weight")),
                eval_method=eval_method,
                applies_to=clean_text(cell_value(ws, row_number, columns, "applies_to")),
                prompt=prompt,
                input_material=input_material,
                prompt_source=prompt_source,
                input_source=input_source,
            )
        )

    return tests


def skip_reason(test: PromptTest, args: argparse.Namespace) -> str | None:
    category = normalized(test.category)
    eval_method = normalized(test.eval_method)
    prompt = normalized(test.prompt)

    if not test.prompt:
        return "missing prompt"
    if not args.include_image and is_image_test(test):
        return "image prompt skipped"
    if args.include_image and is_image_edit_test(test) and not test.input_material:
        return "image edit skipped; no source image path in input material"
    if not args.include_evidence and (
        eval_method == "evidence review"
        or category in {"privacy & data safety", "enterprise"}
        or evidence_id(test.test_id)
    ):
        return "evidence/security review skipped"
    if not args.include_manual_review and any(
        marker in prompt for marker in MANUAL_PROMPT_MARKERS
    ):
        return "manual reviewer assessment skipped"
    if not args.include_manual_review and normalized(test.applies_to).startswith(
        "per product"
    ):
        return "product-level manual review skipped"
    return None


def split_filter(value: str | None) -> set[str]:
    if not value:
        return set()
    return {part.strip() for part in value.split(",") if part.strip()}


def eligible_tests(
    tests: Iterable[PromptTest],
    args: argparse.Namespace,
) -> tuple[list[PromptTest], list[SkippedTest]]:
    only_tests = split_filter(args.only_tests)
    selected: list[PromptTest] = []
    skipped: list[SkippedTest] = []

    for test in tests:
        if only_tests and test.test_id not in only_tests:
            continue

        reason = skip_reason(test, args)
        if reason:
            skipped.append(
                SkippedTest(
                    test_id=test.test_id,
                    category=test.category,
                    criterion=test.criterion,
                    eval_method=test.eval_method,
                    reason=reason,
                )
            )
            continue

        selected.append(test)

    if args.limit is not None:
        limited = selected[: args.limit]
        skipped.extend(
            SkippedTest(
                test_id=test.test_id,
                category=test.category,
                criterion=test.criterion,
                eval_method=test.eval_method,
                reason="outside --limit",
            )
            for test in selected[args.limit :]
        )
        selected = limited

    return selected, skipped


def enabled_models(config: dict[str, Any], only_models: str | None) -> list[dict[str, Any]]:
    selected_keys = split_filter(only_models)
    models = [
        model
        for model in config.get("models", [])
        if model.get("enabled", True) and (not selected_keys or model.get("key") in selected_keys)
    ]
    if selected_keys:
        missing = selected_keys - {model.get("key") for model in models}
        if missing:
            raise ValueError(f"Requested model key(s) not enabled/found: {', '.join(sorted(missing))}")
    return models


def provider_for(config: dict[str, Any], model: dict[str, Any]) -> dict[str, Any]:
    providers = config.get("providers", {})
    provider_key = model.get("provider")
    provider = providers.get(provider_key)
    if not provider:
        raise ValueError(f"Unknown provider {provider_key!r} for model {model.get('key')!r}.")
    return provider


def model_capabilities(config: dict[str, Any], model: dict[str, Any]) -> set[str]:
    configured = model.get("capabilities")
    if configured:
        if isinstance(configured, str):
            configured = [configured]
        return {normalized(str(capability)) for capability in configured}

    provider = provider_for(config, model)
    provider_type = provider.get("type", "openai_compatible")
    if provider_type == "openai_image_generation":
        return {"image"}
    return {"text"}


def model_supports_test(config: dict[str, Any], model: dict[str, Any], test: PromptTest) -> bool:
    required = "image" if is_image_test(test) else "text"
    capabilities = model_capabilities(config, model)
    return required in capabilities or "both" in capabilities


def planned_pairs(
    config: dict[str, Any],
    models: list[dict[str, Any]],
    tests: list[PromptTest],
) -> list[tuple[dict[str, Any], PromptTest]]:
    return [
        (model, test)
        for model in models
        for test in tests
        if model_supports_test(config, model, test)
    ]


def unsupported_tests(
    config: dict[str, Any],
    models: list[dict[str, Any]],
    tests: list[PromptTest],
) -> list[PromptTest]:
    return [
        test
        for test in tests
        if not any(model_supports_test(config, model, test) for model in models)
    ]


def required_api_key_envs(
    config: dict[str, Any],
    pairs: list[tuple[dict[str, Any], PromptTest]],
) -> set[str]:
    envs: set[str] = set()
    for model, _test in pairs:
        provider = provider_for(config, model)
        env_name = clean_text(provider.get("api_key_env"))
        if env_name:
            envs.add(env_name)
    return envs


def validate_api_keys(
    config: dict[str, Any],
    pairs: list[tuple[dict[str, Any], PromptTest]],
) -> None:
    missing = sorted(
        env_name for env_name in required_api_key_envs(config, pairs) if not os.getenv(env_name)
    )
    if missing:
        raise ValueError(
            "Missing API key environment variable(s): "
            f"{', '.join(missing)}. "
            "Use Dry Run to validate without API calls, enter the key in the SwiftUI app, "
            "or export it before running the CLI."
        )


def openrouter_model_catalogue(base_url: str) -> set[str]:
    url = f"{base_url.rstrip('/')}/models"
    with urllib.request.urlopen(url, timeout=30) as response:
        payload = json.loads(response.read().decode("utf-8"))
    return {
        clean_text(item.get("id"))
        for item in payload.get("data", [])
        if clean_text(item.get("id"))
    }


def openrouter_provider(provider: dict[str, Any]) -> bool:
    return "openrouter.ai" in str(provider.get("base_url", "")).lower()


def dot_version_variants(model_id: str) -> list[str]:
    variants = {model_id}
    variants.add(re.sub(r"-(\d+)-(\d+)$", r"-\1.\2", model_id))
    variants.add(re.sub(r"-(\d+)-(\d+)(-)", r"-\1.\2\3", model_id))
    variants.add(model_id.replace("-preview", "-preview"))
    return [variant for variant in variants if variant != model_id]


def likely_openrouter_ids(model_id: str, catalogue: set[str]) -> list[str]:
    candidates: list[str] = []
    possible = {model_id}
    possible.update(dot_version_variants(model_id))

    provider_prefixes = []
    if model_id.startswith("gpt-"):
        provider_prefixes.append("openai")
    if model_id.startswith("claude-"):
        provider_prefixes.append("anthropic")
    if model_id.startswith("gemini-"):
        provider_prefixes.append("google")
    if model_id.startswith("deepseek-"):
        provider_prefixes.append("deepseek")
    if model_id.startswith("llama-"):
        provider_prefixes.append("meta-llama")
    if model_id.startswith("mistral-"):
        provider_prefixes.append("mistralai")

    for value in list(possible):
        candidates.extend([item for item in catalogue if item.endswith(f"/{value}")])
        for prefix in provider_prefixes:
            candidates.append(f"{prefix}/{value}")

    exact = [candidate for candidate in candidates if candidate in catalogue]
    if exact:
        return sorted(set(exact))[:5]

    model_words = re.sub(r"[^a-z0-9]+", " ", model_id.lower()).split()
    if model_words:
        contains_words = [
            item
            for item in catalogue
            if all(word in item.lower() for word in model_words[:4])
        ]
        if contains_words:
            return sorted(contains_words)[:5]

    close = difflib.get_close_matches(model_id, sorted(catalogue), n=5, cutoff=0.62)
    return close


def validate_openrouter_model_ids(
    config: dict[str, Any],
    pairs: list[tuple[dict[str, Any], PromptTest]],
) -> None:
    provider_models: dict[str, tuple[dict[str, Any], set[str]]] = {}
    for model, _test in pairs:
        provider = provider_for(config, model)
        if not openrouter_provider(provider):
            continue
        base_url = str(provider.get("base_url", "")).rstrip("/")
        provider_models.setdefault(base_url, (provider, set()))[1].add(clean_text(model.get("model")))

    errors: list[str] = []
    for base_url, (_provider, model_ids) in provider_models.items():
        catalogue = openrouter_model_catalogue(base_url)
        invalid = sorted(model_id for model_id in model_ids if model_id not in catalogue)
        if not invalid:
            continue
        lines = [f"Invalid OpenRouter model ID(s) for {base_url}:"]
        for model_id in invalid:
            suggestions = likely_openrouter_ids(model_id, catalogue)
            hint = f" Try: {', '.join(suggestions)}" if suggestions else ""
            lines.append(f"  - {model_id}.{hint}")
        lines.append(
            "Add an 'OpenRouter Model ID' column with the exact slug from "
            "https://openrouter.ai/models, or update model_id_string to the exact slug."
        )
        errors.append("\n".join(lines))

    if errors:
        raise ValueError("\n\n".join(errors))


def create_messages(test: PromptTest) -> list[dict[str, str]]:
    user_parts = [test.prompt]
    if test.input_material:
        user_parts.append(f"Input material:\n{test.input_material}")
    return [
        {
            "role": "system",
            "content": (
                "You are responding to a benchmark prompt. Answer the user's "
                "request directly and do not mention the benchmark unless asked."
            ),
        },
        {"role": "user", "content": "\n\n".join(user_parts)},
    ]


def normalize_content(content: Any) -> str:
    if isinstance(content, str):
        return content
    if isinstance(content, list):
        parts: list[str] = []
        for item in content:
            if isinstance(item, dict):
                if item.get("type") == "text" and item.get("text"):
                    parts.append(str(item["text"]))
                elif item.get("content"):
                    parts.append(str(item["content"]))
            elif item:
                parts.append(str(item))
        return "\n".join(parts)
    return "" if content is None else str(content)


def merge_request_options(
    config: dict[str, Any],
    provider: dict[str, Any],
    model: dict[str, Any],
) -> dict[str, Any]:
    options: dict[str, Any] = {}
    options.update(config.get("request", {}))
    options.update(provider.get("request", {}))
    options.update(model.get("request", {}))
    return options


def max_tokens_parameter(provider: dict[str, Any], model: dict[str, Any]) -> str:
    configured = clean_text(model.get("max_tokens_param") or provider.get("max_tokens_param"))
    if configured:
        return configured

    base_url = str(provider.get("base_url", "")).lower()
    if "api.openai.com" in base_url:
        return "max_completion_tokens"
    return "max_tokens"


def api_key_for(provider: dict[str, Any]) -> str:
    env_name = provider.get("api_key_env")
    if not env_name:
        return ""
    api_key = os.getenv(env_name)
    if not api_key:
        raise ValueError(f"Environment variable {env_name} is not set.")
    return api_key


def build_headers(provider: dict[str, Any], model: dict[str, Any]) -> dict[str, str]:
    headers = {
        "Content-Type": "application/json",
    }
    api_key = api_key_for(provider)
    if api_key:
        headers["Authorization"] = f"Bearer {api_key}"
    headers.update(provider.get("extra_headers", {}))
    headers.update(model.get("extra_headers", {}))
    return headers


def compact_http_error_body(body: str) -> str:
    try:
        parsed = json.loads(body)
    except json.JSONDecodeError:
        return body.strip()

    error = parsed.get("error") if isinstance(parsed, dict) else None
    if isinstance(error, dict):
        message = clean_text(error.get("message"))
        code = clean_text(error.get("code"))
        error_type = clean_text(error.get("type"))
        details = [part for part in [message, f"code={code}" if code else "", f"type={error_type}" if error_type else ""] if part]
        return "; ".join(details) or body.strip()
    return body.strip()


def retry_delay_seconds(exc: urllib.error.HTTPError, attempt: int) -> float:
    headers = exc.headers
    for name in ("retry-after-ms", "Retry-After-Ms"):
        value = clean_text(headers.get(name))
        if value:
            try:
                return max(0.0, float(value) / 1000.0)
            except ValueError:
                pass

    for name in ("retry-after", "Retry-After"):
        value = clean_text(headers.get(name))
        if value:
            try:
                return max(0.0, float(value))
            except ValueError:
                pass

    return min(30.0, float(2**attempt))


def http_error(exc: urllib.error.HTTPError, body: str) -> RuntimeError:
    message = f"HTTP {exc.code}: {compact_http_error_body(body)}"
    if exc.code == 429:
        return RateLimitError(message)
    if exc.code == 402:
        return CreditLimitError(message)
    return RuntimeError(message)


def post_json(
    provider: dict[str, Any],
    model: dict[str, Any],
    path: str,
    payload: dict[str, Any],
    timeout: int,
    retries: int,
) -> dict[str, Any]:
    base_url = str(provider.get("base_url", "")).rstrip("/")
    if not base_url:
        raise ValueError("Provider is missing base_url.")

    data = json.dumps(payload).encode("utf-8")
    request = urllib.request.Request(
        f"{base_url}{path}",
        data=data,
        headers=build_headers(provider, model),
    )
    last_error: Exception | None = None

    for attempt in range(retries + 1):
        retry_delay = min(8.0, float(2**attempt))
        try:
            with urllib.request.urlopen(request, timeout=timeout) as response:
                body = response.read().decode("utf-8")
            return json.loads(body)
        except urllib.error.HTTPError as exc:
            body = exc.read().decode("utf-8", errors="replace")
            last_error = http_error(exc, body)
            if exc.code == 429:
                retry_delay = retry_delay_seconds(exc, attempt)
            if exc.code < 500 and exc.code != 429:
                raise last_error from exc
        except (urllib.error.URLError, TimeoutError) as exc:
            last_error = exc

        if attempt < retries:
            time.sleep(retry_delay)

    if isinstance(last_error, (CreditLimitError, RateLimitError)):
        raise last_error
    raise RuntimeError(f"API request failed after retries: {last_error}") from last_error


def call_openai_compatible(
    config: dict[str, Any],
    model: dict[str, Any],
    messages: list[dict[str, str]],
) -> tuple[str, dict[str, Any]]:
    provider = provider_for(config, model)

    provider_type = provider.get("type", "openai_compatible")
    if provider_type != "openai_compatible":
        raise ValueError(f"Unsupported provider type: {provider_type}")

    base_url = str(provider.get("base_url", "")).rstrip("/")
    if not base_url:
        raise ValueError(f"Provider {provider_key!r} is missing base_url.")

    options = merge_request_options(config, provider, model)
    payload: dict[str, Any] = {
        "model": model.get("model"),
        "messages": messages,
        "temperature": options.get("temperature", 0.2),
        max_tokens_parameter(provider, model): options.get("max_tokens", 1800),
    }
    payload.update(provider.get("extra_body", {}))
    payload.update(model.get("extra_body", {}))

    path = provider.get("chat_completions_path", "/chat/completions")
    timeout = int(options.get("timeout_seconds", 120))
    retries = int(options.get("retries", 2))

    parsed = post_json(provider, model, path, payload, timeout, retries)
    choice = parsed.get("choices", [{}])[0]
    message = choice.get("message", {})
    return normalize_content(message.get("content")), parsed.get("usage", {})


def safe_filename(value: str) -> str:
    return re.sub(r"[^A-Za-z0-9_.-]+", "-", value).strip("-") or "item"


def image_prompt(test: PromptTest) -> str:
    parts = [test.prompt]
    if test.input_material and not input_image_path(test):
        parts.append(f"Input material:\n{test.input_material}")
    return "\n\n".join(parts)


def input_image_path(test: PromptTest) -> Path | None:
    raw = clean_text(test.input_material)
    if not raw:
        return None

    candidate = Path(raw).expanduser()
    if not candidate.is_absolute():
        candidate = Path.cwd() / candidate
    return candidate if candidate.exists() and candidate.is_file() else None


def image_payload_options(options: dict[str, Any]) -> dict[str, Any]:
    payload: dict[str, Any] = {}
    option_map = {
        "image_count": "n",
        "n": "n",
        "size": "size",
        "quality": "quality",
        "style": "style",
        "response_format": "response_format",
        "background": "background",
        "moderation": "moderation",
        "output_format": "output_format",
    }
    for source, target in option_map.items():
        if source in options and options[source] is not None:
            payload[target] = options[source]
    return payload


def image_file_extension(options: dict[str, Any]) -> str:
    extension = normalized(str(options.get("output_format") or "png"))
    if extension == "jpeg":
        return "jpg"
    if extension in {"jpg", "png", "webp"}:
        return extension
    return "png"


def save_image_outputs(
    parsed: dict[str, Any],
    output_dir: Path,
    model: dict[str, Any],
    test: PromptTest,
    file_extension: str = "png",
) -> tuple[list[str], list[str], str]:
    image_dir = output_dir / "images" / safe_filename(str(model.get("key", "model")))
    image_dir.mkdir(parents=True, exist_ok=True)

    files: list[str] = []
    urls: list[str] = []
    notes: list[str] = []
    data_items = parsed.get("data", [])

    for index, item in enumerate(data_items, start=1):
        if not isinstance(item, dict):
            continue
        revised_prompt = clean_text(item.get("revised_prompt"))
        if revised_prompt:
            notes.append(f"Revised prompt {index}: {revised_prompt}")

        if item.get("b64_json"):
            image_bytes = base64.b64decode(item["b64_json"])
            output_path = (
                image_dir
                / (
                    f"{safe_filename(test.test_id)}-"
                    f"{safe_filename(str(model.get('key', 'model')))}-"
                    f"{index}.{file_extension}"
                )
            )
            output_path.write_bytes(image_bytes)
            files.append(str(output_path.resolve()))
        if item.get("url"):
            urls.append(str(item["url"]))

    if not files and not urls:
        raise RuntimeError("Image response did not include b64_json or url data.")

    response = "Generated image output."
    if notes:
        response = f"{response}\n" + "\n".join(notes)
    return files, urls, response


def encode_multipart(
    fields: dict[str, Any],
    files: list[tuple[str, Path]],
) -> tuple[bytes, str]:
    boundary = f"----codex-model-eval-{uuid.uuid4().hex}"
    body = bytearray()

    def add(value: bytes) -> None:
        body.extend(value)

    for name, value in fields.items():
        add(f"--{boundary}\r\n".encode("utf-8"))
        add(f'Content-Disposition: form-data; name="{name}"\r\n\r\n'.encode("utf-8"))
        add(str(value).encode("utf-8"))
        add(b"\r\n")

    for name, path in files:
        mime_type = mimetypes.guess_type(path.name)[0] or "application/octet-stream"
        add(f"--{boundary}\r\n".encode("utf-8"))
        add(
            (
                f'Content-Disposition: form-data; name="{name}"; '
                f'filename="{path.name}"\r\n'
            ).encode("utf-8")
        )
        add(f"Content-Type: {mime_type}\r\n\r\n".encode("utf-8"))
        add(path.read_bytes())
        add(b"\r\n")

    add(f"--{boundary}--\r\n".encode("utf-8"))
    return bytes(body), f"multipart/form-data; boundary={boundary}"


def post_multipart(
    provider: dict[str, Any],
    model: dict[str, Any],
    path: str,
    fields: dict[str, Any],
    files: list[tuple[str, Path]],
    timeout: int,
    retries: int,
) -> dict[str, Any]:
    base_url = str(provider.get("base_url", "")).rstrip("/")
    if not base_url:
        raise ValueError("Provider is missing base_url.")

    body, content_type = encode_multipart(fields, files)
    headers = build_headers(provider, model)
    headers["Content-Type"] = content_type
    request = urllib.request.Request(f"{base_url}{path}", data=body, headers=headers)
    last_error: Exception | None = None

    for attempt in range(retries + 1):
        retry_delay = min(8.0, float(2**attempt))
        try:
            with urllib.request.urlopen(request, timeout=timeout) as response:
                response_body = response.read().decode("utf-8")
            return json.loads(response_body)
        except urllib.error.HTTPError as exc:
            response_body = exc.read().decode("utf-8", errors="replace")
            last_error = http_error(exc, response_body)
            if exc.code == 429:
                retry_delay = retry_delay_seconds(exc, attempt)
            if exc.code < 500 and exc.code != 429:
                raise last_error from exc
        except (urllib.error.URLError, TimeoutError) as exc:
            last_error = exc

        if attempt < retries:
            time.sleep(retry_delay)

    if isinstance(last_error, (CreditLimitError, RateLimitError)):
        raise last_error
    raise RuntimeError(f"API request failed after retries: {last_error}") from last_error


def call_openai_image_generation(
    config: dict[str, Any],
    model: dict[str, Any],
    test: PromptTest,
    output_dir: Path,
) -> tuple[str, list[str], list[str], dict[str, Any]]:
    provider = provider_for(config, model)
    provider_type = provider.get("type", "openai_compatible")
    if provider_type != "openai_image_generation":
        raise ValueError(f"Unsupported image provider type: {provider_type}")

    options = merge_request_options(config, provider, model)
    timeout = int(options.get("timeout_seconds", 180))
    retries = int(options.get("retries", 2))
    payload = {
        "model": model.get("model"),
        "prompt": image_prompt(test),
        **image_payload_options(options),
    }
    payload.update(provider.get("extra_body", {}))
    payload.update(model.get("extra_body", {}))

    path = provider.get("image_generations_path", "/images/generations")
    parsed = post_json(provider, model, path, payload, timeout, retries)
    files, urls, response = save_image_outputs(
        parsed,
        output_dir,
        model,
        test,
        file_extension=image_file_extension(options),
    )
    return response, files, urls, parsed.get("usage", {})


def call_openai_image_edit(
    config: dict[str, Any],
    model: dict[str, Any],
    test: PromptTest,
    output_dir: Path,
) -> tuple[str, list[str], list[str], dict[str, Any]]:
    provider = provider_for(config, model)
    provider_type = provider.get("type", "openai_compatible")
    if provider_type != "openai_image_generation":
        raise ValueError(f"Unsupported image provider type: {provider_type}")

    source_image = input_image_path(test)
    if not source_image:
        raise ValueError("Image edit test requires input_material to be a local image path.")

    options = merge_request_options(config, provider, model)
    timeout = int(options.get("timeout_seconds", 180))
    retries = int(options.get("retries", 2))
    fields = {
        "model": model.get("model"),
        "prompt": test.prompt,
        **image_payload_options(options),
    }
    fields.update(provider.get("extra_body", {}))
    fields.update(model.get("extra_body", {}))

    path = provider.get("image_edits_path", "/images/edits")
    parsed = post_multipart(
        provider=provider,
        model=model,
        path=path,
        fields=fields,
        files=[("image", source_image)],
        timeout=timeout,
        retries=retries,
    )
    files, urls, response = save_image_outputs(
        parsed,
        output_dir,
        model,
        test,
        file_extension=image_file_extension(options),
    )
    return response, files, urls, parsed.get("usage", {})


def call_image_model(
    config: dict[str, Any],
    model: dict[str, Any],
    test: PromptTest,
    output_dir: Path,
) -> tuple[str, list[str], list[str], dict[str, Any]]:
    if is_image_edit_test(test):
        return call_openai_image_edit(config, model, test, output_dir)
    return call_openai_image_generation(config, model, test, output_dir)


def extract_json_object(text: str) -> dict[str, Any]:
    try:
        return json.loads(text)
    except json.JSONDecodeError:
        pass

    fenced = re.search(r"```(?:json)?\s*(\{.*?\})\s*```", text, flags=re.DOTALL)
    if fenced:
        return json.loads(fenced.group(1))

    start = text.find("{")
    end = text.rfind("}")
    if start >= 0 and end > start:
        return json.loads(text[start : end + 1])

    raise ValueError("No JSON object found in judge response.")


def judge_messages(test: PromptTest, model_response: str) -> list[dict[str, str]]:
    user = f"""
Grade the model response for this benchmark test.

Test ID: {test.test_id}
Category: {test.category}
Criterion: {test.criterion}
Prompt:
{test.prompt}

Input material:
{test.input_material or "(none)"}

Model response:
{model_response}

Return only JSON with:
{{"score": number from 1 to 10, "reasoning": "one or two concise sentences"}}

Scoring guidance:
- Reward direct prompt adherence, correctness, completeness, and useful structure.
- Penalize hallucinated current facts, missing requested sources, unsafe assumptions,
  or refusing when enough information was provided.
- For prompts that require current prices, availability, or citations, penalize
  unsupported claims unless the response clearly states its limits.
""".strip()

    return [
        {
            "role": "system",
            "content": "You are a strict but fair evaluator of AI model benchmark outputs.",
        },
        {"role": "user", "content": user},
    ]


def score_response(
    config: dict[str, Any],
    judge: dict[str, Any],
    test: PromptTest,
    response: str,
) -> tuple[float | None, str]:
    judge_response, _usage = call_openai_compatible(config, judge, judge_messages(test, response))
    parsed = extract_json_object(judge_response)
    score = parsed.get("score")
    reasoning = clean_text(parsed.get("reasoning"))
    try:
        numeric_score = float(score)
    except (TypeError, ValueError):
        numeric_score = None
    return numeric_score, reasoning


def load_existing_jsonl(path: Path) -> list[dict[str, Any]]:
    if not path.exists():
        return []

    rows: list[dict[str, Any]] = []
    with path.open("r", encoding="utf-8") as handle:
        for line in handle:
            line = line.strip()
            if line:
                rows.append(json.loads(line))
    return rows


def append_jsonl(path: Path, row: dict[str, Any]) -> None:
    with path.open("a", encoding="utf-8") as handle:
        handle.write(json.dumps(row, ensure_ascii=False) + "\n")


def make_output_dir(base: Path | None) -> Path:
    if base:
        base.mkdir(parents=True, exist_ok=True)
        return base

    stamp = dt.datetime.now().strftime("%Y%m%d-%H%M%S")
    output_dir = Path("outputs") / "model_tests" / stamp
    output_dir.mkdir(parents=True, exist_ok=True)
    return output_dir


def stringify_usage(value: Any) -> str:
    if value in (None, ""):
        return ""
    if isinstance(value, str):
        return value
    return json.dumps(value, sort_keys=True)


def write_results_csv(path: Path, rows: list[dict[str, Any]]) -> None:
    with path.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=CSV_COLUMNS)
        writer.writeheader()
        for row in rows:
            writer.writerow(
                {
                    column: (
                        stringify_usage(row.get(column))
                        if column == "usage"
                        else row.get(column, "")
                    )
                    for column in CSV_COLUMNS
                }
            )


def average(values: list[float]) -> float | None:
    return sum(values) / len(values) if values else None


def summarize_results(rows: list[dict[str, Any]]) -> list[dict[str, Any]]:
    by_model: dict[str, list[dict[str, Any]]] = {}
    for row in rows:
        by_model.setdefault(row.get("model_key", ""), []).append(row)

    summaries: list[dict[str, Any]] = []
    for model_key, model_rows in sorted(by_model.items()):
        scored = [row for row in model_rows if row.get("score") not in (None, "")]
        scores = [float(row["score"]) for row in scored]
        weighted_pairs = [
            (float(row["score"]), float(row.get("weight") or 1.0))
            for row in scored
        ]
        weight_total = sum(weight for _score, weight in weighted_pairs)
        weighted_avg = (
            sum(score * weight for score, weight in weighted_pairs) / weight_total
            if weight_total
            else None
        )
        latencies = [
            float(row["latency_seconds"])
            for row in model_rows
            if row.get("latency_seconds") not in (None, "")
        ]
        summaries.append(
            {
                "model_key": model_key,
                "model_name": model_rows[0].get("model_name", ""),
                "provider_model": model_rows[0].get("provider_model", ""),
                "attempted": len(model_rows),
                "completed": sum(
                    1
                    for row in model_rows
                    if row.get("response") or row.get("output_files") or row.get("output_urls")
                ),
                "errors": sum(1 for row in model_rows if row.get("error")),
                "avg_score": average(scores),
                "weighted_avg": weighted_avg,
                "avg_latency_seconds": average(latencies),
            }
        )
    return summaries


def write_sheet_rows(ws: Any, rows: list[list[Any]]) -> None:
    for row in rows:
        ws.append(row)


def style_header(ws: Any) -> None:
    fill = PatternFill("solid", fgColor="1F2937")
    font = Font(color="FFFFFF", bold=True)
    for cell in ws[1]:
        cell.fill = fill
        cell.font = font
        cell.alignment = Alignment(vertical="center", wrap_text=True)
    ws.freeze_panes = "A2"
    ws.auto_filter.ref = ws.dimensions


def set_widths(ws: Any, widths: dict[int, int]) -> None:
    for index, width in widths.items():
        ws.column_dimensions[get_column_letter(index)].width = width


def save_workbook_atomic(workbook: Any, output_path: Path) -> None:
    output_path.parent.mkdir(parents=True, exist_ok=True)
    temp_path = output_path.with_name(f".{output_path.stem}.tmp{output_path.suffix}")
    workbook.save(temp_path)
    temp_path.replace(output_path)


def populate_results_sheets(
    wb: Any,
    rows: list[dict[str, Any]],
    skipped: list[SkippedTest],
) -> None:
    summary_ws = wb.create_sheet("Run Summary", 0)
    result_ws = wb.create_sheet("Run Results", 1)
    skipped_ws = wb.create_sheet("Skipped Tests", 2)

    write_sheet_rows(
        summary_ws,
        [
            [
                "Model Key",
                "Model Name",
                "Provider Model",
                "Attempted",
                "Completed",
                "Errors",
                "Average Score",
                "Weighted Average",
                "Average Latency Seconds",
            ]
        ],
    )
    for summary in summarize_results(rows):
        summary_ws.append(
            [
                summary["model_key"],
                summary["model_name"],
                summary["provider_model"],
                summary["attempted"],
                summary["completed"],
                summary["errors"],
                summary["avg_score"],
                summary["weighted_avg"],
                summary["avg_latency_seconds"],
            ]
        )

    result_ws.append(CSV_COLUMNS)
    for row in rows:
        result_ws.append(
            [
                stringify_usage(row.get(column)) if column == "usage" else row.get(column, "")
                for column in CSV_COLUMNS
            ]
        )

    skipped_ws.append(["Test ID", "Category", "Criterion", "Eval Method", "Reason"])
    for test in skipped:
        skipped_ws.append(
            [test.test_id, test.category, test.criterion, test.eval_method, test.reason]
        )

    for ws in [summary_ws, result_ws, skipped_ws]:
        style_header(ws)
        for row in ws.iter_rows():
            for cell in row:
                cell.alignment = Alignment(vertical="top", wrap_text=True)

    set_widths(
        summary_ws,
        {1: 16, 2: 28, 3: 34, 4: 12, 5: 12, 6: 10, 7: 14, 8: 16, 9: 22},
    )
    set_widths(
        result_ws,
        {
            1: 20,
            2: 22,
            3: 16,
            4: 26,
            5: 16,
            6: 34,
            7: 12,
            8: 24,
            9: 28,
            10: 10,
            11: 20,
            14: 14,
            15: 80,
            16: 58,
            17: 58,
            19: 48,
            20: 16,
            22: 36,
        },
    )
    set_widths(skipped_ws, {1: 12, 2: 26, 3: 30, 4: 22, 5: 38})


def write_live_results_workbook(
    output_path: Path,
    rows: list[dict[str, Any]],
    skipped: list[SkippedTest],
) -> None:
    wb = Workbook()
    default_sheet = wb.active
    wb.remove(default_sheet)
    populate_results_sheets(wb, rows, skipped)
    save_workbook_atomic(wb, output_path)


def write_results_workbook(
    source_workbook: Path,
    output_path: Path,
    rows: list[dict[str, Any]],
    skipped: list[SkippedTest],
) -> None:
    wb = load_workbook(source_workbook)
    for sheet_name in ["Run Summary", "Run Results", "Skipped Tests"]:
        if sheet_name in wb.sheetnames:
            del wb[sheet_name]

    populate_results_sheets(wb, rows, skipped)
    save_workbook_atomic(wb, output_path)


def result_row(
    run_id: str,
    model: dict[str, Any],
    test: PromptTest,
    provider: str,
    output_type: str = "text",
    response: str = "",
    output_files: list[str] | None = None,
    output_urls: list[str] | None = None,
    score: float | None = None,
    reasoning: str = "",
    latency_seconds: float | None = None,
    usage: dict[str, Any] | None = None,
    error: str = "",
) -> dict[str, Any]:
    return {
        "run_id": run_id,
        "timestamp": dt.datetime.now(dt.timezone.utc).isoformat(),
        "model_key": model.get("key", ""),
        "model_name": model.get("name", model.get("key", "")),
        "provider": provider,
        "provider_model": model.get("model", ""),
        "test_id": test.test_id,
        "category": test.category,
        "criterion": test.criterion,
        "weight": test.weight,
        "eval_method": test.eval_method,
        "prompt_source": test.prompt_source,
        "input_source": test.input_source,
        "output_type": output_type,
        "response": response,
        "output_files": "\n".join(output_files or []),
        "output_urls": "\n".join(output_urls or []),
        "score": score if score is not None else "",
        "reasoning": reasoning,
        "latency_seconds": round(latency_seconds, 3) if latency_seconds is not None else "",
        "usage": usage or {},
        "error": error,
    }


def print_plan(
    config: dict[str, Any],
    tests: list[PromptTest],
    skipped: list[SkippedTest],
    models: list[dict[str, Any]],
) -> None:
    print(f"Models enabled: {len(models)}")
    for model in models:
        capabilities = ", ".join(sorted(model_capabilities(config, model)))
        print(
            f"  - {model.get('key')}: {model.get('name')} "
            f"({model.get('model')}; {capabilities})"
        )
    print(f"Automated tests: {len(tests)}")
    by_category: dict[str, int] = {}
    for test in tests:
        by_category[test.category] = by_category.get(test.category, 0) + 1
    for category, count in sorted(by_category.items()):
        print(f"  - {category}: {count}")
    print(f"Skipped tests: {len(skipped)}")
    for test in skipped:
        print(f"  - {test.test_id}: {test.reason}")
    unsupported = unsupported_tests(config, models, tests)
    if unsupported:
        print("Selected tests without an enabled compatible model:")
        for test in unsupported:
            required = "image" if is_image_test(test) else "text"
            print(f"  - {test.test_id}: needs {required} capability")
    print(f"Total API calls for selected model/test pairs: {len(planned_pairs(config, models, tests))}")


def parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--workbook", required=True, help="Path to the source .xlsx prompt workbook.")
    parser.add_argument("--config", help="Optional path to model_eval_models.json.")
    parser.add_argument(
        "--models-workbook",
        help="Path to an .xlsx model list. First sheet must contain at least a Model ID column.",
    )
    parser.add_argument("--sheet", default="Test Prompts", help="Prompt-library sheet name.")
    parser.add_argument("--output-dir", help="Output directory. Defaults to outputs/model_tests/<timestamp>.")
    parser.add_argument("--dry-run", action="store_true", help="Print the run plan without API calls.")
    parser.add_argument("--score", action="store_true", help="Auto-score each response with config.judge.")
    parser.add_argument("--force", action="store_true", help="Ignore existing responses.jsonl in output-dir.")
    parser.add_argument(
        "--max-tokens",
        type=int,
        help="Override max output tokens per text response. Lower this if provider credit limits reject requests.",
    )
    parser.add_argument(
        "--excel-every",
        type=int,
        default=1,
        help="Refresh responses.xlsx every N completed rows. Use 0 to disable live Excel output.",
    )
    parser.add_argument("--limit", type=int, help="Limit the number of selected prompt tests.")
    parser.add_argument("--only-tests", help="Comma-separated Test IDs, e.g. W1,C1,S2.")
    parser.add_argument("--only-models", help="Comma-separated model keys from the config.")
    parser.add_argument("--include-image", action="store_true", help="Include image-generation prompts.")
    parser.add_argument("--include-evidence", action="store_true", help="Include evidence/privacy/security rows.")
    parser.add_argument("--include-manual-review", action="store_true", help="Include manual reviewer rows.")
    parser.add_argument(
        "--rate-limit-skip-after",
        type=int,
        default=3,
        help=(
            "Skip remaining tests for a model after this many rate-limit errors. "
            "Use 0 to keep trying every selected pair."
        ),
    )
    parser.add_argument(
        "--verbose-errors",
        action="store_true",
        help="Print full tracebacks for failed model calls.",
    )
    parser.add_argument(
        "--no-inherit-shorthand",
        action="store_true",
        help="Disable workbook shorthand inheritance for blank prompts and ^ input cells.",
    )
    return parser.parse_args(argv)


def main(argv: list[str]) -> int:
    args = parse_args(argv)
    workbook_path = Path(args.workbook).expanduser()
    config_path = Path(args.config).expanduser() if args.config else None
    models_workbook_path = (
        Path(args.models_workbook).expanduser() if args.models_workbook else None
    )
    requested_output_dir = Path(args.output_dir).expanduser() if args.output_dir else None

    if config_path:
        config = load_json(config_path)
    else:
        config = default_config()
    if models_workbook_path:
        config = read_model_workbook(models_workbook_path, config)
    elif not config.get("models"):
        raise ValueError("Provide --models-workbook or a --config file with models.")
    if args.max_tokens is not None:
        if args.max_tokens < 1:
            raise ValueError("--max-tokens must be greater than 0.")
        config.setdefault("request", {})["max_tokens"] = args.max_tokens
    if args.excel_every < 0:
        raise ValueError("--excel-every must be 0 or greater.")
    if args.rate_limit_skip_after < 0:
        raise ValueError("--rate-limit-skip-after must be 0 or greater.")

    models = enabled_models(config, args.only_models)
    tests = read_prompt_library(
        workbook_path=workbook_path,
        sheet_name=args.sheet,
        inherit_shorthand=not args.no_inherit_shorthand,
    )
    selected_tests, skipped = eligible_tests(tests, args)

    pairs = planned_pairs(config, models, selected_tests)

    if args.dry_run:
        print_plan(config, selected_tests, skipped, models)
        return 0
    if not models:
        raise ValueError("No enabled models found in the config.")
    if not selected_tests:
        raise ValueError("No eligible tests selected.")
    if not pairs:
        raise ValueError("No eligible model/test pairs. Check model capabilities in the config.")
    validate_api_keys(config, pairs)
    validate_openrouter_model_ids(config, pairs)

    judge = config.get("judge", {})
    if args.score and not judge.get("enabled", False):
        raise ValueError("Set judge.enabled=true in the config before using --score.")

    print_plan(config, selected_tests, skipped, models)

    output_dir = make_output_dir(requested_output_dir)
    run_id = output_dir.name
    jsonl_path = output_dir / "responses.jsonl"
    live_xlsx_path = output_dir / "responses.xlsx"
    existing_rows = [] if args.force else load_existing_jsonl(jsonl_path)
    planned_keys = {(model.get("key"), test.test_id) for model, test in pairs}
    completed = {
        (row.get("model_key"), row.get("test_id"))
        for row in existing_rows
        if (row.get("model_key"), row.get("test_id")) in planned_keys
        and (
            row.get("response")
            or row.get("output_files")
            or row.get("output_urls")
            or row.get("error")
        )
    }
    all_rows = list(existing_rows)
    sleep_seconds = float(config.get("request", {}).get("sleep_seconds", 0.5))
    if args.excel_every:
        write_live_results_workbook(live_xlsx_path, all_rows, skipped)

    total = len(pairs)
    done_count = len(completed)
    rate_limit_errors_by_model: dict[str, int] = {}
    rate_limited_models: set[str] = set()
    for model, test in pairs:
        provider = model.get("provider", "")
        key = (model.get("key"), test.test_id)
        if key in completed:
            print(f"Skipping existing {key[0]} / {key[1]}")
            continue
        if model.get("key") in rate_limited_models:
            print(f"Skipping rate-limited {key[0]} / {key[1]}")
            continue

        done_count += 1
        print(f"[{done_count}/{total}] {model.get('key')} -> {test.test_id}", flush=True)
        started = time.monotonic()
        try:
            if is_image_test(test):
                response, output_files, output_urls, usage = call_image_model(
                    config, model, test, output_dir
                )
                row = result_row(
                    run_id=run_id,
                    model=model,
                    test=test,
                    provider=provider,
                    output_type="image",
                    response=response,
                    output_files=output_files,
                    output_urls=output_urls,
                    latency_seconds=time.monotonic() - started,
                    usage=usage,
                )
            else:
                response, usage = call_openai_compatible(config, model, create_messages(test))
                score = None
                reasoning = ""
                if args.score:
                    score, reasoning = score_response(config, judge, test, response)
                row = result_row(
                    run_id=run_id,
                    model=model,
                    test=test,
                    provider=provider,
                    response=response,
                    score=score,
                    reasoning=reasoning,
                    latency_seconds=time.monotonic() - started,
                    usage=usage,
                )
        except Exception as exc:  # pragma: no cover - depends on remote APIs
            if isinstance(exc, RateLimitError):
                model_key = clean_text(model.get("key"))
                rate_limit_errors_by_model[model_key] = rate_limit_errors_by_model.get(model_key, 0) + 1
                if (
                    args.rate_limit_skip_after
                    and rate_limit_errors_by_model[model_key] >= args.rate_limit_skip_after
                ):
                    rate_limited_models.add(model_key)
            row = result_row(
                run_id=run_id,
                model=model,
                test=test,
                provider=provider,
                output_type="image" if is_image_test(test) else "text",
                latency_seconds=time.monotonic() - started,
                error=f"{type(exc).__name__}: {exc}",
            )
            if args.verbose_errors:
                print(traceback.format_exc(), file=sys.stderr)
            else:
                print(f"  error: {row['error']}", file=sys.stderr)
            if model.get("key") in rate_limited_models:
                print(
                    "  rate limit: skipping remaining tests for "
                    f"{model.get('key')} after {args.rate_limit_skip_after} rate-limit errors",
                    file=sys.stderr,
                )

        append_jsonl(jsonl_path, row)
        all_rows.append(row)
        if args.excel_every and len(all_rows) % args.excel_every == 0:
            write_live_results_workbook(live_xlsx_path, all_rows, skipped)
        if sleep_seconds:
            time.sleep(sleep_seconds)

    if args.excel_every:
        write_live_results_workbook(live_xlsx_path, all_rows, skipped)
    write_results_csv(output_dir / "responses.csv", all_rows)
    write_results_workbook(
        source_workbook=workbook_path,
        output_path=output_dir / "model_test_results.xlsx",
        rows=all_rows,
        skipped=skipped,
    )

    print(f"Wrote {output_dir / 'responses.jsonl'}")
    print(f"Wrote {live_xlsx_path}")
    print(f"Wrote {output_dir / 'responses.csv'}")
    print(f"Wrote {output_dir / 'model_test_results.xlsx'}")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main(sys.argv[1:]))
    except KeyboardInterrupt:
        print("Cancelled.", file=sys.stderr)
        raise SystemExit(130)
    except Exception as exc:
        print(f"Error: {exc}", file=sys.stderr)
        raise SystemExit(1)
