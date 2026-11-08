# EPTS mapping data provenance and annual update

The app pins reviewed OPTN mapping data. It never downloads allocation data at
runtime. `eptscalc/EPTSMappingTables.swift` is generated from the canonical
`Research/epts_mapping_tables.json` catalog.

## Current release

As of November 7, 2026, HRSA's current PDF is the 2026 publication based on all
adult kidney candidates on the waiting list on December 31, 2025. The table is
based on the OPTN database as of April 3, 2026.

Official current resources:

- EPTS calculator and resources: https://www.hrsa.gov/optn/data-calculators/allocation-calculators/epts-calculator
- Current mapping PDF: https://www.hrsa.gov/sites/default/files/hrsa/optn/epts_mapping_table.pdf
- Calculation guide: https://www.hrsa.gov/sites/default/files/hrsa/optn/epts_guide.pdf

The catalog contains the ten annual December 31 reference populations from 2016
through 2025. A mapping's publication year is the following calendar year.

| Publication | Reference population | Official table |
| ---: | ---: | --- |
| 2017 | Dec. 31, 2016 | [PDF](https://optn.transplant.hrsa.gov/media/3411/epts_mapping_table-31dec2016.pdf) |
| 2018 | Dec. 31, 2017 | [PDF](https://optn.transplant.hrsa.gov/media/mcng4epy/epts_mapping_table_2017.pdf) |
| 2019 | Dec. 31, 2018 | [PDF](https://optn.transplant.hrsa.gov/media/2973/epts_mapping_table_2018.pdf) |
| 2020 | Dec. 31, 2019 | [PDF](https://optn.transplant.hrsa.gov/media/3803/epts_mapping_table_2019.pdf) |
| 2021 | Dec. 31, 2020 | [PDF](https://optn.transplant.hrsa.gov/media/wn3buk04/epts_mapping_table_2020.pdf) |
| 2022 | Dec. 31, 2021 | [PDF](https://optn.transplant.hrsa.gov/media/diolqyfc/epts_mapping_table_2021.pdf) |
| 2023 | Dec. 31, 2022 | [PDF](https://www.hrsa.gov/sites/default/files/hrsa/optn/epts_mapping_table_2022.pdf) |
| 2024 | Dec. 31, 2023 | [PDF](https://www.hrsa.gov/sites/default/files/hrsa/optn/epts_mapping_table_2023.pdf) |
| 2025 | Dec. 31, 2024 | [PDF](https://www.hrsa.gov/sites/default/files/hrsa/optn/epts_mapping_table_2024.pdf) |
| 2026 | Dec. 31, 2025 | [current PDF](https://www.hrsa.gov/sites/default/files/hrsa/optn/epts_mapping_table.pdf) |

## Validation contract

`Scripts/import_epts_mapping.py` fails unless:

- the PDF identifies the requested December 31 reference year;
- percentiles 0 through 99 each appear exactly once and percentile 100 appears
  in both the observed-maximum and upper-sentinel rows;
- the 101 retained upper bounds are strictly increasing;
- every interval begins at the preceding interval's upper bound;
- the publication year follows the reference year; and
- provenance uses an HTTPS HRSA/OPTN source URL.

The lookup uses the official interval convention: raw EPTS is greater than the
lower bound and less than or equal to the upper bound. Values above the observed
maximum map to 100%.

## Sustainable release workflow

`.github/workflows/check-epts-mapping.yml` checks HRSA's current PDF every
Monday and can also be run manually. If HRSA publishes the next sequential
reference year, it validates the PDF, appends the catalog, regenerates Swift,
and opens a pull request. It does not open a duplicate while an update for that
publication year awaits review, and it never merges or releases automatically.

The checker attempts a direct HRSA download first. If HRSA's CDN rejects the
unattended request, the scheduled check may use Jina Reader as a read-only text
transport for the same official PDF URL. That fallback can only create an
unmerged candidate pull request; review must compare it with the official HRSA
PDF before merge.

If HRSA revises thresholds within an already-pinned reference year, skips a
year, changes the PDF layout, or serves a non-PDF response, the workflow fails
closed for manual investigation.

For a manual local import:

```sh
python3 Scripts/import_epts_mapping.py \
  --input /path/to/epts_mapping_table.pdf \
  --reference-year 2026 \
  --publication-year 2027 \
  --database-as-of "April 2, 2027" \
  --source-url "https://www.hrsa.gov/sites/default/files/hrsa/optn/epts_mapping_table.pdf" \
  --catalog Research/epts_mapping_tables.json

python3 Scripts/generate_epts_mapping_data.py \
  --catalog Research/epts_mapping_tables.json \
  --output eptscalc/EPTSMappingTables.swift
```

Review the official PDF, JSON and generated Swift diff, run the app tests, and
verify representative values against the official calculator before merging.
