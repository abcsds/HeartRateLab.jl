# Poster notes — *Normative Evaluation of HRV with HeartRateLab.jl*

**JuliaCon Global 2026 · Alberto Barradas (abcsds) · Mainz, Aug 10–15 2026**

Distributable companion to the poster: the exact method, the full feature panel with
its fitted distributions and fit quality, the selection model, and an honest limitations
list. If someone at the booth asks "how does this actually work / is this rigorous?",
this is the answer.

---

## 1. The question

Given a new HRV recording, **"is it normal?"** is unanswerable without a reference. We
build that reference from open data, score any recording against it, and are explicit
about what the score does and does not mean.

## 2. What is compared with what (read this first)

There are **three** data sources but they play **two** roles:

| Role | Data | Size | Use |
|---|---|---|---|
| **Healthy reference (the "prior")** | PhysioNet **nsrdb + nsr2db** (normal-sinus-rhythm) | 56,472 windows, **66 subjects** | pooled → one fitted normative distribution per feature |
| **Case A — meditation** | PhysioNet *Heart Rate Oscillations during Meditation*, **during-meditation** state (Chi + Kundalini, records ending `med`) | 263 windows, **11 practitioners** | scored against the reference |
| **Case B — one participant** | Longitudinal self-recordings ("Participant P1"), 2019–2025 | 148 windows, 88 dates | scored against the reference |

So both cases are compared **against the same healthy reference**, not against each
other. The poster's 3-way comparison figure overlays all three distributions per feature
so you can see reference vs meditators vs P1 directly.

## 3. The pipeline (end to end, in Julia)

1. **Read** inter-beat intervals — `read_txt` / `read_wfdb` / `read_xdf`. IBIs in ms.
2. **Preprocess** — `replace_zeros`, `replace_bio_outliers` (physiological range
   300–2000 ms), `interpolate_nans`. Non-mutating and mutating (`!`) pairs.
3. **Extract features** — 53 registered HRV features via the `@register` + `@memoize`
   registry; time-domain, frequency-domain (Lomb–Scargle), and nonlinear.
4. **Window** — 360 beats, 120-beat stride (`windowed_feature_set`). One feature row per
   window.
5. **Fit a normative prior** per feature by **maximum likelihood** over the 56,472 healthy
   windows, choosing a family (Normal / Gamma / Beta / LogNormal) per feature (see §4).
6. **Score** a new window: `percentile = F_prior(x)`, then
   `z_equivalent = Φ⁻¹(percentile)`. This is a **quantile re-expression on a standard
   normal**, valid for skewed families — *not* standard deviations of the raw feature.

## 4. Feature panel, fitted distributions, and fit quality

Below: every registered feature, its fitted family + MLE parameters, the
Kolmogorov–Smirnov goodness-of-fit p-value, valid-window count, and (where modelled) its
selection stability + direction in the meditation model (§5). Sorted by stability.

> **Honest fit-quality note.** **All 36 fitted families are *rejected* by the KS test
> (every p < 0.05).** With n = 56,472, KS rejects even tiny departures, so these
> parametric priors are **convenient approximations, not verified fits** — adequate for
> percentile scoring, not a claim that HRV features *are* Gamma/Beta/etc. **Eight
> features are not fitted at all** (entropy/fractal: apen, sampen, dfa2, hurst,
> renyi0/1/2, ulf) — no prior, no score. `sdann`/`vlf` have reduced valid-window counts.

| Feature | Family | MLE params | KS p (fit) | n valid | Stability | Dir |
|---|---|---|---|---|---|---|
| lf_hf_ratio | LogNormal | L(0.858, 0.857) | 8.4e-12 | 56472 | 77% | ↑ |
| hf_peak | Normal | N(0.212, 0.0625) | 5.9e-112 | 56472 | 70% | ↑ |
| lf_percentage | Gamma | G(8.91, 4.38) | 2.6e-39 | 56472 | 67% | ↑ |
| lf_relative | Beta | B(5.3, 8.29) | 2.6e-63 | 56472 | 67% | ↑ |
| lf_peak | Normal | N(0.0644, 0.0182) | 0.0e+00 | 56472 | 64% | ↑ |
| pnn20 | Beta | B(2.64, 12.5) | 6.6e-29 | 56472 | 61% | ↑ |
| tp | Gamma | G(0.996, 1.52e+03) | 9.0e-163 | 56472 | 52% | ↑ |
| lf | Gamma | G(0.871, 706) | 1.6e-183 | 56472 | 47% | ↑ |
| sd2_sd1 | LogNormal | L(1.16, 0.526) | 3.8e-05 | 56472 | 46% | ↓ |
| mean_hr | Normal | N(79.8, 14.9) | 3.1e-69 | 56472 | 46% | ↑ |
| pnn50 | Beta | B(0.427, 10.3) | 1.5e-153 | 56472 | 43% | ↑ |
| tinn | Gamma | G(5.4, 30.6) | 1.2e-27 | 56472 | 36% | ↓ |
| max_hr | Normal | N(65.8, 13.5) | 6.9e-45 | 56472 | 34% | ↑ |
| median | Normal | N(779, 147) | 1.1e-50 | 56472 | 32% | ↑ |
| mean | Normal | N(778, 144) | 5.3e-42 | 56472 | 28% | ↓ |
| hf_percentage | Gamma | G(2.54, 7.59) | 7.6e-49 | 56472 | 26% | ↑ |
| hf_relative | Beta | B(1.36, 5.7) | 2.8e-50 | 56472 | 26% | ↑ |
| std_hr | Gamma | G(3.92, 377) | 6.1e-22 | 56472 | 26% | ↓ |
| min_hr | Normal | N(99.7, 20.5) | 2.1e-113 | 56472 | 24% | ↓ |
| triangular_index | Gamma | G(6.11, 1.69) | 1.7e-27 | 56472 | 24% | ↑ |
| cvi | Normal | N(4.27, 0.424) | 1.1e-28 | 56472 | 21% | ↑ |
| max | Normal | N(951, 196) | 1.1e-14 | 56472 | 18% | ↓ |
| cvsd | Gamma | G(3.2, 0.013) | 2.5e-141 | 56472 | 17% | ↑ |
| min | Normal | N(627, 126) | 2.6e-30 | 56472 | 16% | ↓ |
| ccsi | LogNormal | L(6.65, 0.879) | 2.3e-06 | 56472 | 15% | ↓ |
| rRR | Gamma | G(4.63, 0.785) | 2.9e-215 | 56472 | 12% | ↓ |
| sd2 | Gamma | G(3.87, 18) | 1.7e-45 | 56472 | 8% | ↑ |
| hf | Gamma | G(0.692, 461) | 1.1e-188 | 56472 | 7% | ↓ |
| range | Gamma | G(3.62, 89.4) | 8.3e-33 | 56472 | 7% | ↓ |
| rmssd | Gamma | G(2.7, 12.2) | 7.5e-66 | 56472 | 6% | ↑ |
| sd1 | Gamma | G(2.7, 8.62) | 7.7e-66 | 56472 | 6% | ↑ |
| sdsd | Gamma | G(2.7, 12.2) | 7.7e-66 | 56472 | 6% | ↑ |
| sd1_sd2_area | LogNormal | L(8.2, 0.977) | 1.1e-28 | 56472 | 4% | ↓ |
| sdnn | Gamma | G(4.02, 13.1) | 4.0e-55 | 56472 | 2% | ↑ |
| apen | Normal | — (not fitted) | — | 0 | — | — |
| dfa2 | Normal | — (not fitted) | — | 0 | — | — |
| hurst | Beta | — (not fitted) | — | 0 | — | — |
| renyi0 | Normal | — (not fitted) | — | 0 | — | — |
| renyi1 | Normal | — (not fitted) | — | 0 | — | — |
| renyi2 | Normal | — (not fitted) | — | 0 | — | — |
| sampen | Normal | — (not fitted) | — | 0 | — | — |
| sdann | Gamma | G(0.87, 27.9) | 2.2e-38 | 18609 | — | — |
| ulf | Gamma | — (not fitted) | — | 0 | — | — |
| vlf | Gamma | G(1.24, 892) | 0.0e+00 | 54083 | — | — |

## 5. The selection model (which features actually matter, without cherry-picking)

**Motivation.** Several features are, by definition, functions of others, so presenting a
hand-picked set as independent evidence is misleading. Measured collinearity on the
healthy reference:

- **SDSD = SD1 = RMSSD** — |r| = **1.000** (algebraically the same information)
- **HF-relative = HF %**, **LF-relative = LF %** — |r| = 1.000
- **Mean IBI ≈ Median IBI** — 0.997; **Mean IBI ≈ Mean HR** — 0.972
- **SDNN ≈ SD2** — 0.976

**Method.** L1-regularized logistic regression (**meditation-state vs healthy**),
standardized to the healthy frame, solved by proximal-gradient FISTA. Instead of one fit,
**stability selection**: 200 resamples, each drawing meditation **records** and healthy
**subjects** as whole groups (so windows within a recording never leak across the split),
classes balanced. We report how often each feature is selected. L1 keeps one representative
of each collinear cluster and drops the rest — the model does the de-duplication for us.

**Results.**

| Feature | Selection stability | Direction |
|---|---|---|
| **LF/HF** | **77 %** | ↑ higher in meditation |
| HF peak | 70 % | ↑ |
| LF relative / LF % | 67 % | ↑ (one variable, two names) |
| LF peak | 64 % | ↑ |
| pNN20 | 61 % | ↑ |
| Total power | 52 % | ↑ |
| LF power | 47 % | ↑ |

**Discrimination:** subject-grouped 5-fold cross-validated **AUC = 0.73 ± 0.27**.

**Interpretation.** Allowed to choose among 34 collinear features with leakage-free
resampling, the model most stably selects the **~0.1 Hz LF-band features** (LF/HF, LF
fraction, LF/HF peak) plus **pNN20** — physiologically coherent with the slow (~6 breaths/
min) breathing of Chi and Kundalini meditation, which concentrates spectral power in the
LF band. **This is the LF-band story the poster tells — but earned by a principled
selection rather than asserted.** Crucially, the effect is **modest and uncertain**: AUC
≈ 0.73 with a ±0.27 spread, no feature exceeds 77 % stability, and there are only **11
meditators** — this is exploratory, not a validated classifier.

## 6. Case results as scored (descriptive)

- **Case A — meditation (during-meditation windows, quantile z vs prior):**
  pNN50 +0.84, SDNN +0.81, RMSSD +0.38, Mean IBI +0.23 — all within ±1σ; a mild, coherent
  vagal shift. (Pooling rest + meditation epochs inflates these to +0.9…+1.3σ — the effect
  is epoch-dependent, which is why we score meditation-state windows only.)
- **Case B — Participant P1 (quantile z vs prior):** LF/HF +2.64, LF power +2.55, SD2
  +1.19, SDNN +1.12, pNN50 +0.74, Mean IBI +0.07, SD1/RMSSD +0.03, HF −0.17 — a selective
  LF-band elevation consistent with a resonant-breathing practice.

## 7. Limitations (what these numbers are *not*)

1. **Pseudoreplication.** Windows within a recording are autocorrelated. The per-window z
   and the dispersion bands are **window-level, descriptive** — not per-subject inferential
   tests. The selection model mitigates this with subject-grouped resampling; the case
   z-scores do not, and should be read descriptively.
2. **Tiny meditation n.** 11 practitioners. CV AUC ±0.27 reflects this honestly.
3. **Collinearity.** Handled in the model (§5) but *present* — never read the raw
   per-feature z-scores as independent lines of evidence.
4. **Parametric priors are KS-rejected** (§4) — approximations for scoring, not fitted laws.
5. **Case B is n = 1** (the author's own data, anonymised as P1). A demonstration of the
   *monitor*, not a population claim.
6. **Dropped: the "variable over time" scatter plots.** They plotted one person's daily
   values inside a between-subject band with no temporal structure and a flat trend — a
   scatter of noise that showed nothing a distribution doesn't. Removed rather than
   dressed up.

## 8. Reproduce

- Priors: `docs/normative_priors.csv` · z-score reconciliation: `docs/poster/zscore-reconciliation.html`
- Model: `scratchpad/model.jl` → `docs/poster/model_results.csv`, `figs/feature_correlation.png`
- Figures: `scratchpad/regen_participant_figs.jl`, `scratchpad/caseA_fig.jl`
- Data: `test/testdata/{nsrdb,nsr2db,meditation}/windowed_w360_s120_features.csv`,
  `test/testdata/export/` (P1 recordings)
- Run natively (no Docker): `julia --project=<repo root>` (absolute path), headless GR
  (`ENV["GKSwstype"]="100"`); `using HeartRateLab` needs the absolute project.
