# HeartRateLab.jl — v1 (0.1.0) Release-Readiness Review

**Reviewer:** independent release auditor (read-only pass)
**Branch:** `cl`  ·  **Date:** 2026-06-17
**Scope:** code quality, tests, v1 goals/exit-criteria, documentation drift.

---

## Executive Verdict

**NOT READY to publish as-is — but the blockers are shallow (documentation + one
namespace defect), not deep.** The engineering core is in good shape: the test
suite is genuinely green (868 pass / 2 honest `@test_broken` / 0 fail per the
confirmed gate), the new d-20 (AIC/BIC ranking) and d-24 (long-record NSRDB
validation) work is solid and honestly tested, the 53-feature registry count is
verified correct in-container (53 features / 11 representations / DEFAULT 39 /
FAST 40 / NONLINEAR 14 / ALL 53, all matching the README), and there are no
sham `try/catch "@warn skipping"` tests in the wired suite.

What blocks a *publishable* v1 is that **the first code a new user copy-pastes
from the README fails with `MethodError`** (verified in-container), the
**advertised `using GLMakie; plot_ibi_series(...)` path silently returns
`nothing`** because of a namespace defect in the visualization layer, and
**`docs/SPEC.md` — the self-declared "ground truth for merge readiness" — is
months stale** and contradicts itself. None of these require algorithmic work;
they are correctness-of-the-public-surface issues that a published library
cannot ship with.

### Top blockers (must fix before tagging 0.1.0)

1. **README model quick-start is broken (verified MethodError).** `README.md:27`
   `LIF(τ=50, I_base=0.5, threshold=1.0, noise_amp=0.1)` — none of `I_base`,
   `threshold`, `noise_amp` are LIF fields (`src/Models/LIF.jl:30-39`: the
   ctor is `LIF(; τ, V_rest, V_reset, V_threshold, R, I)`). In-container this
   throws `MethodError`.
2. **README `simulate(...; n_beats=1000)` is broken (verified MethodError).**
   `README.md:29` and `README.md:218` and `docs/src/index.md:38` call
   `simulate` with a `n_beats=` keyword, but every method is positional
   `simulate(model, params, n_beats::Int)` (`src/Models/*.jl`). In-container:
   `MethodError`.
3. **Exported offline plots silently no-op without `using Plots` in `Main`.**
   `Plots` is a hard `[deps]`, yet `src/Visualization/Visualization.jl` never
   imports it — every plot fn does `isdefined(Main, :plot) || (println(...);
   return nothing)` (e.g. `:74`, `:124`, `:181`, `:266`...). The README's viz
   snippet (`README.md:34-38`) does `using GLMakie` (not `using Plots`), so
   `plot_ibi_series(ibis)` returns `nothing`, not a figure. Tests only pass
   because `test/test_visualization.jl:3` does `using Plots`.
4. **GLMakie extension is ~half dead/parallel code that the README points users
   at.** `ext/HeartRateLabVisualizationExt.jl` defines `plot_ibi_series`,
   `plot_poincare`, `plot_spectrum`, `plot_lorenz_3d`, etc. (`:88`, `:133`,
   `:200`, `:414`...) as *new functions inside the ext module* — they do **not**
   extend `HeartRateLab.Visualization.plot_*` (grep confirms zero qualified
   `Visualization.plot_*` definitions in the ext). So `using HeartRateLab,
   GLMakie; plot_ibi_series(x)` resolves to the Plots.jl version, never the
   GLMakie one. The README (`:34`, `:55` "13 Visualization Functions",
   `:225-244`) advertises GLMakie figures the public API cannot return.
5. **`docs/SPEC.md` (the "authoritative merge checklist") is stale and
   self-contradictory.** Header still dated 2026-03-10; says version 1.0.0 "is
   premature, should be 0.1.0" (`:54-56`) though `Project.toml` is already
   `0.1.0`; still lists `find_peak` "incorrect index bug at Frequency.jl:88"
   (`:210`) which is fixed *and marked fixed in the same file's BUG table*;
   `nix run .#build` "broken" (`:72`); ectopic/ULF "1 error in current test
   suite" (`:127`); SPEC-V4/V5/V6 "PARTIAL — stubs / GLMakie error" (`:377-388`)
   though implemented; SPEC-T3 "620 pass" (`:461`) vs the real 868. Publishing
   with the source-of-truth doc this wrong is a credibility problem.

---

## Prioritized Findings

Severity: **blocker** (cannot ship v1) · **major** (should fix for v1) ·
**minor** (nice-to-have / post-v1).

| # | Sev | Dim | Location | Issue | Recommended fix |
|---|-----|-----|----------|-------|-----------------|
| 1 | blocker | doc | `README.md:27` | `LIF(τ=50, I_base=0.5, threshold=1.0, noise_amp=0.1)` — fields don't exist; verified `MethodError`. | Use real ctor: `LIF()` or `LIF(τ=200.0, I=1.52)`. |
| 2 | blocker | doc | `README.md:29,218`; `docs/src/index.md:38` | `simulate(..., n_beats=1000)` keyword; `simulate` is positional. Verified `MethodError`. | `simulate(result.model, result.params, 1000)`. |
| 3 | blocker | code | `src/Visualization/Visualization.jl:74,124,181,...` | Exported plots reach into `Main.plot`; hard-dep `Plots` never imported in `src/`. Silent `nothing` return when caller hasn't `using Plots`. | `import Plots` in the module and call `Plots.plot` etc.; drop the `Main`-sniffing / silent-nothing guard. |
| 4 | blocker | code | `ext/HeartRateLabVisualizationExt.jl:88,133,200,292,354,414` | Ext `plot_*` are independent functions, never extend `Visualization.plot_*` → unreachable dead code; contradicts README's GLMakie promise. | Either make the ext methods extend the parent generics (`function HeartRateLab.Visualization.plot_ibi_series(...)`) and choose a real dispatch story, or delete the dead duplicates and stop advertising GLMakie figures for these. |
| 5 | blocker | doc | `docs/SPEC.md` (header, `:54,72,127,210,377-388,461`) | Stale, self-contradictory "source of truth"; predates all `cl` work. | Reconcile statuses to reality (version 0.1.0, find_peak fixed, build works, viz specs DONE, test count 868) or clearly retire it in favour of the README + backlog plan. |
| 6 | major | doc | `README.md:274` ("Real-time Streaming ✅ Available via `nix run .#viz`") + `CLAUDE.md` viz/fmt rows "⏳ Not yet implemented" | `flake.nix` now *has* `apps.viz` (`:91`) and `apps.fmt` (`:119`) — internal CLAUDE.md is the stale one; README's "✅ Available" for live LSL streaming is a strong claim for a path needing a live LSL device + a `.viz-env`. | Soften README streaming claim to "experimental / requires live LSL stream + first-run env build"; update CLAUDE.md viz/fmt rows. |
| 7 | major | code | `src/Features.jl:1067` | `sampen`: `EntropyHub.SampEn(n.data, m=+1, r=r)` — `m=+1` is the literal `1`, almost certainly meant `m=m+1` (sample entropy needs the m and m+1 template counts). Likely a numerically wrong `sampen` for any non-default `m`. | Verify intent against EntropyHub; fix to `m=m+1` if confirmed, regen any baseline. |
| 8 | major | test | `test/test_features.jl:48-54` | Entropy/nonlinear features (`apen`, `sampen`, `fuzzyen`, `mse`, etc.) are only asserted **finite**, plus a frozen `example.csv` regression. No cross-library / known-answer correctness check. Combined with #7, a wrong `sampen` would pass. | Add at least one known-answer or cross-lib parity assertion for the entropy family (the internal d-11 parity is the natural home; pin one numeric expectation in-repo). |
| 9 | major | doc | `Project.toml:33-42` vs `ext/HeartRateLabDeepExt.jl` | `Flux`/`DiffEqFlux` are weakdeps wiring `HeartRateLabDeepExt`, which is a **pure stub** (no models, only TODOs and an empty `__init__`). The plan claims dead exts were removed; this one remains and ships a documented-but-empty extension. | Delete `HeartRateLabDeepExt.jl` + its weakdeps/extension entries for v1 (it's post-v1 VAE/NeuralODE work), or clearly gate it as experimental. |
| 10 | major | goal | `backlog` plan §5 exit-criteria 2 & 3 | v1 exit requires (2) the internal d-11 cross-library parity actually run+reviewed, and (3) docs deploy live (user must add `DOCUMENTER_KEY` secret). Neither is verifiable from the repo; CI `docs` job is wired (`.github/workflows/CI.yml:86-116`) but inert without the secret. | Confirm the secret is set + a docs build has gone green on `main`; run and archive the d-11 parity results before tagging. |
| 11 | minor | code | `test/tools/dataset_loaders.jl:40,47,54,67` | `fill(800.0, 100)` fake-data fallbacks remain (d-18). Dev tooling (not package API), so acceptable for v1 per plan, but a real foot-gun: a download failure silently yields plausible fake IBIs. | Replace with `error(...)`; it's a 4-line change and removes a silent-corruption path even in dev tooling. |
| 12 | minor | code | `src/Evaluation.jl:938-941` | `rank_models`: if *every* model returns `-Inf` loglik, `minimum(crit)=Inf`, `delta=Inf-Inf=NaN`, weights `NaN`. Edge case only. | Guard: if all criteria non-finite, set `delta=0`/`weight=NaN` explicitly or skip the weight calc. |
| 13 | minor | code | `src/Evaluation.jl:120-132,310-323` | `windowed_feature_set`/`extract_ensemble_features` swallow per-window feature-extraction errors into all-NaN rows via bare `catch e`. Masks genuine extraction bugs. | Log the exception (at least `@debug`) instead of silent NaN; the project forbids silent-skip elsewhere. |
| 14 | minor | doc | `README.md:271` | Implementation-status table: "Mechanistic Models ✅ Complete — LIF, Van der Pol, Lorenz (ODE-based)" omits DMD from the row but DMD is a headline model (listed separately as 🧪 Beta `:272`). Slightly confusing. | Clarify the 3 ODE models vs DMD split. |
| 15 | minor | code | `src/Features.jl:553-554` | Module-load-time `throw` on `config["freq_method"]` references an undefined `method` var in the error string (`"$method"`); only reachable if config is corrupted, but the error itself would `UndefVarError`. | Use `$(config["freq_method"])` in the message. |
| 16 | minor | test | `test/test_preprocessing.jl:129` | `@warn "Ectopic beats test skipped..."` if `example.txt` missing — borderline sham (the file is vendored and always present, so it never fires, but it's the exact anti-pattern the project bans). | Drop the guard or convert to a hard `@test isfile(...)`. |

---

## Dimension Notes

### Code quality
- **Models** are clean: LIF/VDP/Lorenz/DMD implement `simulate`/`fit`/
  `parameter_space`; LIF ctor and analytic inversion are coherent
  (`src/Models/LIF.jl`). `read_wfdb` now correctly returns `Float64` ms
  (`src/input.jl:56-67`, validated by d-24's `eltype` assertion).
- **Frequency** `find_peak`/`get_power` index logic is correct
  (`src/Frequency.jl:83-91`) — the SPEC "bug at :88" claim is stale.
- **Evaluation/d-20** (`src/Evaluation.jl:778-944`) is the strongest new code:
  thoughtful Gaussian-residual likelihood with documented rationale, DMD
  param-count special-case, AIC/BIC + Akaike weights, honest edge handling
  (empty → empty DataFrame, sim failure → `-Inf` → ranks last).
- **Main worry is the visualization layer** (#3, #4): the `Main.plot` indirection
  and the unreachable GLMakie ext are a genuine architecture smell, made worse by
  the README advertising the GLMakie path.

### Tests
- Genuinely green and non-sham. d-20 coverage (`test/test_evaluation.jl:623-718`)
  exercises formulas, per-model `k`, likelihood mean-matching, robustness, and
  ranking/weights incl. the DMD-is-weaker demonstration. d-24
  (`test/test_longrecord.jl`) is a well-designed *meaningfulness* check (loose
  physiological ranges + the short-vs-long α2 contrast), not a brittle baseline.
- The single `@test_broken` (DMD mean, `test/test_models.jl:57`) and single
  `@test_skip` (headless GLMakie, `test/test_visualization.jl:117`) are honest
  with accurate messages.
- Gap: entropy-family correctness is finiteness-only (#8), which would hide #7.

### Goals / exit criteria
- In-repo work (d-24, d-20) is **done and committed**; green gate holds.
- Out-of-repo criteria (d-11 parity run+reviewed; docs-deploy secret live) are
  **not verifiable from the tree** and gate the tag (#10).
- d-18 loaders intentionally remain dev tooling with fake-data fallbacks (#11).

### Documentation drift (most concentrated risk)
- **README**: two broken code examples (#1, #2), a viz path that can't return
  what it claims (#3, #4), an aggressive "Real-time ✅ Available" (#6).
- **SPEC.md**: pervasively stale (#5).
- **CLAUDE.md** (internal/gitignored): viz/fmt marked "not implemented" though
  `flake.nix` now has them — lower priority since it's not shipped.
- **Verified-correct** docs: feature counts (53/39/40/14/53) match code exactly;
  `docs/src/` and `docs/flagship_demo.qmd` use the *correct* `LIF()` /
  positional `simulate` API (only the README/index.md are wrong).
