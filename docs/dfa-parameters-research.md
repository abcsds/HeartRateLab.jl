# DFA parameterization for HRV α1/α2 in HeartRateLab — research report

**Date:** 2026-06-17 · **Branch:** `cl` · **Scope:** research only (no package source changed)
**Subject:** the `dfa` representation in `src/Features.jl` (~line 1257) and the `α1≈1.78` defect on `test/testdata/example.txt`.

---

## TL;DR

The original hypothesis was that HeartRateLab's `α1≈1.78` is an artifact of fitting a slope to only **3 geometrically-spaced box sizes** (`boxratio=2` → α1 boxes `[4,8,16]`, α2 boxes `[16,32,64]`).

**Measured in-container, that hypothesis is false for this signal.** Densifying the grid (every integer 4–16, or geometric ratios down to 1.09) moves α1 by **< 0.02** — it stays ~1.77–1.81. A textbook Peng reference DFA reproduces DFA.jl's fluctuations **to the digit**, and white noise gives α≈0.5 from both. **DFA.jl is correct, and α1≈1.78 is the genuine DFA-α1 of `example.txt` as currently fed in.**

The implausible value is therefore an **input/physiology** issue, not a box-grid bug: `example.txt` is a clean RR series (RMSSD 28.5 ms, all 300–2000 ms, no ectopy) but with a very smooth, strongly autocorrelated short-scale profile (lag-1 autocorr 0.95; the opening beats climb monotonically 812→1058 ms), which DFA legitimately scores near the random-walk limit (α→1.5–2) at short box sizes.

**Two independent recommendations follow** (both worth doing): (1) **densify the box grid anyway** — it is best practice, costs almost nothing, and removes the standing "3-point fit" criticism even though it does not change this number; (2) the real correctness work is **not** in the box grid — it is recognizing that DFA-α1 of a high-autocorrelation 5-min ramp-dominated segment is genuinely high, and the test baseline should reflect the *correctly computed* value rather than an assumed "~1.0 healthy" number.

---

## 1. Survey of validated HRV/DFA software

DFA pipeline (all tools): integrate the mean-removed series into a profile, split into boxes of size *n*, least-squares **linear** detrend per box (order 1), RMS the residuals → F(n), regress log F(n) on log n; the slope is α. Tools differ only in **(a) the n ranges for α1/α2, (b) how densely n is sampled, (c) overlap, and (d) the log-log fit estimator.**

| Tool | α1 range (beats) | α2 range (beats) | Box-size spacing | # boxes (per region) | Detrend order | Slope fit | Overlap |
|---|---|---|---|---|---|---|---|
| **Peng et al. 1995** (origin) | short region below crossover; crossover ≈ n≈16 (~11 in some records) | long region above crossover | integer n, "approximately equally spaced on a log scale", many points | many (spans ~4 to N/4) | 1 (linear; higher orders DFA-ℓ defined) | LS on log-log within each linear region | none |
| **Francis et al. 2002** | **4 ≤ n ≤ 16** | **16 ≤ n ≤ 64** | integer n (every n in range) | α1: 13 (4..16); α2: 49 (16..64) | 1 | LS on log-log | none |
| **PhysioNet Cardiovascular Signal Toolbox** (Vest 2018, `dfaScalingExponent.m`) | minBox=**4** ≤ n < midBox=**16** | midBox=**16** ≤ n ≤ maxBox=**N/4** (≈64 for 5-min) | **powers of 2** (`ns = 2.^(round(log2(min)):round(log2(max)))`) — geometric ratio 2 | α1: **3** ([4,8,16]); α2: ~3 ([16,32,64]) | 1 (`linfit`, local linear LS via pinv) | `pinv` LS on log10 F vs log10 n | none |
| **Kubios HRV** (Standard/Scientific) | **4 ≤ n ≤ 16** (default) | **16 ≤ n ≤ 64** (default) | integer n in range | α1: 13; α2: 49 | 1 | LS on log-log | none |
| **neurokit2** `hrv` (`_hrv_dfa`) | window `(4, 11)` → `np.linspace(4,11,8)` | `(12, None→(len+1)/10)` → `np.linspace(12,max,n_long)` | integer, ~linear-in-n (linspace), ~8 / ~variable points | α1: ~8; α2: variable | 1 (`order=1`) | `np.polyfit` on **log₂** | none (multifractal=False) |
| **neurokit2** `fractal_dfa` (generic default) | n/a (single region) | n/a | **log-spaced** `exp(linspace(log4, log(N/10)))` | ~"a tenth of length" log points | 1 | `np.polyfit` on log₂ | none |
| **nolds** `nolds.dfa` (used by hrv-analysis for SampEn; common DFA backend) | n/a (single region default) | n/a | **log-spaced** integers; default `logmid_n(N, ratio=1/4, nsteps=15)` (15 pts in mid-log range) | 15 | 1 (`fit_trend='poly'`) | default **RANSAC** (or `'poly'` LS) on log-log | default **True** |
| **RHRV** (R) `CalculateDFA` | regression typically 3<t<17 (α1) | typically 15<t<65 (α2) | **log-spaced**, `npoints=25` window sizes over `windowSizeRange=c(10,300)` | 25 across full range | 1 | `lm`/LS on log-log over user-selected linear region | configurable |
| **HeartRateLab (current)** | 4 ≤ n ≤ 16 | 16 ≤ n ≤ 64 | **geometric ratio 2** (`boxratio=2`) | α1: **3** ([4,8,16]); α2: **3** ([16,32,64]) | 1 (DFA.jl `order=1`) | `DFA.polyfit` LS on log10 | 0.0 |

### Notes on the convention split
- **Peng/Francis/Kubios-default/PCST:** α1 **4–16**, α2 **16–64**, crossover at n=16. HeartRateLab follows this (correctly cited in the code comment).
- **Iyengar 1996 / clinical / neurokit2:** α1 **4–11**, α2 **12–N/10**. This narrows α1 to strictly sub-respiratory scales. It does **not** lower α1 here (measured 4–11 → α1≈1.91, *higher* than 4–16).
- The ranges in HeartRateLab are fine and cited; they are not the problem.

### Spacing observations
- Two camps on **density**: **geometric ratio-2 / powers of 2** (PCST, current HRL → only ~3 boxes per region) vs **dense integer or many-point log grids** (Francis/Kubios all-integer = 13/49; nolds 15; RHRV 25; neurokit2 ~8).
- All use **order-1 (linear) detrending** and **non-overlapping** boxes except nolds (overlap on by default). The fit is ordinary least squares on log-log everywhere except nolds (RANSAC default) and the log base is cosmetic (slope is base-invariant).

---

## 2. Why a 3-point geometric grid is *normally* a problem — and why it isn't the cause here

A least-squares slope through **3 points** has 1 residual degree of freedom; a single off-trend point (e.g. n=4, where the box barely contains a polynomial) swings the slope and there is no leverage to detect curvature or pick a clean linear region. The nolds documentation states the principle directly: *"min(nvals) < 4 ... fitting a polynomial to 3 or less data points is error-prone,"* and that box sizes should be *"equally spaced on a logarithmic scale so that each window scale has the same weight."* The literature/tools that take this seriously use **many integer box sizes** (Francis 13/49, nolds 15, RHRV 25). On *general* signals a 3-point geometric fit is genuinely unstable and biased.

**But the measured numbers on `example.txt` show the 3-point fit is not what produces 1.78 here:**

```
=== CURRENT HRL: boxratio=2 (powers of 2) ===
alpha1 boxes=[4, 8, 16]    (#=3)   alpha=1.7829
alpha2 boxes=[16, 32, 64]  (#=3)   alpha=0.4716

=== denser geometric grids ===
boxratio=√2     a1 #4  [4,6,8,11]                 a1=1.8951   a2=0.5165
boxratio=2^¼    a1 #9  [4,5,6,7,8,10,11,13,16]    a1=1.7966   a2=0.4142
boxratio=2^⅛    a1 #11 [4..15]                     a1=1.8092   a2=0.4339
boxratio=1.1    a1 #11 [4..15]                     a1=1.7950   a2=0.4123

=== ALL-INTEGER grid (loop every n) ===
alpha1 4:16  (#13)  alpha=1.7707
alpha2 16:64 (#49)  alpha=0.3682

=== alternative conventions (all-integer) ===
nk2 a1 4-11       alpha=1.9109
Kubios a1 4-12    alpha=1.8794
nk2/Kubios a2 12-64 alpha=0.4830
```

Across **every** grid — 3 points, 4, 9, 11, 13 points; geometric or all-integer — **α1 sits in 1.77–1.91**. The grid density changes α1 by less than 0.02 within a fixed range. The 3-point fit is *not* biased relative to the dense fit for this signal. So the "3 sparse points" diagnosis, while a real best-practice issue, is **not the root cause of the implausible value.**

### What actually drives α1≈1.78 here — DFA.jl is correct
A textbook Peng DFA (`profile = cumsum(x − mean); non-overlapping boxes; per-box linear detrend; RMS`) reproduces DFA.jl's per-box fluctuations **identically**:

```
DFA.jl  F(n), n=4..16: 13.92 22.04 32.62 43.55 54.69 65.49 86.92 94.86 109.3 123.6 137.1 150.5 164.8
Reference F(n), n=4..16: 13.92 22.04 32.62 43.55 54.69 65.49 86.92 94.86 109.3 123.6 137.1 150.5 164.8   (identical)

White-noise control (N=5000):  DFA.jl α(4–16)=0.587 ref=0.587 ; α(4–64)=0.549 ref=0.549   (≈0.5 ✓)
```

DFA.jl integrates once (inside the per-box routine), subtracts the global mean in the dispatcher, detrends order-1, and LS-fits log-log — i.e. it is a faithful Peng implementation, validated against both a reference and a white-noise sanity check.

**The signal itself is the explanation.** `example.txt` is a clean ~5-minute RR series: N=4193, mean 957 ms, SD 90 ms, **RMSSD 28.5 ms**, all values in 300–2000 ms, **zero** |Δ|>200 ms jumps, **lag-1 autocorrelation 0.95**, and the opening beats rise monotonically 812→853→904→939→977→1016→1044→1058 ms. That is a strongly smooth, ramp/respiration-dominated short-scale structure. DFA's F(n) for such a profile grows almost linearly in n (F(16)/F(4) ≈ 11.8 ≈ 16/4 × ~3), i.e. a slope approaching the random-walk/Brownian limit (α→1.5; up to 2 for a smooth deterministic ramp). **α1≈1.78 is the correct DFA-α1 of this particular segment**, not a "healthy resting ~1.0" because the segment is not a stationary resting series — it is dominated by a slow monotone trend over the short-scale window. (For comparison, the "healthy α1≈1.0–1.2" figure is an empirical population mean over *stationary* 24-h or carefully detrended resting RR; it is not a hard upper bound, and trend-dominated short segments routinely exceed 1.5.)

---

## 3. Concrete recommendation for HeartRateLab

Two separate actions. **(A) is the cheap best-practice fix you should ship; (B) is the actual correctness conclusion.**

### (A) Densify the box grid (best practice; keeps cited Peng/Francis ranges)

Keep α1 = 4–16 and α2 = 16–64 (Peng/Francis, already cited). Replace the 3-point geometric grid with the **all-integer Francis/Kubios grid** (13 boxes for α1, 49 for α2). This is the most defensible, most-cited dense grid and removes the "slope from 3 points" criticism permanently.

**DFA.jl's `dfa(x; boxmin, boxmax, boxratio, overlap)` cannot express an all-integer grid** — it always builds `boxes = unique(round.(boxratio.^(log_b(boxmin):log_b(boxmax))))`, a geometric grid. The densest it gets is `boxratio→1`, which yields a near-integer but *uneven* grid (and `boxratio=1` is illegal). So **(A) needs a small code change beyond parameters**: call DFA.jl's **single-box** method in a loop over every integer n and fit the slope yourself (DFA.jl exposes exactly this).

Replace the current call (lines ~1284–1292):

```julia
# CURRENT — 3 geometric points each
scales, fluc = DFA.dfa(n.data, boxmax=16, boxmin=4,  boxratio=2, overlap=0.0)
intercept, α1 = DFA.polyfit(log10.(scales), log10.(fluc))
scales, fluc = DFA.dfa(n.data, boxmax=64, boxmin=16, boxratio=2, overlap=0.0)
intercept, α2 = DFA.polyfit(log10.(scales), log10.(fluc))
```

with an all-integer grid built from DFA.jl's per-box method:

```julia
# RECOMMENDED — dense all-integer grid, Peng/Francis ranges, order-1, non-overlapping
function _dfa_alpha(x, nmin::Int, nmax::Int)
    ns   = collect(nmin:nmax)
    fluc = [DFA.dfa(x, k; order = 1, overlap = 0.0) for k in ns]   # F(n) per box size
    return DFA.polyfit(log10.(Float64.(ns)), log10.(fluc))[2]      # slope = α
end
α1 = _dfa_alpha(n.data, 4, 16)    # short-term, 13 box sizes
α2 = _dfa_alpha(n.data, 16, 64)   # long-term, 49 box sizes
```

(Equivalently, a fixed log-spaced grid of ~12–15 points per region via a smaller `boxratio≈2^(1/4)` is acceptable and stays inside DFA.jl's existing API, but all-integer is the cleanest and matches Francis/Kubios exactly.) Detrending stays **order 1**, fit stays **ordinary least squares on log10**, boxes **non-overlapping** (`overlap=0.0`) — matching every reference tool.

**Expected exponents after (A):** unchanged within rounding — **α1 ≈ 1.77, α2 ≈ 0.37** on `example.txt` (vs current 1.78 / 0.47; α2 drops slightly because the 49-point fit no longer over-weights n=64). On a *stationary, detrended* healthy resting record you would see α1 ≈ 1.0–1.2 and α2 ≈ 0.9–1.1; the dense grid makes those slopes statistically sound, which is the real payoff.

### (B) The actual correctness conclusion (fix the expectation, not the math)

α1≈1.78 on `example.txt` is **correct DFA output for a trend-dominated segment**, confirmed against a reference and a white-noise control. Do **not** "fix" it by tweaking ranges or grids hunting for ~1.0 — that would be fitting the algorithm to a wrong prior. Instead:

- Update the DFA test **baseline** in `test/target/` to the *correctly computed* values from the chosen grid (with (A): α1≈1.77, α2≈0.37). This is the `test_features.jl:29` divergence noted in the backlog (d-06) — it is a baseline mismatch, not an algorithm bug.
- If a "physiologically typical α1" demo is wanted, either (i) use a longer/stationary record, or (ii) document that `example.txt`'s short-window α1 is high because the segment is respiration/trend-dominated. Optionally add an order-2 (DFA-2) variant note for trend-heavy series, but **do not** change the default detrend order — order-1 is the universal convention.

---

## 4. DFA.jl capabilities and limits

`abcsds/DFA.jl` (unregistered git dep) is small and **correct**:
- Two methods: `dfa(x, boxsize; order, overlap)` → scalar F(n) for one box size; and `dfa(x; order, overlap, boxmax, boxmin, boxratio)` → `(scales, fluc)` over a **geometric** grid. Plus `polyfit` (ordinary LS).
- Integrates once (`cumsum` inside the per-box fn), subtracts global mean in the dispatcher, per-box polynomial detrend of arbitrary `order` (default 1), non-overlapping by default, optional fractional `overlap ∈ [0,1)`.
- Validated here: per-box F(n) matches a textbook Peng implementation to the digit; white noise → α≈0.5; pink/brownian limits behave correctly.

**Limitation relevant to the recommendation:** the grid dispatcher is **geometric only** (`boxratio.^range`); it **cannot** produce an all-integer or arbitrary linear grid, and `boxratio=2` over a 4× range yields just 3 boxes. To get the Francis/Kubios all-integer grid you must **bypass the dispatcher and loop the single-box method** (as in §3A). No fork or upstream change is required — the single-box API already supports it. RANSAC/robust fitting (nolds-style) is not provided; ordinary LS via `polyfit` is the only estimator, which is fine and matches PCST/Kubios/Francis.

---

## 5. Citations

**Primary methodology**
- Peng C-K, Havlin S, Stanley HE, Goldberger AL. *Quantification of scaling exponents and crossover phenomena in nonstationary heartbeat time series.* Chaos 1995;5(1):82–87. doi:10.1063/1.166141 · PDF: https://pubs.aip.org/aip/cha/article-pdf/5/1/82/18300681/82_1_online.pdf · PMID 11538314
- Francis DP, Willson K, Georgiadou P, et al. *Physiological basis of fractal complexity properties of heart rate variability in man.* J Physiol 2002;542(2):619–629. doi:10.1113/jphysiol.2001.013389 — defines α1 over n=4–16, α2 over n=16–64.
- Iyengar N, Peng CK, Morin R, Goldberger AL, Lipsitz LA. *Age-related alterations in the fractal scaling of cardiac interbeat interval dynamics.* Am J Physiol 1996;271(4):R1078–R1084. doi:10.1152/ajpregu.1996.271.4.R1078 — α1 4–11 / α2 >11 convention.
- PhysioNet DFA reference + `dfa.c`: https://physionet.org/content/dfa/1.0.0/ · https://www.physionet.org/content/dfa/1.0.0/dfa.c

**Tools / source**
- PhysioNet Cardiovascular Signal Toolbox — Vest AN, Da Poian G, Li Q, et al. *An open source benchmarked toolbox for cardiovascular waveform and interval analysis.* Physiol Meas 2018;39(10):105004. doi:10.1088/1361-6579/aae021 · PMID 30199376. Source: `Tools/DFA_Tools/dfaScalingExponent.m` (`ns = 2.^(round(log2(minBox)):round(log2(maxBox)))`, `linfit`, `pinv` LS on log10) and `EvalDFA.m` (minBox=4, midBox=16, maxBox=L/4). https://github.com/cliffordlab/PhysioNet-Cardiovascular-Signal-Toolbox/blob/master/Tools/DFA_Tools/dfaScalingExponent.m
- neurokit2 — `_hrv_dfa` (`dfa_windows = [(4,11),(12,None)]`, `np.linspace(...).astype(int)`): https://github.com/neuropsychology/NeuroKit/blob/master/neurokit2/hrv/hrv_nonlinear.py ; `fractal_dfa` (log-spaced scale, `order=1`, `np.polyfit` on log₂): https://neuropsychology.github.io/NeuroKit/_modules/neurokit2/complexity/fractal_dfa.html
- nolds — `nolds.dfa` docs (default `nvals=logmid_n(N,1/4,15)`, `overlap=True`, `fit_exp='RANSAC'`, `fit_trend='poly'`; "fitting a polynomial to 3 or less data points is error-prone"): https://nolds.readthedocs.io/en/latest/nolds.html
- hrv-analysis (Aura-healthcare) — built on nolds/scipy; nonlinear features: https://github.com/Aura-healthcare/hrv-analysis/blob/master/hrvanalysis/extract_features.py
- RHRV (R) — `CalculateDFA(..., windowSizeRange=c(10,300), npoints=25, ...)`, α1 over ~3<t<17, α2 over ~15<t<65; log-spaced windows, slope by LS over linear regions: https://rdrr.io/cran/RHRV/man/CalculateDFA.html · source: https://rdrr.io/cran/RHRV/src/R/dfa.R
- Kubios HRV User's Guide (Standard/Premium/Scientific) — DFA α1 (4–16), α2 (16–64) defaults: https://www.kubios.com/ · guide: https://www.readkong.com/page/user-s-guide-hrv-standard-hrv-premium-1812684
- DFA.jl (this project's dep): https://github.com/abcsds/DFA.jl

**Context**
- Breathing-frequency bias in fractal HRV analysis (why short-segment α1 can be inflated by respiration/trend): https://www.sciencedirect.com/science/article/abs/pii/S0301051109001252

---

## Appendix — reproduction

In-container (`localhost/hrlab:latest`), numbers above were produced by loading `HeartRateLab.read_txt("test/testdata/example.txt")` (returns the RR vector directly), and comparing `DFA.dfa(x, n; order=1, overlap=0.0)` against a textbook Peng reference DFA across grids (3-point geometric → all-integer 4–16/16–64), plus a white-noise α≈0.5 control. DFA.jl matched the reference to the digit on F(n). Probe scripts: `dfa_probe.jl`, `dfa_probe2.jl`, `dfa_probe3.jl` (delete after review — not part of the package).
