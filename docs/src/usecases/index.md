# Use Cases

HeartRateLab.jl is not just a feature library; it has been used to answer real
questions on real recordings. This section collects finished applied studies,
each built end-to-end with the package, from IBI parsing and windowed feature
extraction to a concrete, reproducible result. Every number on these pages is
grounded in the committed data in this repository.

## The applications

| Use case | Question answered | Headline result |
|----------|-------------------|-----------------|
| [Is my data normal?](normative.md) | Where does one HRV window sit relative to a healthy population? | A quantile *z*-equivalent against 61 715 pooled healthy windows, live-overlaid in `default_normative()`. |
| [Meditation & resonant breathing](meditation.md) | What does a vagally dominant or resonance state look like in HRV space? | Meditation cohort: broad vagal elevation (mean IBI +0.99σ, SDNN +0.87σ). A longitudinal resonant-breathing participant: a selective LF-band boost (LF/HF +2.62σ) with typical RMSSD. |
| [What do reported effects look like?](effect-distributions.md) | Does the harvested HRV applications literature carry publication-bias fingerprints? | p-curve and funnel/Egger tests over the [HRV knowledge base](../zoo/references.md) fields; bias indicated in the one well-powered cell. |

## The JuliaCon 2026 poster

![JuliaCon 2026 poster, normative evaluation of HRV from open datasets](figs/poster-full.png)

The normative-evaluation and breathing use cases were assembled into a JuliaCon
Global 2026 poster, "Using HeartRateLab.jl for Normative Evaluation of Heart
Rate Variability from Open Datasets". The poster sources, figures, and data
live under `docs/poster/`.

## How these relate to the rest of the docs

The features scored on these pages each have a dedicated entry in the
[HRV Variable Zoo](../zoo/index.md), with definition, normative distribution,
and seminal citation. The normative and personal-baseline machinery is
documented under [Visualization](../visualization.md).
