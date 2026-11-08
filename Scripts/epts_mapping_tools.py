"""Shared parsing and validation for OPTN EPTS mapping releases."""

from __future__ import annotations

import json
import re
import subprocess
from pathlib import Path
from typing import Any


ROW_PATTERN = re.compile(
    r"(-?\d+(?:\.\d+)?)\s+"
    r"(-?\d+(?:\.\d+)?)\s+"
    r"(?:–>|-->|->)[^0-9%]{0,100}"
    r"(\d+)(?:\.\d+)?%"
)


def read_source_text(path: Path) -> str:
    if path.suffix.lower() == ".pdf":
        completed = subprocess.run(
            ["pdftotext", "-layout", str(path), "-"],
            check=True,
            capture_output=True,
            text=True,
        )
        return completed.stdout
    return path.read_text(encoding="utf-8")


def extract_upper_bounds(text: str, source_label: str) -> list[float]:
    rows = [
        (float(lower), float(upper), int(percentile))
        for lower, upper, percentile in ROW_PATTERN.findall(text)
    ]

    counts = {percentile: 0 for percentile in range(101)}
    for _, _, percentile in rows:
        if percentile in counts:
            counts[percentile] += 1

    expected = {
        percentile: (2 if percentile == 100 else 1)
        for percentile in range(101)
    }
    if counts != expected:
        raise ValueError(
            f"{source_label}: expected one row for 0-99 and two rows for 100; "
            f"found {counts}"
        )

    first_row: dict[int, tuple[float, float]] = {}
    for lower, upper, percentile in rows:
        first_row.setdefault(percentile, (lower, upper))

    bounds = [first_row[percentile][1] for percentile in range(101)]
    if any(left >= right for left, right in zip(bounds, bounds[1:])):
        raise ValueError(f"{source_label}: upper bounds are not strictly increasing")

    for percentile in range(1, 101):
        previous_upper = first_row[percentile - 1][1]
        current_lower = first_row[percentile][0]
        if abs(previous_upper - current_lower) > 1e-12:
            raise ValueError(
                f"{source_label}: discontinuity before percentile {percentile}: "
                f"{previous_upper} != {current_lower}"
            )

    return bounds


def load_catalog(path: Path) -> dict[str, Any]:
    if not path.exists():
        return {"schemaVersion": 1, "tables": []}
    catalog = json.loads(path.read_text(encoding="utf-8"))
    validate_catalog(catalog, str(path))
    return catalog


def validate_catalog(catalog: dict[str, Any], source_label: str) -> None:
    if catalog.get("schemaVersion") != 1:
        raise ValueError(f"{source_label}: unsupported schemaVersion")

    tables = catalog.get("tables")
    if not isinstance(tables, list) or not tables:
        raise ValueError(f"{source_label}: tables must be a non-empty array")

    prior_reference_year = None
    for table in tables:
        reference_year = table.get("referenceYear")
        publication_year = table.get("publicationYear")
        bounds = table.get("upperBounds")

        if not isinstance(reference_year, int) or not isinstance(publication_year, int):
            raise ValueError(f"{source_label}: table years must be integers")
        if publication_year != reference_year + 1:
            raise ValueError(
                f"{source_label}: {reference_year} reference must publish in the following year"
            )
        if prior_reference_year is not None and reference_year <= prior_reference_year:
            raise ValueError(f"{source_label}: tables must be strictly chronological")
        prior_reference_year = reference_year

        if not isinstance(table.get("databaseAsOf"), str) or not table["databaseAsOf"]:
            raise ValueError(f"{source_label}: databaseAsOf is required")
        if not isinstance(table.get("sourceURL"), str) or not table["sourceURL"].startswith("https://"):
            raise ValueError(f"{source_label}: sourceURL must be HTTPS")
        if not isinstance(bounds, list) or len(bounds) != 101:
            raise ValueError(f"{source_label}: {reference_year} must have 101 upper bounds")
        if any(not isinstance(value, (int, float)) for value in bounds):
            raise ValueError(f"{source_label}: upper bounds must be numeric")
        if any(left >= right for left, right in zip(bounds, bounds[1:])):
            raise ValueError(f"{source_label}: {reference_year} bounds are not increasing")


def write_catalog(path: Path, catalog: dict[str, Any]) -> None:
    validate_catalog(catalog, str(path))
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_suffix(path.suffix + ".tmp")
    temporary.write_text(
        json.dumps(catalog, indent=2, sort_keys=False) + "\n",
        encoding="utf-8",
    )
    temporary.replace(path)
