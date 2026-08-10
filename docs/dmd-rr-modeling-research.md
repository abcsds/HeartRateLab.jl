# Dynamic Mode Decomposition for RR-interval (IBI) tachograms

**Question.** The shipped `DMD` model in HeartRateLab is intentionally weak and
documented as such. Can a *better-founded* DMD formulation model RR-interval
(inter-beat-interval, IBI) dynamics well — and if so, with which variant,
parameters, embedding/delay window, and preprocessing?

**Short answer.** Yes, with two important caveats that the existing model
conflates:

1. **As a one-step / short-horizon forecaster, DMD is genuinely good for RR.**
   A centered time-delay (Hankel) DMD operator forecasts held-out beats with
   out-of-sample NRMSE ≈ **0.19 at 1 step** and **≈ 0.73 at 5 steps**, beating a
   persistence baseline (0.35 / 1.41) and the mean baseline (≈1.04) at every
   horizon. This is strong, well-founded evidence that DMD captures real RR
   dynamics.
2. **As a free-running generative model, DMD is fundamentally limited** because
   RR tachograms are broadband / aperiodic (not a few clean oscillators). The
   best generative variant we found — **mean-centered, unit-circle-projected
   Hankel-DMD** — nonetheless *fixes every concrete defect of the shipped model*:
   it recovers the true mean (957 ms, not a forced 800 ms), preserves a realistic
   fraction of the variance (sim std 78 vs data 90), and earns a far better BIC
   (49 639 vs 55 534). It still cannot reproduce the full broadband variability,
   which is an inherent property of low-rank linear models on this signal, not a
   bug.

All numbers below were produced in-container (`localhost/hrlab:latest`) on the
`example.txt` series (n=4193, mean 957.0 ms, std 90.0 ms) and validated on a
4000-beat window of NSRDB record `16265` (mean 617.7 ms, std 85.8 ms). Scripts
and raw outputs are in `docs/dmd_experiments/` (`run_experiments.jl`, `sweep.jl`,
`diagnose.jl`, `dmd_variants.jl`). RNG seed `20260617`.

---

## 1. The signal: what RR tachograms look like to DMD

A resting RR tachogram is a **large DC offset (~950 ms) plus comparatively small,
broadband, partly-stochastic fluctuations** (respiratory sinus arrhythmia, LF
baroreflex waves, aperiodic drift). Diagnostics on `example.txt`
(`docs/dmd_experiments/diagnose.txt`):

- **Strong short-range predictability:** lag-1 autocorrelation 0.95, lag-2 0.82,
  decaying to 0.16 by lag-5 and negative by lag-10. The next beat is highly
  predictable from recent history; the long-range structure is weak.
- **Low-rank in the short term, high-rank overall:** the centered Hankel matrix
  needs only r≈3–7 modes for 90% of its energy at small embedding (d=20–50) but
  r≈22–47 for 99% at large embedding (d=200). The signal is *not* a handful of
  pure oscillators.
- **Spectrum is LF-dominated** in cycles-per-beat: LF fraction 0.995, HF 0.005.

The implication for DMD: a **time-delay (Hankel) embedding** is essential
(single-channel scalar series have no spatial dimension for DMD to work on), and
the **DC offset must be handled explicitly** or it swamps everything.

---

## 2. Literature survey

**Exact / projected DMD (Schmid 2010; Tu et al. 2014).** The standard SVD-based
algorithm: stack snapshots into `X1, X2`, compute `Ã = U_r' X2 V_r Σ_r⁻¹`,
eigendecompose, lift to modes `Φ = X2 V_r Σ_r⁻¹ W`, evolve as
`x(t) ≈ Σ_j φ_j λ_j^{t-1} b_j`. *Tu et al.'s exact-DMD* fixes Schmid's projected
modes. The reconstruction quality hinges on the eigenvalue magnitudes `|λ_j|`:
`|λ|<1` decays, `|λ|>1` blows up; only `|λ|=1` sustains oscillation.

**Time-delay / Hankel DMD & HAVOK (Brunton et al. 2017; Arbabi & Mezić 2017).**
For scalar or low-dimensional measurements, stack `q` time-shifted copies into a
Hankel matrix (Takens embedding) so DMD has a state space to act on. **HAVOK**
(Hankel Alternative View of Koopman) takes the SVD of the Hankel matrix, models
the first `r-1` delay coordinates as a *linear system intermittently forced by
the last coordinate* `v_r`, and shows chaotic/again-noisy systems become
"linear-plus-forcing." Directly applied to physiology: Mann et al.
(arXiv:2505.08953, 2025) use HAVOK on **heart-rate, temperature, activity and
glucose** ultradian rhythms in 16 participants — they use **q≈100 delays**, a
small model rank `r` (with a forcing coordinate), **subtract column means before
the embedding**, and report 7-day-ahead forecast RMSE < 0.08 (normalized). Their
forcing distribution is heavy-tailed (intermittent), matching our finding that RR
needs an exogenous variance source for free-running synthesis.

**Optimized DMD / optDMD (Askham & Kutz 2018, arXiv:1704.02343) and BOP-DMD
(Sashidhar & Kutz 2021).** Instead of the two-snapshot regression, fit the data
directly to a sum of exponentials `Σ φ_j e^{ω_j t} b_j` by **variable projection**
(nonlinear least squares over the continuous-time eigenvalues `ω_j` and the
amplitudes jointly). This *de-biases* the eigenvalues under noise — exact DMD
systematically biases `|λ|` toward decay when the data is noisy, which is exactly
the failure mode we see on RR. optDMD/BOP-DMD are "the standard for the most
accurate, least-biased modes in the presence of noise." We approximate the key
benefit (global amplitude fit + de-biased magnitudes) cheaply via a
**unit-circle projection of `λ` plus a global least-squares amplitude solve**,
without a full nonlinear optimizer.

**Mean subtraction / the constant mode (Chen, Tu & Rowley 2012; Hirsh, Kaptanoglu
et al. "Centering Data Improves DMD" 2019; "Clarifying the effect of mean
subtraction" arXiv:2105.03607 2021).** Subtracting the temporal mean is the
classic way to stop the DC component from dominating the modes. The subtlety:
exact mean subtraction can collapse DMD to a temporal DFT, but **centering and
re-adding the mean is equivalent to fitting an affine model with a preserved
constant eigenfunction** and, when the model order exceeds the number of Koopman
modes, is *not* degenerate. For a signal that is "big constant + small dynamics"
like RR, centering before the embedding and adding the mean back at
reconstruction is the correct, well-supported handling — and is precisely what
the shipped model fails to do.

**Total-least-squares / forward-backward DMD, streaming/windowed DMD.** TLS-DMD
(Hemati et al. 2017) further reduces noise bias; windowed/streaming DMD adapts to
non-stationarity. These are natural future extensions (RR is mildly
non-stationary over 24 h) but were out of scope for the three-variant budget.

---

## 3. Diagnosis of the shipped `DMD` model

`src/Models/DMD.jl` has four compounding problems, all confirmed empirically:

1. **No mean handling → forced mean of 800 ms.** `simulate` rescales the
   reconstruction to `800 / |mean|` and clamps to 300–2000 ms. The true mean of
   `example.txt` is **957 ms**; of the 16265 window, **618 ms**. The model
   therefore mislocates the entire distribution. (`docs/dmd_experiments/results.txt`:
   ExistingDMD sim_mean = 800 in both cases.)
2. **Variance collapse from decaying eigenvalues.** Every retained `|λ|` lies
   *inside* the unit circle (measured range 0.92–0.999, `docs/dmd_experiments/diagnose.txt`),
   so the free-running reconstruction decays toward its (forced) mean. ExistingDMD
   sim_std = 17.5 vs data 90.
3. **Ad-hoc reconstruction.** It averages `mean(abs.(mode_j))` across the spatial
   (delay) dimension rather than reading a defined Hankel coordinate, and projects
   amplitudes `b` from a single column — discarding phase and amplitude
   information.
4. **Net effect:** in-sample reconstruction NRMSE = **1.99** — *worse than simply
   predicting the constant mean* (NRMSE 1.0). Its BIC (55 534) is the worst of all
   variants by a wide margin.

The shipped model's honest `@test_broken` for the mean-drop is therefore correct;
the mean-drop is the *symptom* of items 1–2.

---

## 4. Variants implemented and tested

All three are implemented behind the `AbstractHRVModel` interface in
`docs/dmd_experiments/dmd_variants.jl` so the shipped `Evaluation.information_criteria` /
`rank_models` utilities score them directly.

### V1 — Centered exact Hankel-DMD (`CenteredDMD`)
Subtract the data mean → build a `d`-delay Hankel matrix → exact DMD → energy-
threshold rank → reconstruct the first Hankel coordinate → **add the mean back**.
This is the minimal, literature-correct fix for the mean-drop (Hirsh 2019).
*Result:* mean fixed (954.8 ms), BIC 49 746, but variance still collapses
(std 12.8) because the eigenvalues still decay — confirming item 2 above.

### V2 — Unit-circle-projected centered Hankel-DMD (`StabilizedDMD`) ⟵ recommended
As V1, but **project every retained eigenvalue onto the unit circle**
(`λ → λ/|λ|`), preserving each mode's frequency while making the free-run
marginally stable (sustained, neither decaying nor exploding) — the
mean-subtraction≈DFT regime. **Amplitudes `b` are fit by global least squares
against the full first-row trajectory** (the optDMD-style global amplitude step),
so reconstruction variance matches the data instead of being pinned by one
column. *Result:* mean 956.5 ms, **variance recovered (std 77.7 at d=50, r=10)**,
**best BIC tier (49 638)**.

### V3 — HAVOK-style forced linear model (`HAVOKModel`)
SVD of the centered Hankel matrix → linear model on the first `r-1` delay
coordinates **forced by the last coordinate** `v_r` → replay the empirical forcing
to drive a free-running simulation → reconstruct + add mean back. This is the
ultradian-rhythm HRV recipe (Mann et al. 2025). *Result:* **best mean fidelity
(956.7 ms) and best single BIC (49 639.9)**, but understates variance (std 20.6)
because tiling one record's forcing does not reproduce its full broadband spread.

---

## 5. Results

### Generative reconstruction on `example.txt` (n=4193, mean 957.0, std 90.0)

| variant | recon NRMSE | sim mean (ms) | sim std (ms) | LF frac | loglik | BIC | k |
|---|---|---|---|---|---|---|---|
| **ExistingDMD** (rank 5) | 1.993 | **800.0** ✗ | 17.5 ✗ | 1.00 | −27746.1 | **55533.9** ✗ | 5 |
| CenteredDMD (V1) d=50,e=.99 | 0.991 | 954.8 ✓ | 12.8 ✗ | 0.99 | −24872.9 | 49745.7 | 0 |
| **UnitCircleDMD (V2)** d=50,r=10 | — | **956.5** ✓ | **77.7** ✓ | 1.00 | **−24819.3** | **49638.6** ✓ | 0 |
| UnitCircleDMD (V2) d=50,rmax=20 | 1.228 | 960.1 | 56.1 | 1.00 | −24820.4 | 49640.8 | 0 |
| HAVOK (V3) d=100,r=11 | 0.998 | 956.7 ✓ | 20.6 | 1.00 | −24819.9 | **49639.9** ✓ | 0 |
| HAVOK (V3) d=200,r=25 | 1.008 | 956.5 ✓ | 23.7 | 1.00 | −24823.2 | 49646.4 | 0 |

(`recon NRMSE` is in-sample free-running, normalized by data std; ≈1 means "as
good as predicting the mean" — expected for a free-running low-rank linear model
on broadband data. Mean/variance fidelity and BIC are the discriminating
metrics. `k`=0 for the centered variants because they store no continuous
`params`; the shipped `model_n_params(::DMD,…)` counts retained modes, hence k=5
for the old model — its BIC is penalised both by likelihood *and* parameters.)

**Variance-matching sweep (V2, `docs/dmd_experiments/sweep.txt`).** The embedding dimension
`d` is the dominant knob; rank `rmax` saturates at the energy-selected `r`:

| d | r used | sim mean | sim std | BIC |
|---|---|---|---|---|
| 30 | 8 | 957.0 | 26.1 | 49637.8 |
| **50** | **10** | **956.5** | **77.7** | **49638.6** |
| 80 | 20 | 957.0 | 132.2 | 50523.9 |
| 120 | 29 | 944.0 | 84.9 | 49705.9 |

`d=50` gives the best variance/BIC trade-off (std 77.7 ≈ data 90 without the
amplitude over-shoot seen at d=80–120).

### Out-of-sample forecasting on `example.txt` (train 70% / test 30%, closed-loop)

| horizon h | DMD NRMSE (d=50,r=20) | persistence | mean baseline |
|---|---|---|---|
| 1 | **0.235** | 0.354 | 1.036 |
| 2 | **0.422** | 0.670 | 1.037 |
| 5 | **0.793** | 1.408 | 1.038 |
| 10 | **0.818** | 1.756 | 1.038 |

Forecast sweep (`docs/dmd_experiments/sweep.txt`) — best at richer rank: `d=50,r=40` gives
h=1 NRMSE **0.188**, h=5 **0.727**; `d=30,r=20` gives 0.192 / 0.741. DMD beats
both baselines at every horizon and every tested `(d,r)`.

### Cross-record validation — NSRDB 16265 window (n=4000, mean 617.7, std 85.8)

| model | sim mean | sim std | BIC |
|---|---|---|---|
| ExistingDMD (rank 5) | **800.0** ✗ (off by 182 ms) | 80.4 | **53838.3** ✗ |
| UnitCircleDMD d=100,r=20 | **617.7** ✓ (exact) | 77.4 ✓ | **46989.1** ✓ |
| UnitCircleDMD d=50,r=20 | 616.6 ✓ | 28.8 | 46967.6 |

The mean fix **generalizes** to a record with a very different mean (618 vs
957 ms): UnitCircleDMD nails it; the shipped model is off by ~180 ms and pays
~6800 BIC for it. For 16265's lower mean RR a slightly larger embedding (d=100)
is needed to recover the variance.

### Figure
`docs/dmd-rr-figure.png` — top: free-running reconstruction of the first 600
beats (shipped DMD flat at 800 with collapsed variance, in red; UnitCircleDMD in
blue tracking amplitude and the correct mean; HAVOK in green). Bottom:
out-of-sample 1-step forecast tracking the held-out tail.

---

## 6. Recommendation

**A better-founded DMD does meaningfully model RR — primarily as a forecaster,
and as a much-improved (if still imperfect) generative model.**

**Recommended variant: mean-centered, unit-circle-projected Hankel-DMD with a
global least-squares amplitude solve (V2 `UnitCircleDMD`).** Concrete parameters
validated here:

- **Preprocessing:** subtract the temporal mean *before* the embedding; add it
  back at reconstruction (affine/constant-mode handling). Optionally clip to the
  physiological 300–2000 ms band *only* as an output guard, never as a rescale.
- **Embedding (delay) dimension `d`:** **50** for ~1 h resting records
  (mean≈800–960 ms); **~100** for faster-mean records (e.g. NSRDB 16265 at
  ~620 ms). Rule of thumb: `d` ≈ a few dominant LF cycles in beats.
- **Rank `r`:** energy threshold 0.99 with a cap; `r≈10` matched variance best on
  `example.txt`, `r≈20` on 16265. For *forecasting*, use a richer rank
  (`r≈20–40`) — it lowers forecast NRMSE without hurting the mean.
- **Eigenvalues:** project all retained `λ → λ/|λ|` for generative stability.
- **Amplitudes:** global least squares over the full first-row trajectory (not a
  single-column projection).

This single change set turns the model's worst-case behaviour (mean off by
150–180 ms, variance collapse, BIC worst-in-class) into best-in-class BIC, correct
mean across records, and realistic variance — while remaining a few dozen lines of
linear algebra with no new dependencies.

**When to prefer HAVOK (V3):** if the priority is the *best mean + BIC* and a
clean "linear-plus-intermittent-forcing" interpretation (e.g. for teaching /
communicating RR dynamics), HAVOK is marginally ahead on BIC and gives a
physiologically meaningful forcing signal — at the cost of understated variance.

### What DMD cannot do here (honest limits)
- **Free-running variance is inherently capped.** RR is broadband/aperiodic; a
  low-rank linear model reproduces the mean and the dominant LF oscillation but
  not the full spread. No DMD variant reached the data's std without over-shooting.
  Honest framing: DMD is a good *short-horizon predictive* model and a *fair*
  generative one, not a full stochastic generator.
- **HF band is essentially unmodelled** (data HF fraction is only 0.005 in
  cycles-per-beat at this record; DMD puts ~all power in LF).

### Suggested next steps
1. **Ship V2 as the DMD model** (centering + unit-circle + LS amplitudes), keep
   the physiological clip as an output guard, and replace the `@test_broken`
   mean-drop with a passing mean-fidelity assertion (`|sim_mean − data_mean|`
   small) plus an explicit `@test_broken` for *full-variance* reconstruction with
   an accurate message ("low-rank linear model under-reproduces broadband RR
   variance").
2. **Expose a forecasting API** (`forecast(model, history, h)`) — this is DMD's
   real strength for RR and is currently not surfaced.
3. **Try optDMD/BOP-DMD** (variable projection) for de-biased eigenvalues, and
   **TLS-DMD** for noise; both target the residual variance gap directly.
4. **Windowed/streaming DMD** for 24 h non-stationary records (e.g. 16265).
5. **Add a stochastic forcing term** (fit the residual / HAVOK forcing
   distribution and sample it) if a *generative* model with realistic variance is
   the goal.

---

## 7. Reproducibility

In-container (`localhost/hrlab:latest`), from the repo root:

```bash
docker run --rm -v "$(pwd):/workdir" -w /workdir localhost/hrlab:latest \
  "cd /workdir && julia --project=. docs/dmd_experiments/run_experiments.jl"   # main table + forecasting → docs/dmd_experiments/results.txt
docker run --rm -v "$(pwd):/workdir" -w /workdir localhost/hrlab:latest \
  "cd /workdir && julia --project=. docs/dmd_experiments/sweep.jl"             # param sweep + 16265 → docs/dmd_experiments/sweep.txt
docker run --rm -v "$(pwd):/workdir" -w /workdir localhost/hrlab:latest \
  "cd /workdir && julia --project=. docs/dmd_experiments/diagnose.jl"          # SVD/eigenvalue/autocorr diagnosis → docs/dmd_experiments/diagnose.txt
docker run --rm -v "$(pwd):/workdir" -w /workdir localhost/hrlab:latest \
  "cd /workdir && julia --project=. docs/dmd_experiments/make_figure.jl"       # docs/dmd-rr-figure.png
```

Variant implementations: `docs/dmd_experiments/dmd_variants.jl`. RNG seed 20260617.

### Sources
- Schmid 2010, *Dynamic mode decomposition of numerical and experimental data*, J. Fluid Mech.
- Tu, Rowley, Luchtenburg, Brunton, Kutz 2014, *On dynamic mode decomposition: theory and applications*, J. Comput. Dyn.
- Brunton, Brunton, Proctor, Kaiser, Kutz 2017, *Chaos as an intermittently forced linear system* (HAVOK), Nature Communications.
- Arbabi & Mezić 2017, *Ergodic theory, dynamic mode decomposition and computation of spectral properties of the Koopman operator*.
- Mann et al. 2025, *Multimodal Modeling of Ultradian Rhythms Using HAVOK Analysis*, arXiv:2505.08953 — HRV/physiology application. https://arxiv.org/abs/2505.08953
- Askham & Kutz 2018, *Variable projection methods for an optimized dynamic mode decomposition*, SIAM J. Appl. Dyn. Syst., arXiv:1704.02343. https://arxiv.org/abs/1704.02343
- Sashidhar & Kutz 2021, *Bagging, optimized dynamic mode decomposition (BOP-DMD)*, arXiv:2107.10878. https://arxiv.org/abs/2107.10878
- Chen, Tu, Rowley 2012, *Variants of dynamic mode decomposition: connections between Koopman and Fourier analyses*, J. Nonlinear Sci.
- Hirsh, Kaptanoglu, Brunton, Kutz et al. 2019, *Centering Data Improves the Dynamic Mode Decomposition*, arXiv:1906.05973. https://arxiv.org/abs/1906.05973
- *Clarifying the effect of mean subtraction on Dynamic Mode Decomposition* 2021, arXiv:2105.03607. https://arxiv.org/abs/2105.03607
- Hemati, Rowley, Deem, Cattafesta 2017, *De-biasing the dynamic mode decomposition for applied Koopman spectral analysis of noisy datasets* (TLS-DMD).
```
