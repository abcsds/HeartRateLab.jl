# HeartRateLab.jl — Agent Context (CLAUDE.md)

## Project Overview

HeartRateLab is a Julia package (v1.0.0) for comprehensive Heart Rate Variability (HRV) analysis based on inter-beat intervals (IBIs). It provides feature extraction, preprocessing, frequency analysis, modeling, and real-time visualization.

- **Author**: Alberto Barradas <abcsds@gmail.com>
- **Repository**: `abcsds/HeartRateLab.jl`
- **Julia version**: 1.11+
- **Code style**: [BlueStyle](https://github.com/invenia/BlueStyle)
- **License**: MIT (pending)

## Architecture

```
src/
├── HeartRateLab.jl          # Main module entry point, exports, includes
├── input.jl                 # Input: read_xdf, read_txt, read_wfdb
├── preprocessing.jl         # Preprocessing: outlier removal, interpolation, windowing
├── Features.jl              # Feature registry + 44 HRV features via @register macro
├── Frequency.jl             # Frequency analysis: Welch, Lomb-Scargle, band power
├── Visualization/           # GLMakie + LSL real-time visualizations
│   ├── Visualization.jl     # Submodule with lazy loaders
│   ├── default.jl           # Full LSL dashboard (RR, NN, SDNN, Poincaré, spectrum)
│   ├── geometric.jl         # Poincaré plot with ellipse overlay
│   ├── heart_rate.jl        # BPM time series
│   ├── heart_rate_tt.jl     # BPM with time tags
│   └── distribution.jl      # Histogram / density
└── Models/                  # [NOT INTEGRATED] Experimental model scripts
    ├── Models.jl            # Empty — needs module definition
    ├── LIF.jl               # Leaky Integrate-and-Fire + Turing inference skeleton
    ├── neural_ODE.jl        # Neural ODE VAE with Flux/DiffEqFlux
    ├── van_der_pol_interactive.jl  # Van der Pol oscillator (GLMakie interactive)
    └── VAE.jl               # Empty — planned for ectopic beat detection
```

## Key Design Decisions

### Feature Registry System
Features are declared with a custom `@register` macro in `Features.jl`. Each feature is a memoized function that receives an `HRMeasurement` struct. The registry tracks name, aliases, domains, and documentation. Feature extraction returns DataFrames.

```julia
# Typical feature declaration pattern:
@register "feature_name" ["alias1"] [:time_domain] """
Documentation string with citation.
"""
feature_name(m::HRMeasurement) = # computation
```

Three registries: `feature_registry`, `representation_registry`, `function_registry`.

### Submodule Access Pattern
- Input and Preprocessing functions are directly exported from `HeartRateLab`
- Features, Frequency, and Visualization are accessed via dot notation:
  - `HeartRateLab.Features.extract_feature_set(data)`
  - `HeartRateLab.Frequency.welch(data)`
  - `HeartRateLab.Visualization.default()`
- Models module is commented out in `HeartRateLab.jl:10`

### Visualization Architecture
Visualizations are currently **executable scripts** loaded via `include()` at runtime through lazy loader functions. They depend on LSL for real-time streaming. They are NOT modular functions — they use global state and create their own figures.

## Running Tests

```bash
# From project root, using the WFDB tools:
julia --project=. -e 'using Pkg; Pkg.test()'

# Or via nix:
nix run .#test
```

Tests require:
- WFDB `ann2rr` binary on PATH (for `read_wfdb` tests)
- Test data in `test/testdata/`
- Baseline CSVs in `test/target/`

### Current Test Status (as of 2026-02-17)
- **11 pass, 7 error** — errors are in Input (5), Preprocessing/ectopic_beats (1), Features (1)
- Input errors likely due to missing WFDB binary or XDF dependency issues
- Features error likely cascades from Input failure

## Dependencies

**Core**: CSV, DataFrames, DataInterpolations, StatsBase, Memoization, MacroTools, Distributed
**Signal Processing**: DSP, LombScargle, Trapz, DFA ([abcsds/DFA.jl](https://github.com/abcsds/DFA.jl) — unregistered, installed via git URL), Hurst, EntropyHub
**Visualization**: GLMakie, Plots, LSL
**Input**: XDF
**Models (not in Project.toml yet)**: DifferentialEquations, Flux, DiffEqFlux, Optim, Turing

## Important Files

| File | Purpose |
|------|---------|
| `src/HeartRateLab.jl` | Main module — controls what's included and exported |
| `src/Features.jl` | Largest file (~992 lines) — feature registry + all 44 features |
| `src/Frequency.jl` | Welch/Lomb-Scargle periodograms + band power calculation |
| `test/runtests.jl` | Full test suite — comparison against baseline CSVs |
| `test/target/example.csv` | Baseline: 44 features for the example dataset |
| `Project.toml` | Dependencies — Models deps not yet added |
| `LOG.md` | Development diary — timeline and design decisions |
| `README.md` | Feature checklist (README-driven development) |

## Known Issues and TODOs

### Critical Missing Features (Aspirational Documentation)
- **`fit()` method for models** — Documented in ModelFitResult but NOT implemented
  - Expected: `fit(model, data; method=:bayesian)` using Turing.jl
  - Status: Only `simulate()` works for VanDerPol
  - Impact: Cannot fit model parameters to real data, only manual parameter selection
- **VanDerPol parameter_space()** — Documented in interface but NOT implemented
- **DMD, Lorenz, LIF models** — Have comprehensive tests but models don't exist (sham tests)

### Code Issues
- `Features.jl:920` — FIXME: DFA scales are wrong
- `Frequency.jl:88` — FIXME: `find_peak` incorrect index after filtering
- `Features.jl:434` — TODO: all other interpolation methods via config
- `Features.jl:868-869` — TODO: DFA visualization
- Visualization scripts use global state and `include()` pattern — needs refactoring

### Missing Dependencies
- Missing model deps in Project.toml: DifferentialEquations, Flux, DiffEqFlux, Turing, Optim, BlackBoxOptim

## Conventions

- Preprocessing functions come in mutating (`!`) and non-mutating pairs
- All feature functions receive `HRMeasurement` and are `@memoize`d
- NaN is used as sentinel for missing/invalid IBI values throughout the pipeline
- IBI values are in **milliseconds** throughout the package
- Test data: `test/testdata/example.txt` contains 4,193 IBI samples
- Windowed analysis uses `:beats` or `:ms` time units
- Frequency bands: ULF (0-0.003), VLF (0.003-0.04), LF (0.04-0.15), HF (0.15-0.4)

## Testing Standards and Anti-Patterns

### ⛔ PROHIBITED: Sham Tests (Tests that Pass for Non-Existent Functionality)

**Problem**: `test/test_models.jl` contains tests wrapped in `try/catch` blocks that claim to test models (DMD, Lorenz, LIF) but silently skip when those models don't exist:

```julia
# ⛔ ANTI-PATTERN - DO NOT DO THIS
try
    @testset "DMD Model" begin
        dmd = HeartRateLab.Models.DMD(rank=5)  # DMD doesn't exist!
        @test dmd.rank == 5
    end
catch err
    @warn "Skipping DMD model tests - LinearAlgebra not available" exception=err
end
```

**Why this is toxic**:
1. **Misleading error message**: Claims "LinearAlgebra not available" when the real issue is DMD doesn't exist
2. **False sense of completeness**: Test suite appears comprehensive but tests nothing
3. **Breaks TDD**: Tests should be written BEFORE implementation, then FAIL until implementation is complete
4. **Silent failures**: CI shows green but functionality is missing

**Correct TDD approach**:

```julia
# ✅ CORRECT - Tests fail loudly until implementation exists
@testset "DMD Model" begin
    @test_skip begin  # Explicitly mark as not yet implemented
        dmd = HeartRateLab.Models.DMD(rank=5)
        @test dmd.rank == 5
    end
end

# OR mark entire test file as pending:
# @testset "DMD Model (NOT YET IMPLEMENTED)" begin
#     @test_broken begin
#         dmd = HeartRateLab.Models.DMD(rank=5)
#         @test dmd.rank == 5
#     end
# end
```

**Action Required**:
- Replace `try/catch @warn "Skipping..."` with `@test_skip` or `@test_broken`
- Tests for unimplemented features must explicitly fail or be marked as pending
- Error messages must accurately describe the problem
- Never use `try/catch` to silently suppress test failures

**Test Philosophy**:
- **Red → Green → Refactor**: Tests must fail (red) before implementation
- Tests are executable specifications: they document what SHOULD work
- Green tests mean "this functionality works" - never let tests lie about this

## Reproducibility & Workflow (Using Nix)

### ⚠️ IMPORTANT: Always Use `nix run` Commands

This project uses **Nix flakes** for reproducible development and testing. Docker containers ensure consistent Julia 1.11 environment, dependencies, and WFDB tools across all developers and CI/CD systems.

**DO NOT run tests locally without Nix/Docker** — you may have missing WFDB binaries or inconsistent Julia versions.

### Nix Workflow Quick Reference

```bash
# 🔷 Setup Phase (run ONCE when starting new feature work)
nix run .#build              # Build Docker image with Julia 1.11 + WFDB
                             # Output: hrlab:latest image

# 🔶 Development Phase (run for testing/iteration)
nix run .#test               # Run full Julia test suite in container
                             # Runs: julia --project=. -e 'Pkg.test()'
                             # Exit code 0 = all tests pass

# 🟢 Rendering Phase (for notebook demos)
nix run .#build-render       # Build Docker image with Quarto 1.8 + IJulia
                             # Output: hrlab:render image (larger, ~4.8 GB)

nix run .#render             # Render flagship_demo.qmd to HTML
                             # Requires: must run build-render FIRST
                             # Output: docs/flagship_demo.html

# 🔵 Interactive Phase (when you need a shell)
nix run                      # Open interactive Julia REPL in container
nix run .#act                # Run GitHub Actions locally for CI testing
```

### Workflow by Task Type

#### ✅ Running Tests
```bash
# Single command: build image and run all tests
nix run .#build && nix run .#test

# Running just model tests:
nix run .#test
# (Inside the container, you can specify: julia --project=. test/test_models.jl)
```

#### ✅ Implementing Model Features
When implementing Phase B-F (models, fitting, etc.):

```bash
# 1. Build image once
nix run .#build

# 2. After each code change, verify tests pass:
nix run .#test

# 3. If tests fail, read output carefully:
#    - @test_broken = not yet implemented (expected)
#    - Error output = bug in your code (fix it)
#    - Package load errors = dependency issue (check Project.toml)
```

#### ✅ Rendering Notebooks
When working on documentation/demos (flagship_demo.qmd, comprehensive_demo.qmd, etc.):

```bash
# 1. Build render image (includes Quarto + IJulia)
nix run .#build-render

# 2. Render the notebook
nix run .#render

# 3. Check output
ls -lh docs/flagship_demo.html
```

#### ✅ Interactive Julia Session
To debug or manually test code:

```bash
nix run                     # Opens Julia REPL
# Inside REPL:
# julia> using HeartRateLab
# julia> include("test/test_models.jl")
```

### Inside the Container

Once you run `nix run .#test` (or `nix run` for interactive), you're inside a Docker container with:
- **Julia 1.11** (official julia:1.11 base image)
- **WFDB tools** (ann2rr, rdsamp, etc.)
- **Python 3** (for data processing)
- **Quarto 1.8** (if using build-render)
- **Project dependencies** (all Pkg.instantiate'd and precompiled)

In the container:
```bash
# Project root is /workdir
cd /workdir

# Full test suite
julia --project=. -e 'using Pkg; Pkg.test()'

# Specific test file
julia --project=. test/test_models.jl

# Interactive session
julia --project=.
```

### Dockerfile & Image Strategy

**Two image types** (both defined in single `Dockerfile`):

1. **Development Image** (default, `hrlab:latest`)
   ```bash
   docker build . -t hrlab:latest
   ```
   - Julia 1.11
   - All dependencies from Project.toml
   - WFDB tools for input reading
   - Size: ~3.8 GB

2. **Render Image** (with Quarto, `hrlab:render`)
   ```bash
   docker build --build-arg INSTALL_QUARTO=true . -t hrlab:render
   ```
   - Includes: Julia 1.11 + Quarto 1.8 + IJulia kernel
   - For rendering .qmd notebooks
   - Size: ~4.8 GB (larger due to Quarto + Node deps)

**Both images are managed by `flake.nix`** — you run `nix run .#build` and the correct image is built automatically.

### Troubleshooting

**Problem**: `docker: command not found`
- **Solution**: Install Docker or use `nix flake` support in your system

**Problem**: Test hangs after "Precompiling HeartRateLab"
- **Likely cause**: The bare docstring bug in `src/Features.jl:89-91` (FIXED in recent commits)
- **Solution**: Verify your code matches the memory note about the fix

**Problem**: Tests fail with "ann2rr not found"
- **Expected**: Some Input tests skip when WFDB binary missing
- **Normal**: This is OK — WFDB tests are gated with `Sys.which("ann2rr")`

**Problem**: Package manifest mismatch warnings
- **Normal**: Expected when running fresh tests — Pkg.resolve() handles it
- **Not an error**: Tests still run successfully

**Problem**: `nix run .#render` says "Render failed - output file does not exist"
- **Likely cause**: Missing `nix run .#build-render` step
- **Solution**: Run `nix run .#build-render` FIRST, then `nix run .#render`

### Example: Complete Development Workflow

Working on implementing Phase B (VanDerPol Bayesian fitting):

```bash
# 1. Setup: build container image (one-time)
nix run .#build

# 2. Edit code: src/Models.jl (add fit() and parameter_space() methods)

# 3. Test: run test suite to verify
nix run .#test
# Output shows: @test_broken items still broken, other tests pass

# 4. Repeat step 2-3 until fit() implementation is complete

# 5. Final test run: verify all Phase B tests now pass
nix run .#test

# 6. Commit your changes
git add src/Models.jl test/test_models.jl
git commit -m "Implement VanDerPol Bayesian fitting with Turing.jl"
```

### For CI/CD Integration

The GitHub Actions workflow (if present) would use:
```yaml
- name: Run tests
  run: nix run .#test
```

This ensures **reproducible CI** — same container, same Julia version, same WFDB tools for all developers and CI runners.
