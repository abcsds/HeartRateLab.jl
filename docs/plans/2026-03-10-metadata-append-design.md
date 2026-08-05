# Design: Append-Safe metadata.toml for Normative Datasets

**Date:** 2026-03-10
**Status:** Approved

## Problem

`write_metadata` in `collect_normative_datasets.jl` opens `metadata.toml` with `"w"` (overwrite). Running
collection with different `WINDOW_SIZE`/`STRIDE` values replaces the previous `[collection]` record and
`[files].windowed_features` pointer, losing provenance for earlier runs.

## Solution: TOML Array of Tables (`[[analyses]]`)

Replace the single `[collection]` block with a TOML array-of-tables `[[analyses]]`. Each collection run
appends one entry. The `[files]` section retains only `participant_features`; the windowed CSV filename
moves into each analysis entry.

### New metadata.toml structure

```toml
[dataset]
name = "nsrdb"
# ... stable dataset metadata ...

[normative]
# ... unchanged ...

[files]
participant_features = "participant_features.csv"

[[analyses]]
date = "2026-03-01T16:29:30.573"
window_size = 10
stride = 5
windowed_features = "windowed_w10_s5_features.csv"
heartrateLab_version = "1.0.0"
n_records_attempted = 18
n_records_collected = 18
n_records_failed = 0
elapsed_seconds = 15346.8

[[analyses]]
date = "2026-03-10T09:00:00.000"
window_size = 60
stride = 30
windowed_features = "windowed_w60_s30_features.csv"
# ...
```

## Implementation

1. `write_metadata` reads existing `metadata.toml` if present.
2. Extracts `analyses` array (handles old `[collection]` single-table by migrating it as first entry).
3. Appends new analysis entry.
4. Writes the full file back (stable sections + updated analyses array).
5. Existing `metadata.toml` files in testdata migrated manually to new format.

## Affected Files

- `test/tools/collect_normative_datasets.jl` — `write_metadata` function (lines 582–621)
- `test/testdata/nsrdb/metadata.toml` — migrate to new format
- `test/testdata/nsr2db/metadata.toml` — migrate to new format
- `test/testdata/mvtdb/metadata.toml` — migrate to new format
