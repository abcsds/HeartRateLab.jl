# Poster notes — *Normative Evaluation of HRV with HeartRateLab.jl*

**JuliaCon Global 2026 · Alberto Barradas (abcsds) · Mainz, Aug 10–15 2026**

Distributable companion to the poster: the exact method, the full feature panel with
its fitted distributions and fit quality, the selection model, and an honest limitations
list. If someone at the booth asks "how does this actually work / is this rigorous?",
this is the answer.

---

## 1. The question

Given a new HRV recording, **"is it normal?"** is unanswerable without a reference — and
the answer *changes with the reference*. We build references from open data, score **one
participant's** recordings against them, and are explicit about what the score does and
does not mean. This is a **framing device** — placing one recording in a normative context
— **not a statistical study of that participant** (n = 1).

## 2. What is compared with what (read this first)

The centrepiece is **one subject, scored against two references.** Three data sources,
one of which is the subject and two of which are references:

| Role | Data | Size | Use |
|---|---|---|---|
| **Subject — Participant P1** | Longitudinal self-recordings, **paced resonant breathing**, 2019–2025 | 148 windows, 88 dates | scored against **both** references below |
| **Reference 1 — general healthy population** | PhysioNet **nsrdb + nsr2db** (normal-sinus-rhythm) | 61,715 windows, **66 subjects** | pooled → one fitted prior per feature |
| **Reference 2 — meditators** | PhysioNet *Heart Rate Oscillations during Meditation*, **during-meditation** state (Chi + Kundalini, records ending `med`) | 263 windows, **11 practitioners** | second fitted prior per feature |

**Key result.** Against the general population P1's low-frequency band is strongly elevated
(**LF/HF** z = +2.6, **LF power** z = +2.5) while short-term vagal tone sits at the healthy
median (**RMSSD** z = +0.0, **Mean IBI** z = +0.1). Re-scored against the meditators the LF
elevation roughly **halves** (LF/HF z = +1.7, LF power z = +0.9): paced resonant breathing
places P1 **atypical for the general population but meditator-like** — the same recording,
two verdicts. The meditators themselves differ only mildly from healthy (pNN50 z = +0.4,
SDNN z = +0.8, all < 1σ), so they are a *reference group*, not the finding.

The poster's z-score dumbbell shows P1 against both references at once; the 3-way comparison
figure overlays reference / meditators / P1 distributions per feature.

**On the word "normative."** The references are *convenience* open datasets (nsrdb/nsr2db),
not populations sampled to represent "normal" — a statistician will (rightly) push on this.
The claim is deliberately narrow: *relative to these datasets*, here is where P1 falls.

## 3. The pipeline (end to end, in Julia)

1. **Read** inter-beat intervals — `read_txt` / `read_wfdb` / `read_xdf`. IBIs in ms.
2. **Preprocess** — `replace_zeros`, `replace_bio_outliers` (physiological range
   300–2000 ms), `interpolate_nans`. Non-mutating and mutating (`!`) pairs.
3. **Extract features** — 53 registered HRV features via the `@register` + `@memoize`
   registry; time-domain, frequency-domain (Lomb–Scargle), and nonlinear.
4. **Window** — 360 beats, 120-beat stride (`windowed_feature_set`). One feature row per
   window.
5. **Fit a normative prior** per feature by **maximum likelihood** over the 61,715 healthy
   windows, choosing a family (Normal / Gamma / Beta / LogNormal) per feature (see §4).
6. **Score** a new window: `percentile = F_prior(x)`, then
   `z_equivalent = Φ⁻¹(percentile)`. This is a **quantile re-expression on a standard
   normal**, valid for skewed families — *not* standard deviations of the raw feature.

## 4. Feature panel, fitted distributions, and fit quality

Below: **all 53 registered features** — fitted family + MLE parameters, the Kolmogorov–Smirnov goodness-of-fit p-value, valid-window count, and (where modelled) its selection stability + direction in the meditation model (§5). Sorted by stability.

> **Honest fit-quality note.** With n = 61,715, the KS test rejects every fitted family (all p < 0.05) — it is so powered that any minute departure from the parametric family reads as significant. The MLE parameters are sound; these are **convenient approximations for percentile scoring, not a claim that HRV features *are* Gamma/Beta/etc.** **52 of the 53 features are fitted; only `ulf`** (ultra-low-frequency power, 0–0.003 Hz) is unfittable — a 360-beat (~6 min) window has zero ULF observations, so it is recorded, not scored.

| feature | family | params | KS p | n | stability | dir |
|---|---|---|---:|---:|---:|:--:|
| LF power | Gamma | α=0.868, θ=705 | 5e-118 | 61715 | 92% | ↑ |
| pNN20 | Beta | α=1.81, β=3.3 | 2e-17 | 61715 | 92% | ↓ |
| CVI | Normal | μ=4.27, σ=0.439 | 7e-16 | 61715 | 88% | ↑ |
| rRR | Gamma | α=4.16, θ=0.881 | 3e-172 | 61715 | 85% | ↑ |
| SD2/SD1 | LogNormal | μ=1.14, σ=0.533 | 1e-07 | 61715 | 78% | ↓ |
| HF peak | Normal | μ=0.213, σ=0.0633 | 1e-111 | 61715 | 62% | ↑ |
| Total power | Gamma | α=0.946, θ=1.65e+03 | 2e-125 | 61715 | 62% | ↑ |
| LF/HF | LogNormal | μ=0.852, σ=0.869 | 7e-09 | 61715 | 57% | ↑ |
| LF % | Gamma | α=8.66, θ=4.5 | 0.0003 | 61715 | 56% | ↑ |
| LF rel | Beta | α=5.13, β=8.02 | 2e-12 | 61715 | 56% | ↑ |
| SD HR | Gamma | α=3.79, θ=392 | 1e-09 | 61715 | 52% | ↓ |
| Median IBI | Normal | μ=780, σ=151 | 1e-77 | 61715 | 52% | ↑ |
| LF peak | Normal | μ=0.0642, σ=0.0183 | 3e-306 | 61715 | 51% | ↑ |
| Mean HR | Normal | μ=79.7, σ=15.2 | 2e-95 | 61715 | 51% | ↓ |
| Mean IBI | Normal | μ=780, σ=147 | 1e-64 | 61715 | 48% | ↑ |
| Min HR | Normal | μ=100, σ=21.1 | 1e-40 | 61715 | 47% | ↓ |
| HRV tri-index | Gamma | α=5.94, θ=1.74 | 1e-14 | 61715 | 36% | ↑ |
| TINN | Gamma | α=5.32, θ=30.9 | 2e-18 | 61715 | 28% | ↑ |
| CVSD | Gamma | α=2.93, θ=0.0146 | 6e-44 | 61715 | 27% | ↑ |
| Max HR | Normal | μ=65.7, σ=13.8 | 9e-68 | 61715 | 26% | ↓ |
| HF % | Gamma | α=2.48, θ=7.84 | 1e-26 | 61715 | 23% | ↑ |
| HF rel | Beta | α=1.31, β=5.44 | 3e-40 | 61715 | 23% | ↑ |
| IBI range | Gamma | α=3.49, θ=94.1 | 4e-14 | 61715 | 20% | ↓ |
| Min IBI | Normal | μ=625, σ=128 | 5e-27 | 61715 | 16% | ↓ |
| Max IBI | Normal | μ=953, σ=197 | 3e-11 | 61715 | 16% | ↓ |
| pNN50 | Beta | α=0.321, β=3.56 | 2e-98 | 61715 | 14% | ↓ |
| SD1 | Gamma | α=2.4, θ=10.1 | 3e-50 | 61715 | 13% | ↑ |
| SDSD | Gamma | α=2.4, θ=14.2 | 3e-50 | 61715 | 13% | ↑ |
| RMSSD | Gamma | α=2.4, θ=14.2 | 3e-50 | 61715 | 12% | ↑ |
| cCSI | LogNormal | μ=6.64, σ=0.882 | 4e-05 | 61715 | 8% | ↓ |
| SD2 | Gamma | α=3.73, θ=18.7 | 2e-24 | 61715 | 4% | ↑ |
| SDNN | Gamma | α=3.79, θ=14 | 4e-29 | 61715 | 2% | ↑ |
| HF power | Gamma | α=0.615, θ=587 | 7e-208 | 61715 | 2% | ↓ |
| SD1·SD2 area | LogNormal | μ=8.21, σ=1.01 | 7e-16 | 61715 | 1% | ↓ |
| apen | Normal | μ=0.761, σ=0.271 | 4e-22 | 61715 | — | — |
| cvnni | Normal | μ=0.0679, σ=0.0337 | 5e-115 | 61715 | — | — |
| dfa2 | Normal | μ=0.975, σ=0.25 | 5e-30 | 61715 | — | — |
| fuzzyen | Normal | μ=2.14, σ=0.411 | 2e-18 | 61715 | — | — |
| hurst | Beta | α=2.88, β=6.17 | 1e-21 | 61715 | — | — |
| median_hr | Normal | μ=79.8, σ=15.5 | 4e-108 | 61715 | — | — |
| mse | Normal | μ=5.24, σ=1.48 | 4e-50 | 59851 | — | — |
| perm_en | Normal | μ=2.45, σ=0.0726 | 7e-172 | 61715 | — | — |
| range_hr | Gamma | α=3.49, θ=9.87 | 4e-52 | 61715 | — | — |
| renyi0 | Normal | μ=-6.64, σ=0.188 | 1e-83 | 61715 | — | — |
| renyi1 | Normal | μ=-6.64, σ=0.188 | 6e-82 | 61715 | — | — |
| renyi2 | Normal | μ=-6.65, σ=0.189 | 2e-80 | 61715 | — | — |
| sampen | Normal | μ=2.04, σ=0.488 | 8e-42 | 61390 | — | — |
| sdann | Gamma | α=0.873, θ=27.8 | 6e-28 | 20672 | — | — |
| shan_en | Normal | μ=3, σ=0.467 | 6e-11 | 61715 | — | — |
| spec_en | Normal | μ=0.163, σ=0.00571 | 2e-213 | 61715 | — | — |
| svd_en | Normal | μ=0.139, σ=0.0717 | 7e-90 | 61715 | — | — |
| vlf | Gamma | α=1.27, θ=1.02e+03 | 0 | 58892 | — | — |

## 5. Feature redundancy and a selection model

**Motivation.** Several features are, by definition, functions of others, so the method
accounts for their collinearity rather than treating them as independent. Measured
collinearity on the healthy reference:

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

## 6. Results as scored (descriptive)

**Participant P1 — one subject scored against two reference priors** (quantile z; from
`docs/poster/zscores.csv`; **all 35 features that have a fitted prior + P1 data**, no
hand-picked subset, sorted by z vs healthy):

| feature | z vs healthy | z vs meditators |
|---|:---:|:---:|
| LF/HF | +2.6 | +1.7 |
| LF power | +2.6 | +0.9 |
| TINN | +1.9 | +1.2 |
| Total power | +1.8 | +0.6 |
| HRV tri-index | +1.5 | +1.0 |
| LF rel | +1.4 | +0.6 |
| LF % | +1.4 | +0.7 |
| cCSI | +1.3 | +1.2 |
| SD2 | +1.2 | +0.7 |
| SD2/SD1 | +1.1 | +1.2 |
| SDNN | +1.1 | +0.5 |
| SD1·SD2 area | +0.8 | +0.1 |
| CVI | +0.8 | +0.1 |
| pNN20 | +0.7 | +2.6 |
| pNN50 | +0.4 | +0.2 |
| rRR | +0.3 | −0.4 |
| IBI range | +0.2 | −0.1 |
| Max IBI | +0.1 | −0.1 |
| Mean IBI | +0.1 | +0.1 |
| Min IBI |  0.0 | +0.1 |
| Median IBI |  0.0 | +0.1 |
| CVSD |  0.0 | −0.5 |
| RMSSD |  0.0 | −0.5 |
| SD1 |  0.0 | −0.5 |
| SDSD |  0.0 | −0.5 |
| LF peak |  0.0 | −0.2 |
| sdann |  0.0 | −0.1 |
| HF power | −0.2 | −0.7 |
| Min HR | −0.2 | −0.2 |
| Mean HR | −0.2 | −0.3 |
| Max HR | −0.3 | −0.1 |
| HF peak | −0.7 | −0.5 |
| SD HR | −1.0 | −0.6 |
| HF rel | −1.5 | −1.1 |
| HF % | −2.1 | −1.5 |

Read top-to-bottom, P1's variance is **shifted into the low-frequency band** (LF/HF, LF
power, total power, TINN, SD2, tri-index all ↑) and **out of the HF-relative measures**
(HF% −2.1, HF-rel −1.5 ↓) — the textbook resonant-breathing signature — while absolute
short-term vagal tone (RMSSD ≡ SD1 ≡ SDSD, all ≈ 0.0) sits at the healthy median. The two
largest deviations are the **LF-band** (LF/HF +2.6, LF power +2.6). Re-scored against
meditators the LF-band elevation shrinks (LF/HF +2.6 → +1.7): P1 reads atypical for the
general population but meditator-like.

**The meditator reference group** (during-meditation windows, quantile z vs the healthy
prior): pNN50 +0.4, SDNN +0.8, RMSSD +0.3, Mean IBI +0.2 — all within ±1σ, a mild
coherent vagal shift, so the meditators are a *reference*, not the finding. (Pooling rest +
meditation epochs inflates these to +0.9…+1.3σ; we score meditation-state windows only.)

## 7. Limitations (what these numbers are *not*)

1. **Pseudoreplication.** Windows within a recording are autocorrelated. The per-window z
   and the dispersion bands are **window-level, descriptive** — not per-subject inferential
   tests. The selection model mitigates this with subject-grouped resampling; the case
   z-scores do not, and should be read descriptively.
2. **Tiny meditation n.** 11 practitioners. CV AUC ±0.27 reflects this honestly.
3. **Collinearity.** Handled in the model (§5) but *present* — never read the raw
   per-feature z-scores as independent lines of evidence.
4. **Parametric priors are KS-rejected** (§4) — approximations for scoring, not fitted laws.
5. **P1 is n = 1** (the author's own data). A demonstration of the
   *monitor*, not a population claim.
6. **Dropped: the "variable over time" scatter plots.** They plotted one person's daily
   values inside a between-subject band with no temporal structure and a flat trend — a
   scatter of noise that showed nothing a distribution doesn't. Removed rather than
   dressed up.

## 8. Reproduce

- Priors: `docs/normative_priors.csv` · P1 z-scores: `docs/poster/zscores.csv`
- Model: `docs/poster/scripts/model.jl` → `docs/poster/model_results.csv`
- Figures: `docs/poster/scripts/{regen_participant_figs,zscore_fig,figs_model,clustermap,pipeline_fig}.jl` → `docs/poster/figs/` (see `docs/poster/scripts/README.md`)
- Data: `test/testdata/{nsrdb,nsr2db,meditation}/windowed_w360_s120_features.csv`,
  `test/testdata/export/` (P1 recordings)
- Run natively (no Docker): `julia --project=<repo root>` (absolute path), headless GR
  (`ENV["GKSwstype"]="100"`); `using HeartRateLab` needs the absolute project.
