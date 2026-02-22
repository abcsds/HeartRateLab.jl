# HeartRateLab Development Workflow

**Last Updated**: February 22, 2026
**Intended For**: All agents and developers working on this repository

## TL;DR: Quick Start

```bash
# 1. First time working on this repo? Read this file!

# 2. Setup (once per feature branch)
nix run .#build

# 3. Develop (repeat as needed)
# Edit code...
nix run .#test
# If tests fail, fix code and re-run nix run .#test

# 4. When done
git add <files>
git commit -m "Your message"
# (Don't push unless explicitly asked or authorized)
```

---

## Environment

### System Requirements

You need **ONE** of:
- **Docker** installed + `nix flake` (preferred)
- **Docker Desktop** on macOS/Windows
- Or: Follow the "Docker alternative" section below

### Julia Version

This project targets **Julia 1.11+**. All testing/rendering uses:
- Official `julia:1.11-bookworm` Docker image
- Reproducible across Linux, macOS, Windows

### WFDB Tools

Input reading tests require `ann2rr` (from PhysioNet WFDB toolkit). The Docker container includes this. Local testing will skip WFDB tests gracefully if missing.

---

## The Nix Build System

### What is Nix?

Nix ensures reproducible builds across developers and CI/CD:
- **Pinned dependencies**: Same Julia 1.11, same packages for everyone
- **Declarative**: `flake.nix` defines exactly what tools you get
- **Isolated**: No conflicts with your system's Julia or Python

### Available Commands

| Command | Purpose | Output | Time |
|---------|---------|--------|------|
| `nix run .#build` | Build dev Docker image | `hrlab:latest` (3.8 GB) | 3-5 min |
| `nix run .#test` | Run full test suite | Test results, exit code 0/1 | 2-10 min |
| `nix run .#build-render` | Build render image with Quarto | `hrlab:render` (4.8 GB) | 5-10 min |
| `nix run .#render` | Render .qmd notebook to HTML | `docs/flagship_demo.html` | 1-5 min |
| `nix run` | Interactive Julia REPL | Julia prompt in container | Instant |
| `nix run .#act` | GitHub Actions local test | CI workflow output | Varies |

---

## Development Workflows by Task Type

### ✅ Workflow 1: Implementing Features (Models, Functions, etc.)

When implementing Phase B-G from PLAN.md:

```bash
# 1. Setup workspace (once at start)
nix run .#build
# Wait for Docker image to build (~3-5 min)

# 2. Edit code
vim src/Models.jl          # Make your changes

# 3. Test your changes
nix run .#test
# Watch for:
#   - @test_broken = expected (not yet implemented)
#   - Error = bug in your code
#   - Pass = feature works!

# 4. Iterate: repeat steps 2-3 until tests pass

# 5. Verify all tests pass
nix run .#test
# Exit code should be 0

# 6. Commit your work
git add src/Models.jl test/test_models.jl
git commit -m "Implement VanDerPol Bayesian fitting with Turing.jl"
```

### ✅ Workflow 2: Rendering Notebooks (Quarto)

When creating/updating .qmd demo notebooks:

```bash
# 1. Build render image (includes Quarto + IJulia)
nix run .#build-render
# Wait for image (~5-10 min, only needed once)

# 2. Edit your notebook
vim docs/flagship_demo.qmd

# 3. Render to HTML
nix run .#render

# 4. Preview the output
ls -lh docs/flagship_demo.html
# Check file size and modification time

# 5. If render failed
# Read the error message carefully:
#   - "Render failed - output file does not exist" → run build-render first
#   - Execution error → fix your notebook code
#   - Missing package → add to Project.toml

# 6. Verify notebook runs correctly
# (Either manually inspect HTML or run tests)
nix run .#test

# 7. Commit the notebook
git add docs/flagship_demo.qmd
git commit -m "Update flagship demo with new visualization"
```

### ✅ Workflow 3: Debugging/Interactive Session

When you need to test code manually or debug:

```bash
# 1. Start interactive session
nix run

# 2. You're now in a Julia REPL inside the container
julia> using HeartRateLab
julia> # Try your code here

# 3. Load and run a specific test file
julia> include("test/test_models.jl")

# 4. Exit when done
julia> exit()
# Back to your terminal
```

### ✅ Workflow 4: Just Running Tests (Minimal)

Quick test run after small changes:

```bash
nix run .#test

# That's it! Exit code tells you if tests pass:
# Exit code 0 = ✅ all tests pass
# Exit code 1 = ❌ some tests failed (read output)
```

---

## Understanding Test Output

### Example: Successful Run
```
Testing HeartRateLab
  ...package loading...
Test Summary: 14 passed
✓ Tests passed (exit code 0)
```

### Example: With @test_broken (Expected)
```
Test Summary:
  14 passed
  4 broken  ← These are @test_broken blocks (not yet implemented)
✓ Tests passed (exit code 0)  ← Still passes! Broken tests are expected
```

### Example: Actual Failure (Needs Fixing)
```
Test Summary:
  14 passed
  1 failed  ← This is an actual error
❌ Tests FAILED (exit code 1)

...error message showing which test failed...
```

### How to Read Error Messages

1. **Look for line numbers**: `Error in test/test_models.jl:153`
2. **Identify the failing test**: Find that line in the test file
3. **Read the error type**: `ArgumentError: ...`, `MethodError: ...`, etc.
4. **Stack trace**: Shows which functions called which (bottom-most is usually the problem)

---

## Common Scenarios

### Scenario 1: Test Hangs or Takes Forever

**Symptom**: Test hangs after "Precompiling HeartRateLab"

**Likely Cause**: Code bug causing infinite loop or exponential behavior

**Solution**:
1. Press `Ctrl+C` to stop
2. Review the last code change you made
3. Look for loops that might not terminate
4. Fix the code and try again

### Scenario 2: "ann2rr not found" Error

**Symptom**: Some tests skip with "ann2rr not found"

**Normal behavior**: WFDB tools are optional. Some Input tests skip gracefully.

**If this is blocking your work**: Run inside the container:
```bash
nix run
# Inside container:
julia> using Pkg
julia> Pkg.test()  # Full tests with WFDB available
```

### Scenario 3: "Package manifest mismatch" Warnings

**Symptom**: Lots of manifest warnings but tests still run

**Normal behavior**: Expected when fresh container. Warnings are harmless.

**Not an error**: Tests will still run and complete successfully.

### Scenario 4: Docker Image Build Fails

**Symptom**: `nix run .#build` errors

**Common Causes**:
1. Disk space full → Free up space
2. Network issue → Check internet connection
3. Docker daemon not running → Start Docker
4. Dockerfile syntax error → Review recent Dockerfile changes

**Solution**:
```bash
# Remove old images and try again
docker image prune -a
nix run .#build
```

### Scenario 5: "fit() method not found"

**Symptom**: Tests fail because `fit()` doesn't exist

**Normal during Phase B-F implementation**: The fit() method is being implemented incrementally

**Expected behavior**:
- Phase A: Tests marked as `@test_broken`
- Phase B-F: Tests gradually move from `@test_broken` to passing
- When complete: All tests pass

---

## Docker Alternative (If Nix Unavailable)

If you don't have Nix flakes but have Docker:

```bash
# Build dev image
docker build . -t hrlab:latest

# Run tests
docker run --rm -v .:/workdir -w /workdir hrlab:latest \
  julia --project=. -e 'using Pkg; Pkg.test()'

# Build render image (with Quarto)
docker build --build-arg INSTALL_QUARTO=true . -t hrlab:render

# Render notebook
docker run --rm -v .:/workdir hrlab:render \
  quarto render /workdir/docs/flagship_demo.qmd --to html --execute
```

---

## Key Files You'll Interact With

| File | Purpose | Edit when... |
|------|---------|--------------|
| `src/Models.jl` | Model implementations | Implementing Phase B-F |
| `test/test_models.jl` | Model tests | Tests need updates (already fixed in Phase A) |
| `docs/flagship_demo.qmd` | Flagship demo notebook | Creating/updating demos |
| `docs/comprehensive_demo.qmd` | Comprehensive demo | Phase G (creating new) |
| `Project.toml` | Dependencies | Adding new packages needed by models |
| `flake.nix` | Nix configuration | Rarely (unless changing Julia version) |
| `Dockerfile` | Container definition | Rarely (unless adding new system tools) |

---

## Testing Best Practices

### ✅ DO:
- Run `nix run .#test` after every code change
- Read test output carefully (error messages tell you what's wrong)
- Use `@test_broken` for unimplemented features
- Write tests BEFORE writing implementation (TDD)
- Commit only when `nix run .#test` passes

### ❌ DON'T:
- Run `julia --project=. -e 'Pkg.test()'` directly (missing WFDB tools)
- Use `try/catch` to hide test failures (sham tests)
- Commit code that makes tests fail
- Ignore @test_broken markers (they're expected)
- Skip the `nix run .#build` step for new features

---

## Commit Message Convention

When committing your work:

```bash
git commit -m "Phase B: Implement VanDerPol Bayesian fitting with Turing.jl

- Add parameter_space() for priors (μ, heart_rate, σ_noise)
- Implement fit() with NUTS MCMC sampling
- Extract MAP estimates and posterior diagnostics
- All R-hat values < 1.1 for convergence

Fixes sham tests, enables downstream Phases C-G"
```

Good commit messages:
- Describe WHAT and WHY, not just WHAT
- Reference the phase (Phase B, C, etc.)
- Mention any blockers resolved
- Keep under 72 characters for title

---

## Reproducibility Guarantees

This workflow ensures:

✅ **Same environment for all developers**: Docker pins Julia version, WFDB, all packages
✅ **Same results locally and in CI**: GitHub Actions use identical containers
✅ **Version control of dependencies**: Manifest.toml pins every package version
✅ **Fast iteration**: Docker layer caching makes rebuilds quick
✅ **No "works on my machine"**: All tests run in reproducible container

---

## Getting Help

If you're stuck:

1. **Read this file** (you're already doing great!)
2. **Check AGENTS.md** for architecture context
3. **Check PLAN.md** for current implementation status
4. **Read error messages carefully** (they're usually very helpful)
5. **Try running `nix run` for interactive debugging**
6. **Check test output**: Sometimes error is in a test, not your code

---

## Summary

| Action | Command |
|--------|---------|
| Setup once | `nix run .#build` |
| Test your code | `nix run .#test` |
| Debug interactively | `nix run` |
| Render notebook | `nix run .#build-render && nix run .#render` |
| Check status | `git status` |
| Commit work | `git commit -m "..."` |

**Remember**: Always test with `nix run .#test` before committing!
