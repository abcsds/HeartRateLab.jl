# Use Cases

HeartRateLab.jl is not just a feature library — it has been used to answer real
questions on real recordings. This section collects **finished applied studies**,
each built end-to-end with the package: from IBI parsing and windowed feature
extraction through to a concrete, reproducible result.

Every number on these pages is grounded in a shipped report or the committed data
in this repository; where a headline figure was superseded by a later
reconciliation, we say so explicitly and quote the corrected value.

## The applications

| Use case | Question answered | Headline result |
|----------|-------------------|-----------------|
| [Is my data normal?](normative.md) | Where does one HRV window sit relative to a healthy population? | A quantile *z*-equivalent against **61 715** pooled healthy windows, live-overlaid in `default_normative()`. |
| [Meditation & paced breathing](meditation.md) | What does a vagally-dominant state look like in HRV space? | Meditation cohort: elevated Mean IBI (+0.99σ) & SDNN (+0.87σ) against 61 715 pooled healthy windows. |
| [What do reported effects look like?](effect-distributions.md) | Does the harvested HRV applications literature carry publication-bias fingerprints? | p-curve + caliper tests over 153 study records from the [HRV knowledge base](../zoo/references.md) fields; only the clinical cell is individually powered. |

## How these relate to the rest of the docs

- The features scored on these pages each have a dedicated entry in the
  [HRV Variable Zoo](../zoo/index.md) — definition, normative distribution, and
  seminal citation.
- The normative and personal-baseline machinery is documented under
  [Visualization](../visualization.md).
