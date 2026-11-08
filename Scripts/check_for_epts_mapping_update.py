#!/usr/bin/env python3
"""Check HRSA's current EPTS PDF and stage a validated catalog update if new."""

from __future__ import annotations

import argparse
import re
import subprocess
import tempfile
from pathlib import Path

from epts_mapping_tools import (
    extract_upper_bounds,
    load_catalog,
    read_source_text,
    write_catalog,
)
from generate_epts_mapping_data import render_swift
from import_epts_mapping import download_official


CURRENT_SOURCE_URL = (
    "https://www.hrsa.gov/sites/default/files/hrsa/optn/epts_mapping_table.pdf"
)


def download_reader_text(official_url: str) -> str:
    # Detection-only fallback for CDNs that reject unattended PDF downloads.
    # Any resulting app-data change is still delivered as an unmerged review PR.
    reader_url = "https://r.jina.ai/http://" + official_url.removeprefix("https://")
    temporary = tempfile.NamedTemporaryFile(suffix=".txt", delete=False)
    temporary.close()
    output_path = Path(temporary.name)
    subprocess.run(
        [
            "curl", "--fail", "--location", "--silent", "--show-error",
            "--max-time", "60", "--output", str(output_path), reader_url,
        ],
        check=True,
    )
    text = output_path.read_text(encoding="utf-8")
    if "Title: EPTS Mapping Table" not in text or f"Final URL: {official_url}" not in text:
        raise ValueError("reader fallback did not identify the requested official HRSA PDF")
    return text


def extract_release_metadata(text: str) -> tuple[int, str]:
    year_match = re.search(r"December\s+31,\s+(\d{4})", text)
    date_match = re.search(
        r"database\s+as\s+of\s+([A-Za-z]+\s+\d{1,2},\s+\d{4})",
        text,
        re.IGNORECASE,
    )
    if not year_match or not date_match:
        raise ValueError("could not extract the reference year and database date")
    return int(year_match.group(1)), date_match.group(1)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--catalog", type=Path, required=True)
    parser.add_argument("--swift-output", type=Path, required=True)
    parser.add_argument("--url", default=CURRENT_SOURCE_URL)
    parser.add_argument("--input", type=Path, help="Local PDF/text fixture; skips download")
    parser.add_argument(
        "--allow-reader-fallback",
        action="store_true",
        help="Allow a read-only text proxy when HRSA's CDN rejects direct download",
    )
    args = parser.parse_args()

    if args.input:
        source_text = read_source_text(args.input)
    else:
        try:
            downloaded = download_official(args.url)
            source_text = read_source_text(downloaded)
        except (subprocess.CalledProcessError, ValueError):
            if not args.allow_reader_fallback:
                raise
            source_text = download_reader_text(args.url)
    reference_year, database_as_of = extract_release_metadata(source_text)
    publication_year = reference_year + 1
    bounds = extract_upper_bounds(source_text, args.url)

    catalog = load_catalog(args.catalog)
    latest = catalog["tables"][-1]
    latest_reference_year = latest["referenceYear"]

    if reference_year < latest_reference_year:
        raise ValueError(
            f"official current PDF regressed from {latest_reference_year} to {reference_year}"
        )

    if reference_year == latest_reference_year:
        if latest["upperBounds"] != bounds:
            raise ValueError(
                "official PDF changed within an existing reference year; manual review required"
            )
        print(f"No update: reference year {reference_year} is already pinned")
        return

    if reference_year != latest_reference_year + 1:
        raise ValueError(
            f"expected reference year {latest_reference_year + 1}, found {reference_year}"
        )

    catalog["tables"].append({
        "referenceYear": reference_year,
        "publicationYear": publication_year,
        "databaseAsOf": database_as_of,
        "sourceURL": args.url,
        "upperBounds": bounds,
    })
    write_catalog(args.catalog, catalog)
    args.swift_output.write_text(render_swift(args.catalog), encoding="utf-8")
    print(
        f"Staged publication {publication_year} using the December 31, "
        f"{reference_year} reference population"
    )


if __name__ == "__main__":
    main()
