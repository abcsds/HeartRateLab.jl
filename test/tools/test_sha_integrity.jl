#!/usr/bin/env julia
# Quick test for SHA integrity helpers from collect_normative_datasets.jl
# Run: julia test/tools/test_sha_integrity.jl

using SHA, TOML, Downloads, Dates

# ─── Copy the SHA helper functions inline ─────────────────────────────────────

const SHA_MANIFEST_FILE = "sha256_manifest.toml"

function sha256_file(path::String)::String
    return open(path, "r") do io
        bytes2hex(sha256(io))
    end
end

function load_sha_manifest(dir::String)::Dict{String,String}
    manifest_path = joinpath(dir, SHA_MANIFEST_FILE)
    if isfile(manifest_path)
        raw = TOML.parsefile(manifest_path)
        hashes = get(raw, "hashes", Dict{String,Any}())
        return Dict{String,String}(string(k) => string(v) for (k, v) in hashes)
    else
        return Dict{String,String}()
    end
end

function save_sha_manifest(dir::String, manifest::Dict{String,String})
    data = Dict("hashes" => manifest,
                "_meta"  => Dict("description" => "SHA-256 hashes of downloaded files",
                                 "updated"     => string(now())))
    open(joinpath(dir, SHA_MANIFEST_FILE), "w") do io
        TOML.print(io, data)
    end
end

function file_integrity(path::String, manifest::Dict{String,String})::Symbol
    fname = basename(path)
    if !isfile(path)
        return :missing
    end
    expected = get(manifest, fname, nothing)
    if isnothing(expected)
        return :missing
    end
    actual = sha256_file(path)
    return actual == expected ? :match : :mismatch
end

function download_with_sha!(url::String, dest::String,
                            manifest::Dict{String,String})::Bool
    status = file_integrity(dest, manifest)
    if status == :match
        println("    ✓ SKIP (SHA match): $(basename(dest))")
        return true
    elseif status == :mismatch
        println("    ⟳ SHA MISMATCH: $(basename(dest)) — re-downloading")
        rm(dest; force=true)
    else
        println("    ↓ DOWNLOAD: $(basename(dest))")
    end
    try
        Downloads.download(url, dest)
        manifest[basename(dest)] = sha256_file(dest)
        println("      SHA: $(manifest[basename(dest)])")
        return true
    catch e
        println("    ✗ Download failed: $url  ($e)")
        return false
    end
end

# ─── Test harness ─────────────────────────────────────────────────────────────

tmpdir = mktempdir()
println("Test directory: $tmpdir\n")

# Use a small known PhysioNet file
test_url = "https://physionet.org/files/nsrdb/1.0.0/16265.hea"
test_file = joinpath(tmpdir, "16265.hea")

manifest = Dict{String,String}()

# Test 1: Fresh download — should download and record SHA
println("═══ Test 1: Fresh download (no manifest, no file) ═══")
@assert !isfile(test_file) "File should not exist yet"
@assert isempty(manifest) "Manifest should be empty"
ok = download_with_sha!(test_url, test_file, manifest)
@assert ok "Download should succeed"
@assert isfile(test_file) "File should exist after download"
@assert haskey(manifest, "16265.hea") "Manifest should have the file hash"
sha1 = manifest["16265.hea"]
println("  ✓ File downloaded, SHA recorded: $(sha1[1:16])...\n")

# Test 2: Re-download with manifest — should SKIP
println("═══ Test 2: Re-download with valid manifest — should skip ═══")
ok2 = download_with_sha!(test_url, test_file, manifest)
@assert ok2 "Should return true (skip)"
@assert manifest["16265.hea"] == sha1 "SHA should be unchanged"
println("  ✓ Download correctly skipped\n")

# Test 3: Save and reload manifest
println("═══ Test 3: Persist manifest to TOML, reload ═══")
save_sha_manifest(tmpdir, manifest)
manifest_path = joinpath(tmpdir, SHA_MANIFEST_FILE)
@assert isfile(manifest_path) "Manifest TOML should exist"
println("  Written: $manifest_path")

reloaded = load_sha_manifest(tmpdir)
@assert reloaded["16265.hea"] == sha1 "Reloaded SHA should match"
println("  ✓ Manifest round-trips correctly\n")

# Test 4: Corrupt file — should detect mismatch and re-download
println("═══ Test 4: Corrupt file — should detect mismatch ═══")
open(test_file, "a") do io
    write(io, "\n# corrupted!")
end
corrupted_sha = sha256_file(test_file)
@assert corrupted_sha != sha1 "Corrupted file should have different SHA"
println("  Corrupted SHA: $(corrupted_sha[1:16])...")

status = file_integrity(test_file, manifest)
@assert status == :mismatch "Should detect mismatch"
println("  ✓ Correctly detected :mismatch")

# Re-download should fix it
ok3 = download_with_sha!(test_url, test_file, manifest)
@assert ok3 "Re-download should succeed"
@assert manifest["16265.hea"] == sha1 "SHA should be restored to original"
println("  ✓ Re-downloaded and SHA restored\n")

# Test 5: File exists but not in manifest — should treat as :missing
println("═══ Test 5: File without manifest entry — should download ═══")
manifest2 = Dict{String,String}()  # empty manifest
status2 = file_integrity(test_file, manifest2)
@assert status2 == :missing "File not in manifest should be :missing"
ok4 = download_with_sha!(test_url, test_file, manifest2)
@assert ok4 "Should succeed"
@assert haskey(manifest2, "16265.hea") "Should add to manifest"
println("  ✓ Handled correctly\n")

# Test 6: Non-existent file — should download
println("═══ Test 6: Missing file — should download ═══")
rm(test_file; force=true)
manifest3 = Dict("16265.hea" => sha1)
status3 = file_integrity(test_file, manifest3)
@assert status3 == :missing "Non-existent file should be :missing"
ok5 = download_with_sha!(test_url, test_file, manifest3)
@assert ok5 "Should download"
@assert manifest3["16265.hea"] == sha1 "SHA should match original"
println("  ✓ Downloaded missing file correctly\n")

# Cleanup
rm(tmpdir; recursive=true)

println("═"^50)
println("All 6 tests passed! SHA integrity system works correctly.")
println("═"^50)
