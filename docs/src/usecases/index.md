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
| [Meditation & paced breathing](meditation.md) | What does a vagally dominant state look like in HRV space? | Meditation cohort: elevated mean IBI (+0.99σ) and SDNN (+0.87σ) against the pooled healthy windows. |
| [What do reported effects look like?](effect-distributions.md) | Does the harvested HRV applications literature carry publication-bias fingerprints? | p-curve and funnel/Egger tests over the [HRV knowledge base](../zoo/references.md) fields; bias indicated in the one well-powered cell. |

## How these relate to the rest of the docs

The features scored on these pages each have a dedicated entry in the
[HRV Variable Zoo](../zoo/index.md), with definition, normative distribution,
and seminal citation. The normative and personal-baseline machinery is
documented under [Visualization](../visualization.md).
