#!/usr/bin/env python3
"""Import one official OPTN EPTS mapping release into the pinned catalog."""

from __future__ import annotations

import argparse
import subprocess
import tempfile
import urllib.parse
from pathlib import Path

from epts_mapping_tools import (
    extract_upper_bounds,
    load_catalog,
    read_source_text,
    write_catalog,
)


def download_official(url: str) -> Path:
    parsed = urllib.parse.urlparse(url)
    if parsed.scheme != "https" or not (
        parsed.hostname == "hrsa.gov" or (parsed.hostname or "").endswith(".hrsa.gov")
    ):
        raise ValueError("Only an HTTPS hrsa.gov source URL is accepted")

    suffix = Path(parsed.path).suffix or ".pdf"
    temporary = tempfile.NamedTemporaryFile(suffix=suffix, delete=False)
    temporary.close()
    output_path = Path(temporary.name)
    subprocess.run(
        [
            "curl", "--fail", "--location", "--silent", "--show-error",
            "--max-time", "60", "--user-agent", "eptscalc-mapping-maintainer/1.0",
            "--output", str(output_path), url,
        ],
        check=True,
    )
    payload = output_path.read_bytes()
    if suffix.lower() == ".pdf" and not payload.startswith(b"%PDF"):
        raise ValueError("official URL did not return a PDF")
    return output_path


def main() -> None:
    parser = argparse.ArgumentParser()
    input_group = parser.add_mutually_exclusive_group(required=True)
    input_group.add_argument("--input", type=Path, help="Downloaded official PDF or extracted text")
    input_group.add_argument("--url", help="Direct official hrsa.gov PDF URL")
    parser.add_argument("--reference-year", type=int, required=True)
    parser.add_argument("--publication-year", type=int, required=True)
    parser.add_argument("--database-as-of", required=True)
    parser.add_argument("--source-url", help="Required with --input; official source recorded in provenance")
    parser.add_argument("--catalog", type=Path, required=True)
    parser.add_argument("--replace", action="store_true", help="Replace an existing reference year")
    args = parser.parse_args()

    if args.publication_year != args.reference_year + 1:
        raise ValueError("publication year must be the year after the December 31 reference year")

    if args.url:
        source_url = args.url
        input_path = download_official(args.url)
    else:
        if not args.source_url:
            parser.error("--source-url is required with --input")
        source_url = args.source_url
        input_path = args.input

    source_text = read_source_text(input_path)
    expected_heading = f"December 31, {args.reference_year}"
    if expected_heading not in source_text:
        raise ValueError(f"source does not contain expected heading: {expected_heading}")

    bounds = extract_upper_bounds(source_text, str(input_path))
    new_table = {
        "referenceYear": args.reference_year,
        "publicationYear": args.publication_year,
        "databaseAsOf": args.database_as_of,
        "sourceURL": source_url,
        "upperBounds": bounds,
    }

    catalog = load_catalog(args.catalog) if args.catalog.exists() else {"schemaVersion": 1, "tables": []}
    existing = next(
        (table for table in catalog["tables"] if table["referenceYear"] == args.reference_year),
        None,
    )
    if existing and not args.replace:
        raise ValueError(
            f"reference year {args.reference_year} already exists; pass --replace explicitly"
        )
    if existing:
        catalog["tables"].remove(existing)

    catalog["tables"].append(new_table)
    catalog["tables"].sort(key=lambda table: table["referenceYear"])
    write_catalog(args.catalog, catalog)
    print(
        f"Imported reference {args.reference_year} / publication {args.publication_year}: "
        f"101 validated percentile bounds"
    )


if __name__ == "__main__":
    main()
