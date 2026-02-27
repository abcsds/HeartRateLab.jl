# HeartRateLab.jl — Agent Context (CLAUDE.md)

## Project Overview

HeartRateLab is a Julia package (v1.0.0) for comprehensive Heart Rate Variability (HRV) analysis based on inter-beat intervals (IBIs). It provides feature extraction, preprocessing, frequency analysis, modeling, and real-time visualization.

## Features

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

## Running Tests

```bash
# From project root, using the WFDB tools:
julia --project=. -e 'using Pkg; Pkg.test()'

# Or via nix:
nix run .#test
```

**Core**: CSV, DataFrames, DataInterpolations, StatsBase, Memoization, MacroTools, Distributed
**Signal Processing**: DSP, LombScargle, Trapz, DFA ([abcsds/DFA.jl](https://github.com/abcsds/DFA.jl) — unregistered, installed via git URL), Hurst, EntropyHub
**Visualization**: GLMakie, Plots, LSL
**Input**: XDF
**Models (not in Project.toml yet)**: DifferentialEquations, Flux, DiffEqFlux, Optim, Turing

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