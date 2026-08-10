# Detrended Fluctuation Analysis (DFA) in HeartRateLab

Detrended Fluctuation Analysis quantifies the **long-range correlation /
self-similar scaling** of an inter-beat-interval (IBI) series. It produces two
scaling exponents:

- **α1** — *short-term* scaling, fitted over small box sizes (default 4–16 beats).
- **α2** — *long-term* scaling, fitted over large box sizes (default 16–64 beats).

In HeartRateLab these are exposed as the features `dfa1` (α1), `dfa2` (α2) and the
representation `dfa` (returns the tuple `(α1, α2)`).

```julia
using HeartRateLab
data = HeartRateLab.read_txt("test/testdata/example.txt")
m    = HeartRateLab.Features.HRMeasurement(data)

HeartRateLab.Features.function_registry["dfa1"](m)   # α1
HeartRateLab.Features.function_registry["dfa2"](m)   # α2
HeartRateLab.Features.function_registry["dfa"](m)    # (α1, α2)
```

## The algorithm

The DFA *algorithm* is **identical** across every validated HRV tool (neurokit2,
Kubios, the PhysioNet Cardiovascular Signal Toolbox, Francis 2002, Peng 1995,
nolds, RHRV). For a box size `n`:

1. **Integrate** the mean-removed series into a profile (cumulative sum).
2. **Split** the profile into non-overlapping boxes of length `n`.
3. **Detrend** each box with an **order-1 (linear)** least-squares fit.
4. **RMS** the residuals across all boxes → the fluctuation `F(n)`.
5. Repeat for a range of `n`, then **OLS-regress** `log10 F(n)` on `log10 n`. The
   slope is the scaling exponent α.

Tools differ **only** in (a) the box-size (`n`) ranges chosen for α1/α2, and
(b) how densely `n` is sampled. They do **not** differ in the math above.

## Default convention: Peng / Francis, dense all-integer grid

HeartRateLab defaults to the **Peng/Francis** convention with the crossover fixed
at `n = 16`:

| Exponent | Box-size range | # box sizes (default integer grid) |
|----------|----------------|------------------------------------|
| α1       | 4 ≤ n ≤ 16     | 13                                 |
| α2       | 16 ≤ n ≤ 64    | 49                                 |

The grid is the **dense, all-integer** Francis/Kubios grid (every integer `n` in
each range), fitted by ordinary least squares on `log10 F(n)` vs `log10 n` with
order-1 detrending and non-overlapping boxes. This is statistically sound and
removes the "slope from only 3 points" criticism of a sparse geometric grid.

> A geometric grid with ratio 2 produces only the 3 box sizes `[4, 8, 16]` for α1
> and `[16, 32, 64]` for α2 — the legacy behaviour, still selectable (see below).
> On real RR series, densifying the grid changes α1 by `< 0.02`; the win is
> statistical soundness, not a different number.

## Configuration

The ranges and the grid are configurable through
`HeartRateLab.Features.config` — the same module-level config dictionary used for
`freq_method`/`fs`. No source edit is required.

| Key | Default | Meaning |
|-----|---------|---------|
| `config["dfa_alpha1_range"]` | `(4, 16)`  | `(nmin, nmax)` box sizes for the short-term α1 fit. |
| `config["dfa_alpha2_range"]` | `(16, 64)` | `(nmin, nmax)` box sizes for the long-term α2 fit. |
| `config["dfa_grid"]`         | `:integer` | `:integer` → every integer `n` in the range (dense, Francis/Kubios; default). `:geometric` → DFA.jl's geometric dispatcher with `dfa_boxratio` (legacy 3-point grid when ratio = 2). |
| `config["dfa_boxratio"]`     | `2`        | Geometric grid ratio, used **only** when `dfa_grid == :geometric`. |

`dfa1`/`dfa2`/`dfa` are memoized; after changing config call
`Memoization.empty_all_caches!()` to force recomputation.

### Following the neurokit2 / Iyengar convention

A competing **clinical** convention (Iyengar 1996, as used by neurokit2's `hrv`)
narrows α1 to strictly sub-respiratory scales and lets α2 run to `N/10`:

```julia
using HeartRateLab, Memoization
F = HeartRateLab.Features
N = length(data)                         # series length in beats
F.config["dfa_alpha1_range"] = (4, 11)   # Iyengar / neurokit2 α1
F.config["dfa_alpha2_range"] = (12, N ÷ 10)
Memoization.empty_all_caches!()
F.function_registry["dfa1"](m)           # α1 over 4–11
F.function_registry["dfa2"](m)           # α2 over 12–N/10
```

Set these if you need agreement with neurokit2; keep the defaults for the
Peng/Francis/Kubios literature convention.

### Why the conventions diverge

They diverge **only in the n-ranges**, not in the algorithm:

- **Peng / Francis / Kubios-default / PhysioNet CST:** α1 `4–16`, α2 `16–64`,
  crossover at `n = 16`. (HeartRateLab default.)
- **Iyengar 1996 / clinical / neurokit2:** α1 `4–11`, α2 `12–N/10`. This narrows
  α1 to scales below the respiratory band.

The narrower α1 range does *not* systematically lower α1; on a trend-dominated
short segment it can be slightly *higher*.

## Long-record meaningfulness of α2

α2 is fitted over the 16–64-beat (long) scales. On a **short ~5-minute / ~1-hour
segment** these "long" scales are still short in absolute terms, and α2 is
**degenerate** — e.g. on `example.txt` (≈ 4193 beats) α2 ≈ 0.37, well below the
≈ 1.0 expected of a healthy long-term exponent.

On a genuine **≥ 24-hour record** the same 16–64-beat scales become a real
long-term exponent. On NSRDB 16265 (≈ 99 819 beats, ≈ 22 h of beats):

| Record | α1 | α2 |
|--------|----|----|
| `example.txt` (≈ 1 h) | ≈ 1.77 | ≈ 0.37 (degenerate) |
| NSRDB 16265 (≈ 24 h)  | ≈ 1.24 | ≈ 0.99 (≈ 1, healthy 1/f-like) |

`test/test_longrecord.jl` validates α2 on 16265 with loose physiological ranges
(not point baselines) precisely to exercise this meaningfulness. 16265 is already
a single > 24 h record; multi-day nsr2db Holter records could extend the long
horizon further but are not fetched in the test suite.

> α1 ≈ 1.77 on `example.txt` is the **correct** DFA-α1 of that segment, not a bug:
> it is a clean, strongly autocorrelated (lag-1 ≈ 0.95), trend-dominated RR series,
> which DFA legitimately scores near the random-walk limit at short scales. See
> `docs/dfa-parameters-research.md` for the cross-tool study that established this.

## Implementation notes

The unregistered dependency [`DFA.jl`](https://github.com/abcsds/DFA.jl) provides
a single-box fluctuation `DFA.dfa(x, n; order=1, overlap=0.0)` and a geometric grid
dispatcher `DFA.dfa(x; boxmin, boxmax, boxratio, overlap)`. The dispatcher is
**geometric-only**, so the all-integer Francis/Kubios grid is built by looping the
single-box method over every integer `n` and fitting the slope with `DFA.polyfit`
(ordinary least squares on `log10`). No fork of DFA.jl is needed.

## Citations

- **Peng C-K, Havlin S, Stanley HE, Goldberger AL.** *Quantification of scaling
  exponents and crossover phenomena in nonstationary heartbeat time series.* Chaos
  1995;5(1):82–87. [doi:10.1063/1.166141](https://doi.org/10.1063/1.166141) — origin
  of the n = 16 crossover and the α1/α2 decomposition.
- **Francis DP, Willson K, Georgiadou P, et al.** *Physiological basis of fractal
  complexity properties of heart rate variability in man.* J Physiol
  2002;542(2):619–629.
  [doi:10.1113/jphysiol.2001.013389](https://doi.org/10.1113/jphysiol.2001.013389) —
  defines α1 over n = 4–16 and α2 over n = 16–64 (the all-integer default grid).
- **Iyengar N, Peng CK, Morin R, Goldberger AL, Lipsitz LA.** *Age-related
  alterations in the fractal scaling of cardiac interbeat interval dynamics.* Am J
  Physiol 1996;271(4):R1078–R1084.
  [doi:10.1152/ajpregu.1996.271.4.R1078](https://doi.org/10.1152/ajpregu.1996.271.4.R1078)
  — the α1 4–11 / α2 > 11 (clinical) convention.
- **Vest AN, Da Poian G, Li Q, et al.** *An open source benchmarked toolbox for
  cardiovascular waveform and interval analysis* (PhysioNet Cardiovascular Signal
  Toolbox). Physiol Meas 2018;39(10):105004.
  [doi:10.1088/1361-6579/aae021](https://doi.org/10.1088/1361-6579/aae021) —
  minBox = 4, midBox = 16, α2 over 16 ≤ n ≤ N/4.
- **Kubios HRV** (Standard/Scientific) User's Guide — DFA α1 (4–16), α2 (16–64)
  defaults. <https://www.kubios.com/>
- **neurokit2** — `_hrv_dfa` (α1 window `(4, 11)`, α2 `(12, None → (len+1)/10)`,
  `np.polyfit` on log₂). <https://github.com/neuropsychology/NeuroKit>

For the full cross-tool survey (PhysioNet CST, nolds, RHRV, the white-noise
control, and the analysis of why α1 ≈ 1.77 on `example.txt` is correct), see
[`docs/dfa-parameters-research.md`](dfa-parameters-research.md).
