#!/usr/bin/env bash
# =============================================================================
# recollect_normative.sh
#
# Runs collect_normative_datasets.jl for all three window/stride configurations.
# With SKIP_EXISTING=true (default), skips heavy feature extraction if CSVs
# already exist and only appends a metadata entry — runs in seconds per pass.
#
# Set SKIP_EXISTING=false to force full re-extraction (very slow — see ETAs).
#
# Estimated wall-clock times per run (SKIP_EXISTING=false, from prior runs):
#   w10  s5   : nsrdb ~4.3h  + nsr2db ~13.9h + mvtdb <1min  ≈ 18h
#   w60  s30  : nsrdb ~0.7h  + nsr2db ~2.3h  + mvtdb <1min  ≈  3h  (estimated)
#   w360 s120 : nsrdb <5min  + nsr2db <10min + mvtdb <1min  ≈ 15min (estimated)
#   Total worst-case: ~21 hours
#
# Usage (from project root):
#   bash recollect_normative.sh
#   SKIP_EXISTING=false bash recollect_normative.sh   # full re-extraction
# =============================================================================

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT="$PROJECT_ROOT/test/tools/collect_normative_datasets.jl"
JULIA="${JULIA:-julia}"

hr() { printf '%0.s─' $(seq 1 70); echo; }

run_collection() {
    local w=$1 s=$2 eta=$3
    hr
    echo "  Window: w${w}  Stride: s${s}   (ETA if full re-run: ${eta})"
    echo "  Started: $(date '+%Y-%m-%d %H:%M:%S')"
    hr
    local t0=$SECONDS
    WINDOW_SIZE=$w STRIDE=$s "$JULIA" --project="$PROJECT_ROOT" "$SCRIPT"
    local elapsed=$(( SECONDS - t0 ))
    printf "  Finished in %dh %02dm %02ds\n" \
        $(( elapsed/3600 )) $(( (elapsed%3600)/60 )) $(( elapsed%60 ))
}

echo
echo "HeartRateLab — Normative Dataset Re-collection"
echo "SKIP_EXISTING=${SKIP_EXISTING:-true}"
echo

run_collection  10   5  "~18h"
run_collection  60  30  "~3h"
run_collection 360 120  "~15min"

hr
echo "  All three runs complete: $(date '+%Y-%m-%d %H:%M:%S')"
echo "  Check test/testdata/*/metadata.toml for [[analyses]] entries."
hr
