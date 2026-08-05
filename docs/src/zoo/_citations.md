# HRV feature → seminal-reference map

Fills the `[CITE:<feature>]` slots in the feature Pokédex. Keys resolve against
`docs/references.bib`. One row per `@register`ed measure in `src/Features.jl`.

- **Representation** rows (`diff`, `length`, `duration`, `pgram`, `max_t`, `px`,
  `py`, `histogram`, `renyi`, `dfa`) are building blocks, not scalar features;
  they inherit the citation of the scalar measures built on them.
- Where the "first" author is genuinely contested, both candidates are listed
  and flagged **(contested)**.

Coverage: 53 scalar features. 48 have a confident seminal reference; 5 are
descriptive primitives attributed to the Task Force 1996 standard by convention
(no earlier single origin exists); 5 map to a contested pair or lineage dispute
(`sd1`/`sd2`, `sd2_sd1`, `sdnn`/`sdann`).

## Time domain

| Feature | BibTeX key(s) | Who / what / year |
|---------|---------------|-------------------|
| `mean` (mean_rr/nn) | `taskforce1996` | Task Force standard time-domain panel, 1996 (basic descriptive statistic; no earlier single origin) |
| `median` | `taskforce1996` | Task Force 1996 (descriptive primitive) |
| `max` / `min` / `range` | `taskforce1996` | Task Force 1996 (descriptive primitives) |
| `sdnn` | `kleiger1987`; `wolf1978`; `taskforce1996` | Kleiger et al. 1987 established/popularised SDNN as the prognostic 24-h HRV index; standardised by Task Force 1996. **Primacy contested:** Wolf et al. 1978 already linked a cruder RR-SD/variance measure to post-MI mortality ~9 years earlier |
| `sdann` | `kleiger1987`; `wolf1978`; `taskforce1996` | SDANN (SD of 5-min mean NN), Kleiger 1987 / Task Force 1996. **Primacy contested:** as `sdnn` — Wolf et al. 1978 predates Kleiger |
| `sdsd` | `taskforce1996`; `ewing1984` | Task Force 1996 (SD of successive differences). Lineage: successive-difference measures predate the Task Force — Ewing et al. 1984 used them clinically; the statistic itself traces to von Neumann's 1941 mean-square successive difference (not independently on file) |
| `rmssd` | `taskforce1996`; `ewing1984` | Task Force 1996 short-term vagal index (consensus standard). Lineage: as `sdsd` — predates the Task Force via Ewing 1984 / von Neumann 1941 |
| `pnn50` | `ewing1984`; `taskforce1996` | Ewing et al. 1984 introduced the NN50 count; pNN50 formalised by Task Force 1996 |
| `pnn20` | `mietus2002` | Mietus et al. 2002, "The pNNx files" — generalised pNNx incl. pNN20 |
| `cvnni` | `taskforce1996` | Coefficient of variation of NN (SDNN/mean), Task Force 1996 |
| `cvsd` | `taskforce1996` | CV of successive differences (RMSSD/mean), Task Force 1996 |
| `rRR` | `vollmer2015` | Vollmer 2015 — relative-RR robustness measure (cited in docstring) |
| `mean_hr` / `std_hr` / `max_hr` / `min_hr` / `median_hr` / `range_hr` | `taskforce1996` | BPM re-expressions of the time-domain panel, Task Force 1996 |

## Frequency domain (Lomb–Scargle / Welch)

| Feature | BibTeX key(s) | Who / what / year |
|---------|---------------|-------------------|
| `pgram` *(repr.)* | `lomb1976`, `scargle1982`, `moody1993`; `welch1967` | Lomb 1976 + Scargle 1982 least-squares periodogram; Moody 1993 applied it to unevenly-sampled HR; Welch 1967 for the Welch backend |
| `ulf` | `bigger1996`; `taskforce1996` | Ultra-low-freq / 1-f power-law scaling, Bigger et al. 1996; bands per Task Force 1996 |
| `vlf` | `akselrod1981`; `taskforce1996` | Akselrod et al. 1981 (seminal HRV power-spectrum paper); band per Task Force 1996 |
| `lf` | `akselrod1981`; `taskforce1996` | Akselrod 1981 / Task Force 1996 LF band (0.04–0.15 Hz) |
| `hf` | `akselrod1981`; `taskforce1996` | Akselrod 1981 / Task Force 1996 HF band (0.15–0.4 Hz) |
| `tp` | `akselrod1981`; `taskforce1996` | Total power, Akselrod 1981 / Task Force 1996 |
| `lf_peak` / `hf_peak` | `taskforce1996` | Band peak frequencies, Task Force 1996 |
| `lf_hf_ratio` | `pagani1986`; `taskforce1996` | Pagani et al. 1986 introduced the LF/HF ratio as a sympatho-vagal marker; standardised as "sympathovagal balance" by Task Force 1996 |
| `lf_relative` / `hf_relative` / `lf_percentage` / `hf_percentage` | `taskforce1996` | Normalised-unit / %-of-total-power representations, Task Force 1996 |

## Poincaré / Lorenz-plot geometry

| Feature | BibTeX key(s) | Who / what / year |
|---------|---------------|-------------------|
| `px` / `py` *(repr.)* | `tulppo1996` | Poincaré (return-map) coordinates; quantified by Tulppo et al. 1996 |
| `sd1` | `tulppo1996`; `brennan2001` | Tulppo et al. 1996 introduced SD1 ellipse fitting; Brennan et al. 2001 gave the closed-form **(contested)** |
| `sd2` | `tulppo1996`; `brennan2001` | as `sd1` **(contested)** |
| `sd2_sd1` (csi) | `tulppo1996`; `toichi1997` | SD2/SD1 ratio, Tulppo 1996; the "cardiac sympathetic index" naming, Toichi et al. 1997 **(contested)** |
| `sd1_sd2_area` | `brennan2001`; `taskforce1996` | Poincaré ellipse area π·SD1·SD2, Brennan 2001 / Task Force geometric methods |
| `cvi` | `toichi1997` | Cardiac vagal index, Toichi et al. 1997 |
| `ccsi` (modified/corrected CSI = 4·SD2²/SD1) | `jeppesen2014` | Modified CSI, Jeppesen et al. 2014 (Lorenz-plot seizure detection) |
| `histogram` *(repr.)* | `taskforce1996` | RR density histogram, Task Force 1996 geometric methods |
| `triangular_index` | `malik1989`; `taskforce1996` | HRV triangular index, Malik et al. 1989; standardised Task Force 1996 |
| `tinn` | `malik1989`; `taskforce1996` | Triangular Interpolation of NN histogram, Malik et al. 1989 / Task Force 1996 |

## Entropy / complexity

| Feature | BibTeX key(s) | Who / what / year |
|---------|---------------|-------------------|
| `apen` | `pincus1991` | Approximate entropy, Pincus 1991 (PNAS) |
| `sampen` | `richman2000` | Sample entropy, Richman & Moorman 2000 |
| `fuzzyen` | `chen2007` | Fuzzy entropy, Chen et al. 2007 |
| `shan_en` | `shannon1948` | Shannon entropy of the RR histogram, Shannon 1948 |
| `svd_en` | `roberts1999` | SVD (singular-spectrum) entropy, Roberts, Penny & Rezek 1999 |
| `spec_en` | `inouye1991` | Spectral entropy, Inouye et al. 1991 |
| `perm_en` | `bandt2002` | Permutation entropy, Bandt & Pompe 2002 |
| `mse` | `costa2002` | Multiscale entropy, Costa, Goldberger & Peng 2002 |
| `renyi0` / `renyi1` / `renyi2` | `renyi1961` | Rényi generalised entropy of order α, Rényi 1961 |
| `renyi` *(repr.)* | `renyi1961` | Rényi 1961 (base dispatcher) |

## Fractal / scaling

| Feature | BibTeX key(s) | Who / what / year |
|---------|---------------|-------------------|
| `dfa` *(repr.)* | `peng1994`, `peng1995` | DFA algorithm, Peng et al. 1994 (PRE); heartbeat α1/α2, Peng et al. 1995 (Chaos) |
| `dfa1` | `peng1995`; `francis2002` | Short-term α1 (n=4–16), Peng 1995; window convention Francis et al. 2002 |
| `dfa2` | `peng1995`; `francis2002`, `iyengar1996` | Long-term α2 (n=16–64), Peng 1995 / Francis 2002; competing clinical range Iyengar et al. 1996 |
| `hurst` | `hurst1951` | Hurst exponent (rescaled-range analysis), Hurst 1951 |

## Unresolved / notes

- **SD1/SD2 & SD2/SD1 (contested):** Tulppo 1996 introduced the ellipse-fitting
  SD1/SD2 during exercise; Brennan 2001 derived the closed-form linking them to
  SDNN/SDSD. Both are legitimately "first" for different framings — cite both.
- **CSI naming (contested):** the `csi` alias on `sd2_sd1` conflates the plain
  SD2/SD1 ratio (Tulppo) with Toichi's L/T "cardiac sympathetic index." They are
  numerically the same ratio with different axis definitions.
- **SDNN/SDANN prognostic primacy (contested):** Kleiger et al. 1987 is
  conventionally credited with establishing SDNN as *the* prognostic 24-h HRV
  index post-MI, but Wolf et al. 1978 (Med J Aust) had already shown a cruder
  RR-interval SD/variance measure predicting lower post-MI hospital mortality
  nearly a decade earlier. Both are cited on `sdnn`/`sdann`; Kleiger remains the
  index's namesake and populariser, Wolf the earlier empirical finding.
- **RMSSD/SDSD lineage (predates Task Force 1996):** successive-difference HRV
  measures are older than the 1996 standard that formalised them — Ewing et al.
  1984 already used them clinically (cited on `rmssd`/`sdsd`), and the
  underlying statistic (mean square of successive differences) traces back to
  von Neumann's 1941 *Ann. Math. Statist.* paper on ratio-of-successive-
  differences-to-variance, which is not independently verified/on file here.
- **Descriptive primitives** (`mean`, `median`, `max`, `min`, `range`, `cvsd`,
  `cvnni`, HR re-expressions): no single seminal paper; attributed to the Task
  Force 1996 standard by convention. These are the 5 "no confident single
  origin" cases.
