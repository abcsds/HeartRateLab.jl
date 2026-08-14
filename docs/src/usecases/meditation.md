# Meditation & Resonant Breathing

## Motivation

Slow, paced breathing near 0.1 Hz is known to reshape heart-rate variability.
Which features move, and by how much relative to a healthy baseline? Using the
[normative reference](normative.md), this use case scores two very different
real datasets and reads off their HRV signatures as quantile z-equivalents: a
meditation cohort and a longitudinal resonant-breathing participant.

Features are scored against the pooled healthy prior (`nsrdb` + `nsr2db`,
61 715 windows, 360-beat windows with a 120-beat stride) using the quantile
z-equivalent ``z = \Phi^{-1}(F_{\text{prior}}(x))``.

## Case A: the meditation cohort

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

## Case B: a longitudinal resonant-breathing participant

**Dataset.** One pseudonymized participant (`Resonant_Breathing`) recorded over
88 dates across 2019 to 2025, yielding 148 windows at the same 360-beat window
and 120-beat stride. Per-feature medians ship in `docs/poster/zscores.csv`
(column `p1_median`), scored against the same healthy prior; the full
per-feature report is
[participant, w360 / s120](reports/participant_Resonant_Breathing_w360s120_report.html).

**Result: a selective LF-band boost.** Unlike the broad shift of Case A, this
participant's departure from normal is concentrated in the low-frequency band
and its ratio, while short-term vagal indices stay squarely typical:

| Feature | z | Feature | z | Feature | z |
|---|---|---|---|---|---|
| [`lf_hf_ratio`](../zoo/lf_hf_ratio.md) | **+2.62** | [`sdnn`](../zoo/sdnn.md) | +1.06 | [`rmssd`](../zoo/rmssd.md) | −0.01 |
| [`lf`](../zoo/lf.md) (LF power) | **+2.55** | [`pnn50`](../zoo/pnn50.md) | +0.44 | [`sd1`](../zoo/sd1.md) | −0.01 |
| [`sd2`](../zoo/sd2.md) | +1.16 | [`mean`](../zoo/mean.md) (Mean IBI) | +0.07 | [`hf`](../zoo/hf.md) (HF power) | −0.18 |

LF power and LF/HF sit beyond +2.5σ while RMSSD, SD1, and HF are within a
fifth of a σ of typical. That dissociation, a large low-frequency oscillation
without a matching rise in high-frequency respiratory power or short-term
scatter, is the classic signature of resonant-frequency breathing near 0.1 Hz
driving the baroreflex [akselrod1981](@cite): the maneuver pumps energy
specifically into the LF band.

![Resonant_Breathing participant vs healthy normative reference, 9-feature KDE grid](figs/hero_participant_vs_normative.png)

Each panel shows the participant's feature distribution against the healthy
normative reference with 68/95/99.7 % bands. LF and LF/HF push well into the
outer bands; RMSSD and HF stay central. Tracked over time, the two behave
differently: LF/HF is repeatedly elevated across sessions, while RMSSD stays
inside the typical range.

![LF/HF over time, repeatedly elevated](figs/lfhf_over_time.png)

![RMSSD over time, inside the typical range](figs/rmssd_over_time.png)

## Takeaway

The same normative machinery cleanly separates two kinds of "not average":
Case A's broad vagal shift, with everything elevated together, versus Case B's
narrow spectral signature confined to the LF band. Context, meaning *which*
features move, is the diagnosis.

## Reproduce / where the data lives

- **Case A data:** `test/testdata/meditation/windowed_w360_s120_features.csv`
  (2 686 windows) scored against `docs/normative_priors.csv`; aggregation is
  the all-windows median, quantile z-equivalent.
- **Case B data:** per-feature medians in `docs/poster/zscores.csv`, the
  rendered per-feature report under `docs/src/usecases/reports/`, and the
  figures from the JuliaCon 2026 poster (`docs/poster/figs/`).
- **Scoring:** identical to the [normative use case](normative.md):
  `normative_prior(name)` followed by ``\Phi^{-1}(\mathrm{cdf}(\cdot))``.
