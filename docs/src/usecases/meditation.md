# Meditation & Paced Breathing

## Motivation

Slow, paced breathing — meditation and resonant-frequency breathing near
~0.1 Hz — is known to reshape heart-rate variability. But *which* features move,
and by how much relative to a healthy baseline? Using the
[normative reference](normative.md), this use case scores a real meditation
cohort and reads off its HRV signature as quantile *z*-equivalents.

Features are scored against the pooled healthy prior
(`nsrdb` + `nsr2db`, 61 715 windows, 360-beat windows / 120-beat stride) using the
quantile z-equivalent ``z = \Phi^{-1}(F_{\text{prior}}(x))``.

---

## The meditation cohort

**Dataset.** PhysioNet *Heart Rate Oscillations during Meditation*
[peng1999](@cite) — **58 records** (meditators and comparison groups; record
labels `C*`, `Y*`, `M*`, `N*`, `I*`), cut into **2 686** windows
(`test/testdata/meditation/windowed_w360_s120_features.csv`).

**Method.** For each headline feature, take the **median across all 2 686 windows**,
then map it through the healthy prior with the quantile z-equivalent. Every value
below is reproducible from the two shipped CSVs — no display or WFDB tools needed.

**Result.** The cohort sits **above** the healthy population on the classic
vagal-tone panel:

| Feature | z-equivalent | Reading |
|---------|-------------|---------|
| [`mean`](../zoo/mean.md) (Mean IBI) | **+0.99** | longer inter-beat intervals (slower HR) |
| [`pnn50`](../zoo/pnn50.md) | **+0.71** | more large beat-to-beat changes |
| [`rmssd`](../zoo/rmssd.md) | **+0.84** | short-term vagal tone modestly elevated |
| [`sdnn`](../zoo/sdnn.md) | **+0.87** | overall variability modestly elevated |

The longer Mean IBI together with elevated pNN50 is the expected fingerprint of a
**vagally-dominant** state — consistent with the slowed, deepened breathing of
meditation and its respiratory-sinus-arrhythmia coupling [akselrod1981](@cite),
[taskforce1996](@cite).

!!! warning "Reconciled numbers (2026-07-29, re-referenced 2026-08-11)"
    These are the **reproducible recompute** from the shipped cohort, not the
    original accepted-abstract values. A forensic audit (2026-07-29) found the
    abstract's **RMSSD +0.62 / SDNN +0.78 do not reproduce** under any
    aggregation × method: they imply observed medians (~42–45 / ~70–73 ms)
    *below* what the committed CSV yields (49.98 / 74.68 ms), i.e. they came
    from an earlier feature extraction not committed to this repo. The
    abstract's phrase "reduced pNN50" is also an error — the pNN50
    z-equivalent is an **increase** under every method tried. Full audit:
    [z-score reconciliation report](reports/zscore-reconciliation.html).

    The audit itself scored against the earlier 56 472-window prior fit
    (Mean IBI +1.02, pNN50 +1.32, RMSSD +0.94, SDNN +0.90). The table above
    re-scores the **same unchanged cohort medians** against the current
    61 715-window re-extraction and prior re-fit; the qualitative reading —
    a broad vagal elevation — is unchanged.

## Takeaway

The normative machinery turns "meditation changes HRV" into a quantified,
feature-resolved statement: a **broad vagal shift** — Mean IBI, pNN50, RMSSD,
and SDNN all elevated together against the healthy reference. Context —
*which* features move — is the diagnosis.

## Reproduce / where the data lives

- **Data:** `test/testdata/meditation/windowed_w360_s120_features.csv`
  (2 686 windows) scored against `docs/normative_priors.csv`; aggregation =
  all-windows median, quantile z-equivalent. Audit + method matrix:
  [`reports/zscore-reconciliation.html`](reports/zscore-reconciliation.html).
- **Scoring:** identical to the [normative use case](normative.md) —
  `normative_prior(name)` + ``\Phi^{-1}(\mathrm{cdf}(\cdot))``.
