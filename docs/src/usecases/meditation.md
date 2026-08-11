# Meditation & Paced Breathing

## Motivation

Slow, paced breathing near 0.1 Hz is known to reshape heart-rate variability.
Which features move, and by how much relative to a healthy baseline? Using the
[normative reference](normative.md), this use case scores a real meditation
cohort and reads off its HRV signature as quantile z-equivalents.

Features are scored against the pooled healthy prior (`nsrdb` + `nsr2db`,
61 715 windows, 360-beat windows with a 120-beat stride) using the quantile
z-equivalent ``z = \Phi^{-1}(F_{\text{prior}}(x))``.

## The meditation cohort

**Dataset.** PhysioNet *Heart Rate Oscillations during Meditation*
[peng1999](@cite): 58 records (meditators and comparison groups, record labels
`C*`, `Y*`, `M*`, `N*`, `I*`), cut into 2 686 windows
(`test/testdata/meditation/windowed_w360_s120_features.csv`).

**Method.** For each headline feature, take the median across all 2 686 windows
and map it through the healthy prior. Every value below is reproducible from
the two shipped CSVs; no display or WFDB tools are needed.

**Result.** The cohort sits above the healthy population on the classic
vagal-tone panel:

| Feature | z-equivalent | Reading |
|---------|-------------|---------|
| [`mean`](../zoo/mean.md) (Mean IBI) | **+0.99** | longer inter-beat intervals (slower HR) |
| [`sdnn`](../zoo/sdnn.md) | **+0.87** | overall variability elevated |
| [`rmssd`](../zoo/rmssd.md) | **+0.84** | short-term vagal tone elevated |
| [`pnn50`](../zoo/pnn50.md) | **+0.71** | more large beat-to-beat changes |

The longer mean IBI together with elevated pNN50 is the expected fingerprint
of a vagally dominant state, consistent with the slowed, deepened breathing of
meditation and its respiratory-sinus-arrhythmia coupling [akselrod1981](@cite),
[taskforce1996](@cite).

## Takeaway

The normative machinery turns "meditation changes HRV" into a quantified,
feature-resolved statement: a broad vagal shift, with mean IBI, pNN50, RMSSD,
and SDNN all elevated together against the healthy reference. Context, meaning
*which* features move, is the diagnosis.

## Reproduce / where the data lives

- **Data:** `test/testdata/meditation/windowed_w360_s120_features.csv`
  (2 686 windows) scored against `docs/normative_priors.csv`; aggregation is
  the all-windows median, quantile z-equivalent.
- **Scoring:** identical to the [normative use case](normative.md):
  `normative_prior(name)` followed by ``\Phi^{-1}(\mathrm{cdf}(\cdot))``.
