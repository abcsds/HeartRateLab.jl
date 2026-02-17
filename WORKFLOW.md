# HeartRateLab.jl — Agent TDD Workflow

This document describes how agents (AI or human) develop and test HeartRateLab independently using test-driven development.

---

## 1. Execution Methods

Three ways to run tests, from simplest to most reproducible:

### Method A: Plain Julia (recommended for development)

```bash
# Full test suite
julia --project=. -e 'using Pkg; Pkg.test()'

# Single test file (from project root)
julia --project=. test/test_preprocessing.jl

# Ad-hoc subset (inline)
julia --project=. -e '
cd("test")
using HeartRateLab: HeartRateLab
using Test
include("test_preprocessing.jl")
'
```

**Requirements:** Julia 1.11+, project dependencies resolved (`Pkg.instantiate()`).
**WFDB tests:** Require `ann2rr` on PATH. Skip gracefully if missing.
**Network tests:** Require internet. Tagged `@network`, skipped by default.

### Method B: Docker (reproducible, includes WFDB)

```bash
# Volume-mount method (uses local source, fast iteration)
docker run --rm -v "$(pwd)":/workdir -w /workdir julia:1.11-bookworm \
  julia --project=. -e 'using Pkg; Pkg.test()'

# Run single test file
docker run --rm -v "$(pwd)":/workdir -w /workdir julia:1.11-bookworm \
  julia --project=. test/test_preprocessing.jl

# Full environment with WFDB (requires built hrlab image)
docker run --rm -v "$(pwd)":/workdir -w /workdir hrlab:latest \
  julia --project=. -e 'using Pkg; Pkg.test()'
```

**Note:** The `hrlab` image includes WFDB tools (`ann2rr`). Build it with:
```bash
docker build --network=host . -t hrlab
```

**Known issue:** Dockerfile must copy both `Project.toml` AND `Manifest.toml` because `DFA` is an unregistered package installed from [abcsds/DFA.jl](https://github.com/abcsds/DFA.jl). Without the Manifest, `Pkg.instantiate()` cannot resolve it.

### Method C: Nix (full reproducibility)

```bash
nix run .#build   # Build Docker image + instantiate
nix run .#test    # Run tests in Docker container
nix run           # Open Julia REPL in container
nix run .#act     # Run GitHub CI locally via act
```

**Fallback:** If the nix-built Docker image fails, nix should fall back to a volume-mount Docker run. See the `test` app in `flake.nix`.

**Current status:** `nix run .#build` is broken because the Dockerfile doesn't copy `Manifest.toml`. Fix this first.

---

## 2. Test Suite Architecture

Tests are split into independent files so agents can run only the tests relevant to their work. No agent needs to wait for another's tests to pass.

### Test File Layout

```
test/
├── runtests.jl              # Dispatcher: includes all test files
├── test_input.jl            # Input: read_xdf, read_txt, read_wfdb
├── test_preprocessing.jl    # Preprocessing: outliers, interpolation, windowing
├── test_features.jl         # Features: 44 features, baseline CSV comparison
├── test_frequency.jl        # Frequency: Welch, Lomb-Scargle, band power
├── test_models.jl           # Models: simulate() validity, fit() convergence
├── test_evaluation.jl       # Evaluation: pipeline functions
├── test_datasets.jl         # Datasets: PhysioNet download + feature extraction (@network)
├── test_visualization.jl    # Visualization: plot functions produce Figure objects
├── testdata/                # Static test data (committed)
│   ├── example.txt          # 4193 IBI samples
│   ├── example.xdf          # Same data in XDF format
│   ├── *.atr, *.dat, *.hea  # WFDB records for read_wfdb tests
│   └── README.md
└── target/                  # Baseline CSVs for regression testing
    ├── example.csv           # 44 features for example.txt
    └── example_windowed_60_10.csv
```

### Dependency Map

```
test_input.jl            → testdata/*, optionally ann2rr
test_preprocessing.jl    → synthetic data only (no file deps)
test_features.jl         → testdata/example.txt, target/*.csv
test_frequency.jl        → testdata/example.txt
test_models.jl           → synthetic data only
test_evaluation.jl       → synthetic data + test_models helpers
test_datasets.jl         → network (@network tag), Downloads.jl
test_visualization.jl    → synthetic data, GLMakie
```

### Which Agent Runs What

| Working on... | Run this test file | Blocks others? |
|---------------|-------------------|----------------|
| Input readers | `test_input.jl` | No |
| Preprocessing | `test_preprocessing.jl` | No |
| Features / @register | `test_features.jl` | No |
| Frequency analysis | `test_frequency.jl` | No |
| Any model (LIF, VdP, ...) | `test_models.jl` | No |
| Evaluation pipeline | `test_evaluation.jl` | No |
| Dataset loading | `test_datasets.jl` | No |
| Visualization | `test_visualization.jl` | No |
| **Everything (CI)** | `runtests.jl` | — |

### Independence Rules

1. **No cross-file imports.** Each test file includes its own `using` statements and loads its own data.
2. **Preprocessing tests use synthetic data.** They do NOT depend on `read_txt` working.
3. **Model tests use synthetic IBI series.** They do NOT depend on Input or Features.
4. **Evaluation tests create mock model results.** They do NOT depend on actual model implementations.
5. **Dataset tests are network-gated.** They run only when `ENV["HEARTRATE_NETWORK_TESTS"] == "true"`.
6. **Visualization tests check Figure creation.** They do NOT render or display.

---

## 3. TDD Workflow for Agents

### Step 1: Identify your scope

Read the task assignment. Determine which module(s) you'll modify and which test file(s) are relevant.

### Step 2: Run existing tests (red/green baseline)

```bash
# Run ONLY your relevant test file
julia --project=. test/test_preprocessing.jl
```

Record what passes and what fails. Anything already failing is NOT your responsibility unless your task says to fix it.

### Step 3: Write the test first

Add your test to the appropriate test file. Follow the existing pattern:

```julia
@testset "your_function" begin
    @testset "description" begin
        # Arrange
        input = ...
        expected = ...
        # Act
        result = HeartRateLab.your_function(input)
        # Assert
        @test result == expected          # exact match
        @test result ≈ expected atol=1e-6 # floating point
        @test result isa Vector{Float64}  # type check
    end
end
```

### Step 4: Run and confirm failure

```bash
julia --project=. test/test_your_module.jl
```

The new test should fail (red). If it passes, the test may be trivial or wrong.

### Step 5: Implement

Write the minimum code to make the test pass. Follow BlueStyle conventions.

### Step 6: Run and confirm pass

```bash
julia --project=. test/test_your_module.jl
```

All tests should pass (green), including the ones that passed before.

### Step 7: Run the full suite (before committing)

```bash
julia --project=. -e 'using Pkg; Pkg.test()'
```

Verify you haven't broken other modules. Known failures (WFDB errors without `ann2rr`, floating-point precision in Features) are acceptable.

---

## 4. Test Tags and Filtering

### Network tests

Tests that download data are gated:

```julia
# In test_datasets.jl:
const RUN_NETWORK = get(ENV, "HEARTRATE_NETWORK_TESTS", "false") == "true"

@testset "Datasets" begin
    if !RUN_NETWORK
        @info "Skipping network tests. Set HEARTRATE_NETWORK_TESTS=true to enable."
        return
    end
    # ... network tests here
end
```

Run with: `HEARTRATE_NETWORK_TESTS=true julia --project=. test/test_datasets.jl`

### WFDB tests

```julia
# In test_input.jl:
const HAS_WFDB = !isnothing(Sys.which("ann2rr"))

@testset "read_wfdb" begin
    if !HAS_WFDB
        @info "Skipping WFDB tests. Install wfdb-10.7.0 or use Docker (hrlab image)."
        return
    end
    # ... wfdb tests here
end
```

### Visualization tests

```julia
# In test_visualization.jl:
const HAS_DISPLAY = haskey(ENV, "DISPLAY") || Sys.iswindows()

@testset "Visualization" begin
    if !HAS_DISPLAY
        @info "Skipping visualization tests. No display available."
        return
    end
    # ... visualization tests here
end
```

---

## 5. Baseline Regression Testing

Feature extraction tests compare against stored CSV baselines in `test/target/`.

### Updating baselines

When a feature computation is intentionally changed:

1. Run feature extraction and inspect the diff
2. Verify the new values are correct
3. Regenerate the baseline:
   ```julia
   julia --project=. -e '
   cd("test")
   using HeartRateLab, CSV, DataFrames
   data = HeartRateLab.read_txt("testdata/example.txt")
   fr = HeartRateLab.Features.feature_registry
   ds = HeartRateLab.Features.extract_feature_set(data, features=String.(keys(fr)))
   CSV.write("target/example.csv", ds)
   '
   ```
4. Run the full test suite to confirm
5. Commit the updated CSV with a clear message explaining why values changed

### Floating-point comparisons

Use `isapprox` (not `isequal`) for computed feature values:

```julia
# Prefer:
@test isapprox(ds, target, rtol=1e-10)

# Not:
@test isequal(ds, target)  # fails on harmless precision differences
```

---

## 6. Dataset Tests as Scientific Benchmarks

Dataset tests serve a dual purpose:

1. **Software testing:** verify that download, parsing, feature extraction, model fitting, and evaluation all work end-to-end
2. **Scientific benchmarking:** produce normative populational statistics across PhysioNet datasets

### Structure

```julia
# test/test_datasets.jl

@testset "NSRDB normative statistics" begin
    records = ["16265", "16272", "16273", ...]  # curated list
    all_features = DataFrame()
    for record in records
        data = HeartRateLab.load_nsrdb(record)
        features = HeartRateLab.Features.extract_feature_set(data)
        features.record = [record]
        append!(all_features, features)
    end
    # Basic sanity tests
    @test nrow(all_features) == length(records)
    @test all(all_features.mean .> 0)
    @test all(300 .< all_features.mean .< 1500)  # plausible IBI range

    # Normative statistics (scientific output)
    # These are logged, not just tested — they accumulate as more datasets are added
    @info "NSRDB normative statistics" mean_hr=mean(all_features.mean_hr) std_hr=std(all_features.mean_hr)
end
```

### Adding new datasets

To extend normative benchmarks:

1. Add the dataset wrapper to `src/Datasets.jl` (e.g., `load_newdb(record)`)
2. Add a `@testset` block in `test_datasets.jl` with the curated record list
3. Add sanity checks (plausible ranges, no NaN pollution)
4. Run with `HEARTRATE_NETWORK_TESTS=true`

Over time, these benchmarks accumulate populational statistics that serve as reference values for the scientific community.

---

## 7. Known Issues

| Issue | Impact | Workaround |
|-------|--------|------------|
| `DFA` package unregistered | Docker build fails without Manifest.toml | Copy Manifest.toml in Dockerfile |
| No `ann2rr` in base Julia image | WFDB tests skip | Use `hrlab` Docker image or install WFDB |
| Feature baselines use `isequal` | 2 false failures from fp precision | Switch to `isapprox` with `rtol=1e-10` |
| `nix run .#build` broken | Cascades from DFA issue | Fix Dockerfile first |
| GLMakie requires display | Visualization tests fail headless | Gate on `DISPLAY` env var |
